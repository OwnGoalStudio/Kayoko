//
//  KayokoCopyLogImporter.m
//  Kayoko
//

#import "KayokoCopyLogImporter.h"
#import "KayokoHistoryStore.h"
#import "KayokoImportFileStager.h"
#import "KayokoPasteboardItem.h"
#import "KayokoRichTextRepresentation.h"

#import <CommonCrypto/CommonDigest.h>
#import <ImageIO/ImageIO.h>
#import <math.h>
#import <sys/stat.h>

static NSString *const kKayokoCopyLogImporterErrorDomain = @"com.82flex.kayoko.copylog-importer";
static NSString *const kKayokoCopyLogSnippetsSection = @"Snippets";
static NSString *const kKayokoCopyLogFavoritesSection = @"Favorites";
static NSString *const kKayokoCopyLogHistoryKey = @"history";
static NSString *const kKayokoCopyLogFavoritesKey = @"favorites";
static NSString *const kKayokoCopyLogRemoteClipboardType = @"com.apple.is-remote-clipboard";

@interface KayokoCopyLogSourceRecord : NSObject
@property(nonatomic, copy) NSString *path;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *historyKey;
@property(nonatomic, strong) NSDate *capturedAt;
@end

@implementation KayokoCopyLogSourceRecord
@end

@interface KayokoCopyLogImagePayload : NSObject
@property(nonatomic, strong) NSData *data;
@property(nonatomic, copy) NSString *extension;
@property(nonatomic, assign) NSUInteger pixelWidth;
@property(nonatomic, assign) NSUInteger pixelHeight;
@end

@implementation KayokoCopyLogImagePayload
@end

@interface KayokoCopyLogPreparedItem : NSObject
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *dictionary;
@property(nonatomic, copy) NSString *historyKey;
@property(nonatomic, copy, nullable) NSString *imageName;
@property(nonatomic, strong, nullable) NSData *imageData;
@property(nonatomic, copy, nullable) NSString *richTextName;
@property(nonatomic, strong, nullable) NSData *richTextData;
@end

@implementation KayokoCopyLogPreparedItem
@end

@interface KayokoCopyLogImporter ()
@property(nonatomic, copy) NSString *sourceDirectoryPath;
@property(nonatomic, strong) KayokoHistoryStore *historyStore;
@property(nonatomic, strong) NSDateFormatter *dateFormatter;
@property(nonatomic, assign) NSUInteger skippedItemCount;
@end

@implementation KayokoCopyLogImporter

- (instancetype)initWithSourceDirectoryPath:(NSString *)sourceDirectoryPath
                               historyStore:(KayokoHistoryStore *)historyStore {
    self = [super init];
    if (self) {
        _sourceDirectoryPath = [sourceDirectoryPath copy];
        _historyStore = historyStore;
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        _dateFormatter.timeZone = [NSTimeZone localTimeZone];
        _dateFormatter.dateFormat = @"dd-MM-yyyy HH:mm:ss";
        _dateFormatter.lenient = NO;
    }
    return self;
}

#pragma mark - Import

