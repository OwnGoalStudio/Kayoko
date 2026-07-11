//
//  KayokoAdvancedOptionsListController.m
//  Kayoko
//

#import "KayokoAdvancedOptionsListController.h"
#import "KayokoNotificationKeys.h"
#import "KayokoPreferenceKeys.h"
#import "KayokoPurchaseAuthorization.h"
#import "KayokoRespringControllerSupport.h"
#import "KayokoTagStore.h"

#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <roothide.h>

static NSString *const kKayokoDataDirectoryPath = @"/var/mobile/Library/com.82flex.kayoko";

@interface NSTask : NSObject
- (void)setLaunchPath:(NSString *)launchPath;
- (void)setArguments:(NSArray<NSString *> *)arguments;
- (void)setStandardOutput:(id)standardOutput;
- (void)setStandardError:(id)standardError;
- (void)launch;
- (void)waitUntilExit;
@end

@implementation KayokoAdvancedOptionsListController

#pragma mark - Specifiers

- (NSArray<PSSpecifier *> *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"AdvancedOptions" target:self];
    }

    return _specifiers;
}

#pragma mark - Preference Writing

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];

    if ([[specifier propertyForKey:@"key"] isEqualToString:kKayokoPreferenceKeyGestureRecognizerMode]) {
        [self promptToRespring];
    }
}

#pragma mark - Prompts

- (void)resetPrompt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *resetAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:@"Are you sure you want to reset your "
                                                               @"preferences?"
                                                         value:nil
                                                         table:@"AdvancedOptions"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *resetAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Reset"
                                                                                        value:nil
                                                                                        table:@"AdvancedOptions"]
                                                          style:UIAlertActionStyleDestructive
                                                        handler:^(UIAlertAction *action) {
                                                          [self resetPreferences];
                                                        }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [resetAlert addAction:resetAction];
    [resetAlert addAction:cancelAction];

    [self presentViewController:resetAlert animated:YES completion:nil];
}

- (void)clearFavoritesPrompt {
    [self presentClearConfirmationWithMessageKey:
              @"Are you sure you want to clear all favorite items? This action cannot be undone."
                                  actionTitleKey:@"Clear Favorites"
                                notificationName:kKayokoNotificationKeyCoreClearFavorites];
}

- (void)clearHistoryPrompt {
    [self presentClearConfirmationWithMessageKey:
              @"Are you sure you want to clear all history items? This action cannot be undone."
                                  actionTitleKey:@"Clear History"
                                notificationName:kKayokoNotificationKeyCoreClearHistory];
}

- (void)deactivateAuthorizationPrompt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *deactivateAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:
                                             @"Are you sure you want to deactivate Kayoko on this device? "
                                             @"This removes Kayoko’s mirrored Havoc credentials and "
                                             @"local authorization state."
                                                         value:nil
                                                         table:@"AdvancedOptions"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *deactivateAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Deactivate"
                                                                                             value:nil
                                                                                             table:@"AdvancedOptions"]
                                                               style:UIAlertActionStyleDestructive
                                                             handler:^(UIAlertAction *action) {
                                                               (void)action;
                                                               [self deactivateAuthorization];
                                                             }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [deactivateAlert addAction:deactivateAction];
    [deactivateAlert addAction:cancelAction];

    [self presentViewController:deactivateAlert animated:YES completion:nil];
}

- (void)restoreTagsPrompt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *restoreAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:@"Are you sure you want to restore the default tags? "
                                                               @"Existing tags will be replaced. This action cannot be "
                                                               @"undone."
                                                         value:nil
                                                         table:@"AdvancedOptions"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *restoreAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Restore Tags"
                                                                                          value:nil
                                                                                          table:@"AdvancedOptions"]
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction *action) {
                                                            (void)action;
                                                            [self restoreTags];
                                                          }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [restoreAlert addAction:restoreAction];
    [restoreAlert addAction:cancelAction];

    [self presentViewController:restoreAlert animated:YES completion:nil];
}

- (void)resetThumbnailCachePrompt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:
                                             @"Are you sure you want to reset the thumbnail cache? Thumbnails will "
                                             @"be regenerated as needed."
                                                         value:nil
                                                         table:@"AdvancedOptions"]
                  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *resetAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Reset Thumbnail Cache"
                                                                                        value:nil
                                                                                        table:@"AdvancedOptions"]
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
                                                          (void)action;
                                                          [self resetThumbnailCache];
                                                        }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:resetAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentClearConfirmationWithMessageKey:(NSString *)messageKey
                                actionTitleKey:(NSString *)actionTitleKey
                              notificationName:(NSString *)notificationName {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *clearAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:messageKey value:nil table:@"AdvancedOptions"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *clearAction =
        [UIAlertAction actionWithTitle:[bundle localizedStringForKey:actionTitleKey value:nil table:@"AdvancedOptions"]
                                 style:UIAlertActionStyleDestructive
                               handler:^(UIAlertAction *action) {
                                 CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                                      (CFStringRef)notificationName, nil, nil, YES);
                               }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [clearAlert addAction:clearAction];
    [clearAlert addAction:cancelAction];

    [self presentViewController:clearAlert animated:YES completion:nil];
}

#pragma mark - Data Directory

