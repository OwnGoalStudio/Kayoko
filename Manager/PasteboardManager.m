//
//  PasteboardManager.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "PasteboardManager.h"
#import "ImageUtil.h"
#import "KayokoHistoryChangeNotifier.h"
#import "KayokoHistoryRepository.h"
#import "NotificationKeys.h"
#import "PasteboardItem.h"
#import "PreferenceKeys.h"
#import "StringUtil.h"

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

    dispatch_queue_t _queue;

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

- (void)preparePasteboardQueue {
    if (@available(iOS 16, *)) {
        _queue = dispatch_queue_create("com.82flex.kayoko.queue.pasteboard", DISPATCH_QUEUE_SERIAL);
    }
}

- (void)prepareHistoryStore {
    [_historyRepository prepareStore];
}

#pragma mark - Pasteboard Observation

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

    [_historyRepository ensureStorePrepared];

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
                    [self addPasteboardItem:item toHistoryWithKey:kKayokoHistoryKeyHistory];
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
                [self addPasteboardItem:item toHistoryWithKey:kKayokoHistoryKeyHistory];
            }
        }
    }

    _lastChangeCount = [_pasteboard changeCount];
}

#pragma mark - History Mutations

- (void)addPasteboardItem:(PasteboardItem *)item toHistoryWithKey:(NSString *)historyKey {
    if ([[item content] isEqualToString:@""]) {
        return;
    }

    NSDictionary<NSString *, id> *dictionary = [item dictionaryRepresentation];
    NSUInteger limit = [self limitForHistoryKey:historyKey];
    NSError *error = nil;
    BOOL success = [_historyRepository addItemDictionary:dictionary toHistoryKey:historyKey error:&error];
    if (!success) {
        NSLog(@"Kayoko: Failed to add history item: %@", error);
        return;
    }

    [self postHistoryChangedNotificationForHistoryKey:historyKey
                                           changeType:kKayokoPasteboardManagerHistoryChangeTypeUpsertTop
                                       itemDictionary:dictionary
                                                limit:limit];
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
