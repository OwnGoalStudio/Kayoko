//
//  PasteboardManager.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "PasteboardManager.h"
#import "AlertUtil.h"
#import "ImageUtil.h"
#import "NotificationKeys.h"
#import "PasteboardItem.h"
#import "PreferenceKeys.h"
#import "StringUtil.h"

#import <libroot.h>

@implementation PasteboardManager {
    dispatch_queue_t _queue;
    BOOL _isPerformingDirectPaste;
}

/**
 * Creates the shared instance.
 */
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
      kHistoryPath = JBROOT_PATH_NSSTRING(@"/var/mobile/Library/com.82flex.kayoko/history.json");
    });
    return kHistoryPath;
}

+ (NSString *)historyImagesPath {
    static NSString *kHistoryImagesPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kHistoryImagesPath = JBROOT_PATH_NSSTRING(@"/var/mobile/Library/com.82flex.kayoko/images/");
    });
    return kHistoryImagesPath;
}

+ (NSBundle *)localizationBundle {
    static NSBundle *kLocalizationBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kLocalizationBundle =
          [NSBundle bundleWithPath:JBROOT_PATH_NSSTRING(@"/Library/PreferenceBundles/KayokoPreferences.bundle")];
    });
    return kLocalizationBundle;
}

/**
 * Creates the manager using the shared instance.
 */
