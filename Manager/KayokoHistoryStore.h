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

- (BOOL)addItemDictionary:(NSDictionary *)dictionary
             toHistoryKey:(NSString *)historyKey
                    limit:(NSUInteger)limit
                    error:(NSError **)error;
- (BOOL)moveItemDictionaryToTop:(NSDictionary *)dictionary
                   inHistoryKey:(NSString *)historyKey
                          limit:(NSUInteger)limit
                          error:(NSError **)error;
- (BOOL)moveItemDictionary:(NSDictionary *)dictionary
            fromHistoryKey:(NSString *)sourceHistoryKey
              toHistoryKey:(NSString *)destinationHistoryKey
          destinationLimit:(NSUInteger)destinationLimit
                     error:(NSError **)error;
- (BOOL)removeItemDictionary:(NSDictionary *)dictionary
              fromHistoryKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage
                       error:(NSError **)error;
- (BOOL)removeItemsFromHistoryKey:(NSString *)historyKey
               shouldRemoveImages:(BOOL)shouldRemoveImages
                            error:(NSError **)error;
- (NSMutableArray *)itemsForHistoryKey:(NSString *)historyKey error:(NSError **)error;
- (NSDictionary *_Nullable)latestItemForHistoryKey:(NSString *)historyKey error:(NSError **)error;
- (BOOL)importItemDictionaries:(NSArray<NSDictionary *> *)items
                  toHistoryKey:(NSString *)historyKey
                         error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
