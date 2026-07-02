//
//  PasteboardManager.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "PasteboardManager.h"
#import "KayokoHistoryChangeNotifier.h"
#import "KayokoHistoryRepository.h"
#import "NotificationKeys.h"
#import "PasteboardItem.h"
#import "PreferenceKeys.h"

#import <ImageIO/ImageIO.h>
#import <roothide.h>

NS_ASSUME_NONNULL_BEGIN

@interface SBApplication : NSObject
@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@end

@interface UIApplication (Private)
- (SBApplication *_Nullable)_accessibilityFrontMostApplication;
@end

NS_ASSUME_NONNULL_END

@implementation PasteboardManager {
    UIPasteboard *_pasteboard;
    NSUInteger _lastChangeCount;
    NSFileManager *_fileManager;

    dispatch_queue_t _pasteboardQueue;
    dispatch_queue_t _thumbnailQueue;
    NSCache<NSString *, UIImage *> *_thumbnailCache;

    BOOL _isPerformingDirectPaste;

    KayokoHistoryRepository *_historyRepository;
    KayokoHistoryChangeNotifier *_historyChangeNotifier;
}

#pragma mark - Lifecycle

+ (instancetype)sharedInstance {
    static PasteboardManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sharedInstance = [[PasteboardManager alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Paths and Resources

+ (NSString *)historyPath {
    static NSString *kayokoHistoryPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kayokoHistoryPath = jbroot(@"/var/mobile/Library/com.82flex.kayoko/history.json");
    });
    return kayokoHistoryPath;
}

+ (NSString *)historyImagesPath {
    static NSString *kayokoHistoryImagesPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kayokoHistoryImagesPath = jbroot(@"/var/mobile/Library/com.82flex.kayoko/images/");
    });
    return kayokoHistoryImagesPath;
}

+ (NSBundle *)localizationBundle {
    static NSBundle *kayokoLocalizationBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kayokoLocalizationBundle =
          [NSBundle bundleWithPath:jbroot(@"/Library/PreferenceBundles/KayokoPreferences.bundle")];
    });
    return kayokoLocalizationBundle;
}

+ (NSString *)historyDatabasePath {
    return [KayokoHistoryRepository defaultDatabasePath];
}

+ (NSUInteger)normalizedMaximumHistoryAmountForValue:(NSUInteger)value {
    if (value == 0) {
        return kKayokoPreferenceKeyMaximumHistoryAmountDefaultValue;
    }

    NSArray<NSNumber *> *stepValues = @[ @50, @100, @200, @300, @500, @1000, @2000, @3000, @4000, @5000 ];
    for (NSNumber *stepValue in stepValues) {
        NSUInteger candidate = [stepValue unsignedIntegerValue];
        if (value <= candidate) {
            return candidate;
        }
    }

    return [[stepValues lastObject] unsignedIntegerValue];
}

#pragma mark - Setup

- (instancetype)init {
    self = [super init];
    if (self) {
        _fileManager = [NSFileManager defaultManager];
        if (@available(iOS 16, *)) {
            _pasteboardQueue = dispatch_queue_create("com.82flex.kayoko.queue.pasteboard",
                                                     DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        }
        _thumbnailQueue =
            dispatch_queue_create("com.82flex.kayoko.queue.thumbnail", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        _thumbnailCache = [[NSCache alloc] init];
        [_thumbnailCache setCountLimit:80];
        __weak typeof(self) weakSelf = self;
        _historyRepository =
            [[KayokoHistoryRepository alloc] initWithDatabasePath:[PasteboardManager historyDatabasePath]
                                                       imagesPath:[PasteboardManager historyImagesPath]
                                                    limitProvider:^NSUInteger(NSString *historyKey) {
                                                      return [weakSelf limitForHistoryKey:historyKey];
                                                    }];
        _historyChangeNotifier = [[KayokoHistoryChangeNotifier alloc] init];
        if (@available(iOS 15, *)) {
            [self prepareGeneralPasteboard];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
              [self prepareGeneralPasteboard];
            });
        }
    }
    return self;
}

