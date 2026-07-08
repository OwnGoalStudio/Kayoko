//
//  main.m
//  kayoko_updater
//

#import "KayokoPostinstallUpdater.h"
#import "KayokoPurchaseAuthorization.h"

#import <Foundation/Foundation.h>

static BOOL syncCredentialWithError(NSError **error) {
    return [KayokoPurchaseAuthorization mirrorSileoHavocCredentialToAppleAccessGroupWithError:error];
}

static void syncCredentialBestEffort(void) {
    NSError *syncError = nil;
    if (!syncCredentialWithError(&syncError)) {
        fprintf(stderr, "Kayoko: Unable to sync Sileo Havoc credential: %s\n",
                [[[syncError localizedDescription] description] UTF8String]);
    }
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
        return 0;
    }
}

static int runSyncCredential(void) {
    @autoreleasepool {
        NSError *error = nil;
        if (!syncCredentialWithError(&error)) {
            fprintf(stderr, "Kayoko: Command sync-credential failed: %s\n",
                    [[[error localizedDescription] description] UTF8String]);
            return 1;
        }
        return 0;
    }
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: kayoko_updater postinst|sync-credential\n");
            return 64;
        }

        NSString *command = [NSString stringWithUTF8String:argv[1]];
        if ([command isEqualToString:@"postinst"]) {
            return runPostinstall();
        }
        if ([command isEqualToString:@"sync-credential"]) {
            return runSyncCredential();
        }

        fprintf(stderr, "Kayoko: Unknown command: %s\n", argv[1]);
        return 64;
    }
}
