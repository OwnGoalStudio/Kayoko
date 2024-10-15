#import <HBLog.h>
#import <substrate.h>

@import Foundation;
@import UIKit;

#import "KayokoCore.h"
#import "NotificationKeys.h"

@interface SBUserNotificationAlert : NSObject
- (void)_setActivated:(BOOL)activated;
- (void)_sendResponseAndCleanUp:(BOOL)cleanup;
@end

%group DruidUI

%hook DRPasteAnnouncer

- (void)announceDeniedPaste {
    if (kayokoPrefsDisablePasteTips) return;
    %orig;
}

- (void)announcePaste:(id)arg1 {
    if (kayokoPrefsDisablePasteTips) return;
    %orig;
}

%end

%end

%group NoPasteAlerts16

%hook SBAlertItem

+ (void)activateAlertItem:(id)arg1 {
    id alertItem = arg1;
    if ([alertItem isKindOfClass:NSClassFromString(@"SBUserNotificationAlert")]) {
        NSString *str = MSHookIvar<NSString *>(alertItem, "_alertSource");
        if ([str isEqualToString:@"pasted"]) {
            [alertItem _setActivated:NO];
            if ([alertItem respondsToSelector:@selector(_sendResponseAndCleanUp:)]) {
                [alertItem _sendResponseAndCleanUp:YES];
            }
            return;
        }
    }
    %orig(alertItem);
}

%end

%end

void EnableKayokoDisablePasteTips(void) {
    %init(DruidUI);
    if (@available(iOS 16, *)) {
        %init(NoPasteAlerts16);
    }
}