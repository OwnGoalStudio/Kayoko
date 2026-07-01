//
//  KayokoMenu.m
//  Kayoko
//

#import "KayokoMenu.h"

NSString *KayokoAppleMenuIdentifier(void) { return @"com.apple.menu.standard-edit"; }

NSString *KayokoMenuName(void) { return @"Kayoko"; }

NSString *KayokoMenuActionSelectorName(void) { return @"_Kayoko_OpenTools_ab2e39c7"; }

SEL KayokoMenuActionSelector(void) { return NSSelectorFromString(KayokoMenuActionSelectorName()); }

const char *KayokoMenuActionTypeEncoding(void) { return "v@:"; }

UIMenuItem *KayokoMenuItem(void) {
    static UIMenuItem *menuItem = nil;
    if (!menuItem) {
        menuItem = [[UIMenuItem alloc] initWithTitle:KayokoMenuName() action:KayokoMenuActionSelector()];
    }
    return menuItem;
}

UICommand *KayokoMenuItemUICommand(void) {
    static UICommand *command = nil;
    if (!command) {
        command = [UICommand commandWithTitle:KayokoMenuName()
                                        image:nil
                                       action:KayokoMenuActionSelector()
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
        if ([selectorName isEqualToString:KayokoMenuActionSelectorName()]) {
            return YES;
        }
    }
    return NO;
}
