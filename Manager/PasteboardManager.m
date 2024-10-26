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
      kHistoryPath = JBROOT_PATH_NSSTRING(@"/var/mobile/Library/codes.aurora.kayoko/history.json");
    });
    return kHistoryPath;
}

+ (NSString *)historyImagesPath {
    static NSString *kHistoryImagesPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kHistoryImagesPath = JBROOT_PATH_NSSTRING(@"/var/mobile/Library/codes.aurora.kayoko/images/");
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
        _pasteboard = [UIPasteboard generalPasteboard];
        _lastChangeCount = [_pasteboard changeCount];
        _fileManager = [NSFileManager defaultManager];
    }
    return self;
}

- (void)preparePasteboardQueue {
    if (@available(iOS 16, *)) {
        _queue = dispatch_queue_create("codes.aurora.kayoko.queue.pasteboard", DISPATCH_QUEUE_SERIAL);
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
    NSMutableArray *history = json[historyKey];

    for (NSDictionary *dictionary in history) {
        @autoreleasepool {
            PasteboardItem *historyItem = [PasteboardItem itemFromDictionary:dictionary];

            if ([[historyItem content] isEqualToString:[item content]]) {
                [history removeObject:dictionary];

                if (![[item imageName] isEqualToString:@""] && shouldRemoveImage) {
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

- (void)updatePasteboardWithItem:(PasteboardItem *)item
              fromHistoryWithKey:(NSString *)historyKey
                 shouldAutoPaste:(BOOL)shouldAutoPaste {
    if (@available(iOS 16, *)) {
        dispatch_async(_queue, ^{
          [self _reallyUpdatePasteboardWithItem:item fromHistoryWithKey:historyKey shouldAutoPaste:shouldAutoPaste];
        });
    } else {
        [self _reallyUpdatePasteboardWithItem:item fromHistoryWithKey:historyKey shouldAutoPaste:shouldAutoPaste];
    }
}

/**
 * Updates the pasteboard with an item's content.
 *
 * @param item The item from which to set the content from.
 * @param historyKey The key for the history which the item is from.
 * @param shouldAutoPaste Whether the helper should automatically paste the new content.
 */
- (void)_reallyUpdatePasteboardWithItem:(PasteboardItem *)item
                     fromHistoryWithKey:(NSString *)historyKey
                        shouldAutoPaste:(BOOL)shouldAutoPaste {
    [_pasteboard setString:@""];

    if (![[item imageName] isEqualToString:@""]) {
        NSString *filePath =
            [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        [_pasteboard setImage:image];
    } else {
        [_pasteboard setString:[item content]];
    }

    // The pasteboard updates with the given item, which triggers an update event.
    // Therefore we remove the given item to prevent duplicates.
    [_pasteboard changeCount];
    [self removePasteboardItem:item fromHistoryWithKey:historyKey shouldRemoveImage:YES];

    // Automatic paste should not occur for asynchronous operations.
    if ([self automaticallyPaste] && shouldAutoPaste) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             (CFStringRef)kNotificationKeyHelperPaste, nil, nil, NO);
    }
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
    return json[historyKey] ?: [[NSMutableArray alloc] init];
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