- (void)prepareGeneralPasteboard {
    _pasteboard = [UIPasteboard generalPasteboard];
    _lastChangeCount = [_pasteboard changeCount];
}

- (void)warmUpHistoryAccess {
    [_historyRepository prepareStore];
}

#pragma mark - Image Storage Helpers

- (NSString *)randomStringWithLength:(NSUInteger)length {
    NSString *characters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *string = [NSMutableString stringWithCapacity:length];

    for (NSUInteger i = 0; i < length; i++) {
        [string appendFormat:@"%c", [characters characterAtIndex:arc4random_uniform((uint32_t)[characters length])]];
    }

    return string;
}

- (BOOL)imageHasAlpha:(UIImage *)image {
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo([image CGImage]);
    return (alpha == kCGImageAlphaFirst || alpha == kCGImageAlphaLast || alpha == kCGImageAlphaPremultipliedFirst ||
            alpha == kCGImageAlphaPremultipliedLast);
}

- (UIImage *)imageByApplyingOrientation:(UIImage *)image {
    if ([image imageOrientation] == UIImageOrientationUp) {
        return image;
    }

    UIGraphicsBeginImageContext([image size]);
    [image drawInRect:CGRectMake(0, 0, [image size].width, [image size].height)];
    UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return rotatedImage;
}

#pragma mark - Pasteboard Observation

- (void)pullPasteboardChanges {
    [self pullPasteboardChangesWithCompletion:nil];
}

- (void)pullPasteboardChangesWithCompletion:(void (^)(BOOL didSaveAnyItem))completion {
    void (^complete)(BOOL) = ^(BOOL didSaveAnyItem) {
      if (!completion) {
          return;
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        completion(didSaveAnyItem);
      });
    };

    if (@available(iOS 16, *)) {
        dispatch_async(_pasteboardQueue, ^{
          complete([self _reallyPullPasteboardChanges]);
        });
        return;
    }

    NSArray<PasteboardItem *> *items = [self pasteboardItemsForCurrentChange];
    [self savePasteboardItems:items
             toHistoryWithKey:kKayokoHistoryKeyHistory
                   completion:^(BOOL didSaveAnyItem) {
                     complete(didSaveAnyItem);
                   }];
}

- (BOOL)pasteboardContainsType:(NSString *)pasteboardType {
    return [_pasteboard containsPasteboardTypes:@[ pasteboardType ]];
}

- (BOOL)shouldIgnoreCurrentPasteboardChange {
    if ([self ignoreRemoteReplication] && [self pasteboardContainsType:@"com.apple.is-remote-clipboard"]) {
        return YES;
    }

    return [self pasteboardContainsType:@"com.apple.icns"];
}

