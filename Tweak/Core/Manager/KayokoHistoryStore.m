//
//  KayokoHistoryStore.m
//  Kayoko
//

#import "KayokoHistoryStore.h"
#import "KayokoPasteboardItem.h"

#import <roothide.h>
#import <sqlite3.h>
#import <string.h>

static NSString *const kKayokoHistoryStoreErrorDomain = @"com.82flex.kayoko.history-store";
static NSString *const kKayokoHistoryStoreMigrationKey = @"v4_legacy_sources_imported";

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHistoryStore ()
@property(nonatomic, copy, readwrite) NSString *databasePath;
@property(nonatomic, copy, readwrite) NSString *imagesPath;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoHistoryStore {
    sqlite3 *_database;
}

+ (NSString *)defaultDatabasePath {
    return jbroot(@"/var/mobile/Library/com.82flex.kayoko/history-v4.sqlite");
}

- (instancetype)initWithDatabasePath:(NSString *)databasePath imagesPath:(NSString *)imagesPath {
    self = [super init];
    if (self) {
        _databasePath = [databasePath copy];
        _imagesPath = [imagesPath copy];
    }
    return self;
}

- (void)dealloc {
    if (_database) {
        sqlite3_close(_database);
        _database = NULL;
    }
}

- (BOOL)prepareStoreWithError:(NSError **)error {
    NSString *directoryPath = [[self databasePath] stringByDeletingLastPathComponent];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:directoryPath]) {
        if (![fileManager createDirectoryAtPath:directoryPath
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:error]) {
            return NO;
        }
    }

    if (![fileManager fileExistsAtPath:[self imagesPath]]) {
        if (![fileManager createDirectoryAtPath:[self imagesPath]
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:error]) {
            return NO;
        }
    }

    if (![self openDatabaseWithError:error]) {
        return NO;
    }

    NSString *createHistoryItemsStatement = @"CREATE TABLE IF NOT EXISTS history_items ("
                                             "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                                             "history_key TEXT NOT NULL,"
                                             "bundle_identifier TEXT NOT NULL,"
                                             "content TEXT NOT NULL,"
                                             "image_name TEXT NOT NULL,"
                                             "has_link INTEGER NOT NULL DEFAULT 0,"
                                             "created_at REAL NOT NULL,"
                                             "updated_at REAL NOT NULL,"
                                             "sequence INTEGER NOT NULL"
                                             ")";
    NSString *createUniqueIndexStatement = @"CREATE UNIQUE INDEX IF NOT EXISTS history_items_unique_content "
                                            "ON history_items(history_key, content)";
    NSString *createOrderedIndexStatement = @"CREATE INDEX IF NOT EXISTS history_items_ordered "
                                             "ON history_items(history_key, sequence DESC)";

    NSArray<NSString *> *statements = @[
        @"PRAGMA journal_mode=WAL", @"PRAGMA synchronous=NORMAL",
        @"CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)",
        createHistoryItemsStatement, createUniqueIndexStatement, createOrderedIndexStatement
    ];

    for (NSString *statement in statements) {
        if (![self executeStatement:statement error:error]) {
            return NO;
        }
    }

    return YES;
}

- (BOOL)checkpointWriteAheadLogWithError:(NSError **)error {
    if (![self openDatabaseWithError:error]) {
        return NO;
    }

    int result = sqlite3_wal_checkpoint_v2(_database, NULL, SQLITE_CHECKPOINT_TRUNCATE, NULL, NULL);
    if (result != SQLITE_OK) {
        [self populateError:error code:result message:@"Unable to checkpoint history database"];
        return NO;
    }

    return YES;
}

- (BOOL)isMigrationCompletedWithError:(NSError **)error {
    NSString *value = [self metadataValueForKey:kKayokoHistoryStoreMigrationKey error:error];
    return [value boolValue];
}

- (BOOL)markMigrationCompletedWithError:(NSError **)error {
    return [self setMetadataValue:@"1" forKey:kKayokoHistoryStoreMigrationKey error:error];
}

