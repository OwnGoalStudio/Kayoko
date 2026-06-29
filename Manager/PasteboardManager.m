//
//  PasteboardManager.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "PasteboardManager.h"
#import "ImageUtil.h"
#import "KayokoHistoryMigrator.h"
#import "KayokoHistoryStore.h"
#import "NotificationKeys.h"
#import "PasteboardItem.h"
#import "PreferenceKeys.h"
#import "StringUtil.h"

#import <roothide.h>

static void *kKayokoHistoryQueueSpecificKey = &kKayokoHistoryQueueSpecificKey;

@interface SBApplication : NSObject
@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@end

@interface UIApplication (Private)
- (SBApplication *)_accessibilityFrontMostApplication;
@end

@implementation PasteboardManager {
    UIPasteboard *_pasteboard;
    NSUInteger _lastChangeCount;
    NSFileManager *_fileManager;

    dispatch_queue_t _queue;
    dispatch_queue_t _historyQueue;

    BOOL _isPerformingDirectPaste;
    BOOL _didPrepareHistoryStore;

    KayokoHistoryStore *_historyStore;
}

- (NSDictionary *)historyChangeUserInfoWithType:(NSString *)changeType
                                     historyKey:(NSString *)historyKey
                                 itemDictionary:(NSDictionary *)itemDictionary
                                          limit:(NSUInteger)limit {
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    userInfo[kPasteboardManagerHistoryChangeTypeKey] = changeType ?: kPasteboardManagerHistoryChangeTypeReload;
    if ([historyKey length] > 0) {
        userInfo[kPasteboardManagerHistoryChangeHistoryKeyKey] = historyKey;
        userInfo[kPasteboardManagerHistoryChangeLimitKey] = @(limit);
    }
    if (itemDictionary) {
        userInfo[kPasteboardManagerHistoryChangeItemKey] = itemDictionary;
    }
    return userInfo;
}

+ (instancetype)sharedInstance {
    static PasteboardManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sharedInstance = [[PasteboardManager alloc] init];
    });
    return sharedInstance;
}

+ (NSString *)historyPath {
    static NSString *kHistoryPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kHistoryPath = jbroot(@"/var/mobile/Library/com.82flex.kayoko/history.json");
    });
    return kHistoryPath;
}

+ (NSString *)historyImagesPath {
    static NSString *kHistoryImagesPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kHistoryImagesPath = jbroot(@"/var/mobile/Library/com.82flex.kayoko/images/");
    });
    return kHistoryImagesPath;
}

+ (NSBundle *)localizationBundle {
    static NSBundle *kLocalizationBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kLocalizationBundle = [NSBundle bundleWithPath:jbroot(@"/Library/PreferenceBundles/KayokoPreferences.bundle")];
    });
    return kLocalizationBundle;
}

+ (NSString *)historyDatabasePath {
    return [KayokoHistoryStore defaultDatabasePath];
}

