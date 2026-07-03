//
//  KayokoHistoryStore.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHistoryStore : NSObject

@property(nonatomic, copy, readonly) NSString *databasePath;
@property(nonatomic, copy, readonly) NSString *imagesPath;

+ (NSString *)defaultDatabasePath;

- (instancetype)initWithDatabasePath:(NSString *)databasePath
                          imagesPath:(NSString *)imagesPath NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)prepareStoreWithError:(NSError **)error;
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
- (nullable NSDictionary<NSString *, id> *)latestItemForHistoryKey:(NSString *)historyKey
                                                             error:(NSError *_Nullable *_Nullable)error;
- (BOOL)importItemDictionaries:(NSArray<NSDictionary<NSString *, id> *> *)items
                  toHistoryKey:(NSString *)historyKey
                         error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
