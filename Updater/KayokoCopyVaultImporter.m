//
//  KayokoCopyVaultImporter.m
//  Kayoko
//

#import "KayokoCopyVaultImporter.h"
#import "KayokoHistoryStore.h"
#import "KayokoImportFileStager.h"
#import "KayokoPasteboardItem.h"
#import "KayokoRichTextRepresentation.h"
#import "KayokoTag.h"
#import "KayokoTagStore.h"

#import <CommonCrypto/CommonDigest.h>
#import <ImageIO/ImageIO.h>
#import <math.h>
#import <sys/stat.h>

static NSString *const kKayokoCopyVaultImporterErrorDomain = @"com.82flex.kayoko.copyvault-importer";
static NSString *const kKayokoCopyVaultHistorySection = @"History";
static NSString *const kKayokoCopyVaultArchiveSection = @"Archive";
static NSString *const kKayokoCopyVaultHistoryKey = @"history";
static NSString *const kKayokoCopyVaultFavoritesKey = @"favorites";

@interface KayokoCopyVaultPreparedItem : NSObject
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *dictionary;
@property(nonatomic, copy) NSString *historyKey;
@property(nonatomic, copy, nullable) NSString *categoryTitle;
@property(nonatomic, copy, nullable) NSString *imageName;
@property(nonatomic, strong, nullable) NSData *imageData;
@property(nonatomic, copy, nullable) NSString *richTextName;
@property(nonatomic, strong, nullable) NSData *richTextData;
@end

@implementation KayokoCopyVaultPreparedItem
@end

@interface KayokoCopyVaultImagePayload : NSObject
@property(nonatomic, strong) NSData *data;
@property(nonatomic, copy) NSString *extension;
@property(nonatomic, assign) NSUInteger pixelWidth;
@property(nonatomic, assign) NSUInteger pixelHeight;
@end

@implementation KayokoCopyVaultImagePayload
@end

@interface KayokoCopyVaultImporter ()
@property(nonatomic, copy) NSString *sourceDirectoryPath;
@property(nonatomic, strong) KayokoHistoryStore *historyStore;
@property(nonatomic, strong) KayokoTagStore *tagStore;
@property(nonatomic, strong) NSDateFormatter *dateFormatter;
@property(nonatomic, copy) NSDictionary<NSString *, NSString *> *categoryTitlesByIdentifier;
@property(nonatomic, assign) NSUInteger skippedItemCount;
- (NSString *)hexColorForCategoryTitle:(NSString *)title;
@end

@implementation KayokoCopyVaultImporter

