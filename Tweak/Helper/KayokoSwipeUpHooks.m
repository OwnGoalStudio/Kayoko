//
//  KayokoSwipeUpHooks.m
//  Kayoko
//

#define CHUseSubstrate

#import "KayokoHelperHookInstaller.h"
#import "KayokoHelperRuntime.h"
#import "KayokoSwipeUpGestureRecognizer.h"

#import <CaptainHook/CaptainHook.h>
#import <HBLog.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

CHDeclareClass(UIInputSetHostView);
CHDeclareClass(_UIHostedWindow);
CHDeclareClass(UIViewController);

static char kayokoSwipeUpGestureRecognizerKey;
static char kayokoSwipeUpGestureHandlerKey;
static char kayokoManualSwipeUpActiveKey;

static CGFloat const kKayokoSwipeUpAdditionalBottomSafetyInset = 0.0;
static NSString *const kKayokoSpotlightBundleIdentifier = @"com.apple.Spotlight";

static BOOL kayokoKeyboardExtensionSwipeUpSpotlightOnly = NO;
static NSString *kayokoKeyboardExtensionHostApplicationBundleIdentifier = nil;
static NSString *kayokoLoggedKeyboardExtensionHostApplicationBundleIdentifier = nil;

@interface UIGestureRecognizer (KayokoManualTouchDelivery)
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
@end

@interface UIInputSetHostView : UIView
@end

@interface _UIHostedWindow : UIWindow
@end

@interface UIViewController (KayokoHostApplication)
- (void)_setHostApplicationBundleIdentifier:(NSString *)bundleIdentifier;
@end

@interface UIApplication (KayokoPrivateTouches)
- (void)_cancelAllTouches;
@end

#pragma mark - Swipe Region

static BOOL kayokoPointIsInsideAllowedSwipeRegion(UIView *view, CGPoint point) {
    UIEdgeInsets safeAreaInsets = view.safeAreaInsets;
    safeAreaInsets.bottom += kKayokoSwipeUpAdditionalBottomSafetyInset;
    CGRect allowedBounds = UIEdgeInsetsInsetRect(view.bounds, safeAreaInsets);
    if (CGRectGetWidth(allowedBounds) <= 0 || CGRectGetHeight(allowedBounds) <= 0) {
        return NO;
    }
    if (CGRectIsNull(allowedBounds)) {
        return NO;
    }

    return CGRectContainsPoint(allowedBounds, point);
}

static void kayokoDiscardSwipeUpGestureRecognizer(UIView *view);
static void kayokoSetManualSwipeUpActive(UIWindow *window, BOOL active);

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSwipeUpGestureHandler : NSObject <UIGestureRecognizerDelegate>

#pragma mark - Lifecycle

- (instancetype)initWithView:(UIView *)view keyboardExtension:(BOOL)keyboardExtension;

#pragma mark - Actions

- (void)handleSwipeUpGesture:(UIGestureRecognizer *)recognizer;
@end

@interface KayokoSwipeUpGestureHandler ()

#pragma mark - State

@property(nonatomic, weak, readonly) UIView *view;
@property(nonatomic, assign, readonly, getter=isKeyboardExtension) BOOL keyboardExtension;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSwipeUpGestureHandler

#pragma mark - Lifecycle

- (instancetype)initWithView:(UIView *)view keyboardExtension:(BOOL)keyboardExtension {
    self = [super init];
    if (self) {
        _view = view;
        _keyboardExtension = keyboardExtension;
    }
    return self;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    UIView *view = self.view;
    if (!view || gestureRecognizer != objc_getAssociatedObject(view, &kayokoSwipeUpGestureRecognizerKey)) {
        return YES;
    }

    return kayokoPointIsInsideAllowedSwipeRegion(view, [touch locationInView:view]);
}

#pragma mark - Actions

- (void)handleSwipeUpGesture:(UIGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateRecognized) {
        return;
    }

    if (self.isKeyboardExtension) {
        HBLogDebug(@"Kayoko: manual-feed swipe recognizer action state=%ld", (long)recognizer.state);
        UIWindow *window = (UIWindow *)recognizer.view;
        if ([window isKindOfClass:[UIWindow class]]) {
            kayokoSetManualSwipeUpActive(window, NO);
            kayokoDiscardSwipeUpGestureRecognizer(window);
            HBLogDebug(@"Kayoko: discarded manual-feed swipe recognizer after recognition");
        }
    }

    if ([[KayokoHelperRuntime sharedRuntime] activateKayokoAfterCapturingCurrentFocus]) {
        UIApplication *application = [UIApplication sharedApplication];
        if (![application respondsToSelector:@selector(_cancelAllTouches)]) {
            return;
        }

        [application _cancelAllTouches];
    }
}