+ (NSUInteger)normalizedMaximumHistoryAmountForValue:(NSUInteger)value {
    if (value == 0) {
        return kPreferenceKeyMaximumHistoryAmountDefaultValue;
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

- (instancetype)init {
    self = [super init];
    if (self) {
        _fileManager = [NSFileManager defaultManager];
        _historyQueue = dispatch_queue_create("com.82flex.kayoko.queue.history", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_historyQueue, kKayokoHistoryQueueSpecificKey, kKayokoHistoryQueueSpecificKey,
                                    NULL);
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

- (void)preparePasteboardQueue {
    if (@available(iOS 16, *)) {
        _queue = dispatch_queue_create("com.82flex.kayoko.queue.pasteboard", DISPATCH_QUEUE_SERIAL);
    }
}

- (void)pullPasteboardChanges {
    if (@available(iOS 16, *)) {
        dispatch_async(_queue, ^{
          [self _reallyPullPasteboardChanges];
        });
    } else {
        [self _reallyPullPasteboardChanges];
    }
}

- (void)_reallyPullPasteboardChanges {
    // Return if the pasteboard is empty.
    if ([_pasteboard changeCount] == _lastChangeCount || (![_pasteboard hasStrings] && ![_pasteboard hasImages])) {
        return;
    }

    [self ensureResourcesExist];

    if ([self saveText]) {
        // Don't pull strings if the pasteboard contains images.
        // For example: When copying an image from the web we only want the image, without the string.
        if (!([_pasteboard hasStrings] && [_pasteboard hasImages])) {
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
                    [self addPasteboardItem:item toHistoryWithKey:kHistoryKeyHistory];
                }
            }
        }
    }

    if ([self saveImages]) {
        for (UIImage *image in [_pasteboard images]) {
            @autoreleasepool {
                NSString *imageName = [StringUtil getRandomStringWithLength:32];

                // Only save as PNG if the image has an alpha channel to save storage space.
                if ([ImageUtil imageHasAlpha:image]) {
                    imageName = [imageName stringByAppendingString:@".png"];
                    NSString *filePath =
                        [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], imageName];
                    [UIImagePNGRepresentation([ImageUtil getRotatedImageFromImage:image]) writeToFile:filePath
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
                [self addPasteboardItem:item toHistoryWithKey:kHistoryKeyHistory];
            }
        }
    }

    _lastChangeCount = [_pasteboard changeCount];
}

- (void)addPasteboardItem:(PasteboardItem *)item toHistoryWithKey:(NSString *)historyKey {
    if ([[item content] isEqualToString:@""]) {
        return;
    }

    NSDictionary *dictionary = [self dictionaryForPasteboardItem:item];
    NSUInteger limit = [self limitForHistoryKey:historyKey];
    __block NSError *error = nil;
    __block BOOL success = NO;
    [self performHistorySync:^{
      success = [[self historyStoreOnHistoryQueue] addItemDictionary:dictionary
                                                        toHistoryKey:historyKey
                                                               limit:limit
                                                               error:&error];
    }];
    if (!success) {
        NSLog(@"Kayoko: Failed to add history item: %@", error);
        return;
    }

    [self postHistoryChangedNotificationForHistoryKey:historyKey
                                           changeType:kPasteboardManagerHistoryChangeTypeUpsertTop
                                       itemDictionary:dictionary
                                                limit:limit];
}

- (void)removePasteboardItem:(PasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage {
    NSDictionary *dictionary = [self dictionaryForPasteboardItem:item];
    __block NSError *error = nil;
    __block BOOL success = NO;
    [self performHistorySync:^{
      success = [[self historyStoreOnHistoryQueue] removeItemDictionary:dictionary
                                                         fromHistoryKey:historyKey
                                                      shouldRemoveImage:shouldRemoveImage
                                                                  error:&error];
    }];
    if (!success) {
        NSLog(@"Kayoko: Failed to remove history item: %@", error);
        return;
    }

    [self postHistoryChangedNotificationForHistoryKey:historyKey
                                           changeType:kPasteboardManagerHistoryChangeTypeRemove
                                       itemDictionary:dictionary
                                                limit:[self limitForHistoryKey:historyKey]];
}

- (void)removePasteboardItem:(PasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage
                  completion:(void (^)(BOOL success))completion {
    NSDictionary *dictionary = [self dictionaryForPasteboardItem:item];
    [self performHistoryAsync:^{
      NSError *error = nil;
      BOOL success = [[self historyStoreOnHistoryQueue] removeItemDictionary:dictionary
                                                              fromHistoryKey:historyKey
                                                           shouldRemoveImage:shouldRemoveImage
                                                                       error:&error];
      if (!success) {
          NSLog(@"Kayoko: Failed to remove history item: %@", error);
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) {
            completion(success);
        }
      });
    }];
}

- (void)movePasteboardItem:(PasteboardItem *)item
        fromHistoryWithKey:(NSString *)sourceHistoryKey
          toHistoryWithKey:(NSString *)destinationHistoryKey
                completion:(void (^)(BOOL success))completion {
    NSDictionary *dictionary = [self dictionaryForPasteboardItem:item];
    NSUInteger destinationLimit = [self limitForHistoryKey:destinationHistoryKey];
    [self performHistoryAsync:^{
      NSError *error = nil;
      BOOL success = [[self historyStoreOnHistoryQueue] moveItemDictionary:dictionary
                                                            fromHistoryKey:sourceHistoryKey
                                                              toHistoryKey:destinationHistoryKey
                                                          destinationLimit:destinationLimit
                                                                     error:&error];
      if (!success) {
          NSLog(@"Kayoko: Failed to move history item: %@", error);
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) {
            completion(success);
        }
      });
    }];
}

- (void)removeAllPasteboardItemsFromHistoryWithKey:(NSString *)historyKey
                                shouldRemoveImages:(BOOL)shouldRemoveImages
                           postsChangeNotification:(BOOL)postsChangeNotification
                                        completion:(void (^)(BOOL success))completion {
    [self performHistoryAsync:^{
      NSError *error = nil;
      BOOL success = [[self historyStoreOnHistoryQueue] removeItemsFromHistoryKey:historyKey
                                                               shouldRemoveImages:shouldRemoveImages
                                                                            error:&error];
      if (!success) {
          NSLog(@"Kayoko: Failed to remove history items: %@", error);
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        if (success && postsChangeNotification) {
            [self postHistoryChangedNotificationForHistoryKey:historyKey
                                                   changeType:kPasteboardManagerHistoryChangeTypeClear
                                               itemDictionary:nil
                                                        limit:[self limitForHistoryKey:historyKey]];
        }
        if (completion) {
            completion(success);
        }
      });
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

- (void)performDirectPasteWithPasteboardItem:(PasteboardItem *)pasteboardItem
                                 historyItem:(PasteboardItem *)historyItem
                          fromHistoryWithKey:(NSString *)historyKey
                             shouldAutoPaste:(BOOL)shouldAutoPaste {
    if (@available(iOS 16, *)) {
        if (_queue) {
            dispatch_async(_queue, ^{
              [self _reallyPerformDirectPasteWithPasteboardItem:pasteboardItem
                                                    historyItem:historyItem
                                             fromHistoryWithKey:historyKey
                                                shouldAutoPaste:shouldAutoPaste];
            });
            return;
        }
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
                                             (CFStringRef)kNotificationKeyHelperPaste, nil, nil, NO);
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

    NSDictionary *dictionary = [self dictionaryForPasteboardItem:item];
    NSUInteger limit = [self limitForHistoryKey:historyKey];
    __block NSError *error = nil;
    __block BOOL success = NO;
    [self performHistorySync:^{
      success = [[self historyStoreOnHistoryQueue] moveItemDictionaryToTop:dictionary
                                                              inHistoryKey:historyKey
                                                                     limit:limit
                                                                     error:&error];
    }];
    if (!success) {
        NSLog(@"Kayoko: Failed to promote history item: %@", error);
        return;
    }

    [self postHistoryChangedNotificationForHistoryKey:historyKey
                                           changeType:kPasteboardManagerHistoryChangeTypeUpsertTop
                                       itemDictionary:dictionary
                                                limit:limit];
}

- (NSMutableArray *)getItemsFromHistoryWithKey:(NSString *)historyKey {
    __block NSError *error = nil;
    __block NSMutableArray *history = nil;
    [self performHistorySync:^{
      history = [[self historyStoreOnHistoryQueue] itemsForHistoryKey:historyKey error:&error];
    }];
    if (error) {
        NSLog(@"Kayoko: Failed to load history items: %@", error);
    }
    return history ?: [[NSMutableArray alloc] init];
}

- (void)getItemsFromHistoryWithKey:(NSString *)historyKey completion:(void (^)(NSMutableArray *items))completion {
    [self performHistoryAsync:^{
      NSError *error = nil;
      NSMutableArray *history = [[self historyStoreOnHistoryQueue] itemsForHistoryKey:historyKey error:&error];
      if (error) {
          NSLog(@"Kayoko: Failed to load history items: %@", error);
      }
      NSMutableArray *items = history ?: [[NSMutableArray alloc] init];
      if (!completion) {
          return;
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(items);
      });
    }];
}

- (PasteboardItem *)getLatestHistoryItem {
    __block NSError *error = nil;
    __block NSDictionary *dictionary = nil;
    [self performHistorySync:^{
      dictionary = [[self historyStoreOnHistoryQueue] latestItemForHistoryKey:kHistoryKeyHistory error:&error];
    }];
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

- (NSDictionary *)dictionaryForPasteboardItem:(PasteboardItem *)item {
    return @{
        kItemKeyBundleIdentifier : [item bundleIdentifier] ?: @"com.apple.springboard",
        kItemKeyContent : [item content] ?: @"",
        kItemKeyImageName : [item imageName] ?: @"",
        kItemKeyHasLink : @([item hasLink])
    };
}

- (void)postHistoryChangedNotification {
    [self postHistoryChangedNotificationForHistoryKey:nil
                                           changeType:kPasteboardManagerHistoryChangeTypeReload
                                       itemDictionary:nil
                                                limit:0];
}

- (void)postHistoryChangedNotificationForHistoryKey:(NSString *)historyKey
                                         changeType:(NSString *)changeType
                                     itemDictionary:(NSDictionary *)itemDictionary
                                              limit:(NSUInteger)limit {
    NSDictionary *userInfo = [self historyChangeUserInfoWithType:changeType
                                                      historyKey:historyKey
                                                  itemDictionary:itemDictionary
                                                           limit:limit];
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter] postNotificationName:kPasteboardManagerHistoryDidChangeNotification
                                                          object:self
                                                        userInfo:userInfo];
    });
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreReload, nil, nil, YES);
}

