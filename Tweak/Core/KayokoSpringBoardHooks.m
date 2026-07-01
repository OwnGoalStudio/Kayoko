//
//  KayokoSpringBoardHooks.m
//  Kayoko
//

#define CHUseSubstrate

#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>

#import "KayokoCoreRuntime.h"

CHDeclareClass(UIStatusBarWindow);
CHDeclareClass(SpringBoard);
CHDeclareClass(UIViewController);
CHDeclareClass(SBCoverSheetPrimarySlidingViewController);
CHDeclareClass(SBHIconManager);
CHDeclareClass(SBSpotlightMultiplexingViewController);
CHDeclareClass(SBMainDisplaySystemGestureManager);
CHDeclareClass(SBMainSwitcherViewController);
CHDeclareClass(SBMainSwitcherControllerCoordinator);

NS_ASSUME_NONNULL_BEGIN

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

@interface SBMainDisplaySystemGestureManager : NSObject
- (BOOL)_isGestureWithTypeAllowed:(NSInteger)type;
@end

NS_ASSUME_NONNULL_END

static const NSInteger kKayokoSystemGestureTypeCoverSheet = 0x1;
static const NSInteger kKayokoSystemGestureTypeControlCenter = 0x6;

CHOptimizedMethod1(self, id, UIStatusBarWindow, initWithFrame, CGRect, frame) {
    UIStatusBarWindow *window = CHSuper1(UIStatusBarWindow, initWithFrame, frame);
    KayokoCoreInstallPanelInStatusBarWindow(window);
    return window;
}

CHOptimizedMethod1(self, void, SpringBoard, applicationDidFinishLaunching, id, application) {
    CHSuper1(SpringBoard, applicationDidFinishLaunching, application);
    KayokoCorePreloadInitialHistory();
}

static BOOL kayokoIsHomeScreenController(id controller) {
    static Class iconControllerClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      iconControllerClass = NSClassFromString(@"SBIconController");
    });
    return iconControllerClass && [controller isKindOfClass:iconControllerClass];
}

static void kayokoHideForHomeScreenIfVisible(id controller) {
    if (!kayokoIsHomeScreenController(controller)) {
        return;
    }

    KayokoCoreHide();
}

CHOptimizedMethod1(self, void, UIViewController, viewWillAppear, BOOL, animated) {
    CHSuper1(UIViewController, viewWillAppear, animated);
    kayokoHideForHomeScreenIfVisible(self);
}

CHOptimizedMethod1(self, void, SBHIconManager, rootFolderControllerViewWillAppear, id, controller) {
    CHSuper1(SBHIconManager, rootFolderControllerViewWillAppear, controller);
    KayokoCoreHide();
}

CHOptimizedMethod1(self, void, SBCoverSheetPrimarySlidingViewController, _endTransitionToAppeared, BOOL, appeared) {
    CHSuper1(SBCoverSheetPrimarySlidingViewController, _endTransitionToAppeared, appeared);
    if (appeared) {
        KayokoCoreHideImmediately();
    }
}

CHOptimizedMethod1(self, void, SBSpotlightMultiplexingViewController, viewWillDisappear, BOOL, animated) {
    CHSuper1(SBSpotlightMultiplexingViewController, viewWillDisappear, animated);
    if (animated) {
        KayokoCoreHide();
    } else {
        KayokoCoreHideImmediately();
    }
}

CHOptimizedMethod1(self, BOOL, SBMainDisplaySystemGestureManager, _isGestureWithTypeAllowed, NSInteger, type) {
    if ((type == kKayokoSystemGestureTypeCoverSheet || type == kKayokoSystemGestureTypeControlCenter) &&
        KayokoCoreFullscreenSearchActive()) {
        return NO;
    }

    return CHSuper1(SBMainDisplaySystemGestureManager, _isGestureWithTypeAllowed, type);
}

static void kayokoHideForLayoutStateTransition(void) {
    if (!KayokoCorePanelVisible()) {
        return;
    }

    KayokoCoreHide();
}

