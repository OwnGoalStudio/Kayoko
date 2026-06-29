//
//  main.m
//  kayoko_updater
//

#import "KayokoPostinstallUpdater.h"

#import <Foundation/Foundation.h>

static int runPostinstall(void) {
    @autoreleasepool {
        KayokoPostinstallUpdater *updater = [[KayokoPostinstallUpdater alloc] init];
        NSError *error = nil;
        if (![updater runPostinstallWithError:&error]) {
            fprintf(stderr, "kayoko_updater: postinst failed: %s\n",
                    [[[error localizedDescription] description] UTF8String]);
            return 0;
        }

        NSArray<NSString *> *legacyPaths = [updater safelyDeletableLegacyPathsWithError:&error];
        if ([legacyPaths count] > 0) {
            fprintf(stderr, "kayoko_updater: the following legacy Kayoko data paths were imported into v4 storage and "
                            "can be removed manually:\n");
            for (NSString *path in legacyPaths) {
                fprintf(stderr, "kayoko_updater:   %s\n", [path fileSystemRepresentation]);
            }
        } else if (error) {
            fprintf(stderr, "kayoko_updater: unable to inspect legacy cleanup paths: %s\n",
                    [[[error localizedDescription] description] UTF8String]);
        }
        return 0;
    }
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: kayoko_updater postinst\n");
            return 64;
        }

        NSString *command = [NSString stringWithUTF8String:argv[1]];
        if ([command isEqualToString:@"postinst"]) {
            return runPostinstall();
        }

        fprintf(stderr, "kayoko_updater: unknown command: %s\n", argv[1]);
        return 64;
    }
}
