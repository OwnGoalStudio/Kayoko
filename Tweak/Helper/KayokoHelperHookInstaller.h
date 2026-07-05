//
//  KayokoHelperHookInstaller.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHelperHookInstaller : NSObject
+ (void)installApplicationHooksWithActivationMethod:(NSUInteger)activationMethod;
+ (void)installSpringBoardActivationHooksWithActivationMethod:(NSUInteger)activationMethod;
+ (void)installKeyboardExtensionHooksWithActivationMethod:(NSUInteger)activationMethod
                                     spotlightSwipeUpOnly:(BOOL)spotlightSwipeUpOnly;
@end

@interface KayokoHelperHookInstaller (PredictionBar)
+ (void)installPredictionBarHooks;
@end

@interface KayokoHelperHookInstaller (CalloutMenu)
+ (void)installCalloutBarHooks;
@end

@interface KayokoHelperHookInstaller (InputSwitcher)
+ (void)installInputSwitcherHooks;
@end

@interface KayokoHelperHookInstaller (Dictation)
+ (void)installDictationHooks;
@end

@interface KayokoHelperHookInstaller (SwipeUp)
+ (void)installSwipeUpHooks;
+ (void)installKeyboardExtensionSwipeUpHooksForSpotlightOnly:(BOOL)spotlightOnly;
@end

NS_ASSUME_NONNULL_END
