//
//  KayokoHistoryRepository.m
//  Kayoko
//

#import "KayokoHistoryRepository.h"
#import "KayokoHistoryMigrator.h"
#import "KayokoHistoryStore.h"

static void *kayokoHistoryQueueSpecificKey = &kayokoHistoryQueueSpecificKey;

@implementation KayokoHistoryRepository {
    NSString *_databasePath;
    NSString *_imagesPath;
    KayokoHistoryLimitProvider _limitProvider;

    dispatch_queue_t _historyQueue;
    BOOL _didPrepareHistoryStore;
    KayokoHistoryStore *_historyStore;
}

+ (NSString *)defaultDatabasePath {
    return [KayokoHistoryStore defaultDatabasePath];
}

- (instancetype)initWithDatabasePath:(NSString *)databasePath
                          imagesPath:(NSString *)imagesPath
                       limitProvider:(KayokoHistoryLimitProvider)limitProvider {
    self = [super init];
    if (self) {
        _databasePath = [databasePath copy];
        _imagesPath = [imagesPath copy];
        _limitProvider = [limitProvider copy];
        _historyQueue = dispatch_queue_create("com.82flex.kayoko.queue.history", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_historyQueue, kayokoHistoryQueueSpecificKey, kayokoHistoryQueueSpecificKey, NULL);
    }
    return self;
}

- (void)prepareStore {
    [self performAsync:^{
      [self ensureStorePreparedOnQueue];
    }];
}

- (void)ensureStorePrepared {
    [self performSync:^{
      [self ensureStorePreparedOnQueue];
    }];
}

- (BOOL)addItemDictionary:(NSDictionary<NSString *, id> *)dictionary
             toHistoryKey:(NSString *)historyKey
                    error:(NSError **)error {
    __block BOOL success = NO;
    __block NSError *blockError = nil;
    [self performSync:^{
      success = [[self historyStoreOnQueue] addItemDictionary:dictionary
                                                 toHistoryKey:historyKey
                                                        limit:[self limitForHistoryKey:historyKey]
                                                        error:&blockError];
    }];
    if (error) {
        *error = blockError;
    }
    return success;
}

- (BOOL)moveItemDictionaryToTop:(NSDictionary<NSString *, id> *)dictionary
                   inHistoryKey:(NSString *)historyKey
                          error:(NSError **)error {
    __block BOOL success = NO;
    __block NSError *blockError = nil;
    [self performSync:^{
      success = [[self historyStoreOnQueue] moveItemDictionaryToTop:dictionary
                                                       inHistoryKey:historyKey
                                                              limit:[self limitForHistoryKey:historyKey]
                                                              error:&blockError];
    }];
    if (error) {
        *error = blockError;
    }
    return success;
}

- (BOOL)removeItemDictionary:(NSDictionary<NSString *, id> *)dictionary
              fromHistoryKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage
                       error:(NSError **)error {
    __block BOOL success = NO;
    __block NSError *blockError = nil;
    [self performSync:^{
      success = [[self historyStoreOnQueue] removeItemDictionary:dictionary
                                                  fromHistoryKey:historyKey
                                               shouldRemoveImage:shouldRemoveImage
                                                           error:&blockError];
    }];
    if (error) {
        *error = blockError;
    }
    return success;
}

- (void)removeItemDictionary:(NSDictionary<NSString *, id> *)dictionary
              fromHistoryKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage
                  completion:(void (^)(BOOL success))completion {
    [self performAsync:^{
      NSError *error = nil;
      BOOL success = [[self historyStoreOnQueue] removeItemDictionary:dictionary
                                                       fromHistoryKey:historyKey
                                                    shouldRemoveImage:shouldRemoveImage
                                                                error:&error];
      if (!success) {
          NSLog(@"Kayoko: Failed to remove history item: %@", error);
      }
      [self dispatchCompletion:completion success:success];
    }];
}

- (void)moveItemDictionary:(NSDictionary<NSString *, id> *)dictionary
            fromHistoryKey:(NSString *)sourceHistoryKey
              toHistoryKey:(NSString *)destinationHistoryKey
                completion:(void (^)(BOOL success))completion {
    [self performAsync:^{
      NSError *error = nil;
      BOOL success = [[self historyStoreOnQueue] moveItemDictionary:dictionary
                                                     fromHistoryKey:sourceHistoryKey
                                                       toHistoryKey:destinationHistoryKey
                                                   destinationLimit:[self limitForHistoryKey:destinationHistoryKey]
                                                              error:&error];
      if (!success) {
          NSLog(@"Kayoko: Failed to move history item: %@", error);
      }
      [self dispatchCompletion:completion success:success];
    }];
}

