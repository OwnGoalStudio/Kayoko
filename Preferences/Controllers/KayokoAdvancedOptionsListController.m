//
//  KayokoAdvancedOptionsListController.m
//  Kayoko
//

#import "KayokoAdvancedOptionsListController.h"
#import "KayokoNotificationKeys.h"
#import "KayokoPreferenceKeys.h"
#import "KayokoRespringControllerSupport.h"

#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <roothide.h>

static NSString *const kKayokoDataDirectoryPath = @"/var/mobile/Library/com.82flex.kayoko";

@implementation KayokoAdvancedOptionsListController

- (NSArray<PSSpecifier *> *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"AdvancedOptions" target:self];
    }

    return _specifiers;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];

    if ([[specifier propertyForKey:@"key"] isEqualToString:kKayokoPreferenceKeyGestureRecognizerMode]) {
        [self promptToRespring];
    }
}

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

- (void)resetPreferences {
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kKayokoPreferencesIdentifier];
    for (NSString *key in [userDefaults dictionaryRepresentation]) {
        [userDefaults removeObjectForKey:key];
    }

    [self reloadSpecifiers];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kKayokoNotificationKeyPreferencesReload, nil, nil, YES);
}

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