- (instancetype)initWithSourceDirectoryPath:(NSString *)sourceDirectoryPath
                               historyStore:(KayokoHistoryStore *)historyStore
                                   tagStore:(KayokoTagStore *)tagStore {
    self = [super init];
    if (self) {
        _sourceDirectoryPath = [sourceDirectoryPath copy];
        _historyStore = historyStore;
        _tagStore = tagStore;

        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        _dateFormatter.timeZone = [NSTimeZone localTimeZone];
        _dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ssSSS";
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
        [self populateError:error code:1 formatKey:@"CopyVault data directory was not found." detail:nil];
        return NO;
    }

    NSString *indexPath = [self.sourceDirectoryPath stringByAppendingPathComponent:@"CopyVault.plist"];
    NSDictionary<NSString *, id> *index = [self dictionaryPropertyListAtPath:indexPath error:error];
    if (!index) {
        return NO;
    }

    if (![self loadCategoryConfigurationWithError:error]) {
        return NO;
    }

    NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *existingContentByHistoryKey =
        [[NSMutableDictionary alloc] init];
    NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *>
        *existingItemsByHistoryKey = [[NSMutableDictionary alloc] init];
    for (NSString *historyKey in @[ kKayokoCopyVaultHistoryKey, kKayokoCopyVaultFavoritesKey ]) {
        NSError *readError = nil;
        NSArray<NSDictionary<NSString *, id> *> *items = [self.historyStore itemsForHistoryKey:historyKey
                                                                                         error:&readError];
        if (!items) {
            if (error) {
                *error = readError;
            }
            return NO;
        }

        NSMutableSet<NSString *> *contents = [[NSMutableSet alloc] initWithCapacity:[items count]];
        NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *itemsByContent =
            [[NSMutableDictionary alloc] initWithCapacity:[items count]];
        for (NSDictionary<NSString *, id> *item in items) {
            NSString *content = [self stringValue:item[kKayokoItemKeyContent]];
            if ([content length] > 0) {
                [contents addObject:content];
                itemsByContent[content] = item;
            }
        }
        existingContentByHistoryKey[historyKey] = contents;
        existingItemsByHistoryKey[historyKey] = itemsByContent;
    }

    NSMutableArray<KayokoCopyVaultPreparedItem *> *preparedItems = [[NSMutableArray alloc] init];
    NSMutableSet<NSString *> *seenUniqueIdentifiers = [[NSMutableSet alloc] init];
    NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *seenContentByHistoryKey = @{
        kKayokoCopyVaultHistoryKey : [[NSMutableSet alloc] init],
        kKayokoCopyVaultFavoritesKey : [[NSMutableSet alloc] init]
    }
                                                                                               .mutableCopy;

    NSArray<NSDictionary<NSString *, NSString *> *> *sections = @[
        @{@"source" : kKayokoCopyVaultHistorySection, @"target" : kKayokoCopyVaultHistoryKey},
        @{@"source" : kKayokoCopyVaultArchiveSection, @"target" : kKayokoCopyVaultFavoritesKey}
    ];
    for (NSDictionary<NSString *, NSString *> *section in sections) {
        NSString *sourceSection = section[@"source"];
        NSString *historyKey = section[@"target"];
        id recordsValue = index[sourceSection];
        if (recordsValue && ![recordsValue isKindOfClass:[NSArray class]]) {
            [self populateInvalidDataError:error
                                    detail:[NSString stringWithFormat:@"%@ is not an array", sourceSection]];
            return NO;
        }

        NSArray *records = [recordsValue isKindOfClass:[NSArray class]] ? recordsValue : @[];
        for (id recordValue in records) {
            if (![recordValue isKindOfClass:[NSDictionary class]]) {
                [self
                    populateInvalidDataError:error
                                      detail:[NSString stringWithFormat:@"%@ contains an invalid item", sourceSection]];
                return NO;
            }

            NSString *sourceUniqueIdentifier =
                [self normalizedUniqueIdentifier:[self stringValue:recordValue[@"unique"]]];
            BOOL duplicateUniqueIdentifier =
                [sourceUniqueIdentifier length] > 0 && [seenUniqueIdentifiers containsObject:sourceUniqueIdentifier];
            if ([sourceUniqueIdentifier length] > 0) {
                [seenUniqueIdentifiers addObject:sourceUniqueIdentifier];
            }

            NSArray<KayokoCopyVaultPreparedItem *> *recordItems = [self preparedItemsForRecord:recordValue
                                                                                 sourceSection:sourceSection
                                                                                    historyKey:historyKey
                                                                                         error:error];
            if (!recordItems) {
                return NO;
            }

            for (KayokoCopyVaultPreparedItem *item in recordItems) {
                NSString *content = [self stringValue:item.dictionary[kKayokoItemKeyContent]];
                if ([content length] == 0 || duplicateUniqueIdentifier) {
                    continue;
                }

                NSMutableSet<NSString *> *seenContents = seenContentByHistoryKey[historyKey];
                if ([seenContents containsObject:content]) {
                    continue;
                }
                [seenContents addObject:content];

                BOOL alreadyExists = [existingContentByHistoryKey[historyKey] containsObject:content];
                NSDictionary<NSString *, id> *existingItem = existingItemsByHistoryKey[historyKey][content];
                BOOL canFillRichText = [item.richTextName length] > 0 &&
                                       [[self stringValue:existingItem[kKayokoItemKeyRichTextName]] length] == 0;
                if (!alreadyExists || canFillRichText ||
                    ([item.imageName length] > 0 &&
                     ![fileManager fileExistsAtPath:[self.historyStore.imagesPath
                                                        stringByAppendingPathComponent:item.imageName]])) {
                    [preparedItems addObject:item];
                }
            }
        }
    }

    NSString *tagsPath = self.tagStore.tagsPath;
    BOOL originalTagsFileExisted = [fileManager fileExistsAtPath:tagsPath];
    NSData *originalTagsData = nil;
    if (originalTagsFileExisted) {
        originalTagsData = [NSData dataWithContentsOfFile:tagsPath options:0 error:error];
        if (!originalTagsData) {
            return NO;
        }
    }

    NSMutableArray<KayokoTag *> *tags = [self.tagStore loadTagsWithError:error];
    if (!tags) {
        return NO;
    }
    NSMutableDictionary<NSString *, KayokoTag *> *tagsByTitle = [[NSMutableDictionary alloc] init];
    for (KayokoTag *tag in tags) {
        if ([[tag title] length] > 0 && !tagsByTitle[[tag title]]) {
            tagsByTitle[[tag title]] = tag;
        }
    }

    BOOL didAddTag = NO;
    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary<NSString *, id> *> *> *itemsByHistoryKey =
        @{
            kKayokoCopyVaultHistoryKey : [[NSMutableArray alloc] init],
            kKayokoCopyVaultFavoritesKey : [[NSMutableArray alloc] init]
        }
            .mutableCopy;
    NSMutableDictionary<NSString *, NSData *> *imageDataByName = [[NSMutableDictionary alloc] init];
    NSMutableDictionary<NSString *, NSData *> *richTextDataByName = [[NSMutableDictionary alloc] init];

    for (KayokoCopyVaultPreparedItem *item in preparedItems) {
        NSString *content = [self stringValue:item.dictionary[kKayokoItemKeyContent]];
        BOOL alreadyExists = [existingContentByHistoryKey[item.historyKey] containsObject:content];
        NSDictionary<NSString *, id> *existingItem = existingItemsByHistoryKey[item.historyKey][content];
        BOOL canFillRichText =
            [item.richTextName length] > 0 && [[self stringValue:existingItem[kKayokoItemKeyRichTextName]] length] == 0;
        if (!alreadyExists) {
            if ([item.categoryTitle length] > 0) {
                KayokoTag *tag = tagsByTitle[item.categoryTitle];
                if (!tag) {
                    tag = [KayokoTag tagWithTitle:item.categoryTitle
                                         hexColor:[self hexColorForCategoryTitle:item.categoryTitle]];
                    tagsByTitle[item.categoryTitle] = tag;
                    [tags addObject:tag];
                    didAddTag = YES;
                }
                item.dictionary[kKayokoItemKeyTagUUID] = tag.uuid;
            }
            [itemsByHistoryKey[item.historyKey] addObject:item.dictionary];
        } else if (canFillRichText) {
            [itemsByHistoryKey[item.historyKey] addObject:item.dictionary];
        }

        if ([item.imageName length] > 0 && item.imageData) {
            NSData *existingPlannedData = imageDataByName[item.imageName];
            if (existingPlannedData && ![existingPlannedData isEqualToData:item.imageData]) {
                [self populateInvalidDataError:error
                                        detail:[NSString stringWithFormat:@"conflicting image %@", item.imageName]];
                return NO;
            }
            imageDataByName[item.imageName] = item.imageData;
        }
        if ([item.richTextName length] > 0 && item.richTextData && (!alreadyExists || canFillRichText)) {
            NSData *existingPlannedData = richTextDataByName[item.richTextName];
            if (existingPlannedData && ![existingPlannedData isEqualToData:item.richTextData]) {
                [self populateInvalidDataError:error
                                        detail:[NSString
                                                   stringWithFormat:@"conflicting rich text %@", item.richTextName]];
                return NO;
            }
            richTextDataByName[item.richTextName] = item.richTextData;
        }
    }

    BOOL success = [self commitItemsByHistoryKey:itemsByHistoryKey
                                 imageDataByName:imageDataByName
                              richTextDataByName:richTextDataByName
                                            tags:tags
                                originalTagsData:originalTagsData
                         originalTagsFileExisted:originalTagsFileExisted
                                   didChangeTags:didAddTag
                                           error:error];
    if (skippedItemCount) {
        *skippedItemCount = self.skippedItemCount;
    }
    return success;
}

