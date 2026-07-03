//
//  KayokoSpringBoardHooks.m
//  Kayoko
//

#define CHUseSubstrate

#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>

#import "KayokoCoreRuntime.h"
#import "KayokoSpringBoardHooks.h"

CHDeclareClass(UIStatusBarWindow);
CHDeclareClass(SpringBoard);
CHDeclareClass(UIViewController);
CHDeclareClass(SBCoverSheetPrimarySlidingViewController);
CHDeclareClass(SBHIconManager);
CHDeclareClass(SBSpotlightMultiplexingViewController);
CHDeclareClass(SBHLibrarySearchController);
CHDeclareClass(SBMainDisplaySystemGestureManager);
CHDeclareClass(SBMainSwitcherViewController);
CHDeclareClass(SBMainSwitcherControllerCoordinator);

@interface UIStatusBarWindow : UIWindow
@end

@interface SpringBoard : UIApplication
- (void)applicationDidFinishLaunching:(id)application;
@end

@interface SBCoverSheetPrimarySlidingViewController : UIViewController
@end

@interface SBMainSwitcherViewController : UIViewController
- (BOOL)isMainSwitcherVisible;
@end

@interface SBMainSwitcherControllerCoordinator : NSObject
- (BOOL)isAnySwitcherVisible;
@end

@interface SBHIconManager : NSObject
- (void)rootFolderControllerViewWillAppear:(id)controller;
@end

@interface SBSpotlightMultiplexingViewController : UIViewController
@end

@interface SBHLibrarySearchController : NSObject
- (void)_willDismissSearchAnimated:(BOOL)animated;
- (void)_willPresentSearchAnimated:(BOOL)animated;
- (void)_didDismissSearch;
- (void)_didPresentSearch;
- (void)beginEditingForSearchField;
- (void)endEditingForSearchField;
- (BOOL)isSearchFieldEditing;
@end

@interface SBMainDisplaySystemGestureManager : NSObject
- (BOOL)_isGestureWithTypeAllowed:(NSInteger)type;
@end

static const NSInteger kKayokoSystemGestureTypeCoverSheet = 0x1;
static const NSInteger kKayokoSystemGestureTypeControlCenter = 0x6;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSpringBoardHookInstaller ()

+ (void)hideForHomeScreenIfVisible:(id)controller;
+ (void)hideForLayoutStateTransition;
+ (void)hideForAppSwitcherIfVisible:(id)switcher;

@end

NS_ASSUME_NONNULL_END

CHOptimizedMethod1(self, id, UIStatusBarWindow, initWithFrame, CGRect, frame) {
    UIStatusBarWindow *window = CHSuper1(UIStatusBarWindow, initWithFrame, frame);
    [[KayokoCoreRuntime sharedRuntime] installPanelInStatusBarWindow:window];
    return window;
}

CHOptimizedMethod1(self, void, SpringBoard, applicationDidFinishLaunching, id, application) {
    CHSuper1(SpringBoard, applicationDidFinishLaunching, application);
    [[KayokoCoreRuntime sharedRuntime] preloadInitialHistory];
}

CHOptimizedMethod1(self, void, UIViewController, viewWillAppear, BOOL, animated) {
    CHSuper1(UIViewController, viewWillAppear, animated);
    [KayokoSpringBoardHookInstaller hideForHomeScreenIfVisible:self];
}

CHOptimizedMethod1(self, void, SBHIconManager, rootFolderControllerViewWillAppear, id, controller) {
    CHSuper1(SBHIconManager, rootFolderControllerViewWillAppear, controller);
    [[KayokoCoreRuntime sharedRuntime] hide];
}

CHOptimizedMethod1(self, void, SBCoverSheetPrimarySlidingViewController, _endTransitionToAppeared, BOOL, appeared) {
    CHSuper1(SBCoverSheetPrimarySlidingViewController, _endTransitionToAppeared, appeared);
    if (appeared) {
        [[KayokoCoreRuntime sharedRuntime] hideImmediately];
    }
}

CHOptimizedMethod1(self, void, SBSpotlightMultiplexingViewController, viewWillDisappear, BOOL, animated) {
    CHSuper1(SBSpotlightMultiplexingViewController, viewWillDisappear, animated);
    if (animated) {
        [[KayokoCoreRuntime sharedRuntime] hide];
    } else {
        [[KayokoCoreRuntime sharedRuntime] hideImmediately];
    }
}

