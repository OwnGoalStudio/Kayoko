//
//  KayokoRootListController.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoRootListController.h"
#import "KayokoNotificationKeys.h"
#import "KayokoPreferenceKeys.h"

#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <roothide.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSConcreteNotification : NSNotification
@end

@interface PSListController (Private)
- (void)_returnKeyPressed:(NSConcreteNotification *)notification;
@end

@interface NSTask : NSObject
@property(nonatomic, copy) NSArray<NSString *> *arguments;
@property(nonatomic, copy) NSString *launchPath;
- (void)launch;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoRootListController {
    ActivationMethod _lastActivationMethod;
    BOOL _hasActivationMethodSnapshot;
}

- (NSArray<PSSpecifier *> *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }

    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    ActivationMethod currentActivationMethod = [self currentActivationMethod];
    if (!_hasActivationMethodSnapshot) {
        _lastActivationMethod = currentActivationMethod;
        _hasActivationMethodSnapshot = YES;
        return;
    }

    if (currentActivationMethod != _lastActivationMethod) {
        _lastActivationMethod = currentActivationMethod;
        [self promptToRespring];
    }
}

- (ActivationMethod)currentActivationMethod {
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kKayokoPreferencesIdentifier];
    ActivationMethod activationMethod = [userDefaults integerForKey:kKayokoPreferenceKeyActivationMethod];
    return activationMethod == 0 ? kKayokoPreferenceKeyActivationMethodDefaultValue : activationMethod;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];

    // Prompt to respring for options that require one to apply changes.
    if ([[specifier propertyForKey:@"key"] isEqualToString:kKayokoPreferenceKeyEnabled] ||
        [[specifier propertyForKey:@"key"] isEqualToString:kKayokoPreferenceKeyActivationMethod] ||
        [[specifier propertyForKey:@"key"] isEqualToString:kKayokoPreferenceKeyAutomaticallyPaste]) {
        if ([[specifier propertyForKey:@"key"] isEqualToString:kKayokoPreferenceKeyActivationMethod]) {
            _lastActivationMethod = [self currentActivationMethod];
            _hasActivationMethodSnapshot = YES;
        }
        [self promptToRespring];
    }
}

- (void)_returnKeyPressed:(NSConcreteNotification *)notification {
    [[self view] endEditing:YES];
    [super _returnKeyPressed:notification];
}

- (void)promptToRespring {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *resetAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:@"This option requires restarting SpringBoard to apply. "
                                                               @"Do you want to restart now?"
                                                         value:nil
                                                         table:@"Root"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *respringAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Respring Now"
                                                                                           value:nil
                                                                                           table:@"Root"]
                                                             style:UIAlertActionStyleDestructive
                                                           handler:^(UIAlertAction *action) {
                                                             [self respring];
                                                           }];

    UIAlertAction *notNowAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Not Now"
                                                                                         value:nil
                                                                                         table:@"Root"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [resetAlert addAction:respringAction];
    [resetAlert addAction:notNowAction];

    [self presentViewController:resetAlert animated:YES completion:nil];
}

- (void)respringPrompt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *respringAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:@"Respringing will restart SpringBoard and close all "
                                                               @"apps. Unsaved work may be lost."
                                                         value:nil
                                                         table:@"Root"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *respringAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Respring Now"
                                                                                           value:nil
                                                                                           table:@"Root"]
                                                             style:UIAlertActionStyleDestructive
                                                           handler:^(UIAlertAction *action) {
                                                             [self respring];
                                                           }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"Root"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [respringAlert addAction:respringAction];
    [respringAlert addAction:cancelAction];

    [self presentViewController:respringAlert animated:YES completion:nil];
}

- (void)respring {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:jbroot(@"/usr/bin/killall")];
    [task setArguments:@[ @"backboardd" ]];
    [task launch];
}

- (void)resetPrompt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *resetAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:@"Are you sure you want to reset your preferences?"
                                                         value:nil
                                                         table:@"Root"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *resetAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Reset"
                                                                                        value:nil
                                                                                        table:@"Root"]
                                                          style:UIAlertActionStyleDestructive
                                                        handler:^(UIAlertAction *action) {
                                                          [self resetPreferences];
                                                        }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"Root"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [resetAlert addAction:resetAction];
    [resetAlert addAction:cancelAction];

    [self presentViewController:resetAlert animated:YES completion:nil];
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

- (UISlider *_Nullable)findSliderInView:(UIView *)view {
    if ([view isKindOfClass:[UISlider class]]) {
        return (UISlider *)view;
    }
    for (UIView *subview in view.subviews) {
        UISlider *slider = [self findSliderInView:subview];
        if (slider) {
            return slider;
        }
    }
    return nil;
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
    if ([key isEqualToString:@"PSSliderCell"]) {
        UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
        NSNumber *isContinuousValue = [specifier propertyForKey:@"isContinuous"];
        BOOL isContinuous = [isContinuousValue boolValue];
        UISlider *slider = [self findSliderInView:cell];
        if (slider) {
            slider.continuous = isContinuous;
        }
        return cell;
    }
    if ([key isEqualToString:@"PSLinkListCell"]) {
        NSString *detail = [specifier propertyForKey:@"detail"];
        if ([detail isEqualToString:@"KayokoListItemsController"]) {
            UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];

            // Get the current activation methods
            ActivationMethod currentOptions = [self currentActivationMethod];

            // Get valid values and titles
            NSArray<NSNumber *> *validValues = [specifier propertyForKey:@"validValues"];
            NSArray<NSString *> *validTitles = [specifier propertyForKey:@"validTitles"];

            // Find selected options
            NSMutableArray<NSString *> *selectedTitles = [NSMutableArray array];
            for (NSUInteger i = 0; i < validValues.count; i++) {
                NSNumber *value = validValues[i];
                if (currentOptions & [value integerValue]) {
                    [selectedTitles addObject:[bundle localizedStringForKey:validTitles[i] value:nil table:@"Root"]];
                }
            }

            // Format the detail text based on the number of selected options
            NSString *detailText;
            if (selectedTitles.count == 1) {
                // Only one option - display its name
                detailText = selectedTitles[0];
            } else if (selectedTitles.count == 2) {
                // Two options - display "Option A and Option B"
                NSString *format = [bundle localizedStringForKey:@"%@ and %@" value:nil table:@"Root"];
                detailText = [NSString stringWithFormat:format, selectedTitles[0], selectedTitles[1]];
            } else if (selectedTitles.count > 2) {
                // Three or more options - display "Option A and X others"
                NSString *format = [bundle localizedStringForKey:@"%@ and %d others" value:nil table:@"Root"];
                detailText = [NSString stringWithFormat:format, selectedTitles[0], (int)selectedTitles.count - 1];
            } else {
                // No options (shouldn't happen)
                detailText = @"";
            }

            cell.detailTextLabel.text = detailText;
            return cell;
        }
    }
    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

@end