#pragma mark - Record Preparation

- (NSArray<KayokoCopyVaultPreparedItem *> *)preparedItemsForRecord:(NSDictionary<NSString *, id> *)record
                                                     sourceSection:(NSString *)sourceSection
                                                        historyKey:(NSString *)historyKey
                                                             error:(NSError **)error {
    NSString *time = [self stringValue:record[@"time"]];
    if ([time length] == 0 || [time containsString:@"/"] || [time isEqualToString:@"."] ||
        [time isEqualToString:@".."]) {
        [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"invalid %@ timestamp", sourceSection]];
        return nil;
    }

    NSDate *capturedAt = [self.dateFormatter dateFromString:time];
    if (!capturedAt || ![[self.dateFormatter stringFromDate:capturedAt] isEqualToString:time]) {
        [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"invalid timestamp %@", time]];
        return nil;
    }

    NSString *sectionPath = [self.sourceDirectoryPath stringByAppendingPathComponent:sourceSection];
    struct stat sectionStat;
    if (lstat([sectionPath fileSystemRepresentation], &sectionStat) != 0 || !S_ISDIR(sectionStat.st_mode)) {
        [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"invalid item path %@", sourceSection]];
        return nil;
    }

    NSString *recordPath = [sectionPath stringByAppendingPathComponent:[time stringByAppendingPathExtension:@"plist"]];
    NSString *standardizedSectionPath = [[sectionPath stringByStandardizingPath] stringByAppendingString:@"/"];
    if (![[recordPath stringByStandardizingPath] hasPrefix:standardizedSectionPath]) {
        [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"invalid item path %@", time]];
        return nil;
    }

    NSDictionary<NSString *, id> *contentsPropertyList = [self dictionaryPropertyListAtPath:recordPath error:error];
    if (!contentsPropertyList) {
        return nil;
    }
    id contentsValue = contentsPropertyList[@"contents"];
    if (![contentsValue isKindOfClass:[NSArray class]] || [(NSArray *)contentsValue count] == 0) {
        [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"%@ has no contents", time]];
        return nil;
    }

    BOOL remote = [record[@"remote"] boolValue];
    NSString *bundleIdentifier = remote ? kKayokoContinuityBundleIdentifier : [self stringValue:record[@"bundleID"]];
    if ([bundleIdentifier length] == 0) {
        bundleIdentifier = @"com.apple.springboard";
    }
    NSString *note = [self stringValue:record[@"notes"]];
    NSString *categoryTitle = [self resolvedCategoryTitle:[self stringValue:record[@"category"]]];
    NSString *uniqueIdentifier = [self normalizedUniqueIdentifier:[self stringValue:record[@"unique"]]];

    NSMutableArray<KayokoCopyVaultPreparedItem *> *preparedItems = [[NSMutableArray alloc] init];
    NSUInteger contentIndex = 0;
    for (id contentValue in (NSArray *)contentsValue) {
        if (![contentValue isKindOfClass:[NSDictionary class]]) {
            [self populateInvalidDataError:error
                                    detail:[NSString stringWithFormat:@"%@ contains an invalid payload", time]];
            return nil;
        }

        KayokoCopyVaultPreparedItem *item = [self preparedItemForContentDictionary:contentValue
                                                                        historyKey:historyKey
                                                                  bundleIdentifier:bundleIdentifier
                                                                        capturedAt:capturedAt
                                                                              note:note
                                                                     categoryTitle:categoryTitle
                                                                  uniqueIdentifier:uniqueIdentifier
                                                                      contentIndex:contentIndex
                                                                        sourceName:time
                                                                             error:error];
        if (!item) {
            if (error && *error) {
                return nil;
            }
            self.skippedItemCount++;
            contentIndex++;
            continue;
        }
        [preparedItems addObject:item];
        contentIndex++;
    }

    return preparedItems;
}

