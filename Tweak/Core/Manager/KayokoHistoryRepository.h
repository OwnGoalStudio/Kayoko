//
//  KayokoHistoryRepository.h
//  Kayoko
//

#import <Foundation/Foundation.h>

@class KayokoSearchCriteria;

NS_ASSUME_NONNULL_BEGIN

typedef NSUInteger (^KayokoHistoryLimitProvider)(NSString *historyKey);
typedef void (^KayokoHistoryItemsCompletion)(NSMutableArray<NSDictionary<NSString *, id> *> *items,
                                             NSError *_Nullable error);
typedef void (^KayokoHistoryAppBundleIdentifiersCompletion)(NSArray<NSString *> *bundleIdentifiers,
                                                            NSError *_Nullable error);

// Serializes all access to KayokoHistoryStore and owns store preparation/migration.
@interface KayokoHistoryRepository : NSObject

+ (NSString *)defaultDatabasePath;

- (instancetype)initWithDatabasePath:(NSString *)databasePath
                          imagesPath:(NSString *)imagesPath
                       limitProvider:(KayokoHistoryLimitProvider)limitProvider NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)prepareStore;
- (void)ensureStorePrepared;
- (void)closeStore;
- (void)checkpointWriteAheadLog;
- (BOOL)upgradeSearchIndexWithError:(NSError *_Nullable *_Nullable)error;

- (BOOL)addItemDictionary:(NSDictionary<NSString *, id> *)dictionary
             toHistoryKey:(NSString *)historyKey
                    error:(NSError *_Nullable *_Nullable)error;
- (void)addItemDictionaries:(NSArray<NSDictionary<NSString *, id> *> *)dictionaries
               toHistoryKey:(NSString *)historyKey
                 completion:(nullable void (^)(NSArray<NSDictionary<NSString *, id> *> *savedDictionaries))completion;
- (BOOL)moveItemDictionaryToTop:(NSDictionary<NSString *, id> *)dictionary
                   inHistoryKey:(NSString *)historyKey
                          error:(NSError *_Nullable *_Nullable)error;
- (BOOL)removeItemDictionary:(NSDictionary<NSString *, id> *)dictionary
              fromHistoryKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage
                       error:(NSError *_Nullable *_Nullable)error;

- (void)removeItemDictionary:(NSDictionary<NSString *, id> *)dictionary
              fromHistoryKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage
                  completion:(nullable void (^)(BOOL success))completion;
- (void)moveItemDictionary:(NSDictionary<NSString *, id> *)dictionary
            fromHistoryKey:(NSString *)sourceHistoryKey
              toHistoryKey:(NSString *)destinationHistoryKey
                completion:(nullable void (^)(BOOL success))completion;
- (void)setTagUUID:(nullable NSString *)tagUUID
    forItemDictionary:(NSDictionary<NSString *, id> *)dictionary
         inHistoryKey:(NSString *)historyKey
           completion:(nullable void (^)(BOOL success))completion;
- (void)removeItemsFromHistoryKey:(NSString *)historyKey
               shouldRemoveImages:(BOOL)shouldRemoveImages
                       completion:(nullable void (^)(BOOL success))completion;

- (NSMutableArray<NSDictionary<NSString *, id> *> *)itemsForHistoryKey:(NSString *)historyKey
                                                                 error:(NSError *_Nullable *_Nullable)error;
- (NSMutableArray<NSDictionary<NSString *, id> *> *)itemsForHistoryKey:(NSString *)historyKey
                                                        searchCriteria:(nullable KayokoSearchCriteria *)searchCriteria
                                                                 error:(NSError *_Nullable *_Nullable)error;
- (void)itemsForHistoryKey:(NSString *)historyKey completion:(nullable KayokoHistoryItemsCompletion)completion;
- (void)itemsForHistoryKey:(NSString *)historyKey
            searchCriteria:(nullable KayokoSearchCriteria *)searchCriteria
                completion:(nullable KayokoHistoryItemsCompletion)completion;
- (nullable NSDictionary<NSString *, id> *)latestItemForHistoryKey:(NSString *)historyKey
                                                             error:(NSError *_Nullable *_Nullable)error;
- (void)availableSearchAppBundleIdentifiersWithCompletion:
    (nullable KayokoHistoryAppBundleIdentifiersCompletion)completion;

@end

NS_ASSUME_NONNULL_END
