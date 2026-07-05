//
//  KayokoHelper.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoHelperConfiguration.h"
#import "KayokoHelperHookInstaller.h"
#import "KayokoHelperProcessContext.h"
#import "KayokoHelperRuntime.h"

__attribute((constructor)) static void initialize() {
    KayokoHelperConfiguration *configuration = [KayokoHelperConfiguration currentConfiguration];
    if (!configuration.isEnabled) {
        return;
    }

    KayokoHelperProcessContext *context = [KayokoHelperProcessContext currentContext];
    NSUInteger helperActivationMethod = configuration.activationMethod;

    BOOL systemGestureRecognizerMode = configuration.gestureRecognizerMode == kKayokoGestureRecognizerModeSystem;
    BOOL swipeUpEnabled = (configuration.activationMethod & kActivationMethodSwipeUp) != 0;
    BOOL spotlightProcess = [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.Spotlight"];
    if (systemGestureRecognizerMode && !spotlightProcess) {
        helperActivationMethod &= ~kActivationMethodSwipeUp;
    }

    switch (context.kind) {
    case KayokoHelperProcessKindKeyboardExtension:
        [KayokoHelperHookInstaller
            installKeyboardExtensionHooksWithActivationMethod:helperActivationMethod
                                         spotlightSwipeUpOnly:(systemGestureRecognizerMode && swipeUpEnabled)];
        return;
    case KayokoHelperProcessKindSpringBoard:
        [[KayokoHelperRuntime sharedRuntime] installSpringBoardRuntimeWithConfiguration:configuration];
        [KayokoHelperHookInstaller installSpringBoardActivationHooksWithActivationMethod:helperActivationMethod];
        return;
    case KayokoHelperProcessKindApplication:
        [KayokoHelperHookInstaller installApplicationHooksWithActivationMethod:helperActivationMethod];
        [[KayokoHelperRuntime sharedRuntime] installApplicationRuntimeWithConfiguration:configuration];
        return;
    case KayokoHelperProcessKindUnsupported:
        return;
    }
}