- (KayokoCopyVaultPreparedItem *)preparedItemForContentDictionary:(NSDictionary<NSString *, id> *)contents
                                                       historyKey:(NSString *)historyKey
                                                 bundleIdentifier:(NSString *)bundleIdentifier
                                                       capturedAt:(NSDate *)capturedAt
                                                             note:(NSString *)note
                                                    categoryTitle:(NSString *)categoryTitle
                                                 uniqueIdentifier:(NSString *)uniqueIdentifier
                                                     contentIndex:(NSUInteger)contentIndex
                                                       sourceName:(NSString *)sourceName
                                                            error:(NSError **)error {
    (void)sourceName;
    (void)error;
    KayokoCopyVaultImagePayload *imagePayload = [self imagePayloadFromContents:contents];
    NSString *text = imagePayload ? nil : [self textFromContents:contents];
    KayokoRichTextRepresentation *richText = imagePayload ? nil : [self richTextRepresentationFromContents:contents];
    if ([text length] == 0 && richText) {
        text = [richText plainText];
    }
    if (!imagePayload && [text length] == 0) {
        return nil;
    }

    KayokoCopyVaultPreparedItem *item = [[KayokoCopyVaultPreparedItem alloc] init];
    item.historyKey = historyKey;
    item.categoryTitle = categoryTitle;

    NSMutableDictionary<NSString *, id> *dictionary = [@{
        kKayokoItemKeyBundleIdentifier : bundleIdentifier,
        kKayokoItemKeyCapturedAt : @([capturedAt timeIntervalSince1970])
    } mutableCopy];
    if ([note length] > 0) {
        dictionary[kKayokoItemKeyNote] = note;
    }

    if (imagePayload) {
        NSString *imageIdentifier = uniqueIdentifier;
        if ([imageIdentifier length] == 0) {
            imageIdentifier = [self SHA256StringForData:imagePayload.data];
        }
        NSString *imageName = [NSString stringWithFormat:@"copyvault-%@-%lu.%@", imageIdentifier,
                                                         (unsigned long)contentIndex, imagePayload.extension];
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

#pragma mark - Payload Selection

- (KayokoCopyVaultImagePayload *)imagePayloadFromContents:(NSDictionary<NSString *, id> *)contents {
    KayokoCopyVaultImagePayload *nonAlphaPNG = nil;
    for (NSString *key in @[ @"copyvault.public.png", @"public.png" ]) {
        NSData *data = [contents[key] isKindOfClass:[NSData class]] ? contents[key] : nil;
        KayokoCopyVaultImagePayload *payload = [self imagePayloadForData:data extension:@"png"];
        if (!payload) {
            continue;
        }
        if ([self imageDataHasAlpha:data]) {
            return payload;
        }
        if (!nonAlphaPNG) {
            nonAlphaPNG = payload;
        }
    }

    for (NSString *key in @[ @"copyvault.public.jpeg", @"public.jpeg", @"public.jpg" ]) {
        NSData *data = [contents[key] isKindOfClass:[NSData class]] ? contents[key] : nil;
        KayokoCopyVaultImagePayload *payload = [self imagePayloadForData:data extension:@"jpg"];
        if (payload) {
            return payload;
        }
    }
    if (nonAlphaPNG) {
        return nonAlphaPNG;
    }

    for (NSString *key in @[ @"copyvault.com.apple.uikit.image", @"com.apple.uikit.image" ]) {
        NSData *data = [contents[key] isKindOfClass:[NSData class]] ? contents[key] : nil;
        KayokoCopyVaultImagePayload *payload = [self imagePayloadForData:data extension:nil];
        if (payload) {
            return payload;
        }
    }
    return nil;
}

- (KayokoRichTextRepresentation *)richTextRepresentationFromContents:(NSDictionary<NSString *, id> *)contents {
    NSArray<NSString *> *types = @[ @"com.apple.flat-rtfd", @"public.rtfd", @"public.rtf", @"public.html" ];
    for (NSString *type in types) {
        for (NSString *key in @[ type, [@"copyvault." stringByAppendingString:type] ]) {
            id value = contents[key];
            if (!value) {
                continue;
            }
            KayokoRichTextRepresentation *representation =
                [KayokoRichTextRepresentation preferredRepresentationFromDictionary:@{type : value}];
            if (representation) {
                return representation;
            }
        }
    }
    return nil;
}

- (KayokoCopyVaultImagePayload *)imagePayloadForData:(NSData *)data extension:(NSString *)extension {
    (void)extension;
    if ([data length] == 0) {
        return nil;
    }
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) {
        return nil;
    }
    CFStringRef type = CGImageSourceGetType(source);
    NSString *detectedExtension = nil;
    if (type && CFEqual(type, CFSTR("public.png"))) {
        detectedExtension = @"png";
    } else if (type && (CFEqual(type, CFSTR("public.jpeg")) || CFEqual(type, CFSTR("public.jpg")))) {
        detectedExtension = @"jpg";
    }
    NSDictionary *decodeOptions = @{
        (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
        (NSString *)kCGImageSourceThumbnailMaxPixelSize : @1,
        (NSString *)kCGImageSourceShouldCacheImmediately : @YES
    };
    CGImageRef decodedImage = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)decodeOptions);
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    CFRelease(source);
    NSUInteger width = [properties[(NSString *)kCGImagePropertyPixelWidth] unsignedIntegerValue];
    NSUInteger height = [properties[(NSString *)kCGImagePropertyPixelHeight] unsignedIntegerValue];
    NSUInteger orientation = [properties[(NSString *)kCGImagePropertyOrientation] unsignedIntegerValue];
    if ([detectedExtension length] == 0 || !decodedImage || width == 0 || height == 0) {
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

    KayokoCopyVaultImagePayload *payload = [[KayokoCopyVaultImagePayload alloc] init];
    payload.data = data;
    payload.extension = detectedExtension;
    payload.pixelWidth = width;
    payload.pixelHeight = height;
    return payload;
}

- (BOOL)imageDataHasAlpha:(NSData *)data {
    if ([data length] == 0) {
        return NO;
    }
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) {
        return NO;
    }
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    CFRelease(source);
    return [properties[(NSString *)kCGImagePropertyHasAlpha] boolValue];
}

