//
//  PasteboardManager.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class PasteboardItem;

static NSString *const kHistoryKeyHistory = @"history";
static NSString *const kHistoryKeyFavorites = @"favorites";
static NSString *const kPasteboardManagerHistoryDidChangeNotification = @"com.82flex.kayoko.history.did-change";
static NSString *const kPasteboardManagerHistoryChangeTypeKey = @"change_type";
static NSString *const kPasteboardManagerHistoryChangeHistoryKeyKey = @"history_key";
static NSString *const kPasteboardManagerHistoryChangeItemKey = @"item";
static NSString *const kPasteboardManagerHistoryChangeLimitKey = @"limit";
static NSString *const kPasteboardManagerHistoryChangeTypeReload = @"reload";
static NSString *const kPasteboardManagerHistoryChangeTypeUpsertTop = @"upsert_top";
static NSString *const kPasteboardManagerHistoryChangeTypeRemove = @"remove";
static NSString *const kPasteboardManagerHistoryChangeTypeClear = @"clear";

@interface PasteboardManager : NSObject

@property(nonatomic, assign) NSUInteger maximumHistoryAmount;
@property(nonatomic, assign) BOOL saveText;
@property(nonatomic, assign) BOOL saveImages;
@property(nonatomic, assign) BOOL automaticallyPaste;

+ (instancetype)sharedInstance;
- (instancetype)init NS_UNAVAILABLE;
- (void)preparePasteboardQueue;

+ (NSString *)historyPath;
+ (NSString *)historyDatabasePath;
+ (NSString *)historyImagesPath;
+ (NSBundle *)localizationBundle;
+ (NSUInteger)normalizedMaximumHistoryAmountForValue:(NSUInteger)value;

- (void)pullPasteboardChanges;
- (void)addPasteboardItem:(PasteboardItem *)item toHistoryWithKey:(NSString *)historyKey;
- (void)performDirectPasteWithPasteboardItem:(PasteboardItem *)pasteboardItem
                                 historyItem:(PasteboardItem *)historyItem
                          fromHistoryWithKey:(NSString *)historyKey
                             shouldAutoPaste:(BOOL)shouldAutoPaste;
- (BOOL)copyPasteboardItemToPasteboard:(PasteboardItem *)item;
- (void)updatePasteboardWithItem:(PasteboardItem *)item
              fromHistoryWithKey:(NSString *)historyKey
                 shouldAutoPaste:(BOOL)shouldAutoPaste;
- (void)removePasteboardItem:(PasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage;
- (void)removePasteboardItem:(PasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage
                  completion:(void (^)(BOOL success))completion;
- (void)movePasteboardItem:(PasteboardItem *)item
        fromHistoryWithKey:(NSString *)sourceHistoryKey
          toHistoryWithKey:(NSString *)destinationHistoryKey
                completion:(void (^)(BOOL success))completion;
- (void)removeAllPasteboardItemsFromHistoryWithKey:(NSString *)historyKey
                                shouldRemoveImages:(BOOL)shouldRemoveImages
                                        completion:(void (^)(BOOL success))completion;
- (void)removeAllPasteboardItemsFromHistoryWithKey:(NSString *)historyKey
                                shouldRemoveImages:(BOOL)shouldRemoveImages
                           postsChangeNotification:(BOOL)postsChangeNotification
                                        completion:(void (^)(BOOL success))completion;

- (NSMutableArray *)getItemsFromHistoryWithKey:(NSString *)historyKey;
- (void)getItemsFromHistoryWithKey:(NSString *)historyKey completion:(void (^)(NSMutableArray *items))completion;
- (PasteboardItem *)getLatestHistoryItem;
- (UIImage *)getImageForItem:(PasteboardItem *)item;

@end