- (BOOL)runWithSkippedItemCount:(NSUInteger *)skippedItemCount error:(NSError **)error {
    self.skippedItemCount = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    struct stat sourceDirectoryStat;
    if (![fileManager fileExistsAtPath:self.sourceDirectoryPath isDirectory:&isDirectory] || !isDirectory ||
        lstat([self.sourceDirectoryPath fileSystemRepresentation], &sourceDirectoryStat) != 0 ||
        !S_ISDIR(sourceDirectoryStat.st_mode) || ![fileManager isReadableFileAtPath:self.sourceDirectoryPath]) {
        [self populateError:error code:1 formatKey:@"CopyLog data directory was not found." detail:nil];
        return NO;
    }

    NSArray<KayokoCopyLogSourceRecord *> *favoriteRecords = [self recordsForSection:kKayokoCopyLogFavoritesSection
                                                                         historyKey:kKayokoCopyLogFavoritesKey
                                                                              error:error];
    if (!favoriteRecords) {
        return NO;
    }
    NSArray<KayokoCopyLogSourceRecord *> *snippetRecords = [self recordsForSection:kKayokoCopyLogSnippetsSection
                                                                        historyKey:kKayokoCopyLogHistoryKey
                                                                             error:error];
    if (!snippetRecords) {
        return NO;
    }

    NSMutableSet<NSString *> *favoriteNames = [[NSMutableSet alloc] initWithCapacity:[favoriteRecords count]];
    for (KayokoCopyLogSourceRecord *record in favoriteRecords) {
        [favoriteNames addObject:record.name];
    }

    NSMutableArray<KayokoCopyLogSourceRecord *> *records = [favoriteRecords mutableCopy];
    for (KayokoCopyLogSourceRecord *record in snippetRecords) {
        if (![favoriteNames containsObject:record.name]) {
            [records addObject:record];
        }
    }
    [records
        sortUsingComparator:^NSComparisonResult(KayokoCopyLogSourceRecord *left, KayokoCopyLogSourceRecord *right) {
          NSComparisonResult dateResult = [right.capturedAt compare:left.capturedAt];
          return dateResult == NSOrderedSame ? [right.name compare:left.name] : dateResult;
        }];

    NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *>
        *existingItemsByHistoryKey = [[NSMutableDictionary alloc] init];
    for (NSString *historyKey in @[ kKayokoCopyLogHistoryKey, kKayokoCopyLogFavoritesKey ]) {
        NSArray<NSDictionary<NSString *, id> *> *items = [self.historyStore itemsForHistoryKey:historyKey error:error];
        if (!items) {
            return NO;
        }
        NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *itemsByContent =
            [[NSMutableDictionary alloc] initWithCapacity:[items count]];
        for (NSDictionary<NSString *, id> *item in items) {
            NSString *content = [self stringValue:item[kKayokoItemKeyContent]];
            if ([content length] > 0) {
                itemsByContent[content] = item;
            }
        }
        existingItemsByHistoryKey[historyKey] = itemsByContent;
    }

    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary<NSString *, id> *> *> *itemsByHistoryKey = [@{
        kKayokoCopyLogHistoryKey : [[NSMutableArray alloc] init],
        kKayokoCopyLogFavoritesKey : [[NSMutableArray alloc] init]
    } mutableCopy];
    NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *seenContentsByHistoryKey = [@{
        kKayokoCopyLogHistoryKey : [[NSMutableSet alloc] init],
        kKayokoCopyLogFavoritesKey : [[NSMutableSet alloc] init]
    } mutableCopy];
    NSMutableDictionary<NSString *, NSData *> *imageDataByName = [[NSMutableDictionary alloc] init];
    NSMutableDictionary<NSString *, NSData *> *richTextDataByName = [[NSMutableDictionary alloc] init];

    for (KayokoCopyLogSourceRecord *record in records) {
        NSDictionary<NSString *, id> *propertyList = [self dictionaryPropertyListAtPath:record.path error:error];
        if (!propertyList) {
            return NO;
        }

        NSString *bundleIdentifier = [self stringValue:propertyList[@"bundleID"]];
        BOOL recordIsRemote = [bundleIdentifier isEqualToString:kKayokoCopyLogRemoteClipboardType] ||
                              propertyList[kKayokoCopyLogRemoteClipboardType] != nil;
        if ([bundleIdentifier length] == 0) {
            bundleIdentifier = @"com.apple.springboard";
        }
        NSString *note = [self stringValue:propertyList[@"title"]];
        id itemsValue = propertyList[@"items"];
        NSArray<NSDictionary<NSString *, id> *> *sourceItems = nil;
        if (itemsValue) {
            if (![itemsValue isKindOfClass:[NSArray class]] || [(NSArray *)itemsValue count] == 0) {
                [self populateInvalidDataError:error
                                        detail:[NSString stringWithFormat:@"%@ has no items", record.name]];
                return NO;
            }
            sourceItems = itemsValue;
        } else {
            NSString *legacySnippet = [self stringValue:propertyList[@"snippet"]];
            if ([legacySnippet length] == 0) {
                [self populateInvalidDataError:error
                                        detail:[NSString stringWithFormat:@"%@ has no items", record.name]];
                return NO;
            }
            sourceItems = @[ @{@"public.plain-text" : legacySnippet} ];
        }

        for (id sourceItemValue in sourceItems) {
            if (![sourceItemValue isKindOfClass:[NSDictionary class]]) {
                [self populateInvalidDataError:error
                                        detail:[NSString stringWithFormat:@"%@ contains an invalid item", record.name]];
                return NO;
            }

            NSDictionary<NSString *, id> *sourceItem = sourceItemValue;
            NSString *itemBundleIdentifier = recordIsRemote || sourceItem[kKayokoCopyLogRemoteClipboardType] != nil
                                                 ? kKayokoContinuityBundleIdentifier
                                                 : bundleIdentifier;
            KayokoCopyLogPreparedItem *preparedItem = [self preparedItemForSourceItem:sourceItem
                                                                           historyKey:record.historyKey
                                                                     bundleIdentifier:itemBundleIdentifier
                                                                           capturedAt:record.capturedAt
                                                                                 note:note];
            if (!preparedItem) {
                self.skippedItemCount++;
                continue;
            }

            NSString *content = [self stringValue:preparedItem.dictionary[kKayokoItemKeyContent]];
            NSMutableSet<NSString *> *seenContents = seenContentsByHistoryKey[record.historyKey];
            if ([content length] == 0 || [seenContents containsObject:content]) {
                continue;
            }
            [seenContents addObject:content];

            NSDictionary<NSString *, id> *existingItem = existingItemsByHistoryKey[record.historyKey][content];
            BOOL alreadyExists = existingItem != nil;
            BOOL canFillRichText = [preparedItem.richTextName length] > 0 &&
                                   [[self stringValue:existingItem[kKayokoItemKeyRichTextName]] length] == 0;
            if (!alreadyExists || canFillRichText) {
                [itemsByHistoryKey[record.historyKey] addObject:preparedItem.dictionary];
            }

            if ([preparedItem.imageName length] > 0 && preparedItem.imageData) {
                NSData *plannedData = imageDataByName[preparedItem.imageName];
                if (plannedData && ![plannedData isEqualToData:preparedItem.imageData]) {
                    [self populateInvalidDataError:error
                                            detail:[NSString stringWithFormat:@"conflicting image %@",
                                                                              preparedItem.imageName]];
                    return NO;
                }
                imageDataByName[preparedItem.imageName] = preparedItem.imageData;
            }
            if ([preparedItem.richTextName length] > 0 && preparedItem.richTextData &&
                (!alreadyExists || canFillRichText)) {
                NSData *plannedData = richTextDataByName[preparedItem.richTextName];
                if (plannedData && ![plannedData isEqualToData:preparedItem.richTextData]) {
                    [self populateInvalidDataError:error
                                            detail:[NSString stringWithFormat:@"conflicting rich text %@",
                                                                              preparedItem.richTextName]];
                    return NO;
                }
                richTextDataByName[preparedItem.richTextName] = preparedItem.richTextData;
            }
        }
    }

    NSString *dataDirectoryPath = [self.historyStore.databasePath stringByDeletingLastPathComponent];
    KayokoImportFileStager *fileStager = [[KayokoImportFileStager alloc] initWithBaseDirectoryPath:dataDirectoryPath
                                                                                            prefix:@"copylog-import"];
    if (![fileStager addDataByName:imageDataByName targetDirectory:self.historyStore.imagesPath error:error] ||
        ![fileStager addDataByName:richTextDataByName targetDirectory:self.historyStore.richTextPath error:error]) {
        NSError *rollbackError = nil;
        if (![fileStager rollbackWithError:&rollbackError] && error) {
            *error = rollbackError;
        }
        return NO;
    }
    if (![fileStager commitWithError:error]) {
        return NO;
    }
    if (![self.historyStore importItemDictionariesByHistoryKey:itemsByHistoryKey error:error]) {
        NSError *rollbackError = nil;
        if (![fileStager rollbackWithError:&rollbackError] && error) {
            *error = rollbackError;
        }
        return NO;
    }

    if (skippedItemCount) {
        *skippedItemCount = self.skippedItemCount;
    }
    return YES;
}

