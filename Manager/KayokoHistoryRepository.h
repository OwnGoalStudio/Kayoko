//
//  KayokoHistoryRepository.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSUInteger (^KayokoHistoryLimitProvider)(NSString *historyKey);

// Serializes all access to KayokoHistoryStore and owns store preparation/migration.
@interface KayokoHistoryRepository : NSObject

+ (NSString *)defaultDatabasePath;

- (instancetype)initWithDatabasePath:(NSString *)databasePath
                          imagesPath:(NSString *)imagesPath
                       limitProvider:(KayokoHistoryLimitProvider)limitProvider NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)prepareStore;
- (void)ensureStorePrepared;

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
- (void)removeItemsFromHistoryKey:(NSString *)historyKey
               shouldRemoveImages:(BOOL)shouldRemoveImages
                       completion:(nullable void (^)(BOOL success))completion;

- (NSMutableArray<NSDictionary<NSString *, id> *> *)itemsForHistoryKey:(NSString *)historyKey
                                                                 error:(NSError *_Nullable *_Nullable)error;
- (void)itemsForHistoryKey:(NSString *)historyKey
                completion:(nullable void (^)(NSMutableArray<NSDictionary<NSString *, id> *> *items))completion;
- (nullable NSDictionary<NSString *, id> *)latestItemForHistoryKey:(NSString *)historyKey
                                                             error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
