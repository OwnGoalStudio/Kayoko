//
//  KayokoSpringBoardHooks.m
//  Kayoko
//

#define CHUseSubstrate

#import <CaptainHook/CaptainHook.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "KayokoCoreRuntime.h"
#import "KayokoNotificationKeys.h"
#import "KayokoPreferenceKeys.h"
#import "KayokoSpringBoardHooks.h"
#import "KayokoSwipeUpGestureRecognizer.h"

#include <math.h>

CHDeclareClass(SpringBoard);
CHDeclareClass(UIWindowScene);
CHDeclareClass(UIViewController);
CHDeclareClass(SBCoverSheetPrimarySlidingViewController);
CHDeclareClass(SBHIconManager);
CHDeclareClass(SBSpotlightMultiplexingViewController);
CHDeclareClass(SBHLibrarySearchController);
CHDeclareClass(SBMainDisplaySystemGestureManager);
CHDeclareClass(SBMainSwitcherViewController);
CHDeclareClass(SBMainSwitcherControllerCoordinator);
CHDeclareClass(_UISystemGestureWindow);

@interface SpringBoard : UIApplication
- (void)applicationDidFinishLaunching:(id)application;
- (NSArray<UIKeyCommand *> *)keyCommands;
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

@interface _UISystemGestureWindow : UIWindow
- (UIView *)_systemGestureView;
@end

@interface UIPeripheralHost : NSObject
+ (instancetype)sharedInstance;
+ (NSArray<NSValue *> *)allVisiblePeripheralFrames;
- (BOOL)isOnScreen;
@end

static const NSInteger kKayokoSystemGestureTypeCoverSheet = 0x1;
static const NSInteger kKayokoSystemGestureTypeControlCenter = 0x6;
static CGFloat const kKayokoSystemKeyboardFrameEdgeTolerance = 1.0;
static NSString *const kKayokoExternalKeyboardDiscoverabilityTitle = @"Kayoko";

static char kayokoSystemSwipeUpGestureRecognizerKey;
static char kayokoSystemSwipeUpGestureHandlerKey;

static void kayokoHandleExternalKeyboardShortcut(id self, SEL _cmd, UIKeyCommand *command) {
    (void)self;
    (void)_cmd;
    (void)command;
    KayokoCoreRuntime *runtime = [KayokoCoreRuntime sharedRuntime];
    NSString *notificationName =
        [runtime panelVisible] ? kKayokoNotificationKeyCoreHide : kKayokoNotificationKeyCoreShow;
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)notificationName, nil, nil, YES);
}

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSpringBoardHookInstaller ()

+ (BOOL)isStatusBarWindow:(UIWindow *)window;
+ (void)hideForHomeScreenIfVisible:(id)controller;
+ (void)hideForLayoutStateTransition;
+ (void)hideForAppSwitcherIfVisible:(id)switcher;
+ (void)ensureSystemSwipeUpGestureRecognizerForWindow:(_UISystemGestureWindow *)window;
+ (void)installSystemSwipeUpHooks;

@end

NS_ASSUME_NONNULL_END

static CGRect kayokoVisibleKeyboardFrame(void) {
    Class hostClass = NSClassFromString(@"UIPeripheralHost");
    if (![hostClass respondsToSelector:@selector(sharedInstance)] ||
        ![hostClass respondsToSelector:@selector(allVisiblePeripheralFrames)]) {
        return CGRectNull;
    }

    UIPeripheralHost *host = [(id)hostClass sharedInstance];
    if (![host respondsToSelector:@selector(isOnScreen)] || ![host isOnScreen]) {
        return CGRectNull;
    }

    NSArray<NSValue *> *visibleFrames = [(id)hostClass allVisiblePeripheralFrames];
    if (![visibleFrames isKindOfClass:[NSArray class]] || [visibleFrames count] == 0) {
        return CGRectNull;
    }

    CGRect keyboardFrame = CGRectNull;
    for (NSValue *frameValue in visibleFrames) {
        if (![frameValue respondsToSelector:@selector(CGRectValue)]) {
            continue;
        }

        CGRect frame = [frameValue CGRectValue];
        if (CGRectIsNull(frame) || CGRectIsEmpty(frame)) {
            continue;
        }

        keyboardFrame = CGRectIsNull(keyboardFrame) ? frame : CGRectUnion(keyboardFrame, frame);
    }

    return keyboardFrame;
}