CHOptimizedMethod1(self, void, SBHLibrarySearchController, _willDismissSearchAnimated, BOOL, animated) {
    CHSuper1(SBHLibrarySearchController, _willDismissSearchAnimated, animated);
    if (animated) {
        [[KayokoCoreRuntime sharedRuntime] hide];
    } else {
        [[KayokoCoreRuntime sharedRuntime] hideImmediately];
    }
}

CHOptimizedMethod1(self, BOOL, SBMainDisplaySystemGestureManager, _isGestureWithTypeAllowed, NSInteger, type) {
    if ((type == kKayokoSystemGestureTypeCoverSheet || type == kKayokoSystemGestureTypeControlCenter) &&
        [[KayokoCoreRuntime sharedRuntime] fullscreenSearchActive]) {
        return NO;
    }

    return CHSuper1(SBMainDisplaySystemGestureManager, _isGestureWithTypeAllowed, type);
}

CHOptimizedMethod2(self, void, SBMainSwitcherViewController, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidBeginWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherViewController, layoutStateTransitionCoordinator, coordinator,
             transitionDidBeginWithTransitionContext, context);
    [KayokoSpringBoardHookInstaller hideForLayoutStateTransition];
}

CHOptimizedMethod2(self, void, SBMainSwitcherViewController, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidEndWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherViewController, layoutStateTransitionCoordinator, coordinator,
             transitionDidEndWithTransitionContext, context);
    [KayokoSpringBoardHookInstaller hideForAppSwitcherIfVisible:self];
}

CHOptimizedMethod2(self, void, SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidBeginWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, coordinator,
             transitionDidBeginWithTransitionContext, context);
    [KayokoSpringBoardHookInstaller hideForLayoutStateTransition];
}

CHOptimizedMethod2(self, void, SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidEndWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, coordinator,
             transitionDidEndWithTransitionContext, context);
    [KayokoSpringBoardHookInstaller hideForAppSwitcherIfVisible:self];
}

@implementation KayokoSpringBoardHookInstaller

+ (BOOL)isHomeScreenController:(id)controller {
    static Class iconControllerClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      iconControllerClass = NSClassFromString(@"SBIconController");
    });
    return iconControllerClass && [controller isKindOfClass:iconControllerClass];
}

+ (void)hideForHomeScreenIfVisible:(id)controller {
    if (![self isHomeScreenController:controller]) {
        return;
    }

    [[KayokoCoreRuntime sharedRuntime] hide];
}

+ (void)hideForLayoutStateTransition {
    KayokoCoreRuntime *runtime = [KayokoCoreRuntime sharedRuntime];
    if (![runtime panelVisible]) {
        return;
    }

    [runtime hide];
}

+ (void)hideForAppSwitcherIfVisible:(id)switcher {
    KayokoCoreRuntime *runtime = [KayokoCoreRuntime sharedRuntime];
    if (![runtime panelVisible]) {
        return;
    }

    BOOL switcherVisible = NO;
    if ([switcher respondsToSelector:@selector(isMainSwitcherVisible)]) {
        switcherVisible = [(SBMainSwitcherViewController *)switcher isMainSwitcherVisible];
    } else if ([switcher respondsToSelector:@selector(isAnySwitcherVisible)]) {
        switcherVisible = [(SBMainSwitcherControllerCoordinator *)switcher isAnySwitcherVisible];
    }

    if (switcherVisible) {
        [runtime hide];
    }
}

+ (void)installStatusBarHooks {
    Class statusBarWindowCls = objc_getClass("UIStatusBarWindow");
    if (@available(iOS 17, *)) {
        statusBarWindowCls = objc_getClass("SBStatusBarWindow");
    }

    CHLoadClass_(&UIStatusBarWindow$, statusBarWindowCls);
    CHHook1(UIStatusBarWindow, initWithFrame);
}

+ (void)installHomeScreenHooks {
    Class iconControllerClass = NSClassFromString(@"SBIconController");
    CHLoadClass(UIViewController);
    SEL viewWillAppearSelector = @selector(viewWillAppear:);
    if (iconControllerClass && [CHClass(UIViewController) instancesRespondToSelector:viewWillAppearSelector]) {
        CHHook1(UIViewController, viewWillAppear);
    }

    Class iconManagerClass = NSClassFromString(@"SBHIconManager");
    CHLoadClass_(&SBHIconManager$, iconManagerClass);
    SEL rootFolderWillAppearSelector = @selector(rootFolderControllerViewWillAppear:);
    if ([iconManagerClass instancesRespondToSelector:rootFolderWillAppearSelector]) {
        CHHook1(SBHIconManager, rootFolderControllerViewWillAppear);
    }
}