- (void)checkDataDirectory {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kKayokoNotificationKeyCoreCheckpointHistory, nil, nil, YES);

    NSURL *filzaURL = [self filzaURLForDataDirectoryPath:[self dataDirectoryPath]];
    if (!filzaURL) {
        [self presentDataDirectoryPathAlert];
        return;
    }

    [[UIApplication sharedApplication] openURL:filzaURL
                                       options:@{}
                             completionHandler:^(BOOL success) {
                               if (!success) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                     [self presentDataDirectoryPathAlert];
                                   });
                               }
                             }];
}

- (NSString *)dataDirectoryPath {
    return jbroot(kKayokoDataDirectoryPath);
}

- (NSURL *)filzaURLForDataDirectoryPath:(NSString *)dataDirectoryPath {
    NSString *encodedPath = [dataDirectoryPath
        stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
    NSString *pathComponent = encodedPath ?: dataDirectoryPath;
    NSString *URLString = [@"filza://view" stringByAppendingString:pathComponent];
    return [NSURL URLWithString:URLString];
}

- (void)presentDataDirectoryPathAlert {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *dataDirectoryPath = [self dataDirectoryPath];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:[bundle localizedStringForKey:@"Unable to Open Filza"
                                                                            value:nil
                                                                            table:@"AdvancedOptions"]
                                            message:dataDirectoryPath
                                     preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Copy Path"
                                                                                       value:nil
                                                                                       table:@"AdvancedOptions"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
                                                         [UIPasteboard generalPasteboard].string = dataDirectoryPath;
                                                       }];

    [alert addAction:cancelAction];
    [alert addAction:copyAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Authorization

- (void)deactivateAuthorization {
    NSError *error = nil;
    if (![KayokoPurchaseAuthorization clearAuthorizationStateWithError:&error]) {
        [self presentDeactivateAuthorizationError:error];
        return;
    }

    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)presentDeactivateAuthorizationError:(NSError *)error {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *message = [error localizedDescription]
                            ?: [bundle localizedStringForKey:@"Unable to Deactivate"
                                                       value:nil
                                                       table:@"AdvancedOptions"];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:[bundle localizedStringForKey:@"Unable to Deactivate"
                                                                            value:nil
                                                                            table:@"AdvancedOptions"]
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"OK"
                                                                                   value:nil
                                                                                   table:@"AdvancedOptions"]
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil];
    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Maintenance Actions

- (void)resetThumbnailCache {
    NSString *updaterPath = [self kayokoUpdaterPath];
    if ([updaterPath length] == 0) {
        NSLog(@"Kayoko: Unable to reset thumbnail cache because kayoko_updater is unavailable");
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      @try {
          NSTask *task = [[NSTask alloc] init];
          [task setLaunchPath:updaterPath];
          [task setArguments:@[ @"reset-thumbnail-cache" ]];
          [task setStandardOutput:[NSPipe pipe]];
          [task setStandardError:[NSPipe pipe]];
          [task launch];
          [task waitUntilExit];
      } @catch (NSException *exception) {
          NSLog(@"Kayoko: Unable to launch thumbnail cache reset: %@", exception);
      }
    });
}

- (NSString *)kayokoUpdaterPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSString *> *candidatePaths = @[
        jbroot(@"/usr/local/libexec/kayoko_updater"), @"/var/jb/usr/local/libexec/kayoko_updater",
        @"/usr/local/libexec/kayoko_updater"
    ];
    for (NSString *path in candidatePaths) {
        if ([fileManager isExecutableFileAtPath:path]) {
            return path;
        }
    }
    return nil;
}

- (void)resetPreferences {
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kKayokoPreferencesIdentifier];
    for (NSString *key in [userDefaults dictionaryRepresentation]) {
        [userDefaults removeObjectForKey:key];
    }

    [self reloadSpecifiers];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kKayokoNotificationKeyPreferencesReload, nil, nil, YES);
}

- (void)restoreTags {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    KayokoTagStore *tagStore = [[KayokoTagStore alloc] initWithTagsPath:[KayokoTagStore defaultTagsPath]
                                                     localizationBundle:bundle];

    NSError *error = nil;
    if (![tagStore restoreDefaultTagsWithError:&error]) {
        [self presentRestoreTagsError:error];
    }
}

- (void)presentRestoreTagsError:(NSError *)error {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *message = [error localizedDescription]
                            ?: [bundle localizedStringForKey:@"Unable to Restore Tags"
                                                       value:nil
                                                       table:@"AdvancedOptions"];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:[bundle localizedStringForKey:@"Unable to Restore Tags"
                                                                            value:nil
                                                                            table:@"AdvancedOptions"]
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"OK"
                                                                                   value:nil
                                                                                   table:@"AdvancedOptions"]
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil];
    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    NSString *key = [specifier propertyForKey:@"cell"];
    if ([key isEqualToString:@"PSButtonCell"]) {
        UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
        NSNumber *isDestructiveValue = [specifier propertyForKey:@"isDestructive"];
        BOOL isDestructive = [isDestructiveValue boolValue];
        cell.textLabel.textColor = isDestructive ? [UIColor systemRedColor] : [UIColor systemBlueColor];
        cell.textLabel.highlightedTextColor = isDestructive ? [UIColor systemRedColor] : [UIColor systemBlueColor];
        return cell;
    }

    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

@end
