//
//  KayokoCore.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoCore.h"

#import <CoreFoundation/CoreFoundation.h>

#import "KayokoCoreRuntime.h"
#import "KayokoSpringBoardHooks.h"
#import "NotificationKeys.h"

static void kayokoCoreAddDarwinObserver(CFStringRef name, CFNotificationCallback callback) {
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), NULL, callback, name, NULL,
        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
}

static CFStringRef kayokoCoreNotificationName(NSString *name) { return (__bridge CFStringRef)name; }

static BOOL kayokoCoreIsSpringBoardProcess(void) {
    return [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
}

static BOOL kayokoCoreIsDruidOrPastedProcess(void) {
    NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
    NSString *processName = [[NSProcessInfo processInfo] processName];
    NSString *executablePath = [args firstObject];
    return ([executablePath hasPrefix:@"/System/Library/"] || [executablePath hasPrefix:@"/usr/libexec/"]) &&
           ([processName isEqualToString:@"druid"] || [processName isEqualToString:@"pasted"]);
}

static void kayokoCoreInstallSpringBoardRuntime(void) {
    KayokoCoreLoadPreferences();
    if (!KayokoCoreEnabled()) {
        return;
    }

    EnableKayokoDisablePasteTips();
    KayokoInstallSpringBoardHooks();
    KayokoCoreStartLockStateObserver();

    kayokoCoreAddDarwinObserver(CFSTR("com.apple.pasteboard.notify.changed"), (CFNotificationCallback)KayokoCoreCopy);
    kayokoCoreAddDarwinObserver(kayokoCoreNotificationName(kKayokoNotificationKeyCoreShow),
                                (CFNotificationCallback)KayokoCoreShow);
    kayokoCoreAddDarwinObserver(kayokoCoreNotificationName(kKayokoLegacyNotificationKeyCoreShow),
                                (CFNotificationCallback)KayokoCoreShow);
    kayokoCoreAddDarwinObserver(kayokoCoreNotificationName(kKayokoNotificationKeyCoreHide),
                                (CFNotificationCallback)KayokoCoreHide);
    kayokoCoreAddDarwinObserver(kayokoCoreNotificationName(kKayokoLegacyNotificationKeyCoreHide),
                                (CFNotificationCallback)KayokoCoreHide);
    kayokoCoreAddDarwinObserver(kayokoCoreNotificationName(kKayokoNotificationKeyCoreReload),
                                (CFNotificationCallback)KayokoCoreReload);
    kayokoCoreAddDarwinObserver(kayokoCoreNotificationName(kKayokoNotificationKeyPreferencesReload),
                                (CFNotificationCallback)KayokoCoreLoadPreferences);
    kayokoCoreAddDarwinObserver(kayokoCoreNotificationName(kKayokoNotificationKeyPreferencesHeightReload),
                                (CFNotificationCallback)KayokoCoreLoadHeightPreference);
    kayokoCoreAddDarwinObserver(kayokoCoreNotificationName(kKayokoNotificationKeyHelperPaste),
                                (CFNotificationCallback)KayokoCorePaste);
    kayokoCoreAddDarwinObserver(kayokoCoreNotificationName(kKayokoNotificationKeyPasteWillStart),
                                (CFNotificationCallback)KayokoCorePasteWillStart);
}

static void kayokoCoreInstallDruidOrPastedRuntime(void) {
    KayokoCoreLoadPreferences();
    if (!KayokoCoreEnabled()) {
        return;
    }

    EnableKayokoDisablePasteTips();
    kayokoCoreAddDarwinObserver(kayokoCoreNotificationName(kKayokoNotificationKeyPreferencesReload),
                                (CFNotificationCallback)KayokoCoreLoadPreferences);
}

__attribute((constructor)) static void initialize() {
    if (kayokoCoreIsSpringBoardProcess()) {
        kayokoCoreInstallSpringBoardRuntime();
        return;
    }

    if (kayokoCoreIsDruidOrPastedProcess()) {
        kayokoCoreInstallDruidOrPastedRuntime();
        return;
    }
}