#pragma mark - Source Records

- (NSArray<KayokoCopyLogSourceRecord *> *)recordsForSection:(NSString *)section
                                                 historyKey:(NSString *)historyKey
                                                      error:(NSError **)error {
    NSString *sectionPath = [self.sourceDirectoryPath stringByAppendingPathComponent:section];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:sectionPath isDirectory:&isDirectory]) {
        struct stat missingSectionStat;
        if (lstat([sectionPath fileSystemRepresentation], &missingSectionStat) == 0) {
            [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"%@ is not readable", section]];
            return nil;
        }
        return @[];
    }
    struct stat sectionStat;
    if (!isDirectory || lstat([sectionPath fileSystemRepresentation], &sectionStat) != 0 ||
        !S_ISDIR(sectionStat.st_mode) || ![fileManager isReadableFileAtPath:sectionPath]) {
        [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"%@ is not readable", section]];
        return nil;
    }

    NSArray<NSString *> *names = [fileManager contentsOfDirectoryAtPath:sectionPath error:error];
    if (!names) {
        NSError *underlyingError = error ? *error : nil;
        [self populateError:error
                       code:2
                  formatKey:@"Unable to read CopyLog data: %@"
                     detail:[underlyingError localizedDescription] ?: section];
        return nil;
    }

    NSMutableArray<KayokoCopyLogSourceRecord *> *records = [[NSMutableArray alloc] init];
    for (NSString *name in names) {
        if (![[[name pathExtension] lowercaseString] isEqualToString:@"plist"]) {
            continue;
        }
        NSString *timestamp = [name stringByDeletingPathExtension];
        NSDate *capturedAt = [self.dateFormatter dateFromString:timestamp];
        if (!capturedAt || ![[self.dateFormatter stringFromDate:capturedAt] isEqualToString:timestamp]) {
            [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"invalid timestamp %@", timestamp]];
            return nil;
        }

        NSString *path = [sectionPath stringByAppendingPathComponent:name];
        NSString *standardizedSectionPath = [[sectionPath stringByStandardizingPath] stringByAppendingString:@"/"];
        if (![[path stringByStandardizingPath] hasPrefix:standardizedSectionPath]) {
            [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"invalid item path %@", name]];
            return nil;
        }
        BOOL itemIsDirectory = NO;
        if (![fileManager fileExistsAtPath:path isDirectory:&itemIsDirectory] || itemIsDirectory) {
            [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"invalid item path %@", name]];
            return nil;
        }

        KayokoCopyLogSourceRecord *record = [[KayokoCopyLogSourceRecord alloc] init];
        record.path = path;
        record.name = name;
        record.historyKey = historyKey;
        record.capturedAt = capturedAt;
        [records addObject:record];
    }
    return records;
}