- (BOOL)addItemDictionary:(NSDictionary<NSString *, id> *)dictionary
             toHistoryKey:(NSString *)historyKey
                    limit:(NSUInteger)limit
                    error:(NSError **)error {
    return [self upsertItemDictionary:dictionary inHistoryKey:historyKey limit:limit error:error];
}

- (BOOL)moveItemDictionaryToTop:(NSDictionary<NSString *, id> *)dictionary
                   inHistoryKey:(NSString *)historyKey
                          limit:(NSUInteger)limit
                          error:(NSError **)error {
    return [self upsertItemDictionary:dictionary inHistoryKey:historyKey limit:limit error:error];
}

- (BOOL)moveItemDictionary:(NSDictionary<NSString *, id> *)dictionary
            fromHistoryKey:(NSString *)sourceHistoryKey
              toHistoryKey:(NSString *)destinationHistoryKey
          destinationLimit:(NSUInteger)destinationLimit
                     error:(NSError **)error {
    NSString *content = [self stringValueFromDictionary:dictionary key:kKayokoItemKeyContent fallback:nil];
    if ([content length] == 0 || [sourceHistoryKey length] == 0 || [destinationHistoryKey length] == 0) {
        return YES;
    }

    if ([sourceHistoryKey isEqualToString:destinationHistoryKey]) {
        return [self upsertItemDictionary:dictionary
                             inHistoryKey:destinationHistoryKey
                                    limit:destinationLimit
                                    error:error];
    }

    if (![self beginTransactionWithError:error]) {
        return NO;
    }

    BOOL success = [self upsertItemDictionaryWithoutTransaction:dictionary
                                                   inHistoryKey:destinationHistoryKey
                                                          error:error];
    if (success) {
        success = [self trimHistoryKey:destinationHistoryKey toLimit:destinationLimit error:error];
    }
    if (success) {
        NSInteger deletedCount = 0;
        success = [self executeStatement:@"DELETE FROM history_items WHERE history_key = ? AND content = ?"
                                bindings:@[ sourceHistoryKey, content ]
                                 changes:&deletedCount
                                   error:error];
        if (success && deletedCount == 0) {
            [self populateError:error code:SQLITE_NOTFOUND message:@"History item not found"];
            success = NO;
        }
    }

    if (success) {
        return [self commitTransactionWithError:error];
    }

    [self rollbackTransaction];
    return NO;
}

- (BOOL)removeItemDictionary:(NSDictionary<NSString *, id> *)dictionary
              fromHistoryKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage
                       error:(NSError **)error {
    NSString *content = [self stringValueFromDictionary:dictionary key:kKayokoItemKeyContent fallback:nil];
    if ([content length] == 0 || [historyKey length] == 0) {
        return YES;
    }

    NSString *imageName = [self stringValueFromDictionary:dictionary key:kKayokoItemKeyImageName fallback:@""];
    if (![self beginTransactionWithError:error]) {
        return NO;
    }

    NSInteger deletedCount = 0;
    BOOL success = [self executeStatement:@"DELETE FROM history_items WHERE history_key = ? AND content = ?"
                                 bindings:@[ historyKey, content ]
                                  changes:&deletedCount
                                    error:error];
    if (success && deletedCount == 0) {
        [self populateError:error code:SQLITE_NOTFOUND message:@"History item not found"];
        success = NO;
    }
    if (success && shouldRemoveImage && [imageName length] > 0) {
        success = [self removeImageIfUnreferenced:imageName error:error];
    }

    if (success) {
        return [self commitTransactionWithError:error];
    }

    [self rollbackTransaction];
    return NO;
}