- (NSString *)textFromContents:(NSDictionary<NSString *, id> *)contents {
    NSArray<NSString *> *preferredTypes = @[
        @"public.utf8-plain-text", @"copyvault.public.utf8-plain-text", @"public.plain-text",
        @"copyvault.public.plain-text", @"public.text", @"copyvault.public.text", @"public.url",
        @"copyvault.public.url", @"public.file-url", @"copyvault.public.file-url"
    ];
    for (NSString *type in preferredTypes) {
        id representation = contents[type];
        NSString *value = [self stringValue:representation];
        if (!value && [representation isKindOfClass:[NSData class]]) {
            value = [[NSString alloc] initWithData:representation encoding:NSUTF8StringEncoding];
        }
        if ([value length] > 0) {
            return value;
        }
    }
    return nil;
}

#pragma mark - Categories

- (BOOL)loadCategoryConfigurationWithError:(NSError **)error {
    NSString *path = [self.sourceDirectoryPath stringByAppendingPathComponent:@"Archive.plist"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        self.categoryTitlesByIdentifier = @{};
        return YES;
    }

    NSDictionary<NSString *, id> *propertyList = [self dictionaryPropertyListAtPath:path error:error];
    if (!propertyList) {
        return NO;
    }
    id contentsValue = propertyList[@"contents"];
    if (contentsValue && ![contentsValue isKindOfClass:[NSDictionary class]]) {
        [self populateInvalidDataError:error detail:@"Archive.plist contents is not a dictionary"];
        return NO;
    }
    id indexValue = propertyList[@"index"];
    if (indexValue && ![indexValue isKindOfClass:[NSArray class]]) {
        [self populateInvalidDataError:error detail:@"Archive.plist index is not an array"];
        return NO;
    }
    for (id categoryIdentifier in (NSArray *)indexValue) {
        if (![categoryIdentifier isKindOfClass:[NSString class]]) {
            [self populateInvalidDataError:error detail:@"Archive.plist index contains an invalid category"];
            return NO;
        }
    }

    NSMutableDictionary<NSString *, NSString *> *titles = [[NSMutableDictionary alloc] init];
    [(NSDictionary *)contentsValue enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
      (void)stop;
      NSString *identifier = [self stringValue:key];
      NSString *title = [self stringValue:value];
      if (!title && [value isKindOfClass:[NSDictionary class]]) {
          title = [self stringValue:value[@"title"]] ?: [self stringValue:value[@"name"]];
      }
      if ([identifier length] > 0 && [title length] > 0) {
          titles[identifier] = title;
      }
    }];
    self.categoryTitlesByIdentifier = titles;
    return YES;
}