#pragma mark - Payload Selection

- (KayokoCopyLogPreparedItem *)preparedItemForSourceItem:(NSDictionary<NSString *, id> *)sourceItem
                                              historyKey:(NSString *)historyKey
                                        bundleIdentifier:(NSString *)bundleIdentifier
                                              capturedAt:(NSDate *)capturedAt
                                                    note:(NSString *)note {
    KayokoCopyLogImagePayload *imagePayload = [self imagePayloadFromSourceItem:sourceItem];
    NSString *text = imagePayload ? nil : [self textFromSourceItem:sourceItem];
    KayokoRichTextRepresentation *richText =
        imagePayload ? nil : [KayokoRichTextRepresentation preferredRepresentationFromDictionary:sourceItem];
    if ([text length] == 0 && richText) {
        text = [richText plainText];
    }
    if (!imagePayload && [text length] == 0) {
        return nil;
    }

    KayokoCopyLogPreparedItem *item = [[KayokoCopyLogPreparedItem alloc] init];
    item.historyKey = historyKey;
    NSMutableDictionary<NSString *, id> *dictionary = [@{
        kKayokoItemKeyBundleIdentifier : bundleIdentifier,
        kKayokoItemKeyCapturedAt : @([capturedAt timeIntervalSince1970])
    } mutableCopy];
    if ([note length] > 0) {
        dictionary[kKayokoItemKeyNote] = note;
    }

    if (imagePayload) {
        NSString *imageName = [NSString
            stringWithFormat:@"copylog-%@.%@", [self SHA256StringForData:imagePayload.data], imagePayload.extension];
        dictionary[kKayokoItemKeyContent] = imageName;
        dictionary[kKayokoItemKeyImageName] = imageName;
        dictionary[kKayokoItemKeyImagePixelWidth] = @(imagePayload.pixelWidth);
        dictionary[kKayokoItemKeyImagePixelHeight] = @(imagePayload.pixelHeight);
        dictionary[kKayokoItemKeyImageByteCount] = @([imagePayload.data length]);
        dictionary[kKayokoItemKeyHasLink] = @NO;
        item.imageName = imageName;
        item.imageData = imagePayload.data;
    } else {
        dictionary[kKayokoItemKeyContent] = text;
        dictionary[kKayokoItemKeyImageName] = @"";
        dictionary[kKayokoItemKeyImagePixelWidth] = @0;
        dictionary[kKayokoItemKeyImagePixelHeight] = @0;
        dictionary[kKayokoItemKeyImageByteCount] = @0;
        dictionary[kKayokoItemKeyHasLink] = @([text hasPrefix:@"http://"] || [text hasPrefix:@"https://"]);
        if (richText) {
            NSString *richTextName = [richText stableFileName];
            dictionary[kKayokoItemKeyRichTextUTI] = richText.typeIdentifier;
            dictionary[kKayokoItemKeyRichTextName] = richTextName;
            item.richTextName = richTextName;
            item.richTextData = richText.data;
        }
    }
    item.dictionary = dictionary;
    return item;
}

