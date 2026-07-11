//
//  main.m
//  kayoko_updater
//

#import "KayokoPostinstallUpdater.h"
#import "KayokoPurchaseAuthorization.h"

#import <Foundation/Foundation.h>

#if defined(DEBUG) || defined(__DEBUG__)
static void logSyncedCredentialSource(NSString *source) {
    NSString *displaySource = [source length] > 0 ? [source capitalizedString] : @"Unknown";
    fprintf(stderr, "Kayoko: Synced Havoc credential from %s.\n", [displaySource UTF8String]);
}
#endif

static BOOL syncCredentialWithSource(NSString **source, NSError **error) {
    return [KayokoPurchaseAuthorization mirrorHavocCredentialToAppleAccessGroupWithSource:source error:error];
}

static NSString *externalImportErrorDescription(NSError *error, NSString *fallback) {
    if ([[error domain] isEqualToString:@"com.82flex.kayoko.history-store"] &&
        [[error localizedFailureReason] length] > 0) {
        return [error localizedFailureReason];
    }
    return [error localizedDescription] ?: fallback;
}

static void syncCredentialBestEffort(void) {
    NSError *syncError = nil;
    NSString *source = nil;
    if (!syncCredentialWithSource(&source, &syncError)) {
        fprintf(stderr, "Kayoko: Unable to sync Havoc credential: %s\n",
                [[[syncError localizedDescription] description] UTF8String]);
    }
#if defined(DEBUG) || defined(__DEBUG__)
    else {
        logSyncedCredentialSource(source);
    }
#endif
}

static int runPostinstall(void) {
    @autoreleasepool {
        KayokoPostinstallUpdater *updater = [[KayokoPostinstallUpdater alloc] init];
        NSError *error = nil;
        if (![updater runPostinstallWithError:&error]) {
            fprintf(stderr, "Kayoko: Command postinst failed: %s\n",
                    [[[error localizedDescription] description] UTF8String]);
            return 1;
        }

        NSArray<NSString *> *legacyPaths = [updater safelyDeletableLegacyPathsWithError:&error];
        if ([legacyPaths count] > 0) {
            fprintf(stderr, "Kayoko: The following legacy Kayoko data paths were imported into v4 storage and "
                            "can be removed manually:\n");
            for (NSString *path in legacyPaths) {
                fprintf(stderr, "Kayoko:   %s\n", [path fileSystemRepresentation]);
            }
        } else if (error) {
            fprintf(stderr, "Kayoko: Unable to inspect legacy cleanup paths: %s\n",
                    [[[error localizedDescription] description] UTF8String]);
        }
        syncCredentialBestEffort();

        error = nil;
        if (![updater resetThumbnailCacheWithError:&error]) {
            fprintf(stderr, "Kayoko: Unable to reset thumbnail cache during postinst: %s\n",
                    [[[error localizedDescription] description] UTF8String]);
        }
        return 0;
    }
}

static int runResetThumbnailCache(void) {
    @autoreleasepool {
        KayokoPostinstallUpdater *updater = [[KayokoPostinstallUpdater alloc] init];
        NSError *error = nil;
        if (![updater resetThumbnailCacheWithError:&error]) {
            fprintf(stderr, "Kayoko: Command reset-thumbnail-cache failed: %s\n",
                    [[[error localizedDescription] description] UTF8String]);
            return 1;
        }
        return 0;
    }
}

static int runCopyVaultImport(void) {
    @autoreleasepool {
        KayokoPostinstallUpdater *updater = [[KayokoPostinstallUpdater alloc] init];
        NSError *error = nil;
        NSUInteger skippedItemCount = 0;
        if (![updater importCopyVaultWithSkippedItemCount:&skippedItemCount error:&error]) {
            NSString *description = externalImportErrorDescription(error, @"Unable to import CopyVault data.");
            fprintf(stderr, "%s\n", [description UTF8String]);
            return 1;
        }
        fprintf(stdout, "{\"skipped\":%llu}\n", (unsigned long long)skippedItemCount);
        return 0;
    }
}

static int runCopyLogImport(void) {
    @autoreleasepool {
        KayokoPostinstallUpdater *updater = [[KayokoPostinstallUpdater alloc] init];
        NSError *error = nil;
        NSUInteger skippedItemCount = 0;
        if (![updater importCopyLogWithSkippedItemCount:&skippedItemCount error:&error]) {
            NSString *description = externalImportErrorDescription(error, @"Unable to import CopyLog data.");
            fprintf(stderr, "%s\n", [description UTF8String]);
            return 1;
        }
        fprintf(stdout, "{\"skipped\":%llu}\n", (unsigned long long)skippedItemCount);
        return 0;
    }
}

static int runSyncCredential(void) {
    @autoreleasepool {
        NSError *error = nil;
        NSString *source = nil;
        if (!syncCredentialWithSource(&source, &error)) {
            fprintf(stderr, "Kayoko: Command sync-credential failed: %s\n",
                    [[[error localizedDescription] description] UTF8String]);
            return 1;
        }
#if defined(DEBUG) || defined(__DEBUG__)
        logSyncedCredentialSource(source);
#endif
        return 0;
    }
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr,
                    "usage: kayoko_updater postinst|import-copylog|import-copyvault|reset-thumbnail-cache|sync-credential\n");
            return 64;
        }

        NSString *command = [NSString stringWithUTF8String:argv[1]];
        if ([command isEqualToString:@"postinst"]) {
            return runPostinstall();
        }
        if ([command isEqualToString:@"sync-credential"]) {
            return runSyncCredential();
        }
        if ([command isEqualToString:@"import-copyvault"]) {
            return runCopyVaultImport();
        }
        if ([command isEqualToString:@"import-copylog"]) {
            return runCopyLogImport();
        }
        if ([command isEqualToString:@"reset-thumbnail-cache"]) {
            return runResetThumbnailCache();
        }

        fprintf(stderr, "Kayoko: Unknown command: %s\n", argv[1]);
        return 64;
    }
}