+ (void)installLockScreenTransitionHooks {
    Class coverSheetClass = NSClassFromString(@"SBCoverSheetPrimarySlidingViewController");
    CHLoadClass_(&SBCoverSheetPrimarySlidingViewController$, coverSheetClass);
    SEL transitionEndSelector = @selector(_endTransitionToAppeared:);
    if ([coverSheetClass instancesRespondToSelector:transitionEndSelector]) {
        CHHook1(SBCoverSheetPrimarySlidingViewController, _endTransitionToAppeared);
    }
}

+ (void)installSpotlightHooks {
    Class spotlightClass = NSClassFromString(@"SBSpotlightMultiplexingViewController");
    CHLoadClass_(&SBSpotlightMultiplexingViewController$, spotlightClass);
    SEL viewWillDisappearSelector = @selector(viewWillDisappear:);
    if ([spotlightClass instancesRespondToSelector:viewWillDisappearSelector]) {
        CHHook1(SBSpotlightMultiplexingViewController, viewWillDisappear);
    }
}

+ (void)installLibrarySearchHooks {
    Class librarySearchControllerClass = NSClassFromString(@"SBHLibrarySearchController");
    CHLoadClass_(&SBHLibrarySearchController$, librarySearchControllerClass);
    SEL willDismissSearchSelector = @selector(_willDismissSearchAnimated:);
    if ([librarySearchControllerClass instancesRespondToSelector:willDismissSearchSelector]) {
        CHHook1(SBHLibrarySearchController, _willDismissSearchAnimated);
    }
}

+ (void)installSystemGestureHooks {
    Class gestureManagerClass = NSClassFromString(@"SBMainDisplaySystemGestureManager");
    CHLoadClass_(&SBMainDisplaySystemGestureManager$, gestureManagerClass);
    SEL gestureAllowedSelector = @selector(_isGestureWithTypeAllowed:);
    if ([gestureManagerClass instancesRespondToSelector:gestureAllowedSelector]) {
        CHHook1(SBMainDisplaySystemGestureManager, _isGestureWithTypeAllowed);
    }
}

+ (void)installAppSwitcherHooks {
    SEL transitionBeginSelector = @selector(layoutStateTransitionCoordinator:transitionDidBeginWithTransitionContext:);
    SEL transitionEndSelector = @selector(layoutStateTransitionCoordinator:transitionDidEndWithTransitionContext:);

    Class switcherViewControllerClass = NSClassFromString(@"SBMainSwitcherViewController");
    CHLoadClass_(&SBMainSwitcherViewController$, switcherViewControllerClass);
    if ([switcherViewControllerClass instancesRespondToSelector:transitionBeginSelector]) {
        CHHook2(SBMainSwitcherViewController, layoutStateTransitionCoordinator,
                transitionDidBeginWithTransitionContext);
    }
    if ([switcherViewControllerClass instancesRespondToSelector:transitionEndSelector]) {
        CHHook2(SBMainSwitcherViewController, layoutStateTransitionCoordinator, transitionDidEndWithTransitionContext);
    }

    Class switcherCoordinatorClass = NSClassFromString(@"SBMainSwitcherControllerCoordinator");
    CHLoadClass_(&SBMainSwitcherControllerCoordinator$, switcherCoordinatorClass);
    if ([switcherCoordinatorClass instancesRespondToSelector:transitionBeginSelector]) {
        CHHook2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator,
                transitionDidBeginWithTransitionContext);
    }
    if ([switcherCoordinatorClass instancesRespondToSelector:transitionEndSelector]) {
        CHHook2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator,
                transitionDidEndWithTransitionContext);
    }
}

+ (void)installHooks {
    [self installStatusBarHooks];
    CHLoadClass_(&SpringBoard$, NSClassFromString(@"SpringBoard"));
    CHHook1(SpringBoard, applicationDidFinishLaunching);
    [self installHomeScreenHooks];
    [self installAppSwitcherHooks];
    [self installLockScreenTransitionHooks];
    [self installSpotlightHooks];
    [self installLibrarySearchHooks];
    [self installSystemGestureHooks];
}

@end
