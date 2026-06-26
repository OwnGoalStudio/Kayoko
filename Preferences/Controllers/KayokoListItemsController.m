//
//  KayokoListItemsController.m
//  Kayoko
//
//  Created by Lessica
//

#import "KayokoListItemsController.h"
#import "../NotificationKeys.h"
#import "../PreferenceKeys.h"
#import <Preferences/PSSpecifier.h>

@implementation KayokoListItemsController {
    NSMutableSet *_selectedIndices;
    ActivationMethod _currentOptions;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (!_selectedIndices) {
        _selectedIndices = [NSMutableSet set];
    }

    // Read current configuration value
    id value = [self readPreferenceValue:self.specifier];
    _currentOptions = [value integerValue];
    if (_currentOptions == 0) {
        _currentOptions = kPreferenceKeyActivationMethodDefaultValue;
    }

    // Initialize selected indices
    [_selectedIndices removeAllObjects];
    NSArray *validValues = [self.specifier propertyForKey:@"validValues"];
    for (NSUInteger i = 0; i < validValues.count; i++) {
        NSNumber *value = validValues[i];
        if (_currentOptions & [value integerValue]) {
            [_selectedIndices addObject:@(i)];
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSUInteger selectedIndex = indexPath.row;

    // Check if this option is already selected
    NSNumber *indexNumber = @(selectedIndex);
    if ([_selectedIndices containsObject:indexNumber]) {
        // If this is the last selected item, don't allow deselection
        if (_selectedIndices.count > 1) {
            [_selectedIndices removeObject:indexNumber];
        } else {
            // If only one option is selected, keep it selected
            [tableView reloadData];
            return;
        }
    } else {
        [_selectedIndices addObject:indexNumber];
    }

    // Update options
    ActivationMethod newOptions = 0;
    NSArray *validValues = [self.specifier propertyForKey:@"validValues"];
    for (NSNumber *index in _selectedIndices) {
        NSNumber *value = validValues[[index integerValue]];
        newOptions |= [value integerValue];
    }

    _currentOptions = newOptions;
    [self setPreferenceValue:@(newOptions) specifier:self.specifier];
    [(PSListController *)self.parentController reloadSpecifiers];

    // Post notification
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyPreferencesReload, nil, nil, YES);

    [tableView reloadData];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];

    // Set selection mark
    if ([_selectedIndices containsObject:@(indexPath.row)]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

@end