- (NSUInteger)limitForHistoryKey:(NSString *)historyKey {
    if ([historyKey isEqualToString:kHistoryKeyFavorites]) {
        return NSUIntegerMax;
    }

    return [self maximumHistoryAmount];
}

- (BOOL)isOnHistoryQueue {
    return dispatch_get_specific(kKayokoHistoryQueueSpecificKey) == kKayokoHistoryQueueSpecificKey;
}

- (void)performHistoryAsync:(dispatch_block_t)block {
    if (!block) {
        return;
    }

    if ([self isOnHistoryQueue]) {
        block();
        return;
    }

    dispatch_async(_historyQueue, block);
}

- (void)performHistorySync:(dispatch_block_t)block {
    if (!block) {
        return;
    }

    if ([self isOnHistoryQueue]) {
        block();
        return;
    }

    dispatch_sync(_historyQueue, block);
}

- (KayokoHistoryStore *)historyStoreOnHistoryQueue {
    if (!_historyStore) {
        _historyStore = [[KayokoHistoryStore alloc] initWithDatabasePath:[PasteboardManager historyDatabasePath]
                                                              imagesPath:[PasteboardManager historyImagesPath]];
    }
    [self ensureResourcesExistOnHistoryQueue];
    return _historyStore;
}

- (void)ensureResourcesExist {
    [self performHistorySync:^{
      [self ensureResourcesExistOnHistoryQueue];
    }];
}

- (void)ensureResourcesExistOnHistoryQueue {
    if (_didPrepareHistoryStore) {
        return;
    }

    if (!_historyStore) {
        _historyStore = [[KayokoHistoryStore alloc] initWithDatabasePath:[PasteboardManager historyDatabasePath]
                                                              imagesPath:[PasteboardManager historyImagesPath]];
    }

    NSError *error = nil;
    KayokoHistoryMigrator *migrator =
        [[KayokoHistoryMigrator alloc] initWithHistoryStore:_historyStore
                                           migrationSources:[KayokoHistoryMigrator defaultMigrationSources]];
    if (![migrator migrateIfNeededWithError:&error]) {
        NSLog(@"Kayoko: Failed to prepare v4 history store: %@", error);
    }
    _didPrepareHistoryStore = YES;
}

@end