- (NSArray<PasteboardItem *> *)pasteboardItemsForCurrentChange {
    NSUInteger currentChangeCount = [_pasteboard changeCount];
    if (currentChangeCount == _lastChangeCount) {
        return @[];
    }

    _lastChangeCount = currentChangeCount;

    if ([self shouldIgnoreCurrentPasteboardChange]) {
        return @[];
    }

    BOOL hasStrings = [_pasteboard hasStrings];
    BOOL hasImages = [_pasteboard hasImages];
    if (!hasStrings && !hasImages) {
        return @[];
    }

    NSMutableArray<PasteboardItem *> *items = [[NSMutableArray alloc] init];

    if ([self saveText]) {
        // Don't pull strings if the pasteboard contains images.
        // For example: When copying an image from the web we only want the image, without the string.
        if (!(hasStrings && hasImages)) {
            for (NSString *string in [_pasteboard strings]) {
                @autoreleasepool {
                    // The core only runs on the SpringBoard process, thus we can't use mainbundle to get the process'
                    // bundle identifier. However, we can get it by using UIApplication/SpringBoard
                    // front-most-application.
                    SBApplication *frontMostApplication =
                        [[UIApplication sharedApplication] _accessibilityFrontMostApplication];
                    PasteboardItem *item =
                        [[PasteboardItem alloc] initWithBundleIdentifier:[frontMostApplication bundleIdentifier]
                                                              andContent:string
                                                          withImageNamed:nil];
                    [items addObject:item];
                }
            }
        }
    }

    if ([self saveImages]) {
        for (UIImage *image in [_pasteboard images]) {
            @autoreleasepool {
                NSString *imageName = [self randomStringWithLength:32];

                // Only save as PNG if the image has an alpha channel to save storage space.
                if ([self imageHasAlpha:image]) {
                    imageName = [imageName stringByAppendingString:@".png"];
                    NSString *filePath =
                        [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], imageName];
                    [UIImagePNGRepresentation([self imageByApplyingOrientation:image]) writeToFile:filePath
                                                                                        atomically:YES];
                } else {
                    imageName = [imageName stringByAppendingString:@".jpg"];
                    NSString *filePath =
                        [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], imageName];
                    [UIImageJPEGRepresentation(image, 1) writeToFile:filePath atomically:YES];
                }

                // See the above loop.
                SBApplication *frontMostApplication =
                    [[UIApplication sharedApplication] _accessibilityFrontMostApplication];
                PasteboardItem *item =
                    [[PasteboardItem alloc] initWithBundleIdentifier:[frontMostApplication bundleIdentifier]
                                                          andContent:imageName
                                                      withImageNamed:imageName];
                [items addObject:item];
            }
        }
    }

    return items;
}

- (BOOL)_reallyPullPasteboardChanges {
    NSArray<PasteboardItem *> *items = [self pasteboardItemsForCurrentChange];
    return [self savePasteboardItemsSynchronously:items toHistoryWithKey:kKayokoHistoryKeyHistory];
}

#pragma mark - History Access

- (BOOL)savePasteboardItemsSynchronously:(NSArray<PasteboardItem *> *)items toHistoryWithKey:(NSString *)historyKey {
    BOOL didSaveAnyItem = NO;
    for (PasteboardItem *item in items) {
        if ([self addPasteboardItem:item toHistoryWithKey:historyKey]) {
            didSaveAnyItem = YES;
        }
    }
    return didSaveAnyItem;
}

- (void)savePasteboardItems:(NSArray<PasteboardItem *> *)items
           toHistoryWithKey:(NSString *)historyKey
                 completion:(void (^)(BOOL didSaveAnyItem))completion {
    NSMutableArray<NSDictionary<NSString *, id> *> *dictionaries =
        [[NSMutableArray alloc] initWithCapacity:[items count]];
    for (PasteboardItem *item in items) {
        if ([[item content] isEqualToString:@""]) {
            continue;
        }
        [dictionaries addObject:[item dictionaryRepresentation]];
    }

    if ([dictionaries count] == 0) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    NSUInteger limit = [self limitForHistoryKey:historyKey];
    __weak typeof(self) weakSelf = self;
    [_historyRepository
        addItemDictionaries:dictionaries
               toHistoryKey:historyKey
                 completion:^(NSArray<NSDictionary<NSString *, id> *> *savedDictionaries) {
                   __strong typeof(weakSelf) strongSelf = weakSelf;
                   if (!strongSelf) {
                       return;
                   }
                   for (NSDictionary<NSString *, id> *dictionary in savedDictionaries) {
                       [strongSelf
                           postHistoryChangedNotificationForHistoryKey:historyKey
                                                            changeType:
                                                                kKayokoPasteboardManagerHistoryChangeTypeUpsertTop
                                                        itemDictionary:dictionary
                                                                 limit:limit];
                   }
                   if (completion) {
                       completion([savedDictionaries count] > 0);
                   }
                 }];
}

#pragma mark - History Mutations