- (KayokoCopyLogImagePayload *)imagePayloadFromSourceItem:(NSDictionary<NSString *, id> *)sourceItem {
    NSArray<NSString *> *keys =
        @[ @"copylog.image", @"public.png", @"public.jpeg", @"public.jpg", @"com.apple.uikit.image" ];
    for (NSString *key in keys) {
        id value = sourceItem[key];
        if (![value isKindOfClass:[NSData class]] || [value length] == 0) {
            continue;
        }
        KayokoCopyLogImagePayload *payload = [self imagePayloadForData:value];
        if (payload) {
            return payload;
        }
    }
    return nil;
}

- (KayokoCopyLogImagePayload *)imagePayloadForData:(NSData *)data {
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) {
        return nil;
    }
    CFStringRef type = CGImageSourceGetType(source);
    NSString *extension = nil;
    if (type && CFEqual(type, CFSTR("public.png"))) {
        extension = @"png";
    } else if (type && (CFEqual(type, CFSTR("public.jpeg")) || CFEqual(type, CFSTR("public.jpg")))) {
        extension = @"jpg";
    }
    NSDictionary *decodeOptions = @{
        (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
        (NSString *)kCGImageSourceThumbnailMaxPixelSize : @1,
        (NSString *)kCGImageSourceShouldCacheImmediately : @YES
    };
    CGImageRef decodedImage = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)decodeOptions);
    NSDictionary<NSString *, id> *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    CFRelease(source);
    NSUInteger width = [properties[(NSString *)kCGImagePropertyPixelWidth] unsignedIntegerValue];
    NSUInteger height = [properties[(NSString *)kCGImagePropertyPixelHeight] unsignedIntegerValue];
    NSUInteger orientation = [properties[(NSString *)kCGImagePropertyOrientation] unsignedIntegerValue];
    if ([extension length] == 0 || !decodedImage || width == 0 || height == 0) {
        if (decodedImage) {
            CGImageRelease(decodedImage);
        }
        return nil;
    }
    CGImageRelease(decodedImage);
    if (orientation >= 5 && orientation <= 8) {
        NSUInteger swappedWidth = width;
        width = height;
        height = swappedWidth;
    }

    KayokoCopyLogImagePayload *payload = [[KayokoCopyLogImagePayload alloc] init];
    payload.data = data;
    payload.extension = extension;
    payload.pixelWidth = width;
    payload.pixelHeight = height;
    return payload;
}

