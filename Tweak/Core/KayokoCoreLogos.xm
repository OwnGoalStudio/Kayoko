#import <HBLog.h>
#import <substrate.h>

@import Foundation;
@import UIKit;

#import "KayokoCore.h"
#import "NotificationKeys.h"

@interface PBCFUserNotificationPasteAnnouncer : NSObject
- (void)authorizationDidCompleteWithPasteAllowed:(BOOL)arg1;
- (void)requestAuthorizationForPaste:(id)arg1 replyHandler:(id)arg2;
- (void)announcePaste:(id)arg1 replyHandler:(id)arg2;
@end

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

%hook PBDruidRemotePasteAnnouncer

+ (void)announceDeniedPaste {
    if (kayokoPrefsDisablePasteTips) return;
    %orig;
}

+ (void)announcePaste:(id)arg1 {
    if (kayokoPrefsDisablePasteTips) return;
    %orig;
}

%end

%hook PBCFUserNotificationPasteAnnouncer

+ (void)announceDeniedPaste {
    if (kayokoPrefsDisablePasteTips) return;
    %orig;
}

+ (void)announcePaste:(id)arg1 {
    if (kayokoPrefsDisablePasteTips) return;
    %orig;
}

- (void)requestAuthorizationForPaste:(id)arg1 replyHandler:(void(^)(BOOL))reply {
    reply(YES);
    [self authorizationDidCompleteWithPasteAllowed:YES];
}

- (void)announcePaste:(id)arg1 replyHandler:(void(^)(BOOL))reply {
    reply(YES);
    [self authorizationDidCompleteWithPasteAllowed:YES];
}

%end

%end // DruidUI

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

%end // NoPasteAlerts16

void EnableKayokoDisablePasteTips(void) {
    %init(DruidUI);
    if (@available(iOS 16, *)) {
        %init(NoPasteAlerts16);
    }
}