@end

#pragma mark - Gesture Recognizer Management

static KayokoSwipeUpGestureRecognizer *kayokoEnsureSwipeUpGestureRecognizer(UIView *view, BOOL keyboardExtension) {
    KayokoSwipeUpGestureRecognizer *recognizer = objc_getAssociatedObject(view, &kayokoSwipeUpGestureRecognizerKey);
    if (recognizer) {
        return recognizer;
    }

    KayokoSwipeUpGestureHandler *handler = objc_getAssociatedObject(view, &kayokoSwipeUpGestureHandlerKey);
    if (!handler) {
        handler = [[KayokoSwipeUpGestureHandler alloc] initWithView:view keyboardExtension:keyboardExtension];
        objc_setAssociatedObject(view, &kayokoSwipeUpGestureHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    recognizer = [[KayokoSwipeUpGestureRecognizer alloc] initWithTarget:handler
                                                                 action:@selector(handleSwipeUpGesture:)];
    recognizer.cancelsTouchesInView = NO;
    recognizer.delegate = handler;
    [view addGestureRecognizer:recognizer];
    objc_setAssociatedObject(view, &kayokoSwipeUpGestureRecognizerKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return recognizer;
}

static void kayokoDiscardSwipeUpGestureRecognizer(UIView *view) {
    UIGestureRecognizer *recognizer = objc_getAssociatedObject(view, &kayokoSwipeUpGestureRecognizerKey);
    if (!recognizer) {
        return;
    }

    [view removeGestureRecognizer:recognizer];
    objc_setAssociatedObject(view, &kayokoSwipeUpGestureRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &kayokoSwipeUpGestureHandlerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Manual Touch State

static BOOL kayokoManualSwipeUpIsActive(UIWindow *window) {
    NSNumber *active = objc_getAssociatedObject(window, &kayokoManualSwipeUpActiveKey);
    return [active boolValue];
}

static void kayokoSetManualSwipeUpActive(UIWindow *window, BOOL active) {
    objc_setAssociatedObject(window, &kayokoManualSwipeUpActiveKey, @(active), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSSet<UITouch *> *kayokoTouchesForWindowWithPhase(UIWindow *window, UIEvent *event, UITouchPhase phase) {
    NSMutableSet<UITouch *> *touches = [NSMutableSet set];
    for (UITouch *touch in [event allTouches]) {
        if (touch.window == window && touch.phase == phase) {
            [touches addObject:touch];
        }
    }
    return touches;
}

#pragma mark - Keyboard Extension Hooks

CHOptimizedMethod1(self, void, _UIHostedWindow, sendEvent, UIEvent *, event) {
    if (event.type != UIEventTypeTouches) {
        CHSuper1(_UIHostedWindow, sendEvent, event);
        return;
    }

    if (kayokoKeyboardExtensionSwipeUpSpotlightOnly &&
        ![kayokoKeyboardExtensionHostApplicationBundleIdentifier isEqualToString:kKayokoSpotlightBundleIdentifier]) {
        CHSuper1(_UIHostedWindow, sendEvent, event);
        return;
    }

    NSMutableSet<UITouch *> *windowTouches = [NSMutableSet set];
    for (UITouch *touch in [event allTouches]) {
        if (touch.window == self) {
            [windowTouches addObject:touch];
        }
    }

    if (windowTouches.count > 1) {
        if (kayokoManualSwipeUpIsActive(self)) {
            UIGestureRecognizer *recognizer = objc_getAssociatedObject(self, &kayokoSwipeUpGestureRecognizerKey);
            [recognizer touchesCancelled:windowTouches withEvent:event];
            kayokoSetManualSwipeUpActive(self, NO);
            kayokoDiscardSwipeUpGestureRecognizer(self);
        }
        CHSuper1(_UIHostedWindow, sendEvent, event);
        return;
    }

    NSSet<UITouch *> *beganTouches = kayokoTouchesForWindowWithPhase(self, event, UITouchPhaseBegan);
    if (beganTouches.count > 0) {
        UITouch *touch = [beganTouches anyObject];
        BOOL active =
            beganTouches.count == 1 && kayokoPointIsInsideAllowedSwipeRegion(self, [touch locationInView:self]);
        kayokoSetManualSwipeUpActive(self, active);
        HBLogDebug(@"Kayoko: manual swipe recognizer began active=%@", active ? @"YES" : @"NO");
        if (active) {
            kayokoDiscardSwipeUpGestureRecognizer(self);
            UIGestureRecognizer *recognizer = kayokoEnsureSwipeUpGestureRecognizer(self, YES);
            HBLogDebug(@"Kayoko: installed manual-feed swipe recognizer on _UIHostedWindow from began");
            [recognizer touchesBegan:beganTouches withEvent:event];
        }
        CHSuper1(_UIHostedWindow, sendEvent, event);
        return;
    }

    if (!kayokoManualSwipeUpIsActive(self)) {
        CHSuper1(_UIHostedWindow, sendEvent, event);
        return;
    }

    UIGestureRecognizer *recognizer = objc_getAssociatedObject(self, &kayokoSwipeUpGestureRecognizerKey);
    if (!recognizer) {
        kayokoSetManualSwipeUpActive(self, NO);
        CHSuper1(_UIHostedWindow, sendEvent, event);
        return;
    }

    NSSet<UITouch *> *movedTouches = kayokoTouchesForWindowWithPhase(self, event, UITouchPhaseMoved);
    if (movedTouches.count > 0) {
        [recognizer touchesMoved:movedTouches withEvent:event];
    }

    NSSet<UITouch *> *endedTouches = kayokoTouchesForWindowWithPhase(self, event, UITouchPhaseEnded);
    if (endedTouches.count > 0) {
        [recognizer touchesEnded:endedTouches withEvent:event];
        kayokoSetManualSwipeUpActive(self, NO);
        kayokoDiscardSwipeUpGestureRecognizer(self);
    }

    NSSet<UITouch *> *cancelledTouches = kayokoTouchesForWindowWithPhase(self, event, UITouchPhaseCancelled);
    if (cancelledTouches.count > 0) {
        [recognizer touchesCancelled:cancelledTouches withEvent:event];
        kayokoSetManualSwipeUpActive(self, NO);
        kayokoDiscardSwipeUpGestureRecognizer(self);
    }

    CHSuper1(_UIHostedWindow, sendEvent, event);
}

CHOptimizedMethod1(self, void, UIViewController, _setHostApplicationBundleIdentifier, NSString *, bundleIdentifier) {
    CHSuper1(UIViewController, _setHostApplicationBundleIdentifier, bundleIdentifier);

    if (![bundleIdentifier isKindOfClass:[NSString class]]) {
        return;
    }

    kayokoKeyboardExtensionHostApplicationBundleIdentifier = [bundleIdentifier copy];
    if ([kayokoLoggedKeyboardExtensionHostApplicationBundleIdentifier isEqualToString:bundleIdentifier]) {
        return;
    }

    kayokoLoggedKeyboardExtensionHostApplicationBundleIdentifier = [bundleIdentifier copy];
    HBLogDebug(@"Kayoko: keyboard extension host application bundle identifier=%@", bundleIdentifier);
}

#pragma mark - Keyboard Host Hooks

CHOptimizedMethod0(self, void, UIInputSetHostView, didMoveToWindow) {
    CHSuper0(UIInputSetHostView, didMoveToWindow);

    if (!self.window) {
        return;
    }

    kayokoEnsureSwipeUpGestureRecognizer(self, NO);
}

@implementation KayokoHelperHookInstaller (SwipeUp)

#pragma mark - Hook Installation

+ (void)installSwipeUpHooks {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
      CHLoadClass_(&UIInputSetHostView$, NSClassFromString(@"UIInputSetHostView"));

      CHHook0(UIInputSetHostView, didMoveToWindow);
    });
}

+ (void)installKeyboardExtensionSwipeUpHooksForSpotlightOnly:(BOOL)spotlightOnly {
    static dispatch_once_t sOnceToken;
    kayokoKeyboardExtensionSwipeUpSpotlightOnly = spotlightOnly;
    dispatch_once(&sOnceToken, ^{
      CHLoadClass(UIViewController);
      if ([CHClass(UIViewController) instancesRespondToSelector:@selector(_setHostApplicationBundleIdentifier:)]) {
          CHHook1(UIViewController, _setHostApplicationBundleIdentifier);
      }

      CHLoadClass_(&_UIHostedWindow$, NSClassFromString(@"_UIHostedWindow"));

      CHHook1(_UIHostedWindow, sendEvent);
    });
}

@end
