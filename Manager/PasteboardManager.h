//
//  PasteboardManager.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class PasteboardItem;

static NSString *const kHistoryKeyHistory = @"History";
static NSString *const kHistoryKeyFavorites = @"Favorites";

@interface PasteboardManager : NSObject {
    UIPasteboard *_pasteboard;
    NSUInteger _lastChangeCount;
    NSFileManager *_fileManager;
}
@property(nonatomic, assign) NSUInteger maximumHistoryAmount;
@property(nonatomic, assign) BOOL saveText;
@property(nonatomic, assign) BOOL saveImages;
@property(nonatomic, assign) BOOL automaticallyPaste;

+ (instancetype)sharedInstance;
- (instancetype)init NS_UNAVAILABLE;
- (void)preparePasteboardQueue;

+ (NSString *)historyPath;
+ (NSString *)historyImagesPath;
+ (NSBundle *)localizationBundle;

- (void)pullPasteboardChanges;
- (void)addPasteboardItem:(PasteboardItem *)item toHistoryWithKey:(NSString *)historyKey;
- (void)performDirectPasteWithPasteboardItem:(PasteboardItem *)pasteboardItem
                                 historyItem:(PasteboardItem *)historyItem
                          fromHistoryWithKey:(NSString *)historyKey
                             shouldAutoPaste:(BOOL)shouldAutoPaste;
- (void)updatePasteboardWithItem:(PasteboardItem *)item
              fromHistoryWithKey:(NSString *)historyKey
                 shouldAutoPaste:(BOOL)shouldAutoPaste;
- (void)removePasteboardItem:(PasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage;

- (NSMutableArray *)getItemsFromHistoryWithKey:(NSString *)historyKey;
- (PasteboardItem *)getLatestHistoryItem;
- (UIImage *)getImageForItem:(PasteboardItem *)item;

@end

@interface SBApplication : NSObject
@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@end

@interface UIApplication (Private)
- (SBApplication *)_accessibilityFrontMostApplication;
@end
