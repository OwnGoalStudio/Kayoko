//
//  KayokoMenu.m
//  Kayoko
//
//  Created by Lessica
//

#import "KayokoMenu.h"
#import "KayokoHelper.h"

NSString *KayokoAppleMenuIdentifier(void) { return @"com.apple.menu.standard-edit"; }

UIMenuItem *KayokoMenuItem(void) {
    static UIMenuItem *menuItem = nil;
    if (!menuItem) {
        menuItem = [[UIMenuItem alloc] initWithTitle:kayokoMenuName
                                              action:NSSelectorFromString(kayokoSelectorName)];
    }
    return menuItem;
}

UICommand *KayokoMenuItemUICommand(void) {
    static UICommand *command = nil;
    if (!command) {
        command = [UICommand commandWithTitle:kayokoMenuName
                                        image:nil
                                       action:NSSelectorFromString(kayokoSelectorName)
                                 propertyList:nil];
    }
    return command;
}

BOOL KayokoMenuItemIsWritingTool(id input) {
    if ([input isKindOfClass:[UIMenu class]]) {
        UIMenu *menu = (UIMenu *)input;
        if ([menu.title isEqualToString:KayokoMenuItem().title]) {
            return YES;
        }
    }
    if ([input isKindOfClass:[UIAction class]]) {
        UIAction *action = (UIAction *)input;
        if ([action.title isEqualToString:KayokoMenuItem().title]) {
            return YES;
        }
    }
    if ([input isKindOfClass:[UICommand class]]) {
        UICommand *command = (UICommand *)input;
        NSString *selectorName = NSStringFromSelector(command.action);
        if ([selectorName isEqualToString:kayokoSelectorName]) {
            return YES;
        }
    }
    return NO;
}
