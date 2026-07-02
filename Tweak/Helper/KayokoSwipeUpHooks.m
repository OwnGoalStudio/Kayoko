//
//  KayokoSwipeUpHooks.m
//  Kayoko
//

#define CHUseSubstrate

#import "KayokoHelper.h"
#import "KayokoSwipeUpGestureRecognizer.h"

#import <CaptainHook/CaptainHook.h>
#import <HBLog.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

CHDeclareClass(UIInputSetHostView);
CHDeclareClass(_UIHostedWindow);

static char kayokoSwipeUpGestureRecognizerKey;
static char kayokoSwipeUpGestureHandlerKey;
static char kayokoManualSwipeUpActiveKey;

static CGFloat const kKayokoSwipeUpAdditionalBottomSafetyInset = 0.0;

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

static CGRect kayokoSwipeAllowedBoundsForView(UIView *view) {
    UIEdgeInsets safeAreaInsets = view.safeAreaInsets;
    safeAreaInsets.bottom += kKayokoSwipeUpAdditionalBottomSafetyInset;
    CGRect allowedBounds = UIEdgeInsetsInsetRect(view.bounds, safeAreaInsets);
    if (CGRectGetWidth(allowedBounds) <= 0 || CGRectGetHeight(allowedBounds) <= 0) {
        return CGRectNull;
    }

    return allowedBounds;
}

static BOOL kayokoPointIsInsideAllowedSwipeRegion(UIView *view, CGPoint point) {
    CGRect allowedBounds = kayokoSwipeAllowedBoundsForView(view);
    if (CGRectIsNull(allowedBounds)) {
        return NO;
    }

    return CGRectContainsPoint(allowedBounds, point);
}