- (NSString *)textFromSourceItem:(NSDictionary<NSString *, id> *)sourceItem {
    NSArray<NSString *> *types =
        @[ @"public.utf8-plain-text", @"public.plain-text", @"public.text", @"public.url", @"public.file-url" ];
    for (NSString *type in types) {
        id value = sourceItem[type];
        if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
            return value;
        }
        if ([value isKindOfClass:[NSData class]] && [value length] > 0) {
            NSString *decoded = [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
            if ([decoded length] > 0) {
                return decoded;
            }
        }
    }
    return nil;
}

#pragma mark - Values and Errors

- (NSDictionary<NSString *, id> *)dictionaryPropertyListAtPath:(NSString *)path error:(NSError **)error {
    struct stat sourceStat;
    if (lstat([path fileSystemRepresentation], &sourceStat) == 0 && !S_ISREG(sourceStat.st_mode)) {
        [self populateInvalidDataError:error
                                detail:[NSString stringWithFormat:@"invalid item path %@", [path lastPathComponent]]];
        return nil;
    }

    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) {
        NSError *underlyingError = error ? *error : nil;
        [self populateError:error
                       code:2
                  formatKey:@"Unable to read CopyLog data: %@"
                     detail:[underlyingError localizedDescription] ?: [path lastPathComponent]];
        return nil;
    }
    NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
    id propertyList = [NSPropertyListSerialization propertyListWithData:data
                                                                options:NSPropertyListImmutable
                                                                 format:&format
                                                                  error:error];
    if (![propertyList isKindOfClass:[NSDictionary class]]) {
        NSString *detail = error && *error ? [*error localizedDescription] : [path lastPathComponent];
        [self populateInvalidDataError:error detail:detail];
        return nil;
    }
    return propertyList;
}

- (NSString *)stringValue:(id)value {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

- (NSString *)SHA256StringForData:(NSData *)data {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256([data bytes], (CC_LONG)[data length], digest);
    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        [result appendFormat:@"%02x", digest[index]];
    }
    return result;
}

- (void)populateInvalidDataError:(NSError **)error detail:(NSString *)detail {
    [self populateError:error code:2 formatKey:@"CopyLog data is invalid: %@" detail:detail];
}

- (void)populateError:(NSError **)error code:(NSInteger)code formatKey:(NSString *)formatKey detail:(NSString *)detail {
    if (!error) {
        return;
    }
    NSString *description = [detail length] > 0 ? [NSString stringWithFormat:formatKey, detail] : formatKey;
    *error = [NSError errorWithDomain:kKayokoCopyLogImporterErrorDomain
                                 code:code
                             userInfo:@{NSLocalizedDescriptionKey : description}];
}

@end
