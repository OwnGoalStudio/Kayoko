//
//  KayokoPostinstallUpdater.m
//  Kayoko
//

#import "KayokoPostinstallUpdater.h"
#import "KayokoHistoryMigrator.h"
#import "KayokoHistoryStore.h"
#import "KayokoNotificationKeys.h"

#import <CoreFoundation/CoreFoundation.h>
#import <roothide.h>
#import <unistd.h>

static NSString *const kKayokoCurrentDataDirectory = @"/var/mobile/Library/com.82flex.kayoko";
static NSUInteger const kKayokoMobileUserID = 501;
static NSUInteger const kKayokoMobileGroupID = 501;
static useconds_t const kKayokoCoreMaintenanceGracePeriodMicroseconds = 300000;
static NSInteger const kKayokoUpdaterHistoryStoreBusyTimeoutMilliseconds = 10000;

@implementation KayokoPostinstallUpdater

- (BOOL)runPostinstallWithError:(NSError **)error {
    [self notifyCoreToPrepareForMaintenance];

    KayokoHistoryStore *store = [self historyStore];
    NSError *lockError = nil;
    if (![store verifyExclusiveAccessWithError:&lockError]) {
        if (error) {
            *error = lockError;
        }
        return NO;
    }

    KayokoHistoryMigrator *migrator =
        [[KayokoHistoryMigrator alloc] initWithHistoryStore:store
                                           migrationSources:[KayokoHistoryMigrator defaultMigrationSources]];
    NSError *migrationError = nil;
    BOOL migrated = [migrator migrateIfNeededWithError:&migrationError];

    NSError *searchIndexError = nil;
    BOOL upgradedSearchIndex = migrated && [store upgradeSearchIndexWithError:&searchIndexError];

    NSError *ownershipError = nil;
    BOOL repairedOwnership = [self repairCurrentDataDirectoryOwnershipWithError:&ownershipError];
    if (!migrated) {
        if (error) {
            *error = migrationError;
        }
        return NO;
    }
    if (!upgradedSearchIndex) {
        if (error) {
            *error = searchIndexError;
        }
        return NO;
    }
    if (!repairedOwnership) {
        if (error) {
            *error = ownershipError;
        }
        return NO;
    }

    return YES;
}

- (NSArray<NSString *> *)safelyDeletableLegacyPathsWithError:(NSError **)error {
    KayokoHistoryStore *store = [self historyStore];
    if (![store prepareStoreWithError:error]) {
        return @[];
    }

    if (![store isMigrationCompletedWithError:error]) {
        return @[];
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *activeImagesPath = [[store imagesPath] stringByStandardizingPath];
    NSMutableArray<NSString *> *paths = [[NSMutableArray alloc] init];
    NSMutableSet<NSString *> *seenPaths = [[NSMutableSet alloc] init];

    for (KayokoHistoryMigrationSource *source in [KayokoHistoryMigrator defaultMigrationSources]) {
        [self addPathIfExists:[source historyPath] fileManager:fileManager paths:paths seenPaths:seenPaths];

        NSString *sourceImagesPath = [[source imagesPath] stringByStandardizingPath];
        if (![sourceImagesPath isEqualToString:activeImagesPath]) {
            [self addPathIfExists:[source imagesPath] fileManager:fileManager paths:paths seenPaths:seenPaths];
        }
    }

    return paths;
}

#pragma mark - Private

- (void)notifyCoreToPrepareForMaintenance {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kKayokoNotificationKeyCorePrepareMaintenance, nil, nil,
                                         YES);
    usleep(kKayokoCoreMaintenanceGracePeriodMicroseconds);
}

- (KayokoHistoryStore *)historyStore {
    return [[KayokoHistoryStore alloc] initWithDatabasePath:[KayokoHistoryStore defaultDatabasePath]
                                                 imagesPath:[self currentImagesPath]
                                                lockingMode:KayokoHistoryStoreLockingModeExclusiveWhileOpen
                                     busyTimeoutMilliseconds:kKayokoUpdaterHistoryStoreBusyTimeoutMilliseconds];
}

- (NSString *)currentImagesPath {
    return [jbroot(kKayokoCurrentDataDirectory) stringByAppendingPathComponent:@"images"];
}

- (BOOL)repairCurrentDataDirectoryOwnershipWithError:(NSError **)error {
    NSString *dataDirectory = jbroot(kKayokoCurrentDataDirectory);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:dataDirectory]) {
        return YES;
    }

    if (![self repairOwnershipAtPath:dataDirectory isDirectory:YES fileManager:fileManager error:error]) {
        return NO;
    }

    NSDirectoryEnumerator<NSString *> *enumerator = [fileManager enumeratorAtPath:dataDirectory];
    for (NSString *relativePath in enumerator) {
        NSString *path = [dataDirectory stringByAppendingPathComponent:relativePath];
        BOOL isDirectory = NO;
        if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory]) {
            continue;
        }
        if (![self repairOwnershipAtPath:path isDirectory:isDirectory fileManager:fileManager error:error]) {
            return NO;
        }
    }

    return YES;
}

- (BOOL)repairOwnershipAtPath:(NSString *)path
                  isDirectory:(BOOL)isDirectory
                  fileManager:(NSFileManager *)fileManager
                        error:(NSError **)error {
    NSDictionary<NSFileAttributeKey, id> *attributes = @{
        NSFileOwnerAccountID : @(kKayokoMobileUserID),
        NSFileGroupOwnerAccountID : @(kKayokoMobileGroupID),
        NSFilePosixPermissions : @(isDirectory ? 0755 : 0644)
    };
    return [fileManager setAttributes:attributes ofItemAtPath:path error:error];
}

- (void)addPathIfExists:(NSString *)path
            fileManager:(NSFileManager *)fileManager
                  paths:(NSMutableArray<NSString *> *)paths
              seenPaths:(NSMutableSet<NSString *> *)seenPaths {
    if ([path length] == 0 || ![fileManager fileExistsAtPath:path]) {
        return;
    }

    NSString *standardizedPath = [path stringByStandardizingPath];
    if ([seenPaths containsObject:standardizedPath]) {
        return;
    }

    [seenPaths addObject:standardizedPath];
    [paths addObject:path];
}

@end