- (NSString *)resolvedCategoryTitle:(NSString *)categoryIdentifier {
    if ([categoryIdentifier length] == 0) {
        return nil;
    }
    static NSSet<NSString *> *builtInCategories = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      builtInCategories =
          [NSSet setWithArray:@[ @"BUILTIN_CATEGORY_TEXT", @"BUILTIN_CATEGORY_IMG", @"BUILTIN_CATEGORY_URL" ]];
    });
    if ([builtInCategories containsObject:categoryIdentifier]) {
        return nil;
    }
    return self.categoryTitlesByIdentifier[categoryIdentifier] ?: categoryIdentifier;
}

- (NSString *)hexColorForCategoryTitle:(NSString *)title {
    NSData *titleData = [[title precomposedStringWithCanonicalMapping] dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256([titleData bytes], (CC_LONG)[titleData length], digest);

    double hue = (double)(((uint16_t)digest[0] << 8) | digest[1]) / 65536.0;
    double saturation = 0.55 + ((double)digest[2] / 255.0) * 0.20;
    double brightness = 0.78 + ((double)digest[3] / 255.0) * 0.14;
    double scaledHue = hue * 6.0;
    NSInteger sector = (NSInteger)floor(scaledHue);
    double fraction = scaledHue - sector;
    double minimum = brightness * (1.0 - saturation);
    double descending = brightness * (1.0 - saturation * fraction);
    double ascending = brightness * (1.0 - saturation * (1.0 - fraction));
    double red = 0.0;
    double green = 0.0;
    double blue = 0.0;
    switch (sector) {
    case 0:
        red = brightness;
        green = ascending;
        blue = minimum;
        break;
    case 1:
        red = descending;
        green = brightness;
        blue = minimum;
        break;
    case 2:
        red = minimum;
        green = brightness;
        blue = ascending;
        break;
    case 3:
        red = minimum;
        green = descending;
        blue = brightness;
        break;
    case 4:
        red = ascending;
        green = minimum;
        blue = brightness;
        break;
    default:
        red = brightness;
        green = minimum;
        blue = descending;
        break;
    }

    return [NSString stringWithFormat:@"#%02lX%02lX%02lXFF", (long)lrint(red * 255.0), (long)lrint(green * 255.0),
                                      (long)lrint(blue * 255.0)];
}

#pragma mark - Commit

- (BOOL)commitItemsByHistoryKey:(NSDictionary<NSString *, NSArray<NSDictionary<NSString *, id> *> *> *)itemsByHistoryKey
                imageDataByName:(NSDictionary<NSString *, NSData *> *)imageDataByName
             richTextDataByName:(NSDictionary<NSString *, NSData *> *)richTextDataByName
                           tags:(NSArray<KayokoTag *> *)tags
               originalTagsData:(NSData *)originalTagsData
        originalTagsFileExisted:(BOOL)originalTagsFileExisted
                  didChangeTags:(BOOL)didChangeTags
                          error:(NSError **)error {
    NSString *dataDirectoryPath = [self.historyStore.databasePath stringByDeletingLastPathComponent];
    KayokoImportFileStager *fileStager = [[KayokoImportFileStager alloc] initWithBaseDirectoryPath:dataDirectoryPath
                                                                                            prefix:@"copyvault-import"];
    if (![fileStager addDataByName:imageDataByName targetDirectory:self.historyStore.imagesPath error:error] ||
        ![fileStager addDataByName:richTextDataByName targetDirectory:self.historyStore.richTextPath error:error]) {
        NSError *rollbackError = nil;
        if (![fileStager rollbackWithError:&rollbackError] && error) {
            *error = rollbackError;
        }
        return NO;
    }

    if (didChangeTags && ![self.tagStore saveTags:tags error:error]) {
        NSError *rollbackError = nil;
        if (![fileStager rollbackWithError:&rollbackError] && error) {
            *error = rollbackError;
        }
        return NO;
    }

    if (![fileStager commitWithError:error]) {
        NSError *rollbackError = nil;
        if (![self rollbackTagsWithData:originalTagsData
                            fileExisted:originalTagsFileExisted
                          didChangeTags:didChangeTags
                                  error:&rollbackError] &&
            error) {
            *error = rollbackError;
        }
        return NO;
    }

    BOOL imported = [self.historyStore importItemDictionariesByHistoryKey:itemsByHistoryKey error:error];
    if (!imported) {
        NSError *tagRollbackError = nil;
        BOOL restoredTags = [self rollbackTagsWithData:originalTagsData
                                           fileExisted:originalTagsFileExisted
                                         didChangeTags:didChangeTags
                                                 error:&tagRollbackError];
        NSError *fileRollbackError = nil;
        BOOL restoredFiles = [fileStager rollbackWithError:&fileRollbackError];
        if (!restoredTags && error) {
            *error = tagRollbackError;
        } else if (!restoredFiles && error) {
            *error = fileRollbackError;
        }
        return NO;
    }

    return YES;
}

- (BOOL)rollbackTagsWithData:(NSData *)originalTagsData
                 fileExisted:(BOOL)fileExisted
               didChangeTags:(BOOL)didChangeTags
                       error:(NSError **)error {
    if (!didChangeTags) {
        return YES;
    }
    if (fileExisted) {
        return [originalTagsData writeToFile:self.tagStore.tagsPath options:NSDataWritingAtomic error:error];
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:self.tagStore.tagsPath]) {
        return YES;
    }
    return [fileManager removeItemAtPath:self.tagStore.tagsPath error:error];
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
        if (error && *error) {
            NSError *underlyingError = *error;
            [self populateError:error
                           code:2
                      formatKey:@"Unable to read CopyVault data: %@"
                         detail:[underlyingError localizedDescription]];
        }
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

- (NSString *)normalizedUniqueIdentifier:(NSString *)uniqueIdentifier {
    if ([uniqueIdentifier length] == 0) {
        return nil;
    }
    NSCharacterSet *invalidCharacters = [[NSCharacterSet
        characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"]
        invertedSet];
    if ([uniqueIdentifier rangeOfCharacterFromSet:invalidCharacters].location != NSNotFound) {
        return nil;
    }
    return [uniqueIdentifier lowercaseString];
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
    [self populateError:error code:2 formatKey:@"CopyVault data is invalid: %@" detail:detail];
}

- (void)populateError:(NSError **)error code:(NSInteger)code formatKey:(NSString *)formatKey detail:(NSString *)detail {
    if (!error) {
        return;
    }
    NSString *description = [detail length] > 0 ? [NSString stringWithFormat:formatKey, detail] : formatKey;
    *error = [NSError errorWithDomain:kKayokoCopyVaultImporterErrorDomain
                                 code:code
                             userInfo:@{NSLocalizedDescriptionKey : description}];
}

@end