- (BOOL)removeItemsFromHistoryKey:(NSString *)historyKey
               shouldRemoveImages:(BOOL)shouldRemoveImages
                            error:(NSError **)error {
    if ([historyKey length] == 0) {
        return YES;
    }

    if (![self beginTransactionWithError:error]) {
        return NO;
    }

    NSArray<NSString *> *imageNames = shouldRemoveImages ? [self imageNamesForHistoryKey:historyKey error:error] : @[];
    if (!imageNames) {
        [self rollbackTransaction];
        return NO;
    }

    BOOL success = [self executeStatement:@"DELETE FROM history_items WHERE history_key = ?"
                                 bindings:@[ historyKey ]
                                    error:error];
    if (success && shouldRemoveImages) {
        for (NSString *imageName in imageNames) {
            if (![self removeImageIfUnreferenced:imageName error:error]) {
                success = NO;
                break;
            }
        }
    }

    if (success) {
        return [self commitTransactionWithError:error];
    }

    [self rollbackTransaction];
    return NO;
}

- (NSMutableArray<NSDictionary<NSString *, id> *> *)itemsForHistoryKey:(NSString *)historyKey error:(NSError **)error {
    sqlite3_stmt *statement = NULL;
    NSMutableArray<NSDictionary<NSString *, id> *> *items = [[NSMutableArray alloc] init];
    const char *sql = "SELECT bundle_identifier, content, image_name, has_link "
                      "FROM history_items WHERE history_key = ? ORDER BY sequence DESC";

    if (![self prepareStatement:sql statement:&statement error:error]) {
        return items;
    }

    sqlite3_bind_text(statement, 1, [historyKey UTF8String], -1, SQLITE_TRANSIENT);
    while (sqlite3_step(statement) == SQLITE_ROW) {
        [items addObject:[self dictionaryFromCurrentRowInStatement:statement]];
    }

    sqlite3_finalize(statement);
    return items;
}

- (NSDictionary<NSString *, id> *)latestItemForHistoryKey:(NSString *)historyKey error:(NSError **)error {
    sqlite3_stmt *statement = NULL;
    const char *sql = "SELECT bundle_identifier, content, image_name, has_link "
                      "FROM history_items WHERE history_key = ? ORDER BY sequence DESC LIMIT 1";

    if (![self prepareStatement:sql statement:&statement error:error]) {
        return nil;
    }

    sqlite3_bind_text(statement, 1, [historyKey UTF8String], -1, SQLITE_TRANSIENT);
    NSDictionary<NSString *, id> *dictionary = nil;
    if (sqlite3_step(statement) == SQLITE_ROW) {
        dictionary = [self dictionaryFromCurrentRowInStatement:statement];
    }

    sqlite3_finalize(statement);
    return dictionary;
}

- (BOOL)importItemDictionaries:(NSArray<NSDictionary<NSString *, id> *> *)items
                  toHistoryKey:(NSString *)historyKey
                         error:(NSError **)error {
    if ([items count] == 0) {
        return YES;
    }

    if (![self beginTransactionWithError:error]) {
        return NO;
    }

    BOOL success = YES;
    for (NSDictionary<NSString *, id> *dictionary in [items reverseObjectEnumerator]) {
        success = [self upsertItemDictionaryWithoutTransaction:dictionary inHistoryKey:historyKey error:error];
        if (!success) {
            break;
        }
    }

    if (success) {
        return [self commitTransactionWithError:error];
    }

    [self rollbackTransaction];
    return NO;
}

#pragma mark - Private

- (BOOL)openDatabaseWithError:(NSError **)error {
    if (_database) {
        return YES;
    }

    int result = sqlite3_open_v2([[self databasePath] fileSystemRepresentation], &_database,
                                 SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, NULL);
    if (result != SQLITE_OK) {
        [self populateError:error code:result message:@"Unable to open history database"];
        return NO;
    }

    sqlite3_busy_timeout(_database, 3000);
    return YES;
}