static id kayokoSharedApplication(void) {
    Class applicationClass = NSClassFromString(@"UIApplication");
    SEL sharedApplicationSelector = NSSelectorFromString(@"sharedApplication");
    if (![applicationClass respondsToSelector:sharedApplicationSelector]) {
        return nil;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [applicationClass performSelector:sharedApplicationSelector];
#pragma clang diagnostic pop
}

static void kayokoCancelAllTouches(void) {
    id application = kayokoSharedApplication();
    SEL cancelAllTouchesSelector = NSSelectorFromString(@"_cancelAllTouches");
    if (![application respondsToSelector:cancelAllTouchesSelector]) {
        return;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [application performSelector:cancelAllTouchesSelector];
#pragma clang diagnostic pop
}

static void kayokoShowKayokoAndCancelTouches(void) {
    KayokoHelperCaptureCurrentFirstResponder();
    KayokoHelperPostCoreShow();
    kayokoCancelAllTouches();
}

static void kayokoDiscardSwipeUpGestureRecognizer(UIView *view);
static void kayokoSetManualSwipeUpActive(UIWindow *window, BOOL active);

@interface KayokoSwipeUpGestureHandler : NSObject <UIGestureRecognizerDelegate>
- (instancetype)initWithView:(UIView *)view keyboardExtension:(BOOL)keyboardExtension;
- (void)handleSwipeUpGesture:(UIGestureRecognizer *)recognizer;
@end

@interface KayokoSwipeUpGestureHandler ()
@property(nonatomic, weak, readonly) UIView *view;
@property(nonatomic, assign, readonly, getter=isKeyboardExtension) BOOL keyboardExtension;
@end

@implementation KayokoSwipeUpGestureHandler

- (instancetype)initWithView:(UIView *)view keyboardExtension:(BOOL)keyboardExtension {
    self = [super init];
    if (self) {
        _view = view;
        _keyboardExtension = keyboardExtension;
    }
    return self;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    UIView *view = self.view;
    if (!view || gestureRecognizer != objc_getAssociatedObject(view, &kayokoSwipeUpGestureRecognizerKey)) {
        return YES;
    }

    return kayokoPointIsInsideAllowedSwipeRegion(view, [touch locationInView:view]);
}

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

    kayokoShowKayokoAndCancelTouches();
}

@end

static KayokoSwipeUpGestureHandler *kayokoSwipeUpGestureHandlerForView(UIView *view, BOOL keyboardExtension) {
    KayokoSwipeUpGestureHandler *handler = objc_getAssociatedObject(view, &kayokoSwipeUpGestureHandlerKey);
    if (handler) {
        return handler;
    }

    handler = [[KayokoSwipeUpGestureHandler alloc] initWithView:view keyboardExtension:keyboardExtension];
    objc_setAssociatedObject(view, &kayokoSwipeUpGestureHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return handler;
}

static KayokoSwipeUpGestureRecognizer *kayokoEnsureSwipeUpGestureRecognizer(UIView *view, BOOL keyboardExtension) {
    KayokoSwipeUpGestureRecognizer *recognizer = objc_getAssociatedObject(view, &kayokoSwipeUpGestureRecognizerKey);
    if (recognizer) {
        return recognizer;
    }

    KayokoSwipeUpGestureHandler *handler = kayokoSwipeUpGestureHandlerForView(view, keyboardExtension);
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

static BOOL kayokoManualSwipeUpIsActive(UIWindow *window) {
    NSNumber *active = objc_getAssociatedObject(window, &kayokoManualSwipeUpActiveKey);
    return [active boolValue];
}

static void kayokoSetManualSwipeUpActive(UIWindow *window, BOOL active) {
    objc_setAssociatedObject(window, &kayokoManualSwipeUpActiveKey, @(active), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSSet<UITouch *> *kayokoTouchesForWindow(UIWindow *window, UIEvent *event) {
    NSMutableSet<UITouch *> *touches = [NSMutableSet set];
    for (UITouch *touch in [event allTouches]) {
        if (touch.window == window) {
            [touches addObject:touch];
        }
    }
    return touches;
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

static void kayokoManuallyFeedSwipeUpRecognizerInKeyboardWindow(UIWindow *window, UIEvent *event) {
    if (event.type != UIEventTypeTouches) {
        return;
    }

    NSSet<UITouch *> *windowTouches = kayokoTouchesForWindow(window, event);
    if (windowTouches.count > 1) {
        if (kayokoManualSwipeUpIsActive(window)) {
            UIGestureRecognizer *recognizer = objc_getAssociatedObject(window, &kayokoSwipeUpGestureRecognizerKey);
            [recognizer touchesCancelled:windowTouches withEvent:event];
            kayokoSetManualSwipeUpActive(window, NO);
            kayokoDiscardSwipeUpGestureRecognizer(window);
        }
        return;
    }

    NSSet<UITouch *> *beganTouches = kayokoTouchesForWindowWithPhase(window, event, UITouchPhaseBegan);
    if (beganTouches.count > 0) {
        UITouch *touch = [beganTouches anyObject];
        BOOL active =
            beganTouches.count == 1 && kayokoPointIsInsideAllowedSwipeRegion(window, [touch locationInView:window]);
        kayokoSetManualSwipeUpActive(window, active);
        HBLogDebug(@"Kayoko: manual swipe recognizer began active=%@", active ? @"YES" : @"NO");
        if (active) {
            kayokoDiscardSwipeUpGestureRecognizer(window);
            UIGestureRecognizer *recognizer = kayokoEnsureSwipeUpGestureRecognizer(window, YES);
            HBLogDebug(@"Kayoko: installed manual-feed swipe recognizer on _UIHostedWindow from began");
            [recognizer touchesBegan:beganTouches withEvent:event];
        }
        return;
    }

    if (!kayokoManualSwipeUpIsActive(window)) {
        return;
    }

    UIGestureRecognizer *recognizer = objc_getAssociatedObject(window, &kayokoSwipeUpGestureRecognizerKey);
    if (!recognizer) {
        kayokoSetManualSwipeUpActive(window, NO);
        return;
    }

    NSSet<UITouch *> *movedTouches = kayokoTouchesForWindowWithPhase(window, event, UITouchPhaseMoved);
    if (movedTouches.count > 0) {
        [recognizer touchesMoved:movedTouches withEvent:event];
    }

    NSSet<UITouch *> *endedTouches = kayokoTouchesForWindowWithPhase(window, event, UITouchPhaseEnded);
    if (endedTouches.count > 0) {
        [recognizer touchesEnded:endedTouches withEvent:event];
        kayokoSetManualSwipeUpActive(window, NO);
        kayokoDiscardSwipeUpGestureRecognizer(window);
    }

    NSSet<UITouch *> *cancelledTouches = kayokoTouchesForWindowWithPhase(window, event, UITouchPhaseCancelled);
    if (cancelledTouches.count > 0) {
        [recognizer touchesCancelled:cancelledTouches withEvent:event];
        kayokoSetManualSwipeUpActive(window, NO);
        kayokoDiscardSwipeUpGestureRecognizer(window);
    }
}

CHOptimizedMethod0(self, void, UIInputSetHostView, didMoveToWindow) {
    CHSuper0(UIInputSetHostView, didMoveToWindow);

    if (!self.window) {
        return;
    }

    kayokoEnsureSwipeUpGestureRecognizer(self, NO);
}

CHOptimizedMethod1(self, void, _UIHostedWindow, sendEvent, UIEvent *, event) {
    kayokoManuallyFeedSwipeUpRecognizerInKeyboardWindow(self, event);
    CHSuper1(_UIHostedWindow, sendEvent, event);
}

void EnableKayokoActivationSwipeUp(void) {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
      CHLoadClass_(&UIInputSetHostView$, NSClassFromString(@"UIInputSetHostView"));

      CHHook0(UIInputSetHostView, didMoveToWindow);
    });
}

void EnableKayokoActivationSwipeUpForKeyboardExtension(void) {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
      CHLoadClass_(&_UIHostedWindow$, NSClassFromString(@"_UIHostedWindow"));

      CHHook1(_UIHostedWindow, sendEvent);
    });
}