- (BOOL)addPasteboardItem:(PasteboardItem *)item toHistoryWithKey:(NSString *)historyKey {
    if ([[item content] isEqualToString:@""]) {
        return NO;
    }

    NSDictionary<NSString *, id> *dictionary = [item dictionaryRepresentation];
    NSUInteger limit = [self limitForHistoryKey:historyKey];
    NSError *error = nil;
    BOOL success = [_historyRepository addItemDictionary:dictionary toHistoryKey:historyKey error:&error];
    if (!success) {
        NSLog(@"Kayoko: Failed to add history item: %@", error);
        return NO;
    }

    [self postHistoryChangedNotificationForHistoryKey:historyKey
                                           changeType:kKayokoPasteboardManagerHistoryChangeTypeUpsertTop
                                       itemDictionary:dictionary
                                                limit:limit];
    return YES;
}

- (void)removePasteboardItem:(PasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage {
    NSDictionary<NSString *, id> *dictionary = [item dictionaryRepresentation];
    NSError *error = nil;
    BOOL success = [_historyRepository removeItemDictionary:dictionary
                                             fromHistoryKey:historyKey
                                          shouldRemoveImage:shouldRemoveImage
                                                      error:&error];
    if (!success) {
        NSLog(@"Kayoko: Failed to remove history item: %@", error);
        return;
    }

    [self postHistoryChangedNotificationForHistoryKey:historyKey
                                           changeType:kKayokoPasteboardManagerHistoryChangeTypeRemove
                                       itemDictionary:dictionary
                                                limit:[self limitForHistoryKey:historyKey]];
}

- (void)removePasteboardItem:(PasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage
                  completion:(void (^)(BOOL success))completion {
    NSDictionary<NSString *, id> *dictionary = [item dictionaryRepresentation];
    [_historyRepository removeItemDictionary:dictionary
                              fromHistoryKey:historyKey
                           shouldRemoveImage:shouldRemoveImage
                                  completion:completion];
}

- (void)movePasteboardItem:(PasteboardItem *)item
        fromHistoryWithKey:(NSString *)sourceHistoryKey
          toHistoryWithKey:(NSString *)destinationHistoryKey
                completion:(void (^)(BOOL success))completion {
    NSDictionary<NSString *, id> *dictionary = [item dictionaryRepresentation];
    [_historyRepository moveItemDictionary:dictionary
                            fromHistoryKey:sourceHistoryKey
                              toHistoryKey:destinationHistoryKey
                                completion:completion];
}

- (void)removeAllPasteboardItemsFromHistoryWithKey:(NSString *)historyKey
                                shouldRemoveImages:(BOOL)shouldRemoveImages
                           postsChangeNotification:(BOOL)postsChangeNotification
                                        completion:(void (^)(BOOL success))completion {
    [_historyRepository
        removeItemsFromHistoryKey:historyKey
               shouldRemoveImages:shouldRemoveImages
                       completion:^(BOOL success) {
                         if (success && postsChangeNotification) {
                             [self postHistoryChangedNotificationForHistoryKey:historyKey
                                                                    changeType:
                                                                        kKayokoPasteboardManagerHistoryChangeTypeClear
                                                                itemDictionary:nil
                                                                         limit:[self limitForHistoryKey:historyKey]];
                         }
                         if (completion) {
                             completion(success);
                         }
                       }];
}

- (void)removeAllPasteboardItemsFromHistoryWithKey:(NSString *)historyKey
                                shouldRemoveImages:(BOOL)shouldRemoveImages
                                        completion:(void (^)(BOOL success))completion {
    [self removeAllPasteboardItemsFromHistoryWithKey:historyKey
                                  shouldRemoveImages:shouldRemoveImages
                             postsChangeNotification:YES
                                          completion:completion];
}

#pragma mark - Direct Paste

- (void)performDirectPasteWithPasteboardItem:(PasteboardItem *)pasteboardItem
                                 historyItem:(PasteboardItem *)historyItem
                          fromHistoryWithKey:(NSString *)historyKey
                             shouldAutoPaste:(BOOL)shouldAutoPaste {
    if (@available(iOS 16, *)) {
        dispatch_async(_pasteboardQueue, ^{
          [self _reallyPerformDirectPasteWithPasteboardItem:pasteboardItem
                                                historyItem:historyItem
                                         fromHistoryWithKey:historyKey
                                            shouldAutoPaste:shouldAutoPaste];
        });
        return;
    }

    [self _reallyPerformDirectPasteWithPasteboardItem:pasteboardItem
                                          historyItem:historyItem
                                   fromHistoryWithKey:historyKey
                                      shouldAutoPaste:shouldAutoPaste];
}

- (void)updatePasteboardWithItem:(PasteboardItem *)item
              fromHistoryWithKey:(NSString *)historyKey
                 shouldAutoPaste:(BOOL)shouldAutoPaste {
    [self performDirectPasteWithPasteboardItem:item
                                   historyItem:item
                            fromHistoryWithKey:historyKey
                               shouldAutoPaste:shouldAutoPaste];
}

- (BOOL)copyPasteboardItemToPasteboard:(PasteboardItem *)item {
    BOOL didUpdatePasteboard = [self setPasteboardContentFromItem:item];
    if (didUpdatePasteboard) {
        _lastChangeCount = [_pasteboard changeCount];
    }
    return didUpdatePasteboard;
}

- (void)_reallyPerformDirectPasteWithPasteboardItem:(PasteboardItem *)pasteboardItem
                                        historyItem:(PasteboardItem *)historyItem
                                 fromHistoryWithKey:(NSString *)historyKey
                                    shouldAutoPaste:(BOOL)shouldAutoPaste {
    if (_isPerformingDirectPaste) {
        return;
    }

    _isPerformingDirectPaste = YES;

    BOOL didUpdatePasteboard = [self setPasteboardContentFromItem:pasteboardItem];
    if (didUpdatePasteboard) {
        _lastChangeCount = [_pasteboard changeCount];
        [self movePasteboardItemToTop:historyItem inHistoryWithKey:historyKey];
    }

    if (didUpdatePasteboard && [self automaticallyPaste] && shouldAutoPaste) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             (__bridge CFStringRef)kKayokoNotificationKeyHelperPaste, nil, nil, NO);
    }

    _isPerformingDirectPaste = NO;
}

