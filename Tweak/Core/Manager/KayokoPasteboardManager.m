//
//  KayokoPasteboardManager.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoPasteboardManager.h"
#import "KayokoHistoryChangeNotifier.h"
#import "KayokoHistoryRepository.h"
#import "KayokoKeyboardShortcutSender.h"
#import "KayokoNotificationKeys.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPreferenceKeys.h"

#import <HBLog.h>
#import <ImageIO/ImageIO.h>
#import <roothide.h>

static NSTimeInterval const kKayokoPasteboardWriteConfirmationTimeout = 0.25;
static NSTimeInterval const kKayokoSimulatedAutomaticPasteDelay = 0.2;

@interface SBApplication : NSObject
@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@end

@interface UIApplication (Private)
- (SBApplication *_Nullable)_accessibilityFrontMostApplication;
@end

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPasteboardPendingWrite : NSObject
@property(nonatomic, assign, readonly, getter=isActive) BOOL active;
@property(nonatomic, assign, readonly) BOOL shouldAutoPaste;
@property(nonatomic, assign, readonly) NSUInteger token;
@property(nonatomic, assign, readonly) NSUInteger previousChangeCount;
@property(nonatomic, copy, nullable) dispatch_block_t expirationBlock;
- (NSUInteger)beginAfterChangeCount:(NSUInteger)previousChangeCount shouldAutoPaste:(BOOL)shouldAutoPaste;
- (void)scheduleExpirationOnQueue:(dispatch_queue_t)queue
                       afterDelay:(NSTimeInterval)delay
                          handler:(dispatch_block_t)handler;
- (BOOL)matchesToken:(NSUInteger)token;
- (BOOL)hasAdvancedToChangeCount:(NSUInteger)changeCount;
- (void)cancelExpirationBlock;
- (void)cancel;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoPasteboardPendingWrite

- (NSUInteger)beginAfterChangeCount:(NSUInteger)previousChangeCount shouldAutoPaste:(BOOL)shouldAutoPaste {
    [self cancelExpirationBlock];
    _token++;
    _active = YES;
    _shouldAutoPaste = shouldAutoPaste;
    _previousChangeCount = previousChangeCount;
    return _token;
}

- (void)scheduleExpirationOnQueue:(dispatch_queue_t)queue
                       afterDelay:(NSTimeInterval)delay
                          handler:(dispatch_block_t)handler {
    [self cancelExpirationBlock];
    dispatch_block_t expirationBlock = dispatch_block_create(0, handler);
    self.expirationBlock = expirationBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), queue, expirationBlock);
}

- (BOOL)matchesToken:(NSUInteger)token {
    return _active && token == _token;
}

- (BOOL)hasAdvancedToChangeCount:(NSUInteger)changeCount {
    return _active && changeCount != _previousChangeCount;
}

- (void)cancel {
    [self cancelExpirationBlock];
    _token++;
    _active = NO;
    _shouldAutoPaste = NO;
    _previousChangeCount = 0;
}

- (void)cancelExpirationBlock {
    dispatch_block_t expirationBlock = self.expirationBlock;
    if (expirationBlock) {
        dispatch_block_cancel(expirationBlock);
        self.expirationBlock = nil;
    }
}

@end

@implementation KayokoPasteboardManager {
    UIPasteboard *_pasteboard;
    NSUInteger _lastChangeCount;
    NSFileManager *_fileManager;

    dispatch_queue_t _pasteboardQueue;
    dispatch_queue_t _thumbnailQueue;
    NSCache<NSString *, UIImage *> *_thumbnailCache;

    BOOL _isPerformingDirectPaste;
    KayokoPasteboardPendingWrite *_pendingPasteboardWrite;

    KayokoHistoryRepository *_historyRepository;
    KayokoHistoryChangeNotifier *_historyChangeNotifier;
}

#pragma mark - Lifecycle