- (instancetype)init {
    self = [super init];
    if (self) {
        _fileManager = [NSFileManager defaultManager];
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

/**
 * Pulls new changes from the pasteboard.
 */
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

/**
 * Adds an item to a specified history.
 *
 * @param item The item to save.
 * @param historyKey The key for the history which to save to.
 */
- (void)addPasteboardItem:(PasteboardItem *)item toHistoryWithKey:(NSString *)historyKey {
    if ([[item content] isEqualToString:@""]) {
        return;
    }

    // Remove duplicates.
    [self removePasteboardItem:item fromHistoryWithKey:historyKey shouldRemoveImage:NO];

    NSMutableDictionary *json = [self getJson];
    NSMutableArray *history = [self getItemsFromHistoryWithKey:historyKey];

    [history insertObject:@{
        kItemKeyBundleIdentifier : [item bundleIdentifier] ?: @"com.apple.springboard",
        kItemKeyContent : [item content] ?: @"",
        kItemKeyImageName : [item imageName] ?: @"",
        kItemKeyHasLink : @([item hasLink])
    }
                  atIndex:0];

    // Truncate the history corresponding the set limit.
    while ([history count] > [self maximumHistoryAmount]) {
        [history removeLastObject];
    }

    json[historyKey] = history;

    [self setJsonFromDictionary:json];
}

/**
 * Removes an item from a specified history.
 *
 * @param item The item to remove.
 * @param historyKey The key for the history from which to remove from.
 * @param shouldRemoveImage Whether to remove the item's corresponding image or not.
 */
- (void)removePasteboardItem:(PasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage {
    NSMutableDictionary *json = [self getJson];
    NSMutableArray *history = [self getItemsFromHistoryWithKey:historyKey];

    for (NSDictionary *dictionary in history) {
        @autoreleasepool {
            PasteboardItem *historyItem = [PasteboardItem itemFromDictionary:dictionary];

            if ([[historyItem content] isEqualToString:[item content]]) {
                [history removeObject:dictionary];

                if ([[item imageName] length] > 0 && shouldRemoveImage) {
                    NSString *filePath =
                        [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]];
                    [_fileManager removeItemAtPath:filePath error:nil];
                }

                break;
            }
        }
    }

    json[historyKey] = history;

    [self setJsonFromDictionary:json];
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

/**
 * Performs a direct paste transaction with explicit history promotion.
 *
 * @param pasteboardItem The item from which to set the pasteboard content.
 * @param historyItem The original item that should be moved to the top of its history.
 * @param historyKey The key for the history which the item is from.
 * @param shouldAutoPaste Whether the helper should automatically paste the new content.
 */
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

    NSMutableDictionary *json = [self getJson];
    NSMutableArray *history = [self getItemsFromHistoryWithKey:historyKey];

    NSDictionary *dictionaryToPromote = nil;
    NSUInteger indexToPromote = NSNotFound;
    for (NSUInteger index = 0; index < [history count]; index++) {
        NSDictionary *dictionary = history[index];
        PasteboardItem *historyItem = [PasteboardItem itemFromDictionary:dictionary];
        if ([[historyItem content] isEqualToString:[item content]]) {
            dictionaryToPromote = dictionary;
            indexToPromote = index;
            break;
        }
    }

    if (dictionaryToPromote) {
        [history removeObjectAtIndex:indexToPromote];
    } else {
        dictionaryToPromote = @{
            kItemKeyBundleIdentifier : [item bundleIdentifier] ?: @"com.apple.springboard",
            kItemKeyContent : [item content] ?: @"",
            kItemKeyImageName : [item imageName] ?: @"",
            kItemKeyHasLink : @([item hasLink])
        };
    }

    [history insertObject:dictionaryToPromote atIndex:0];

    while ([history count] > [self maximumHistoryAmount]) {
        [history removeLastObject];
    }

    json[historyKey] = history;
    [self setJsonFromDictionary:json];
}

/**
 * Returns all items from a specified history.
 *
 * @param historyKey The key for the history from which to get the items from.
 *
 * @return The history's items.
 */
- (NSMutableArray *)getItemsFromHistoryWithKey:(NSString *)historyKey {
    NSDictionary *json = [self getJson];
    NSMutableArray *history = json[historyKey];
    if (!history && [historyKey isEqualToString:kHistoryKeyHistory]) {
        history = json[@"History"];
    } else if (!history && [historyKey isEqualToString:kHistoryKeyFavorites]) {
        history = json[@"Favorites"];
    }
    return history ?: [[NSMutableArray alloc] init];
}

/**
 * Returns the latest item from the default history.
 *
 * @return The item.
 */
- (PasteboardItem *)getLatestHistoryItem {
    NSArray *history = [self getItemsFromHistoryWithKey:kHistoryKeyHistory];
    return [PasteboardItem itemFromDictionary:[history firstObject] ?: nil];
}

/**
 * Returns the image for an item.
 *
 * @param item The item from which to get the image from.
 *
 * @return The image.
 */
- (UIImage *)getImageForItem:(PasteboardItem *)item {
    NSData *imageData = [_fileManager
        contentsAtPath:[NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]]];
    return [UIImage imageWithData:imageData];
}

/**
 * Creates and returns a dictionary from the json containing the histories.
 *
 * @return The dictionary.
 */
- (NSMutableDictionary *)getJson {
    [self ensureResourcesExist];

    NSData *jsonData = [NSData dataWithContentsOfFile:[PasteboardManager historyPath]];
    NSMutableDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                options:NSJSONReadingMutableContainers
                                                                  error:nil];

    return json;
}

/**
 * Stores the contents from a dictionary to a json file.
 *
 * @param dictionary The dictionary from which to save the contents from.
 */
- (void)setJsonFromDictionary:(NSMutableDictionary *)dictionary {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:NSJSONWritingPrettyPrinted error:nil];
    [jsonData writeToFile:[PasteboardManager historyPath] atomically:YES];

    // Tell the core to reload the history view.
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreReload, nil, nil, YES);
}

/**
 * Creates the json for the histories and path for the images.
 */
- (void)ensureResourcesExist {
    BOOL isDirectory;
    if (![_fileManager fileExistsAtPath:[PasteboardManager historyImagesPath] isDirectory:&isDirectory]) {
        [_fileManager createDirectoryAtPath:[PasteboardManager historyImagesPath]
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:nil];
    }

    if (![_fileManager fileExistsAtPath:[PasteboardManager historyPath]]) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[[NSMutableDictionary alloc] init]
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:nil];
        [jsonData writeToFile:[PasteboardManager historyPath] options:NSDataWritingAtomic error:nil];
    }
}

@end
