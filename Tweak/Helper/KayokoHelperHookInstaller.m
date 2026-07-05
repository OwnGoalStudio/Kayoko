//
//  KayokoHelperHookInstaller.m
//  Kayoko
//

#import "KayokoHelperHookInstaller.h"
#import "KayokoPreferenceKeys.h"

@implementation KayokoHelperHookInstaller

+ (void)installActivationHooksWithActivationMethod:(NSUInteger)activationMethod {
    if (activationMethod & kActivationMethodPredictionBar) {
        [self installPredictionBarHooks];
    }
    if (activationMethod & kActivationMethodDictationKey) {
        [self installDictationHooks];
    }
    if (activationMethod & kActivationMethodInputSwitcher) {
        [self installInputSwitcherHooks];
    }
    if (activationMethod & kActivationMethodSwipeUp) {
        [self installSwipeUpHooks];
    }
    if (activationMethod & kActivationMethodCalloutBar) {
        [self installCalloutBarHooks];
    }
}

+ (void)installApplicationHooksWithActivationMethod:(NSUInteger)activationMethod {
    [self installActivationHooksWithActivationMethod:activationMethod];
}

+ (void)installSpringBoardActivationHooksWithActivationMethod:(NSUInteger)activationMethod {
    [self installActivationHooksWithActivationMethod:activationMethod];
}

+ (void)installKeyboardExtensionHooksWithActivationMethod:(NSUInteger)activationMethod
                                     spotlightSwipeUpOnly:(BOOL)spotlightSwipeUpOnly {
    if (activationMethod & kActivationMethodSwipeUp) {
        [self installKeyboardExtensionSwipeUpHooksForSpotlightOnly:NO];
    } else if (spotlightSwipeUpOnly) {
        [self installKeyboardExtensionSwipeUpHooksForSpotlightOnly:YES];
    }
}

@end
