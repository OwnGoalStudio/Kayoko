//
//  KayokoHistoryStore.m
//  Kayoko
//

#import "KayokoHistoryStore.h"
#import "KayokoPasteboardItem.h"
#import "KayokoSearchCriteria.h"

#import <limits.h>
#import <roothide.h>
#import <sqlite3.h>
#import <string.h>

static NSString *const kKayokoHistoryStoreErrorDomain = @"com.82flex.kayoko.history-store";
static NSString *const kKayokoHistoryStoreMigrationKey = @"v4_legacy_sources_imported";
static NSString *const kKayokoHistoryStoreSearchIndexSchemaVersionKey = @"search_index_schema_version";
static NSInteger const kKayokoHistoryStoreSearchIndexVersion = 1;
static NSInteger const kKayokoHistoryStoreDefaultBusyTimeoutMilliseconds = 3000;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHistoryStore ()
@property(nonatomic, copy, readwrite) NSString *databasePath;
@property(nonatomic, copy, readwrite) NSString *imagesPath;
@property(nonatomic, assign, readwrite) KayokoHistoryStoreLockingMode lockingMode;
@property(nonatomic, assign, readwrite) NSInteger busyTimeoutMilliseconds;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoHistoryStore {
    sqlite3 *_database;
}

+ (NSString *)defaultDatabasePath {
    return jbroot(@"/var/mobile/Library/com.82flex.kayoko/history-v4.sqlite");
}

- (instancetype)initWithDatabasePath:(NSString *)databasePath imagesPath:(NSString *)imagesPath {
    return [self initWithDatabasePath:databasePath
                           imagesPath:imagesPath
                          lockingMode:KayokoHistoryStoreLockingModeNormal
              busyTimeoutMilliseconds:kKayokoHistoryStoreDefaultBusyTimeoutMilliseconds];
}

- (instancetype)initWithDatabasePath:(NSString *)databasePath
                          imagesPath:(NSString *)imagesPath
                         lockingMode:(KayokoHistoryStoreLockingMode)lockingMode
             busyTimeoutMilliseconds:(NSInteger)busyTimeoutMilliseconds {
    self = [super init];
    if (self) {
        _databasePath = [databasePath copy];
        _imagesPath = [imagesPath copy];
        _lockingMode = lockingMode;
        _busyTimeoutMilliseconds = MAX(busyTimeoutMilliseconds, 0);
    }
    return self;
}

- (void)dealloc {
    [self closeDatabase];
}