- (BOOL)upsertItemDictionary:(NSDictionary<NSString *, id> *)dictionary
                inHistoryKey:(NSString *)historyKey
                       limit:(NSUInteger)limit
                       error:(NSError **)error {
    if (![self beginTransactionWithError:error]) {
        return NO;
    }

    BOOL success = [self upsertItemDictionaryWithoutTransaction:dictionary inHistoryKey:historyKey error:error];
    if (success) {
        success = [self trimHistoryKey:historyKey toLimit:limit error:error];
    }

    if (success) {
        return [self commitTransactionWithError:error];
    }

    [self rollbackTransaction];
    return NO;
}

- (BOOL)upsertItemDictionaryWithoutTransaction:(NSDictionary<NSString *, id> *)dictionary
                                  inHistoryKey:(NSString *)historyKey
                                         error:(NSError **)error {
    NSString *content = [self stringValueFromDictionary:dictionary key:kKayokoItemKeyContent fallback:nil];
    if ([content length] == 0 || [historyKey length] == 0) {
        return YES;
    }

    NSString *bundleIdentifier = [self stringValueFromDictionary:dictionary
                                                             key:kKayokoItemKeyBundleIdentifier
                                                        fallback:@"com.apple.springboard"];
    NSString *imageName = [self stringValueFromDictionary:dictionary key:kKayokoItemKeyImageName fallback:@""];
    NSNumber *hasLink = @([[dictionary objectForKey:kKayokoItemKeyHasLink] boolValue]);
    NSNumber *sequence = @([self nextSequence]);
    NSNumber *now = @([[NSDate date] timeIntervalSince1970]);

    if (![self executeStatement:@"DELETE FROM history_items WHERE history_key = ? AND content = ?"
                       bindings:@[ historyKey, content ]
                          error:error]) {
        return NO;
    }

    return
        [self executeStatement:
                  @"INSERT INTO history_items "
                   "(history_key, bundle_identifier, content, image_name, has_link, created_at, updated_at, sequence) "
                   "VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
                      bindings:@[ historyKey, bundleIdentifier, content, imageName, hasLink, now, now, sequence ]
                         error:error];
}