+ (instancetype)sharedInstance {
    static KayokoPasteboardManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sharedInstance = [[KayokoPasteboardManager alloc] init];
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
        _pendingPasteboardWrite = [[KayokoPasteboardPendingWrite alloc] init];
        __weak typeof(self) weakSelf = self;
        _historyRepository =
            [[KayokoHistoryRepository alloc] initWithDatabasePath:[KayokoPasteboardManager historyDatabasePath]
                                                       imagesPath:[KayokoPasteboardManager historyImagesPath]
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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(generalPasteboardDidChange:)
                                                 name:UIPasteboardChangedNotification
                                               object:_pasteboard];
}

- (void)warmUpHistoryAccess {
    [_historyRepository prepareStore];
}

- (void)checkpointHistoryDatabase {
    [_historyRepository checkpointWriteAheadLog];
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

    NSArray<KayokoPasteboardItem *> *items = [self pasteboardItemsForCurrentChange];
    [self savePasteboardItems:items
             toHistoryWithKey:kKayokoHistoryKeyHistory
                   completion:^(BOOL didSaveAnyItem) {
                     complete(didSaveAnyItem);
                   }];
}

- (BOOL)pasteboardContainsType:(NSString *)pasteboardType {
    return [_pasteboard containsPasteboardTypes:@[ pasteboardType ]];
}

- (void)generalPasteboardDidChange:(NSNotification *)notification {
    (void)notification;
    if ([_pendingPasteboardWrite isActive]) {
        HBLogDebug(@"Kayoko: pending pasteboard write observed changed notification token=%lu changeCount=%lu",
                   (unsigned long)[_pendingPasteboardWrite token], (unsigned long)[_pasteboard changeCount]);
    }
    if (@available(iOS 16, *)) {
        dispatch_async(_pasteboardQueue, ^{
          [self resolvePendingPasteboardWriteForToken:[_pendingPasteboardWrite token] didExpire:NO];
        });
        return;
    }

    [self resolvePendingPasteboardWriteForToken:[_pendingPasteboardWrite token] didExpire:NO];
}

- (BOOL)shouldIgnoreCurrentPasteboardChange {
    if ([self ignoreRemoteReplication] && [self pasteboardContainsType:@"com.apple.is-remote-clipboard"]) {
        return YES;
    }

    return [self pasteboardContainsType:@"com.apple.icns"];
}

- (NSArray<KayokoPasteboardItem *> *)pasteboardItemsForCurrentChange {
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

    NSMutableArray<KayokoPasteboardItem *> *items = [[NSMutableArray alloc] init];

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
                    KayokoPasteboardItem *item =
                        [[KayokoPasteboardItem alloc] initWithBundleIdentifier:[frontMostApplication bundleIdentifier]
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
                        [NSString stringWithFormat:@"%@/%@", [KayokoPasteboardManager historyImagesPath], imageName];
                    [UIImagePNGRepresentation([self imageByApplyingOrientation:image]) writeToFile:filePath
                                                                                        atomically:YES];
                } else {
                    imageName = [imageName stringByAppendingString:@".jpg"];
                    NSString *filePath =
                        [NSString stringWithFormat:@"%@/%@", [KayokoPasteboardManager historyImagesPath], imageName];
                    [UIImageJPEGRepresentation(image, 1) writeToFile:filePath atomically:YES];
                }

                // See the above loop.
                SBApplication *frontMostApplication =
                    [[UIApplication sharedApplication] _accessibilityFrontMostApplication];
                KayokoPasteboardItem *item =
                    [[KayokoPasteboardItem alloc] initWithBundleIdentifier:[frontMostApplication bundleIdentifier]
                                                                andContent:imageName
                                                            withImageNamed:imageName];
                [items addObject:item];
            }
        }
    }

    return items;
}

- (BOOL)_reallyPullPasteboardChanges {
    if ([_pendingPasteboardWrite isActive]) {
        HBLogDebug(@"Kayoko: ignored pasteboard pull while local write is pending token=%lu changeCount=%lu",
                   (unsigned long)[_pendingPasteboardWrite token], (unsigned long)[_pasteboard changeCount]);
        [self resolvePendingPasteboardWriteForToken:[_pendingPasteboardWrite token] didExpire:NO];
        return NO;
    }

    NSArray<KayokoPasteboardItem *> *items = [self pasteboardItemsForCurrentChange];
    return [self savePasteboardItemsSynchronously:items toHistoryWithKey:kKayokoHistoryKeyHistory];
}

