//
//  KayokoPasteTipHooks.m
//  Kayoko
//

#define CHUseSubstrate

#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "KayokoCore.h"
#import "KayokoCoreRuntime.h"

CHDeclareClass(DRPasteAnnouncer);
CHDeclareClass(PBDruidRemotePasteAnnouncer);
CHDeclareClass(PBCFUserNotificationPasteAnnouncer);
CHDeclareClass(SBAlertItem);

typedef void (^KayokoPasteAuthorizationReply)(BOOL allowed);

@interface DRPasteAnnouncer : NSObject
@end

@interface PBDruidRemotePasteAnnouncer : NSObject
@end

@interface PBCFUserNotificationPasteAnnouncer : NSObject
- (void)authorizationDidCompleteWithPasteAllowed:(BOOL)arg1;
- (void)requestAuthorizationForPaste:(id)arg1 replyHandler:(id)arg2;
- (void)announcePaste:(id)arg1 replyHandler:(id)arg2;
@end

@interface SBUserNotificationAlert : NSObject
- (void)_setActivated:(BOOL)activated;
- (void)_sendResponseAndCleanUp:(BOOL)cleanup;
@end

@interface SBAlertItem : NSObject
@end

CHOptimizedMethod0(self, void, DRPasteAnnouncer, announceDeniedPaste) {
    if ([[KayokoCoreRuntime sharedRuntime] pasteTipsDisabled]) {
        return;
    }
    CHSuper0(DRPasteAnnouncer, announceDeniedPaste);
}

CHOptimizedMethod1(self, void, DRPasteAnnouncer, announcePaste, id, arg1) {
    if ([[KayokoCoreRuntime sharedRuntime] pasteTipsDisabled]) {
        return;
    }
    CHSuper1(DRPasteAnnouncer, announcePaste, arg1);
}

CHOptimizedClassMethod0(self, void, PBDruidRemotePasteAnnouncer, announceDeniedPaste) {
    if ([[KayokoCoreRuntime sharedRuntime] pasteTipsDisabled]) {
        return;
    }
    CHSuper0(PBDruidRemotePasteAnnouncer, announceDeniedPaste);
}

CHOptimizedClassMethod1(self, void, PBDruidRemotePasteAnnouncer, announcePaste, id, arg1) {
    if ([[KayokoCoreRuntime sharedRuntime] pasteTipsDisabled]) {
        return;
    }
    CHSuper1(PBDruidRemotePasteAnnouncer, announcePaste, arg1);
}

CHOptimizedClassMethod0(self, void, PBCFUserNotificationPasteAnnouncer, announceDeniedPaste) {
    if ([[KayokoCoreRuntime sharedRuntime] pasteTipsDisabled]) {
        return;
    }
    CHSuper0(PBCFUserNotificationPasteAnnouncer, announceDeniedPaste);
}

CHOptimizedClassMethod1(self, void, PBCFUserNotificationPasteAnnouncer, announcePaste, id, arg1) {
    if ([[KayokoCoreRuntime sharedRuntime] pasteTipsDisabled]) {
        return;
    }
    CHSuper1(PBCFUserNotificationPasteAnnouncer, announcePaste, arg1);
}

CHOptimizedMethod2(self, void, PBCFUserNotificationPasteAnnouncer, requestAuthorizationForPaste, id, arg1, replyHandler,
                   KayokoPasteAuthorizationReply, reply) {
    reply(YES);
    [self authorizationDidCompleteWithPasteAllowed:YES];
}

CHOptimizedMethod2(self, void, PBCFUserNotificationPasteAnnouncer, announcePaste, id, arg1, replyHandler,
                   KayokoPasteAuthorizationReply, reply) {
    reply(YES);
    [self authorizationDidCompleteWithPasteAllowed:YES];
}

CHOptimizedClassMethod1(self, void, SBAlertItem, activateAlertItem, id, arg1) {
    id alertItem = arg1;
    if ([alertItem isKindOfClass:NSClassFromString(@"SBUserNotificationAlert")]) {
        Ivar alertSourceIvar = class_getInstanceVariable(object_getClass(alertItem), "_alertSource");
        NSString *alertSource = alertSourceIvar ? object_getIvar(alertItem, alertSourceIvar) : nil;
        if ([alertSource isEqualToString:@"pasted"]) {
            [alertItem _setActivated:NO];
            if ([alertItem respondsToSelector:@selector(_sendResponseAndCleanUp:)]) {
                [alertItem _sendResponseAndCleanUp:YES];
            }
            return;
        }
    }
    CHSuper1(SBAlertItem, activateAlertItem, alertItem);
}

@implementation KayokoPasteTipHookInstaller

+ (void)installDruidUIHooks {
    CHLoadClass_(&DRPasteAnnouncer$, NSClassFromString(@"DRPasteAnnouncer"));

    CHHook0(DRPasteAnnouncer, announceDeniedPaste);
    CHHook1(DRPasteAnnouncer, announcePaste);
}

+ (void)installPasteboardHooks {
    CHLoadClass_(&PBDruidRemotePasteAnnouncer$, NSClassFromString(@"PBDruidRemotePasteAnnouncer"));
    CHLoadClass_(&PBCFUserNotificationPasteAnnouncer$, NSClassFromString(@"PBCFUserNotificationPasteAnnouncer"));

    CHClassHook0(PBDruidRemotePasteAnnouncer, announceDeniedPaste);
    CHClassHook1(PBDruidRemotePasteAnnouncer, announcePaste);
    CHClassHook0(PBCFUserNotificationPasteAnnouncer, announceDeniedPaste);
    CHClassHook1(PBCFUserNotificationPasteAnnouncer, announcePaste);
    CHHook2(PBCFUserNotificationPasteAnnouncer, requestAuthorizationForPaste, replyHandler);
    CHHook2(PBCFUserNotificationPasteAnnouncer, announcePaste, replyHandler);
}

+ (void)installNoPasteAlerts16Hooks {
    CHLoadClass_(&SBAlertItem$, NSClassFromString(@"SBAlertItem"));

    CHClassHook1(SBAlertItem, activateAlertItem);
}

+ (void)installHooks {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
      [self installDruidUIHooks];
      if (@available(iOS 16, *)) {
          [self installPasteboardHooks];
          [self installNoPasteAlerts16Hooks];
      }
    });
}

@end