- (BOOL)setPasteboardContentFromItem:(PasteboardItem *)item {
    if (!item) {
        return NO;
    }

    if ([[item imageName] length] > 0) {
        NSString *filePath =
            [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        if (!image) {
            return NO;
        }

        [_pasteboard setImage:image];
        return YES;
    }

    if ([[item content] length] == 0) {
        return NO;
    }

    [_pasteboard setString:[item content]];
    return YES;
}

- (void)movePasteboardItemToTop:(PasteboardItem *)item inHistoryWithKey:(NSString *)historyKey {
    if (!item || [[item content] length] == 0 || [[historyKey description] length] == 0) {
        return;
    }

    NSDictionary<NSString *, id> *dictionary = [item dictionaryRepresentation];
    NSUInteger limit = [self limitForHistoryKey:historyKey];
    NSError *error = nil;
    BOOL success = [_historyRepository moveItemDictionaryToTop:dictionary inHistoryKey:historyKey error:&error];
    if (!success) {
        NSLog(@"Kayoko: Failed to promote history item: %@", error);
        return;
    }

    [self postHistoryChangedNotificationForHistoryKey:historyKey
                                           changeType:kKayokoPasteboardManagerHistoryChangeTypeUpsertTop
                                       itemDictionary:dictionary
                                                limit:limit];
}

#pragma mark - History Reads

- (NSMutableArray<NSDictionary<NSString *, id> *> *)getItemsFromHistoryWithKey:(NSString *)historyKey {
    NSError *error = nil;
    NSMutableArray<NSDictionary<NSString *, id> *> *history = [_historyRepository itemsForHistoryKey:historyKey
                                                                                               error:&error];
    if (error) {
        NSLog(@"Kayoko: Failed to load history items: %@", error);
    }
    return history ?: [[NSMutableArray alloc] init];
}

- (void)getItemsFromHistoryWithKey:(NSString *)historyKey
                        completion:(void (^)(NSMutableArray<NSDictionary<NSString *, id> *> *items))completion {
    [_historyRepository itemsForHistoryKey:historyKey completion:completion];
}

- (PasteboardItem *)getLatestHistoryItem {
    NSError *error = nil;
    NSDictionary<NSString *, id> *dictionary = [_historyRepository latestItemForHistoryKey:kKayokoHistoryKeyHistory
                                                                                     error:&error];
    if (error) {
        NSLog(@"Kayoko: Failed to load latest history item: %@", error);
    }
    return [PasteboardItem itemFromDictionary:dictionary];
}

- (UIImage *)getImageForItem:(PasteboardItem *)item {
    NSData *imageData = [_fileManager
        contentsAtPath:[NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]]];
    return [UIImage imageWithData:imageData];
}

