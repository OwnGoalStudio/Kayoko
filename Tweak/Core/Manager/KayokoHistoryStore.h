//
//  KayokoHistoryStore.h
//  Kayoko
//

#import <Foundation/Foundation.h>

@class KayokoSearchCriteria;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, KayokoHistoryStoreLockingMode) {
    KayokoHistoryStoreLockingModeNormal = 0,
    KayokoHistoryStoreLockingModeExclusiveWhileOpen,
};

@interface KayokoHistoryStore : NSObject

@property(nonatomic, copy, readonly) NSString *databasePath;
@property(nonatomic, copy, readonly) NSString *imagesPath;
@property(nonatomic, assign, readonly) KayokoHistoryStoreLockingMode lockingMode;
@property(nonatomic, assign, readonly) NSInteger busyTimeoutMilliseconds;

+ (NSString *)defaultDatabasePath;

- (instancetype)initWithDatabasePath:(NSString *)databasePath
                          imagesPath:(NSString *)imagesPath;
- (instancetype)initWithDatabasePath:(NSString *)databasePath
                          imagesPath:(NSString *)imagesPath
                         lockingMode:(KayokoHistoryStoreLockingMode)lockingMode
              busyTimeoutMilliseconds:(NSInteger)busyTimeoutMilliseconds NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)prepareStoreWithError:(NSError **)error;
- (void)closeDatabase;
- (BOOL)verifyExclusiveAccessWithError:(NSError **)error;
- (BOOL)checkpointWriteAheadLogWithError:(NSError **)error;
- (BOOL)upgradeSearchIndexWithError:(NSError **)error;
- (BOOL)validateSearchIndexWithError:(NSError *_Nullable *_Nullable)error;
- (BOOL)isMigrationCompletedWithError:(NSError **)error;
- (BOOL)markMigrationCompletedWithError:(NSError **)error;

- (BOOL)addItemDictionary:(NSDictionary<NSString *, id> *)dictionary
             toHistoryKey:(NSString *)historyKey
                    limit:(NSUInteger)limit
                    error:(NSError *_Nullable *_Nullable)error;
- (BOOL)moveItemDictionaryToTop:(NSDictionary<NSString *, id> *)dictionary
                   inHistoryKey:(NSString *)historyKey
                          limit:(NSUInteger)limit
                          error:(NSError *_Nullable *_Nullable)error;
- (BOOL)moveItemDictionary:(NSDictionary<NSString *, id> *)dictionary
            fromHistoryKey:(NSString *)sourceHistoryKey
              toHistoryKey:(NSString *)destinationHistoryKey
          destinationLimit:(NSUInteger)destinationLimit
                     error:(NSError *_Nullable *_Nullable)error;
- (BOOL)removeItemDictionary:(NSDictionary<NSString *, id> *)dictionary
              fromHistoryKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage
                       error:(NSError *_Nullable *_Nullable)error;
- (BOOL)removeItemsFromHistoryKey:(NSString *)historyKey
               shouldRemoveImages:(BOOL)shouldRemoveImages
                            error:(NSError *_Nullable *_Nullable)error;
- (NSMutableArray<NSDictionary<NSString *, id> *> *)itemsForHistoryKey:(NSString *)historyKey
                                                                 error:(NSError *_Nullable *_Nullable)error;
- (NSMutableArray<NSDictionary<NSString *, id> *> *)itemsForHistoryKey:(NSString *)historyKey
                                                        searchCriteria:(nullable KayokoSearchCriteria *)searchCriteria
                                                                 error:(NSError *_Nullable *_Nullable)error;
- (nullable NSDictionary<NSString *, id> *)latestItemForHistoryKey:(NSString *)historyKey
                                                             error:(NSError *_Nullable *_Nullable)error;
- (NSArray<NSString *> *)availableSearchAppBundleIdentifiersWithError:(NSError *_Nullable *_Nullable)error;
- (BOOL)importItemDictionaries:(NSArray<NSDictionary<NSString *, id> *> *)items
                  toHistoryKey:(NSString *)historyKey
                         error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