#pragma mark - History Access

- (BOOL)savePasteboardItemsSynchronously:(NSArray<KayokoPasteboardItem *> *)items
                        toHistoryWithKey:(NSString *)historyKey {
    BOOL didSaveAnyItem = NO;
    for (KayokoPasteboardItem *item in items) {
        if ([self addPasteboardItem:item toHistoryWithKey:historyKey]) {
            didSaveAnyItem = YES;
        }
    }
    return didSaveAnyItem;
}

- (void)savePasteboardItems:(NSArray<KayokoPasteboardItem *> *)items
           toHistoryWithKey:(NSString *)historyKey
                 completion:(void (^)(BOOL didSaveAnyItem))completion {
    NSMutableArray<NSDictionary<NSString *, id> *> *dictionaries =
        [[NSMutableArray alloc] initWithCapacity:[items count]];
    for (KayokoPasteboardItem *item in items) {
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

- (BOOL)addPasteboardItem:(KayokoPasteboardItem *)item toHistoryWithKey:(NSString *)historyKey {
    if ([[item content] isEqualToString:@""]) {
        return NO;
    }

    NSDictionary<NSString *, id> *dictionary = [item dictionaryRepresentation];
    NSUInteger limit = [self limitForHistoryKey:historyKey];
    NSError *error = nil;
    BOOL success = [_historyRepository addItemDictionary:dictionary toHistoryKey:historyKey error:&error];
    if (!success) {
        HBLogDebug(@"Kayoko: Failed to add history item: %@", error);
        return NO;
    }

    [self postHistoryChangedNotificationForHistoryKey:historyKey
                                           changeType:kKayokoPasteboardManagerHistoryChangeTypeUpsertTop
                                       itemDictionary:dictionary
                                                limit:limit];
    return YES;
}

- (void)removePasteboardItem:(KayokoPasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage {
    NSDictionary<NSString *, id> *dictionary = [item dictionaryRepresentation];
    NSError *error = nil;
    BOOL success = [_historyRepository removeItemDictionary:dictionary
                                             fromHistoryKey:historyKey
                                          shouldRemoveImage:shouldRemoveImage
                                                      error:&error];
    if (!success) {
        HBLogDebug(@"Kayoko: Failed to remove history item: %@", error);
        return;
    }

    [self postHistoryChangedNotificationForHistoryKey:historyKey
                                           changeType:kKayokoPasteboardManagerHistoryChangeTypeRemove
                                       itemDictionary:dictionary
                                                limit:[self limitForHistoryKey:historyKey]];
}

- (void)removePasteboardItem:(KayokoPasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage
                  completion:(void (^)(BOOL success))completion {
    NSDictionary<NSString *, id> *dictionary = [item dictionaryRepresentation];
    [_historyRepository removeItemDictionary:dictionary
                              fromHistoryKey:historyKey
                           shouldRemoveImage:shouldRemoveImage
                                  completion:completion];
}

- (void)movePasteboardItem:(KayokoPasteboardItem *)item
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

- (void)performDirectPasteWithPasteboardItem:(KayokoPasteboardItem *)pasteboardItem
                                 historyItem:(KayokoPasteboardItem *)historyItem
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

- (void)updatePasteboardWithItem:(KayokoPasteboardItem *)item
              fromHistoryWithKey:(NSString *)historyKey
                 shouldAutoPaste:(BOOL)shouldAutoPaste {
    [self performDirectPasteWithPasteboardItem:item
                                   historyItem:item
                            fromHistoryWithKey:historyKey
                               shouldAutoPaste:shouldAutoPaste];
}

- (BOOL)copyPasteboardItemToPasteboard:(KayokoPasteboardItem *)item {
    if (@available(iOS 16, *)) {
        __block BOOL didUpdatePasteboard = NO;
        dispatch_sync(_pasteboardQueue, ^{
          didUpdatePasteboard = [self _reallyCopyPasteboardItemToPasteboard:item];
        });
        return didUpdatePasteboard;
    }

    return [self _reallyCopyPasteboardItemToPasteboard:item];
}

- (BOOL)_reallyCopyPasteboardItemToPasteboard:(KayokoPasteboardItem *)item {
    [self cancelPendingPasteboardWrite];
    NSUInteger previousChangeCount = [_pasteboard changeCount];
    HBLogDebug(@"Kayoko: copy write started previousChangeCount=%lu contentLength=%lu hasImage=%@",
               (unsigned long)previousChangeCount, (unsigned long)[[item content] length],
               ([[item imageName] length] > 0) ? @"YES" : @"NO");
    BOOL didUpdatePasteboard = [self setPasteboardContentFromItem:item];
    if (didUpdatePasteboard) {
        NSUInteger token = [self beginPendingPasteboardWriteAfterChangeCount:previousChangeCount shouldAutoPaste:NO];
        [self resolvePendingPasteboardWriteForToken:token didExpire:NO];
    } else {
        HBLogDebug(@"Kayoko: copy write did not update pasteboard previousChangeCount=%lu",
                   (unsigned long)previousChangeCount);
    }
    return didUpdatePasteboard;
}

- (void)_reallyPerformDirectPasteWithPasteboardItem:(KayokoPasteboardItem *)pasteboardItem
                                        historyItem:(KayokoPasteboardItem *)historyItem
                                 fromHistoryWithKey:(NSString *)historyKey
                                    shouldAutoPaste:(BOOL)shouldAutoPaste {
    if (_isPerformingDirectPaste) {
        HBLogDebug(@"Kayoko: direct paste ignored because another direct paste is in progress");
        return;
    }

    _isPerformingDirectPaste = YES;

    [self cancelPendingPasteboardWrite];
    NSUInteger previousChangeCount = [_pasteboard changeCount];
    HBLogDebug(@"Kayoko: direct paste write started previousChangeCount=%lu contentLength=%lu hasImage=%@ "
               @"shouldAutoPaste=%@ automaticallyPaste=%@ automaticPasteMode=%lu historyKey=%@",
               (unsigned long)previousChangeCount, (unsigned long)[[pasteboardItem content] length],
               ([[pasteboardItem imageName] length] > 0) ? @"YES" : @"NO", shouldAutoPaste ? @"YES" : @"NO",
               [self automaticallyPaste] ? @"YES" : @"NO", (unsigned long)[self automaticPasteMode], historyKey);
    BOOL didUpdatePasteboard = [self setPasteboardContentFromItem:pasteboardItem];
    if (didUpdatePasteboard) {
        [self movePasteboardItemToTop:historyItem inHistoryWithKey:historyKey];

        NSUInteger token =
            [self beginPendingPasteboardWriteAfterChangeCount:previousChangeCount
                                              shouldAutoPaste:([self automaticallyPaste] && shouldAutoPaste)];
        [self resolvePendingPasteboardWriteForToken:token didExpire:NO];
    } else {
        HBLogDebug(@"Kayoko: direct paste write did not update pasteboard previousChangeCount=%lu",
                   (unsigned long)previousChangeCount);
    }

    _isPerformingDirectPaste = NO;
}

- (NSUInteger)beginPendingPasteboardWriteAfterChangeCount:(NSUInteger)previousChangeCount
                                          shouldAutoPaste:(BOOL)shouldAutoPaste {
    NSUInteger token = [_pendingPasteboardWrite beginAfterChangeCount:previousChangeCount
                                                      shouldAutoPaste:shouldAutoPaste];
    HBLogDebug(@"Kayoko: pending pasteboard write began token=%lu previousChangeCount=%lu shouldAutoPaste=%@",
               (unsigned long)token, (unsigned long)previousChangeCount, shouldAutoPaste ? @"YES" : @"NO");
    dispatch_queue_t timeoutQueue = dispatch_get_main_queue();
    if (@available(iOS 16, *)) {
        timeoutQueue = _pasteboardQueue;
    }
    __weak typeof(self) weakSelf = self;
    [_pendingPasteboardWrite scheduleExpirationOnQueue:timeoutQueue
                                            afterDelay:kKayokoPasteboardWriteConfirmationTimeout
                                               handler:^{
                                                 __strong typeof(weakSelf) strongSelf = weakSelf;
                                                 [strongSelf resolvePendingPasteboardWriteForToken:token didExpire:YES];
                                               }];

    return token;
}

- (BOOL)resolvePendingPasteboardWriteForToken:(NSUInteger)token didExpire:(BOOL)didExpire {
    if (![_pendingPasteboardWrite matchesToken:token]) {
        if (didExpire) {
            HBLogDebug(@"Kayoko: ignored stale pending pasteboard write timeout token=%lu activeToken=%lu active=%@",
                       (unsigned long)token, (unsigned long)[_pendingPasteboardWrite token],
                       ([_pendingPasteboardWrite isActive] ? @"YES" : @"NO"));
        }
        return NO;
    }

    NSUInteger currentChangeCount = [_pasteboard changeCount];
    if (![_pendingPasteboardWrite hasAdvancedToChangeCount:currentChangeCount]) {
        if (didExpire) {
            HBLogDebug(
                @"Kayoko: pending pasteboard write timed out token=%lu previousChangeCount=%lu currentChangeCount=%lu",
                (unsigned long)token, (unsigned long)[_pendingPasteboardWrite previousChangeCount],
                (unsigned long)currentChangeCount);
            [self cancelPendingPasteboardWrite];
        }
        return NO;
    }

    BOOL shouldAutoPaste = [_pendingPasteboardWrite shouldAutoPaste];
    _lastChangeCount = currentChangeCount;
    [self cancelPendingPasteboardWrite];

    HBLogDebug(@"Kayoko: pending pasteboard write confirmed token=%lu currentChangeCount=%lu shouldAutoPaste=%@",
               (unsigned long)token, (unsigned long)currentChangeCount, shouldAutoPaste ? @"YES" : @"NO");
    if (shouldAutoPaste) {
        [self performAutomaticPasteForToken:token];
    }

    return YES;
}

- (void)performAutomaticPasteForToken:(NSUInteger)token {
    if ([self automaticPasteMode] == kKayokoAutomaticPasteModeSimulated) {
        HBLogDebug(@"Kayoko: scheduling simulated Cmd+V automatic paste token=%lu delay=%.2f", (unsigned long)token,
                   kKayokoSimulatedAutomaticPasteDelay);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kKayokoSimulatedAutomaticPasteDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                         CFNotificationCenterPostNotification(
                             CFNotificationCenterGetDarwinNotifyCenter(),
                             (__bridge CFStringRef)kKayokoNotificationKeyPasteWillStart, nil, nil, YES);
                         CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                              (__bridge CFStringRef)kKayokoNotificationKeyPasteFeedback,
                                                              nil, nil, YES);
                         [[KayokoKeyboardShortcutSender sharedSender] sendCommandV];
                       });
        return;
    }

    HBLogDebug(@"Kayoko: posting helper paste notification token=%lu", (unsigned long)token);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kKayokoNotificationKeyHelperPaste, nil, nil, NO);
}

