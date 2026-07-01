//
//  PasteboardManager.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class PasteboardItem;

NS_ASSUME_NONNULL_BEGIN

static NSString *const kKayokoHistoryKeyHistory = @"history";
static NSString *const kKayokoHistoryKeyFavorites = @"favorites";
static NSString *const kKayokoPasteboardManagerHistoryDidChangeNotification = @"com.82flex.kayoko.history.did-change";
static NSString *const kKayokoPasteboardManagerHistoryChangeTypeKey = @"change_type";
static NSString *const kKayokoPasteboardManagerHistoryChangeHistoryKeyKey = @"history_key";
static NSString *const kKayokoPasteboardManagerHistoryChangeItemKey = @"item";
static NSString *const kKayokoPasteboardManagerHistoryChangeLimitKey = @"limit";
static NSString *const kKayokoPasteboardManagerHistoryChangeTypeReload = @"reload";
static NSString *const kKayokoPasteboardManagerHistoryChangeTypeUpsertTop = @"upsert_top";
static NSString *const kKayokoPasteboardManagerHistoryChangeTypeRemove = @"remove";
static NSString *const kKayokoPasteboardManagerHistoryChangeTypeClear = @"clear";

@interface PasteboardManager : NSObject

@property(nonatomic, assign) NSUInteger maximumHistoryAmount;
@property(nonatomic, assign) BOOL saveText;
@property(nonatomic, assign) BOOL saveImages;
@property(nonatomic, assign) BOOL automaticallyPaste;

+ (instancetype)sharedInstance;
- (instancetype)init NS_UNAVAILABLE;
- (void)preparePasteboardQueue;
- (void)prepareHistoryStore;

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
                  completion:(nullable void (^)(BOOL success))completion;
- (void)movePasteboardItem:(PasteboardItem *)item
        fromHistoryWithKey:(NSString *)sourceHistoryKey
          toHistoryWithKey:(NSString *)destinationHistoryKey
                completion:(nullable void (^)(BOOL success))completion;
- (void)removeAllPasteboardItemsFromHistoryWithKey:(NSString *)historyKey
                                shouldRemoveImages:(BOOL)shouldRemoveImages
                                        completion:(nullable void (^)(BOOL success))completion;
- (void)removeAllPasteboardItemsFromHistoryWithKey:(NSString *)historyKey
                                shouldRemoveImages:(BOOL)shouldRemoveImages
                           postsChangeNotification:(BOOL)postsChangeNotification
                                        completion:(nullable void (^)(BOOL success))completion;

- (NSMutableArray<NSDictionary<NSString *, id> *> *)getItemsFromHistoryWithKey:(NSString *)historyKey;
- (void)getItemsFromHistoryWithKey:(NSString *)historyKey
                        completion:(nullable void (^)(NSMutableArray<NSDictionary<NSString *, id> *> *items))completion;
- (nullable PasteboardItem *)getLatestHistoryItem;
- (nullable UIImage *)getImageForItem:(PasteboardItem *)item;

@end

NS_ASSUME_NONNULL_END
