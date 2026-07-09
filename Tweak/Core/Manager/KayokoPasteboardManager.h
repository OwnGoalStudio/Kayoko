//
//  KayokoPasteboardManager.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class KayokoPasteboardItem;
@class KayokoSearchCriteria;

NS_ASSUME_NONNULL_BEGIN

typedef void (^KayokoPasteboardItemsCompletion)(NSMutableArray<NSDictionary<NSString *, id> *> *items,
                                                NSError *_Nullable error);
typedef void (^KayokoPasteboardAppBundleIdentifiersCompletion)(NSArray<NSString *> *bundleIdentifiers,
                                                               NSError *_Nullable error);

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

@interface KayokoPasteboardManager : NSObject

@property(nonatomic, assign) NSUInteger maximumHistoryAmount;
@property(nonatomic, assign) BOOL saveText;
@property(nonatomic, assign) BOOL saveImages;
@property(nonatomic, assign) BOOL automaticallyPaste;
@property(nonatomic, assign) NSUInteger automaticPasteMode;
@property(nonatomic, assign) NSUInteger automaticPromotionMode;
@property(nonatomic, assign) BOOL ignoreRemoteReplication;

+ (instancetype)sharedInstance;
- (instancetype)init NS_UNAVAILABLE;
- (void)warmUpHistoryAccess;
- (void)enterMaintenanceModeUntilProcessExit;

+ (NSString *)historyPath;
+ (NSString *)historyDatabasePath;
+ (NSString *)historyImagesPath;
+ (NSBundle *)localizationBundle;
+ (NSUInteger)normalizedMaximumHistoryAmountForValue:(NSUInteger)value;

- (void)checkpointHistoryDatabase;
- (void)pullPasteboardChanges;
- (void)pullPasteboardChangesWithCompletion:(nullable void (^)(BOOL didSaveAnyItem))completion;
- (BOOL)addPasteboardItem:(KayokoPasteboardItem *)item toHistoryWithKey:(NSString *)historyKey;
- (void)writePasteboardItem:(KayokoPasteboardItem *)pasteboardItem
          sourceHistoryItem:(KayokoPasteboardItem *)sourceHistoryItem
         fromHistoryWithKey:(NSString *)historyKey
       allowsAutomaticPaste:(BOOL)allowsAutomaticPaste;
- (BOOL)copyPasteboardItemToPasteboard:(KayokoPasteboardItem *)item;
- (void)removePasteboardItem:(KayokoPasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage;
- (void)removePasteboardItem:(KayokoPasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage
                  completion:(nullable void (^)(BOOL success))completion;
- (void)movePasteboardItem:(KayokoPasteboardItem *)item
        fromHistoryWithKey:(NSString *)sourceHistoryKey
          toHistoryWithKey:(NSString *)destinationHistoryKey
                completion:(nullable void (^)(BOOL success))completion;
- (void)setTagUUID:(nullable NSString *)tagUUID
    forPasteboardItem:(KayokoPasteboardItem *)item
     inHistoryWithKey:(NSString *)historyKey
           completion:(nullable void (^)(BOOL success))completion;
- (void)setNote:(nullable NSString *)note
    forPasteboardItem:(KayokoPasteboardItem *)item
     inHistoryWithKey:(NSString *)historyKey
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
                        completion:(nullable KayokoPasteboardItemsCompletion)completion;
- (void)getItemsFromHistoryWithKey:(NSString *)historyKey
                    searchCriteria:(nullable KayokoSearchCriteria *)searchCriteria
                        completion:(nullable KayokoPasteboardItemsCompletion)completion;
- (void)availableSearchAppBundleIdentifiersWithCompletion:
    (nullable KayokoPasteboardAppBundleIdentifiersCompletion)completion;
- (nullable KayokoPasteboardItem *)getLatestHistoryItem;
- (nullable UIImage *)getImageForItem:(KayokoPasteboardItem *)item;
- (void)getThumbnailForItem:(KayokoPasteboardItem *)item
                 targetSize:(CGSize)targetSize
                 completion:(void (^)(UIImage *_Nullable image))completion;

@end

NS_ASSUME_NONNULL_END