- (BOOL)trimHistoryKey:(NSString *)historyKey toLimit:(NSUInteger)limit error:(NSError **)error {
    if (limit == NSUIntegerMax) {
        return YES;
    }

    NSString *trimmedRowsSubquery =
        @"SELECT id FROM history_items WHERE history_key = ? ORDER BY sequence DESC LIMIT -1 OFFSET ?";
    sqlite3_stmt *statement = NULL;
    const char *imageSQL =
        "SELECT DISTINCT image_name FROM history_items "
        "WHERE image_name <> '' AND id IN "
        "(SELECT id FROM history_items WHERE history_key = ? ORDER BY sequence DESC LIMIT -1 OFFSET ?)";
    if (![self prepareStatement:imageSQL statement:&statement error:error]) {
        return NO;
    }

    sqlite3_bind_text(statement, 1, [historyKey UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(statement, 2, (sqlite3_int64)limit);

    NSMutableArray<NSString *> *imageNames = [[NSMutableArray alloc] init];
    while (sqlite3_step(statement) == SQLITE_ROW) {
        NSString *imageName = [self stringFromColumn:statement index:0];
        if ([imageName length] > 0) {
            [imageNames addObject:imageName];
        }
    }
    sqlite3_finalize(statement);

    NSString *deleteStatement =
        [NSString stringWithFormat:@"DELETE FROM history_items WHERE id IN (%@)", trimmedRowsSubquery];
    if (![self executeStatement:deleteStatement bindings:@[ historyKey, @(limit) ] error:error]) {
        return NO;
    }

    for (NSString *imageName in imageNames) {
        if (![self removeImageIfUnreferenced:imageName error:error]) {
            return NO;
        }
    }

    return YES;
}

- (NSArray<NSString *> *)imageNamesForHistoryKey:(NSString *)historyKey error:(NSError **)error {
    sqlite3_stmt *statement = NULL;
    const char *sql = "SELECT DISTINCT image_name FROM history_items WHERE history_key = ? AND image_name <> ''";
    if (![self prepareStatement:sql statement:&statement error:error]) {
        return nil;
    }

    sqlite3_bind_text(statement, 1, [historyKey UTF8String], -1, SQLITE_TRANSIENT);
    NSMutableArray<NSString *> *imageNames = [[NSMutableArray alloc] init];
    while (sqlite3_step(statement) == SQLITE_ROW) {
        NSString *imageName = [self stringFromColumn:statement index:0];
        if ([imageName length] > 0) {
            [imageNames addObject:imageName];
        }
    }
    sqlite3_finalize(statement);
    return imageNames;
}

- (BOOL)removeImageIfUnreferenced:(NSString *)imageName error:(NSError **)error {
    NSInteger referenceCount = [self imageReferenceCountForImageName:imageName error:error];
    if ([imageName length] == 0 || referenceCount < 0 || referenceCount > 0) {
        return YES;
    }

    NSString *filePath = [[self imagesPath] stringByAppendingPathComponent:imageName];
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    return YES;
}

- (NSInteger)imageReferenceCountForImageName:(NSString *)imageName error:(NSError **)error {
    sqlite3_stmt *statement = NULL;
    if (![self prepareStatement:"SELECT COUNT(*) FROM history_items WHERE image_name = ?"
                      statement:&statement
                          error:error]) {
        return -1;
    }

    sqlite3_bind_text(statement, 1, [imageName UTF8String], -1, SQLITE_TRANSIENT);
    NSInteger count = 0;
    if (sqlite3_step(statement) == SQLITE_ROW) {
        count = (NSUInteger)sqlite3_column_int64(statement, 0);
    }
    sqlite3_finalize(statement);
    return count;
}

- (sqlite3_int64)nextSequence {
    sqlite3_stmt *statement = NULL;
    if (![self prepareStatement:"SELECT COALESCE(MAX(sequence), 0) + 1 FROM history_items"
                      statement:&statement
                          error:nil]) {
        return (sqlite3_int64)[[NSDate date] timeIntervalSince1970];
    }

    sqlite3_int64 sequence = 1;
    if (sqlite3_step(statement) == SQLITE_ROW) {
        sequence = sqlite3_column_int64(statement, 0);
    }
    sqlite3_finalize(statement);
    return sequence;
}

- (NSString *)metadataValueForKey:(NSString *)key error:(NSError **)error {
    sqlite3_stmt *statement = NULL;
    if (![self prepareStatement:"SELECT value FROM metadata WHERE key = ?" statement:&statement error:error]) {
        return nil;
    }

    sqlite3_bind_text(statement, 1, [key UTF8String], -1, SQLITE_TRANSIENT);
    NSString *value = nil;
    if (sqlite3_step(statement) == SQLITE_ROW) {
        value = [self stringFromColumn:statement index:0];
    }
    sqlite3_finalize(statement);
    return value;
}

- (BOOL)setMetadataValue:(NSString *)value forKey:(NSString *)key error:(NSError **)error {
    return [self executeStatement:@"INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)"
                         bindings:@[ key, value ]
                            error:error];
}

- (NSDictionary<NSString *, id> *)dictionaryFromCurrentRowInStatement:(sqlite3_stmt *)statement {
    NSString *bundleIdentifier = [self stringFromColumn:statement index:0] ?: @"com.apple.springboard";
    NSString *content = [self stringFromColumn:statement index:1] ?: @"";
    NSString *imageName = [self stringFromColumn:statement index:2] ?: @"";
    BOOL hasLink = sqlite3_column_int(statement, 3) != 0;

    return @{
        kKayokoItemKeyBundleIdentifier : bundleIdentifier,
        kKayokoItemKeyContent : content,
        kKayokoItemKeyImageName : imageName,
        kKayokoItemKeyHasLink : @(hasLink)
    };
}

- (NSString *)stringValueFromDictionary:(NSDictionary<NSString *, id> *)dictionary
                                    key:(NSString *)key
                               fallback:(NSString *)fallback {
    id value = [dictionary objectForKey:key];
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    return fallback;
}

- (NSString *)stringFromColumn:(sqlite3_stmt *)statement index:(int)index {
    const unsigned char *text = sqlite3_column_text(statement, index);
    if (!text) {
        return nil;
    }
    return [NSString stringWithUTF8String:(const char *)text];
}

- (BOOL)beginTransactionWithError:(NSError **)error {
    return [self executeStatement:@"BEGIN IMMEDIATE TRANSACTION" error:error];
}

- (BOOL)commitTransactionWithError:(NSError **)error {
    return [self executeStatement:@"COMMIT" error:error];
}

- (void)rollbackTransaction {
    [self executeStatement:@"ROLLBACK" error:nil];
}

- (BOOL)executeStatement:(NSString *)statement error:(NSError **)error {
    return [self executeStatement:statement bindings:@[] error:error];
}

- (BOOL)executeStatement:(NSString *)statement bindings:(NSArray<id> *)bindings error:(NSError **)error {
    return [self executeStatement:statement bindings:bindings changes:NULL error:error];
}

- (BOOL)executeStatement:(NSString *)statement
                bindings:(NSArray<id> *)bindings
                 changes:(NSInteger *)changes
                   error:(NSError **)error {
    sqlite3_stmt *compiledStatement = NULL;
    if (![self prepareStatement:[statement UTF8String] statement:&compiledStatement error:error]) {
        return NO;
    }

    [self bindObjects:bindings toStatement:compiledStatement];
    int result = sqlite3_step(compiledStatement);
    sqlite3_finalize(compiledStatement);

    if (result != SQLITE_DONE && result != SQLITE_ROW) {
        [self populateError:error code:result message:statement];
        return NO;
    }
    if (changes) {
        *changes = sqlite3_changes(_database);
    }
    return YES;
}

- (BOOL)prepareStatement:(const char *)sql statement:(sqlite3_stmt **)statement error:(NSError **)error {
    if (![self openDatabaseWithError:error]) {
        return NO;
    }

    int result = sqlite3_prepare_v2(_database, sql, -1, statement, NULL);
    if (result != SQLITE_OK) {
        [self populateError:error code:result message:[NSString stringWithUTF8String:sql]];
        return NO;
    }
    return YES;
}

- (void)bindObjects:(NSArray<id> *)objects toStatement:(sqlite3_stmt *)statement {
    for (NSUInteger index = 0; index < [objects count]; index++) {
        id object = objects[index];
        int parameterIndex = (int)index + 1;
        if ([object isKindOfClass:[NSNumber class]]) {
            const char *objCType = [object objCType];
            if (strcmp(objCType, @encode(double)) == 0 || strcmp(objCType, @encode(float)) == 0) {
                sqlite3_bind_double(statement, parameterIndex, [object doubleValue]);
            } else {
                sqlite3_bind_int64(statement, parameterIndex, [object longLongValue]);
            }
        } else if ([object isKindOfClass:[NSString class]]) {
            sqlite3_bind_text(statement, parameterIndex, [object UTF8String], -1, SQLITE_TRANSIENT);
        } else if (object == [NSNull null]) {
            sqlite3_bind_null(statement, parameterIndex);
        } else {
            sqlite3_bind_text(statement, parameterIndex, [[object description] UTF8String], -1, SQLITE_TRANSIENT);
        }
    }
}

- (void)populateError:(NSError **)error code:(NSInteger)code message:(NSString *)message {
    if (!error) {
        return;
    }

    NSString *sqliteMessage = _database ? [NSString stringWithUTF8String:sqlite3_errmsg(_database)] : @"";
    *error = [NSError errorWithDomain:kKayokoHistoryStoreErrorDomain
                                 code:code
                             userInfo:@{
                                 NSLocalizedDescriptionKey : message ?: @"SQLite operation failed",
                                 NSLocalizedFailureReasonErrorKey : sqliteMessage ?: @""
                             }];
}

@end