static CGRect kayokoVisibleKeyboardSwipeFrameInView(UIView *view) {
    if (!view || !view.window) {
        return CGRectNull;
    }

    CGRect keyboardFrame = kayokoVisibleKeyboardFrame();
    if (CGRectIsNull(keyboardFrame) || CGRectIsEmpty(keyboardFrame)) {
        return CGRectNull;
    }

    CGRect frameInView = [view convertRect:keyboardFrame fromView:nil];
    if (CGRectIsNull(frameInView) || CGRectIsEmpty(frameInView)) {
        return CGRectNull;
    }

    UIEdgeInsets safeAreaInsets = view.safeAreaInsets;
    if (safeAreaInsets.bottom <= 0) {
        safeAreaInsets = view.window.safeAreaInsets;
    }
    if (safeAreaInsets.bottom > 0 &&
        fabs(CGRectGetMaxY(frameInView) - CGRectGetMaxY(view.bounds)) <= kKayokoSystemKeyboardFrameEdgeTolerance) {
        frameInView.size.height = MAX(CGRectGetHeight(frameInView) - safeAreaInsets.bottom, 0);
    }

    return CGRectIsEmpty(frameInView) ? CGRectNull : frameInView;
}

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSystemSwipeUpGestureHandler : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic, weak, readonly) UIView *view;
- (instancetype)initWithView:(UIView *)view;
- (void)handleSwipeUpGesture:(UIGestureRecognizer *)recognizer;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSystemSwipeUpGestureHandler

- (instancetype)initWithView:(UIView *)view {
    self = [super init];
    if (self) {
        _view = view;
    }
    return self;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    UIView *view = self.view;
    if (!view || gestureRecognizer != objc_getAssociatedObject(view, &kayokoSystemSwipeUpGestureRecognizerKey)) {
        return YES;
    }

    if ([[KayokoCoreRuntime sharedRuntime] panelVisible]) {
        return NO;
    }

    CGRect keyboardFrame = kayokoVisibleKeyboardSwipeFrameInView(view);
    if (CGRectIsNull(keyboardFrame) || CGRectIsEmpty(keyboardFrame)) {
        return NO;
    }

    return CGRectContainsPoint(keyboardFrame, [touch locationInView:view]);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    (void)gestureRecognizer;
    (void)otherGestureRecognizer;
    return YES;
}

- (void)handleSwipeUpGesture:(UIGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateRecognized) {
        return;
    }

    if ([[KayokoCoreRuntime sharedRuntime] panelVisible]) {
        return;
    }

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kKayokoNotificationKeyCoreShow, nil, nil, YES);
}

@end

CHOptimizedMethod1(self, void, UIWindowScene, _delegate_windowDidBecomeVisible, UIWindow *, window) {
    CHSuper1(UIWindowScene, _delegate_windowDidBecomeVisible, window);
    if (![KayokoSpringBoardHookInstaller isStatusBarWindow:window]) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if ([KayokoSpringBoardHookInstaller isStatusBarWindow:window]) {
          [[KayokoCoreRuntime sharedRuntime] installPanelInStatusBarWindow:window];
      }
    });
}

CHOptimizedMethod1(self, void, SpringBoard, applicationDidFinishLaunching, id, application) {
    CHSuper1(SpringBoard, applicationDidFinishLaunching, application);
    [[KayokoCoreRuntime sharedRuntime] preloadInitialHistory];
}