- (NSString *)thumbnailCacheKeyForImageName:(NSString *)imageName targetSize:(CGSize)targetSize scale:(CGFloat)scale {
    return [NSString
        stringWithFormat:@"%@|%.0fx%.0f|%.2f", imageName, ceil(targetSize.width), ceil(targetSize.height), scale];
}

- (void)getThumbnailForItem:(PasteboardItem *)item
                 targetSize:(CGSize)targetSize
                 completion:(void (^)(UIImage *_Nullable image))completion {
    NSString *imageName = [[item imageName] copy];
    if ([imageName length] == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
          completion(nil);
        });
        return;
    }

    CGFloat scale = [[UIScreen mainScreen] scale];
    NSString *cacheKey = [self thumbnailCacheKeyForImageName:imageName targetSize:targetSize scale:scale];
    UIImage *cachedThumbnail = [_thumbnailCache objectForKey:cacheKey];
    if (cachedThumbnail) {
        dispatch_async(dispatch_get_main_queue(), ^{
          completion(cachedThumbnail);
        });
        return;
    }

    NSUInteger maximumPixelSize = (NSUInteger)ceil(MAX(MAX(targetSize.width, targetSize.height), 1) * scale);
    NSString *imagePath = [[PasteboardManager historyImagesPath] stringByAppendingPathComponent:imageName];
    NSURL *imageURL = [NSURL fileURLWithPath:imagePath];

    dispatch_async(_thumbnailQueue, ^{
      CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)imageURL, NULL);
      UIImage *thumbnailImage = nil;
      if (imageSource) {
          NSDictionary *options = @{
              (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
              (NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
              (NSString *)kCGImageSourceShouldCacheImmediately : @YES,
              (NSString *)kCGImageSourceThumbnailMaxPixelSize : @(maximumPixelSize),
          };
          CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef)options);
          if (thumbnail) {
              thumbnailImage = [UIImage imageWithCGImage:thumbnail scale:scale orientation:UIImageOrientationUp];
              CFRelease(thumbnail);
          }
          CFRelease(imageSource);
      }

      if (thumbnailImage) {
          [_thumbnailCache setObject:thumbnailImage forKey:cacheKey];
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        completion(thumbnailImage);
      });
    });
}

#pragma mark - Notifications

- (void)postHistoryChangedNotification {
    [_historyChangeNotifier postReloadNotificationWithObject:self];
}

- (void)postHistoryChangedNotificationForHistoryKey:(NSString *)historyKey
                                         changeType:(NSString *)changeType
                                     itemDictionary:(NSDictionary<NSString *, id> *)itemDictionary
                                              limit:(NSUInteger)limit {
    [_historyChangeNotifier postChangeNotificationForHistoryKey:historyKey
                                                     changeType:changeType
                                                 itemDictionary:itemDictionary
                                                          limit:limit
                                                         object:self];
}

#pragma mark - Limits

- (NSUInteger)limitForHistoryKey:(NSString *)historyKey {
    if ([historyKey isEqualToString:kKayokoHistoryKeyFavorites]) {
        return NSUIntegerMax;
    }

    return [self maximumHistoryAmount];
}

@end
