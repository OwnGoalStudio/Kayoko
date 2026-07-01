//
//  KayokoHelper.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoHelper.h"

#import "PreferenceKeys.h"

static BOOL kayokoHelperIsApplicationProcess(void) {
    NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
    NSUInteger count = [args count];
    if (count == 0) {
        return NO;
    }

    NSString *executablePath = args[0];
    if (executablePath.length == 0) {
        return NO;
    }

    BOOL isApplication = [executablePath rangeOfString:@"/Application/"].location != NSNotFound ||
                         [executablePath rangeOfString:@"/Applications/"].location != NSNotFound;
    if (!isApplication) {
        return NO;
    }

    NSString *processName = [executablePath lastPathComponent];
    BOOL isFileProvider = [[processName lowercaseString] rangeOfString:@"fileprovider"].location != NSNotFound;
    if (isFileProvider) {
        return NO;
    }

    BOOL isProtectedApplication = [processName isEqualToString:@"AdSheet"] ||
                                  [processName isEqualToString:@"CoreAuthUI"] ||
                                  [processName isEqualToString:@"InCallService"] ||
                                  [processName isEqualToString:@"MessagesNotificationViewService"];
    if (isProtectedApplication) {
        return NO;
    }

    BOOL isApplicationExtension = [executablePath rangeOfString:@".appex/"].location != NSNotFound;
    return !isApplicationExtension;
}

static void kayokoHelperInstallApplicationHooks(void) {
    NSUInteger activationMethod = KayokoHelperActivationMethod();
    if (activationMethod & kActivationMethodPredictionBar) {
        EnableKayokoPredictionBar();
    }
    if (activationMethod & kActivationMethodDictationKey) {
        EnableKayokoActivationDictation();
    }
    if (activationMethod & kActivationMethodInputSwitcher) {
        EnableKayokoActivationGlobe();
    }
    if (activationMethod & kActivationMethodSwipeUp) {
        EnableKayokoActivationSwipeUp();
    }
    if (activationMethod & kActivationMethodCalloutBar) {
        EnableKayokoCalloutBar();
    }

    KayokoHelperInstallRuntimeHooks();
    KayokoHelperInstallRuntimeObservers();
}

__attribute((constructor)) static void initialize() {
    KayokoHelperLoadPreferences();

    if (!KayokoHelperEnabled()) {
        return;
    }

    if (KayokoHelperIsKeyboardExtensionProcess()) {
        if (KayokoHelperActivationMethod() & kActivationMethodSwipeUp) {
            EnableKayokoActivationSwipeUpForKeyboardExtension();
        }
        return;
    }

    if (!kayokoHelperIsApplicationProcess()) {
        return;
    }

    kayokoHelperInstallApplicationHooks();
}