static void kayokoHideForAppSwitcherIfVisible(id switcher) {
    if (!KayokoCorePanelVisible()) {
        return;
    }

    BOOL switcherVisible = NO;
    if ([switcher respondsToSelector:@selector(isMainSwitcherVisible)]) {
        switcherVisible = [(SBMainSwitcherViewController *)switcher isMainSwitcherVisible];
    } else if ([switcher respondsToSelector:@selector(isAnySwitcherVisible)]) {
        switcherVisible = [(SBMainSwitcherControllerCoordinator *)switcher isAnySwitcherVisible];
    }

    if (switcherVisible) {
        KayokoCoreHide();
    }
}

CHOptimizedMethod2(self, void, SBMainSwitcherViewController, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidBeginWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherViewController, layoutStateTransitionCoordinator, coordinator,
             transitionDidBeginWithTransitionContext, context);
    kayokoHideForLayoutStateTransition();
}

CHOptimizedMethod2(self, void, SBMainSwitcherViewController, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidEndWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherViewController, layoutStateTransitionCoordinator, coordinator,
             transitionDidEndWithTransitionContext, context);
    kayokoHideForAppSwitcherIfVisible(self);
}

CHOptimizedMethod2(self, void, SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidBeginWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, coordinator,
             transitionDidBeginWithTransitionContext, context);
    kayokoHideForLayoutStateTransition();
}

CHOptimizedMethod2(self, void, SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidEndWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, coordinator,
             transitionDidEndWithTransitionContext, context);
    kayokoHideForAppSwitcherIfVisible(self);
}

static void kayokoInstallStatusBarHooks(void) {
    Class statusBarWindowCls = objc_getClass("UIStatusBarWindow");
    if (@available(iOS 17, *)) {
        statusBarWindowCls = objc_getClass("SBStatusBarWindow");
    }

    CHLoadClass_(&UIStatusBarWindow$, statusBarWindowCls);
    CHHook1(UIStatusBarWindow, initWithFrame);
}

static void kayokoInstallHomeScreenHooks(void) {
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

static void kayokoInstallLockScreenTransitionHooks(void) {
    Class coverSheetClass = NSClassFromString(@"SBCoverSheetPrimarySlidingViewController");
    CHLoadClass_(&SBCoverSheetPrimarySlidingViewController$, coverSheetClass);
    SEL transitionEndSelector = @selector(_endTransitionToAppeared:);
    if ([coverSheetClass instancesRespondToSelector:transitionEndSelector]) {
        CHHook1(SBCoverSheetPrimarySlidingViewController, _endTransitionToAppeared);
    }
}

static void kayokoInstallSpotlightHooks(void) {
    Class spotlightClass = NSClassFromString(@"SBSpotlightMultiplexingViewController");
    CHLoadClass_(&SBSpotlightMultiplexingViewController$, spotlightClass);
    SEL viewWillDisappearSelector = @selector(viewWillDisappear:);
    if ([spotlightClass instancesRespondToSelector:viewWillDisappearSelector]) {
        CHHook1(SBSpotlightMultiplexingViewController, viewWillDisappear);
    }
}

static void kayokoInstallSystemGestureHooks(void) {
    Class gestureManagerClass = NSClassFromString(@"SBMainDisplaySystemGestureManager");
    CHLoadClass_(&SBMainDisplaySystemGestureManager$, gestureManagerClass);
    SEL gestureAllowedSelector = @selector(_isGestureWithTypeAllowed:);
    if ([gestureManagerClass instancesRespondToSelector:gestureAllowedSelector]) {
        CHHook1(SBMainDisplaySystemGestureManager, _isGestureWithTypeAllowed);
    }
}

static void kayokoInstallAppSwitcherHooks(void) {
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

void KayokoInstallSpringBoardHooks(void) {
    kayokoInstallStatusBarHooks();
    CHLoadClass_(&SpringBoard$, NSClassFromString(@"SpringBoard"));
    CHHook1(SpringBoard, applicationDidFinishLaunching);
    kayokoInstallHomeScreenHooks();
    kayokoInstallAppSwitcherHooks();
    kayokoInstallLockScreenTransitionHooks();
    kayokoInstallSpotlightHooks();
    kayokoInstallSystemGestureHooks();
}
