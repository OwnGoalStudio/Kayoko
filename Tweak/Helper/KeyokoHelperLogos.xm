#import <HBLog.h>
#import <substrate.h>

@import Foundation;
@import UIKit;

#import "KayokoHelper.h"
#import "NotificationKeys.h"
#import "PasteboardManager.h"

#define ITEM_ID "codes.aurora.kayoko.globe"

@interface UIInputSwitcherItem : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *localizedTitle;
@property(nonatomic, copy) NSString *localizedSubtitle;
@property(nonatomic, strong) UIFont *titleFont;
@property(nonatomic, strong) UIFont *subtitleFont;
@property(assign, nonatomic) BOOL usesDeviceLanguage;
@property(nonatomic, strong) UISwitch *switchControl;
@property(nonatomic, copy) id switchIsOnBlock;
@property(nonatomic, copy) id switchToggleBlock;
- (instancetype)initWithIdentifier:(NSString *)identifier;
@end

%group KayokoActivationGlobe

%hook UIInputSwitcherView

- (void)_reloadInputSwitcherItems {
    %orig;
    BOOL isForDictation = MSHookIvar<BOOL>(self, "m_isForDictation");
    if (isForDictation) {
        return;
    }
    NSArray *items = MSHookIvar<NSArray *>(self, "m_inputSwitcherItems");
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:items];
    UIInputSwitcherItem *item = [[%c(UIInputSwitcherItem) alloc] initWithIdentifier:@ITEM_ID];
    [item setLocalizedTitle:[[PasteboardManager localizationBundle] localizedStringForKey:@"Kayoko"
                                                                                    value:nil
                                                                                    table:@"Tweak"]];
    if (item) {
        [newItems insertObject:item atIndex:newItems.count - 1];
    }
    MSHookIvar<NSArray *>(self, "m_inputSwitcherItems") = newItems;
}

- (void)didSelectItemAtIndex:(unsigned long long)index {
    NSArray *items = MSHookIvar<NSArray *>(self, "m_inputSwitcherItems");
    UIInputSwitcherItem *item = items[index];
    if ([item.identifier isEqualToString:@ITEM_ID]) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
    }
    %orig;
}

%end

%end // KayokoActivationGlobe

%group KayokoActivationDictation

%hook UIKeyboardDockItem

- (id)initWithImageName:(id)arg1 identifier:(id)arg2 {
    if ([arg1 isEqualToString:@"mic"]) {
        if (@available(iOS 16, *)) {
            arg1 = @"list.clipboard";
        } else {
            arg1 = @"doc.on.clipboard";
        }
    }
    return %orig;
}

- (void)setImageName:(NSString *)arg1 {
    if ([arg1 isEqualToString:@"mic"]) {
        if (@available(iOS 16, *)) {
            arg1 = @"list.clipboard";
        } else {
            arg1 = @"doc.on.clipboard";
        }
    }
    %orig;
}

%end

%hook UISystemKeyboardDockController

- (void)dictationItemButtonWasPressed:(id)arg1 withEvent:(id)arg2 isRunningButton:(BOOL)arg3 {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
}

%end

%end // KayokoActivationDictation


void EnableKayokoActivationGlobe(void) {
    %init(KayokoActivationGlobe);
}

void EnableKayokoActivationDictation(void) {
    %init(KayokoActivationDictation);
}