- (void)cancelPendingPasteboardWrite {
    [_pendingPasteboardWrite cancel];
}

- (BOOL)setPasteboardContentFromItem:(KayokoPasteboardItem *)item {
    if (!item) {
        return NO;
    }

    if ([[item imageName] length] > 0) {
        NSString *filePath =
            [NSString stringWithFormat:@"%@/%@", [KayokoPasteboardManager historyImagesPath], [item imageName]];
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

- (void)movePasteboardItemToTop:(KayokoPasteboardItem *)item inHistoryWithKey:(NSString *)historyKey {
    if (!item || [[item content] length] == 0 || [[historyKey description] length] == 0) {
        return;
    }

    NSDictionary<NSString *, id> *dictionary = [item dictionaryRepresentation];
    NSUInteger limit = [self limitForHistoryKey:historyKey];
    NSError *error = nil;
    BOOL success = [_historyRepository moveItemDictionaryToTop:dictionary inHistoryKey:historyKey error:&error];
    if (!success) {
        HBLogDebug(@"Kayoko: Failed to promote history item: %@", error);
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
        HBLogDebug(@"Kayoko: Failed to load history items: %@", error);
    }
    return history ?: [[NSMutableArray alloc] init];
}

- (void)getItemsFromHistoryWithKey:(NSString *)historyKey
                        completion:(void (^)(NSMutableArray<NSDictionary<NSString *, id> *> *items))completion {
    [_historyRepository itemsForHistoryKey:historyKey completion:completion];
}

- (KayokoPasteboardItem *)getLatestHistoryItem {
    NSError *error = nil;
    NSDictionary<NSString *, id> *dictionary = [_historyRepository latestItemForHistoryKey:kKayokoHistoryKeyHistory
                                                                                     error:&error];
    if (error) {
        HBLogDebug(@"Kayoko: Failed to load latest history item: %@", error);
    }
    return [KayokoPasteboardItem itemFromDictionary:dictionary];
}

- (UIImage *)getImageForItem:(KayokoPasteboardItem *)item {
    NSData *imageData =
        [_fileManager contentsAtPath:[NSString stringWithFormat:@"%@/%@", [KayokoPasteboardManager historyImagesPath],
                                                                [item imageName]]];
    return [UIImage imageWithData:imageData];
}

- (NSString *)thumbnailCacheKeyForImageName:(NSString *)imageName targetSize:(CGSize)targetSize scale:(CGFloat)scale {
    return [NSString
        stringWithFormat:@"%@|%.0fx%.0f|%.2f", imageName, ceil(targetSize.width), ceil(targetSize.height), scale];
}

- (NSUInteger)thumbnailMaximumPixelSizeForImageProperties:(NSDictionary<NSString *, id> *)properties
                                               targetSize:(CGSize)targetSize
                                                    scale:(CGFloat)scale {
    CGFloat targetPixelWidth = MAX(ceil(targetSize.width * scale), 1);
    CGFloat targetPixelHeight = MAX(ceil(targetSize.height * scale), 1);
    CGFloat imagePixelWidth = [properties[(NSString *)kCGImagePropertyPixelWidth] doubleValue];
    CGFloat imagePixelHeight = [properties[(NSString *)kCGImagePropertyPixelHeight] doubleValue];
    NSUInteger orientation = [properties[(NSString *)kCGImagePropertyOrientation] unsignedIntegerValue];
    if (orientation >= 5 && orientation <= 8) {
        CGFloat swappedWidth = imagePixelHeight;
        imagePixelHeight = imagePixelWidth;
        imagePixelWidth = swappedWidth;
    }

    if (imagePixelWidth <= 0 || imagePixelHeight <= 0) {
        return (NSUInteger)ceil(MAX(targetPixelWidth, targetPixelHeight));
    }

    CGFloat fillScale = MAX(targetPixelWidth / imagePixelWidth, targetPixelHeight / imagePixelHeight);
    CGFloat thumbnailPixelWidth = imagePixelWidth * fillScale;
    CGFloat thumbnailPixelHeight = imagePixelHeight * fillScale;
    return (NSUInteger)ceil(MAX(thumbnailPixelWidth, thumbnailPixelHeight));
}

- (void)getThumbnailForItem:(KayokoPasteboardItem *)item
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

    NSString *imagePath = [[KayokoPasteboardManager historyImagesPath] stringByAppendingPathComponent:imageName];
    NSURL *imageURL = [NSURL fileURLWithPath:imagePath];

    dispatch_async(_thumbnailQueue, ^{
      CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)imageURL, NULL);
      UIImage *thumbnailImage = nil;
      if (imageSource) {
          NSDictionary<NSString *, id> *properties =
              CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL));
          NSUInteger maximumPixelSize = [self thumbnailMaximumPixelSizeForImageProperties:properties ?: @{}
                                                                               targetSize:targetSize
                                                                                    scale:scale];
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