- (void)removeItemsFromHistoryKey:(NSString *)historyKey
               shouldRemoveImages:(BOOL)shouldRemoveImages
                       completion:(void (^)(BOOL success))completion {
    [self performAsync:^{
      NSError *error = nil;
      BOOL success = [[self historyStoreOnQueue] removeItemsFromHistoryKey:historyKey
                                                        shouldRemoveImages:shouldRemoveImages
                                                                     error:&error];
      if (!success) {
          NSLog(@"Kayoko: Failed to remove history items: %@", error);
      }
      [self dispatchCompletion:completion success:success];
    }];
}

- (NSMutableArray<NSDictionary<NSString *, id> *> *)itemsForHistoryKey:(NSString *)historyKey error:(NSError **)error {
    __block NSMutableArray<NSDictionary<NSString *, id> *> *history = nil;
    __block NSError *blockError = nil;
    [self performSync:^{
      history = [[self historyStoreOnQueue] itemsForHistoryKey:historyKey error:&blockError];
    }];
    if (error) {
        *error = blockError;
    }
    return history ?: [[NSMutableArray alloc] init];
}

- (void)itemsForHistoryKey:(NSString *)historyKey
                completion:(void (^)(NSMutableArray<NSDictionary<NSString *, id> *> *items))completion {
    [self performAsync:^{
      NSError *error = nil;
      NSMutableArray<NSDictionary<NSString *, id> *> *history =
          [[self historyStoreOnQueue] itemsForHistoryKey:historyKey error:&error];
      if (error) {
          NSLog(@"Kayoko: Failed to load history items: %@", error);
      }
      NSMutableArray<NSDictionary<NSString *, id> *> *items = history ?: [[NSMutableArray alloc] init];
      if (!completion) {
          return;
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(items);
      });
    }];
}

- (NSDictionary<NSString *, id> *)latestItemForHistoryKey:(NSString *)historyKey error:(NSError **)error {
    __block NSDictionary<NSString *, id> *dictionary = nil;
    __block NSError *blockError = nil;
    [self performSync:^{
      dictionary = [[self historyStoreOnQueue] latestItemForHistoryKey:historyKey error:&blockError];
    }];
    if (error) {
        *error = blockError;
    }
    return dictionary;
}

#pragma mark - Queue

- (BOOL)isOnHistoryQueue {
    return dispatch_get_specific(kayokoHistoryQueueSpecificKey) == kayokoHistoryQueueSpecificKey;
}

- (void)performAsync:(dispatch_block_t)block {
    if (!block) {
        return;
    }

    if ([self isOnHistoryQueue]) {
        block();
        return;
    }

    dispatch_async(_historyQueue, block);
}

- (void)performSync:(dispatch_block_t)block {
    if (!block) {
        return;
    }

    if ([self isOnHistoryQueue]) {
        block();
        return;
    }

    dispatch_sync(_historyQueue, block);
}

- (void)dispatchCompletion:(void (^)(BOOL success))completion success:(BOOL)success {
    if (!completion) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      completion(success);
    });
}

#pragma mark - Store

- (KayokoHistoryStore *)historyStoreOnQueue {
    if (!_historyStore) {
        _historyStore = [[KayokoHistoryStore alloc] initWithDatabasePath:_databasePath imagesPath:_imagesPath];
    }
    [self ensureStorePreparedOnQueue];
    return _historyStore;
}

- (void)ensureStorePreparedOnQueue {
    if (_didPrepareHistoryStore) {
        return;
    }

    if (!_historyStore) {
        _historyStore = [[KayokoHistoryStore alloc] initWithDatabasePath:_databasePath imagesPath:_imagesPath];
    }

    NSError *error = nil;
    KayokoHistoryMigrator *migrator =
        [[KayokoHistoryMigrator alloc] initWithHistoryStore:_historyStore
                                           migrationSources:[KayokoHistoryMigrator defaultMigrationSources]];
    if (![migrator migrateIfNeededWithError:&error]) {
        NSLog(@"Kayoko: Failed to prepare v4 history store: %@", error);
    }
    _didPrepareHistoryStore = YES;
}

- (NSUInteger)limitForHistoryKey:(NSString *)historyKey {
    if (_limitProvider) {
        return _limitProvider(historyKey);
    }
    return NSUIntegerMax;
}

@end