CHOptimizedMethod0(self, NSArray<UIKeyCommand *> *, SpringBoard, keyCommands) {
    NSArray<UIKeyCommand *> *keyCommands = CHSuper0(SpringBoard, keyCommands);
    if (!([[KayokoCoreRuntime sharedRuntime] activationMethod] & kActivationMethodExternalKeyboard)) {
        return keyCommands;
    }

    UIKeyCommand *command = [UIKeyCommand keyCommandWithInput:@"V"
                                                modifierFlags:UIKeyModifierCommand | UIKeyModifierShift
                                                       action:@selector(kayokoHandleExternalKeyboardShortcut:)];
    [command setDiscoverabilityTitle:kKayokoExternalKeyboardDiscoverabilityTitle];
    return keyCommands ? [keyCommands arrayByAddingObject:command] : @[ command ];
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

CHOptimizedMethod1(self, void, _UISystemGestureWindow, sendEvent, UIEvent *, event) {
    if (event.type == UIEventTypeTouches) {
        [KayokoSpringBoardHookInstaller ensureSystemSwipeUpGestureRecognizerForWindow:self];
    }

    CHSuper1(_UISystemGestureWindow, sendEvent, event);
}

@implementation KayokoSpringBoardHookInstaller

+ (BOOL)isStatusBarWindow:(UIWindow *)window {
    Class statusBarWindowClass = NSClassFromString(@"UIStatusBarWindow");
    if (statusBarWindowClass && [window isKindOfClass:statusBarWindowClass]) {
        return YES;
    }

    Class springBoardStatusBarWindowClass = NSClassFromString(@"SBStatusBarWindow");
    return springBoardStatusBarWindowClass && [window isKindOfClass:springBoardStatusBarWindowClass];
}

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

+ (void)ensureSystemSwipeUpGestureRecognizerForWindow:(_UISystemGestureWindow *)window {
    if (![window respondsToSelector:@selector(_systemGestureView)]) {
        return;
    }

    UIView *gestureView = [window _systemGestureView];
    if (![gestureView isKindOfClass:[UIView class]]) {
        return;
    }

    if (objc_getAssociatedObject(gestureView, &kayokoSystemSwipeUpGestureRecognizerKey)) {
        return;
    }

    KayokoSystemSwipeUpGestureHandler *handler = [[KayokoSystemSwipeUpGestureHandler alloc] initWithView:gestureView];
    KayokoSwipeUpGestureRecognizer *recognizer =
        [[KayokoSwipeUpGestureRecognizer alloc] initWithTarget:handler action:@selector(handleSwipeUpGesture:)];
    recognizer.cancelsTouchesInView = NO;
    recognizer.delegate = handler;
    [gestureView addGestureRecognizer:recognizer];

    objc_setAssociatedObject(gestureView, &kayokoSystemSwipeUpGestureHandlerKey, handler,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(gestureView, &kayokoSystemSwipeUpGestureRecognizerKey, recognizer,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)installStatusBarHooks {
    Class windowSceneClass = NSClassFromString(@"UIWindowScene");
    SEL windowDidBecomeVisibleSelector = @selector(_delegate_windowDidBecomeVisible:);
    if (!windowSceneClass || ![windowSceneClass instancesRespondToSelector:windowDidBecomeVisibleSelector]) {
        return;
    }

    CHLoadClass_(&UIWindowScene$, windowSceneClass);
    CHHook1(UIWindowScene, _delegate_windowDidBecomeVisible);
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

+ (void)installSystemSwipeUpHooks {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
      Class windowClass = NSClassFromString(@"_UISystemGestureWindow");
      if (![windowClass instancesRespondToSelector:@selector(sendEvent:)]) {
          return;
      }

      CHLoadClass_(&_UISystemGestureWindow$, windowClass);
      CHHook1(_UISystemGestureWindow, sendEvent);
    });
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
    class_addMethod(CHClass(SpringBoard), @selector(kayokoHandleExternalKeyboardShortcut:),
                    (IMP)kayokoHandleExternalKeyboardShortcut, "v@:@");

    CHHook1(SpringBoard, applicationDidFinishLaunching);
    CHHook0(SpringBoard, keyCommands);

    [self installHomeScreenHooks];
    [self installAppSwitcherHooks];
    [self installLockScreenTransitionHooks];
    [self installSpotlightHooks];
    [self installLibrarySearchHooks];
    [self installSystemGestureHooks];

    KayokoCoreRuntime *runtime = [KayokoCoreRuntime sharedRuntime];
    if ((runtime.activationMethod & kActivationMethodSwipeUp) &&
        runtime.gestureRecognizerMode == kKayokoGestureRecognizerModeSystem) {
        [self installSystemSwipeUpHooks];
    }
}

@end