- (BOOL)prepareStoreWithError:(NSError **)error {
    if (![self prepareStorageDirectoriesWithError:error]) {
        return NO;
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
                                             "sequence INTEGER NOT NULL,"
                                             "search_index_version INTEGER NOT NULL DEFAULT 0"
                                             ")";
    NSString *createSearchTokensStatement = @"CREATE TABLE IF NOT EXISTS history_item_search_tokens ("
                                             "item_id INTEGER NOT NULL,"
                                             "history_key TEXT NOT NULL,"
                                             "token_type TEXT NOT NULL,"
                                             "token_value TEXT NOT NULL"
                                             ")";
    NSString *createUniqueIndexStatement = @"CREATE UNIQUE INDEX IF NOT EXISTS history_items_unique_content "
                                            "ON history_items(history_key, content)";
    NSString *createOrderedIndexStatement = @"CREATE INDEX IF NOT EXISTS history_items_ordered "
                                             "ON history_items(history_key, sequence DESC)";
    NSString *createSearchTokenLookupIndexStatement =
        @"CREATE INDEX IF NOT EXISTS history_item_search_tokens_lookup "
         "ON history_item_search_tokens(history_key, token_type, token_value, item_id)";
    NSString *createSearchTokenUniqueIndexStatement =
        @"CREATE UNIQUE INDEX IF NOT EXISTS history_item_search_tokens_unique "
         "ON history_item_search_tokens(item_id, token_type, token_value)";
    NSString *createSearchTokenDeleteTriggerStatement =
        @"CREATE TRIGGER IF NOT EXISTS history_items_delete_search_tokens "
         "AFTER DELETE ON history_items "
         "BEGIN "
         "DELETE FROM history_item_search_tokens WHERE item_id = OLD.id; "
         "END";

    NSArray<NSString *> *statements = @[
        @"PRAGMA journal_mode=WAL", @"PRAGMA synchronous=NORMAL",
        @"CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)",
        createHistoryItemsStatement, createSearchTokensStatement, createUniqueIndexStatement,
        createOrderedIndexStatement, createSearchTokenLookupIndexStatement, createSearchTokenUniqueIndexStatement,
        createSearchTokenDeleteTriggerStatement
    ];

    for (NSString *statement in statements) {
        if (![self executeStatement:statement error:error]) {
            return NO;
        }
    }

    if (![self ensureColumnNamed:@"search_index_version"
                         inTable:@"history_items"
             usingAlterStatement:@"ALTER TABLE history_items ADD COLUMN search_index_version INTEGER NOT NULL DEFAULT 0"
                           error:error]) {
        return NO;
    }

    return YES;
}

- (BOOL)prepareStorageDirectoriesWithError:(NSError **)error {
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

    return YES;
}

- (void)closeDatabase {
    if (_database) {
        sqlite3_close(_database);
        _database = NULL;
    }
}

- (BOOL)verifyExclusiveAccessWithError:(NSError **)error {
    if (![self prepareStorageDirectoriesWithError:error]) {
        return NO;
    }
    if (![self openDatabaseWithError:error]) {
        return NO;
    }
    if ([self lockingMode] != KayokoHistoryStoreLockingModeExclusiveWhileOpen) {
        return YES;
    }
    if (![self executeStatement:@"BEGIN EXCLUSIVE TRANSACTION" error:error]) {
        return NO;
    }

    BOOL committed = [self commitTransactionWithError:error];
    if (!committed) {
        [self rollbackTransaction];
    }
    return committed;
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

- (BOOL)upgradeSearchIndexWithError:(NSError **)error {
    if (![self prepareStoreWithError:error]) {
        return NO;
    }

    NSString *schemaVersion = [self metadataValueForKey:kKayokoHistoryStoreSearchIndexSchemaVersionKey error:nil];
    NSInteger staleItemCount = [self staleSearchIndexItemCountWithError:error];
    if (staleItemCount == NSIntegerMax) {
        return NO;
    }
    if ([schemaVersion integerValue] == kKayokoHistoryStoreSearchIndexVersion && staleItemCount == 0) {
        return YES;
    }

    if (![self beginTransactionWithError:error]) {
        return NO;
    }

    BOOL success = [self rebuildStaleSearchIndexesWithError:error];
    if (success) {
        success = [self setMetadataValue:[@(kKayokoHistoryStoreSearchIndexVersion) stringValue]
                                  forKey:kKayokoHistoryStoreSearchIndexSchemaVersionKey
                                   error:error];
    }

    if (success) {
        return [self commitTransactionWithError:error];
    }

    [self rollbackTransaction];
    return NO;
}

- (BOOL)validateSearchIndexWithError:(NSError **)error {
    NSString *schemaVersion = [self metadataValueForKey:kKayokoHistoryStoreSearchIndexSchemaVersionKey error:error];
    if ([schemaVersion integerValue] != kKayokoHistoryStoreSearchIndexVersion) {
        [self populateError:error code:SQLITE_SCHEMA message:@"Kayoko history search index is not ready"];
        return NO;
    }

    NSInteger staleItemCount = [self staleSearchIndexItemCountWithError:error];
    if (staleItemCount == NSIntegerMax) {
        return NO;
    }
    if (staleItemCount > 0) {
        [self populateError:error code:SQLITE_SCHEMA message:@"Kayoko history search index contains unprocessed items"];
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
    return [self itemsForHistoryKey:historyKey searchCriteria:nil error:error];
}

- (NSMutableArray<NSDictionary<NSString *, id> *> *)itemsForHistoryKey:(NSString *)historyKey
                                                        searchCriteria:(KayokoSearchCriteria *)searchCriteria
                                                                 error:(NSError **)error {
    sqlite3_stmt *statement = NULL;
    NSMutableArray<NSDictionary<NSString *, id> *> *items = [[NSMutableArray alloc] init];
    NSMutableString *sql = [NSMutableString stringWithString:@"SELECT bundle_identifier, content, image_name, has_link "
                                                              "FROM history_items WHERE history_key = ?"];
    NSMutableArray<id> *bindings = [NSMutableArray arrayWithObject:historyKey ?: @""];

    if ([searchCriteria hasSearchText]) {
        if ([[searchCriteria categoryValue] isEqualToString:kKayokoSearchCategoryImage]) {
            [sql appendString:@" AND 0"];
        } else {
            [sql appendString:@" AND image_name = '' AND content LIKE ? ESCAPE '\\'"];
            [bindings addObject:[self likePatternForSearchText:[searchCriteria searchText]]];
        }
    }
    if ([searchCriteria hasCategoryToken]) {
        [sql appendString:@" AND EXISTS ("
                           "SELECT 1 FROM history_item_search_tokens token "
                           "WHERE token.item_id = history_items.id "
                           "AND token.history_key = history_items.history_key "
                           "AND token.token_type = ? "
                           "AND token.token_value = ?"
                           ")"];
        [bindings addObject:kKayokoSearchTokenTypeCategory];
        [bindings addObject:[searchCriteria categoryValue] ?: @""];
    }
    if ([searchCriteria hasAppToken]) {
        [sql appendString:@" AND EXISTS ("
                           "SELECT 1 FROM history_item_search_tokens token "
                           "WHERE token.item_id = history_items.id "
                           "AND token.history_key = history_items.history_key "
                           "AND token.token_type = ? "
                           "AND token.token_value = ?"
                           ")"];
        [bindings addObject:kKayokoSearchTokenTypeApp];
        [bindings addObject:[searchCriteria appBundleIdentifier] ?: @""];
    }
    [sql appendString:@" ORDER BY sequence DESC"];

    if (![self prepareStatement:[sql UTF8String] statement:&statement error:error]) {
        return items;
    }

    [self bindObjects:bindings toStatement:statement];
    int stepResult = SQLITE_OK;
    while ((stepResult = sqlite3_step(statement)) == SQLITE_ROW) {
        [items addObject:[self dictionaryFromCurrentRowInStatement:statement]];
    }
    if (stepResult != SQLITE_DONE) {
        [self populateError:error code:stepResult message:sql];
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

- (NSArray<NSString *> *)availableSearchAppBundleIdentifiersWithError:(NSError **)error {
    sqlite3_stmt *statement = NULL;
    const char *sql = "SELECT DISTINCT bundle_identifier FROM history_items "
                      "WHERE bundle_identifier <> '' ORDER BY bundle_identifier COLLATE NOCASE";
    if (![self prepareStatement:sql statement:&statement error:error]) {
        return @[];
    }

    NSMutableArray<NSString *> *bundleIdentifiers = [[NSMutableArray alloc] init];
    int stepResult = SQLITE_OK;
    while ((stepResult = sqlite3_step(statement)) == SQLITE_ROW) {
        NSString *bundleIdentifier = [self stringFromColumn:statement index:0];
        if ([bundleIdentifier length] > 0) {
            [bundleIdentifiers addObject:bundleIdentifier];
        }
    }
    if (stepResult != SQLITE_DONE) {
        [self populateError:error code:stepResult message:[NSString stringWithUTF8String:sql]];
    }

    sqlite3_finalize(statement);
    return bundleIdentifiers;
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

- (BOOL)ensureColumnNamed:(NSString *)columnName
                  inTable:(NSString *)tableName
      usingAlterStatement:(NSString *)alterStatement
                    error:(NSError **)error {
    sqlite3_stmt *statement = NULL;
    NSString *sql = [NSString stringWithFormat:@"PRAGMA table_info(%@)", tableName];
    if (![self prepareStatement:[sql UTF8String] statement:&statement error:error]) {
        return NO;
    }

    BOOL foundColumn = NO;
    int stepResult = SQLITE_OK;
    while ((stepResult = sqlite3_step(statement)) == SQLITE_ROW) {
        NSString *existingColumnName = [self stringFromColumn:statement index:1];
        if ([existingColumnName isEqualToString:columnName]) {
            foundColumn = YES;
            break;
        }
    }
    if (stepResult != SQLITE_DONE && stepResult != SQLITE_ROW) {
        [self populateError:error code:stepResult message:sql];
        sqlite3_finalize(statement);
        return NO;
    }
    sqlite3_finalize(statement);

    if (foundColumn) {
        return YES;
    }
    return [self executeStatement:alterStatement error:error];
}

- (NSInteger)staleSearchIndexItemCountWithError:(NSError **)error {
    sqlite3_stmt *statement = NULL;
    if (![self prepareStatement:"SELECT COUNT(*) FROM history_items WHERE search_index_version <> ?"
                      statement:&statement
                          error:error]) {
        return NSIntegerMax;
    }

    sqlite3_bind_int64(statement, 1, kKayokoHistoryStoreSearchIndexVersion);
    NSInteger count = NSIntegerMax;
    int stepResult = sqlite3_step(statement);
    if (stepResult == SQLITE_ROW) {
        count = (NSInteger)sqlite3_column_int64(statement, 0);
    } else {
        [self populateError:error
                       code:stepResult
                    message:@"SELECT COUNT(*) FROM history_items WHERE search_index_version <> ?"];
    }
    sqlite3_finalize(statement);
    return count;
}

- (BOOL)rebuildStaleSearchIndexesWithError:(NSError **)error {
    sqlite3_stmt *statement = NULL;
    const char *sql = "SELECT id, history_key, bundle_identifier, content, image_name "
                      "FROM history_items WHERE search_index_version <> ?";
    if (![self prepareStatement:sql statement:&statement error:error]) {
        return NO;
    }

    sqlite3_bind_int64(statement, 1, kKayokoHistoryStoreSearchIndexVersion);
    NSMutableArray<NSDictionary<NSString *, id> *> *rows = [[NSMutableArray alloc] init];
    int stepResult = SQLITE_OK;
    while ((stepResult = sqlite3_step(statement)) == SQLITE_ROW) {
        [rows addObject:@{
            @"id" : @(sqlite3_column_int64(statement, 0)),
            @"history_key" : [self stringFromColumn:statement index:1] ?: @"",
            @"bundle_identifier" : [self stringFromColumn:statement index:2] ?: @"com.apple.springboard",
            @"content" : [self stringFromColumn:statement index:3] ?: @"",
            @"image_name" : [self stringFromColumn:statement index:4] ?: @""
        }];
    }
    if (stepResult != SQLITE_DONE) {
        [self populateError:error code:stepResult message:[NSString stringWithUTF8String:sql]];
        sqlite3_finalize(statement);
        return NO;
    }
    sqlite3_finalize(statement);

    for (NSDictionary<NSString *, id> *row in rows) {
        if (![self rebuildSearchIndexForItemID:[row[@"id"] longLongValue]
                                    historyKey:row[@"history_key"]
                              bundleIdentifier:row[@"bundle_identifier"]
                                       content:row[@"content"]
                                     imageName:row[@"image_name"]
                                         error:error]) {
            return NO;
        }
    }

    return YES;
}

- (BOOL)rebuildSearchIndexForItemID:(sqlite3_int64)itemID
                         historyKey:(NSString *)historyKey
                   bundleIdentifier:(NSString *)bundleIdentifier
                            content:(NSString *)content
                          imageName:(NSString *)imageName
                              error:(NSError **)error {
    if (![self executeStatement:@"DELETE FROM history_item_search_tokens WHERE item_id = ?"
                       bindings:@[ @(itemID) ]
                          error:error]) {
        return NO;
    }

    NSMutableSet<NSString *> *categoryValues = [self categorySearchValuesForContent:content imageName:imageName];
    for (NSString *categoryValue in categoryValues) {
        if (![self insertSearchTokenForItemID:itemID
                                   historyKey:historyKey
                                    tokenType:kKayokoSearchTokenTypeCategory
                                   tokenValue:categoryValue
                                        error:error]) {
            return NO;
        }
    }

    NSString *appValue = [bundleIdentifier length] > 0 ? bundleIdentifier : @"com.apple.springboard";
    if (![self insertSearchTokenForItemID:itemID
                               historyKey:historyKey
                                tokenType:kKayokoSearchTokenTypeApp
                               tokenValue:appValue
                                    error:error]) {
        return NO;
    }

    return [self executeStatement:@"UPDATE history_items SET search_index_version = ? WHERE id = ?"
                         bindings:@[ @(kKayokoHistoryStoreSearchIndexVersion), @(itemID) ]
                            error:error];
}

- (NSMutableSet<NSString *> *)categorySearchValuesForContent:(NSString *)content imageName:(NSString *)imageName {
    NSMutableSet<NSString *> *values = [[NSMutableSet alloc] init];
    if ([imageName length] > 0) {
        [values addObject:kKayokoSearchCategoryImage];
        return values;
    }

    [values addObject:kKayokoSearchCategoryText];
    if ([content length] == 0) {
        return values;
    }

    static NSDataDetector *detector = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      NSTextCheckingTypes types = NSTextCheckingTypeLink | NSTextCheckingTypePhoneNumber | NSTextCheckingTypeDate |
                                  NSTextCheckingTypeAddress | NSTextCheckingTypeTransitInformation;
      detector = [NSDataDetector dataDetectorWithTypes:types error:nil];
    });

    NSArray<NSTextCheckingResult *> *matches = [detector matchesInString:content
                                                                 options:0
                                                                   range:NSMakeRange(0, [content length])];
    for (NSTextCheckingResult *match in matches) {
        switch ([match resultType]) {
        case NSTextCheckingTypeLink:
            [values addObject:kKayokoSearchCategoryLink];
            break;
        case NSTextCheckingTypePhoneNumber:
            [values addObject:kKayokoSearchCategoryPhone];
            break;
        case NSTextCheckingTypeDate:
            [values addObject:kKayokoSearchCategoryDate];
            break;
        case NSTextCheckingTypeAddress:
            [values addObject:kKayokoSearchCategoryAddress];
            break;
        case NSTextCheckingTypeTransitInformation:
            [values addObject:kKayokoSearchCategoryFlight];
            break;
        default:
            break;
        }
    }

    return values;
}

- (BOOL)insertSearchTokenForItemID:(sqlite3_int64)itemID
                        historyKey:(NSString *)historyKey
                         tokenType:(NSString *)tokenType
                        tokenValue:(NSString *)tokenValue
                             error:(NSError **)error {
    if ([historyKey length] == 0 || [tokenType length] == 0 || [tokenValue length] == 0) {
        return YES;
    }

    return [self executeStatement:@"INSERT OR IGNORE INTO history_item_search_tokens "
                                   "(item_id, history_key, token_type, token_value) VALUES (?, ?, ?, ?)"
                         bindings:@[ @(itemID), historyKey, tokenType, tokenValue ]
                            error:error];
}

- (NSString *)likePatternForSearchText:(NSString *)searchText {
    NSMutableString *pattern = [[NSMutableString alloc] initWithString:@"%"];
    for (NSUInteger index = 0; index < [searchText length]; index++) {
        unichar character = [searchText characterAtIndex:index];
        if (character == '%' || character == '_' || character == '\\') {
            [pattern appendString:@"\\"];
        }
        [pattern appendFormat:@"%C", character];
    }
    [pattern appendString:@"%"];
    return pattern;
}

- (BOOL)openDatabaseWithError:(NSError **)error {
    if (_database) {
        return YES;
    }

    int result = sqlite3_open_v2([[self databasePath] fileSystemRepresentation], &_database,
                                 SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, NULL);
    if (result != SQLITE_OK) {
        [self populateError:error code:result message:@"Unable to open history database"];
        [self closeDatabase];
        return NO;
    }

    int busyTimeoutMilliseconds = (int)MIN([self busyTimeoutMilliseconds], (NSInteger)INT_MAX);
    sqlite3_busy_timeout(_database, busyTimeoutMilliseconds);
    if (![self configureDatabaseLockingModeWithError:error]) {
        [self closeDatabase];
        return NO;
    }
    return YES;
}

- (BOOL)configureDatabaseLockingModeWithError:(NSError **)error {
    if ([self lockingMode] != KayokoHistoryStoreLockingModeExclusiveWhileOpen) {
        return YES;
    }

    return [self executeStatement:@"PRAGMA locking_mode=EXCLUSIVE" error:error];
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

    if (![self executeStatement:
                   @"INSERT INTO history_items "
                    "(history_key, bundle_identifier, content, image_name, has_link, created_at, updated_at, sequence, "
                    "search_index_version) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)"
                       bindings:@[ historyKey, bundleIdentifier, content, imageName, hasLink, now, now, sequence ]
                          error:error]) {
        return NO;
    }

    sqlite3_int64 itemID = sqlite3_last_insert_rowid(_database);
    return [self rebuildSearchIndexForItemID:itemID
                                  historyKey:historyKey
                            bundleIdentifier:bundleIdentifier
                                     content:content
                                   imageName:imageName
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
