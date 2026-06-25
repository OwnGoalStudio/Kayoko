#import <HBLog.h>
#import <objc/runtime.h>
#import <substrate.h>

@import Foundation;
@import UIKit;
#include <math.h>

#import "KayokoHelper.h"
#import "NotificationKeys.h"
#import "PasteboardManager.h"

#define ITEM_ID "codes.aurora.kayoko.globe"

static BOOL kayokoSwipeUpTracking = NO;
static BOOL kayokoSwipeUpDidTrigger = NO;
static CGPoint kayokoSwipeUpStartPoint = CGPointZero;
static NSTimeInterval kayokoSwipeUpStartTimestamp = 0;
static char kKayokoSwipeUpGestureRecognizerKey;
static CGFloat const kKayokoSwipeUpMinimumVerticalDistance = 120.0;
static CGFloat const kKayokoSwipeUpMaximumHorizontalDistance = 80.0;
static CGFloat const kKayokoSwipeUpMinimumVerticalDominance = 1.5;
static CGFloat const kKayokoSwipeUpMinimumVerticalVelocity = 350.0;
static NSTimeInterval const kKayokoSwipeUpMaximumDuration = 0.5;
static CGFloat const kKayokoSwipeUpAdditionalBottomSafetyInset = 32.0;

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

static void kayokoResetSwipeUpTracking(void) {
    kayokoSwipeUpTracking = NO;
    kayokoSwipeUpDidTrigger = NO;
    kayokoSwipeUpStartPoint = CGPointZero;
    kayokoSwipeUpStartTimestamp = 0;
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
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
    kayokoCancelAllTouches();
}

static void kayokoHandleSwipeUpLocation(CGPoint location, NSTimeInterval timestamp) {
    if (!kayokoSwipeUpTracking || kayokoSwipeUpDidTrigger) {
        return;
    }

    CGFloat deltaX = location.x - kayokoSwipeUpStartPoint.x;
    CGFloat deltaY = location.y - kayokoSwipeUpStartPoint.y;
    CGFloat absDeltaX = fabs(deltaX);
    CGFloat absDeltaY = fabs(deltaY);
    NSTimeInterval duration = timestamp - kayokoSwipeUpStartTimestamp;
    if (duration <= 0 || duration > kKayokoSwipeUpMaximumDuration) {
        return;
    }

    CGFloat verticalVelocity = absDeltaY / duration;
    if (deltaY <= -kKayokoSwipeUpMinimumVerticalDistance &&
        absDeltaX <= kKayokoSwipeUpMaximumHorizontalDistance &&
        absDeltaY >= absDeltaX * kKayokoSwipeUpMinimumVerticalDominance &&
        verticalVelocity >= kKayokoSwipeUpMinimumVerticalVelocity) {
        kayokoSwipeUpDidTrigger = YES;
        kayokoShowKayokoAndCancelTouches();
    }
}

static void kayokoTrackSwipeUpInKeyboardWindow(UIWindow *window, UIEvent *event) {
    if (event.type != UIEventTypeTouches) {
        return;
    }

    NSSet<UITouch *> *touches = [event allTouches];
    if (touches.count != 1) {
        kayokoResetSwipeUpTracking();
        return;
    }

    UITouch *touch = [touches anyObject];
    if (touch.window != window) {
        return;
    }

    CGPoint location = [touch locationInView:window];
    switch (touch.phase) {
        case UITouchPhaseBegan:
            kayokoSwipeUpTracking = kayokoPointIsInsideAllowedSwipeRegion(window, location);
            kayokoSwipeUpDidTrigger = NO;
            kayokoSwipeUpStartPoint = location;
            kayokoSwipeUpStartTimestamp = touch.timestamp;
            break;
        case UITouchPhaseMoved:
            kayokoHandleSwipeUpLocation(location, touch.timestamp);
            break;
        case UITouchPhaseEnded:
            kayokoHandleSwipeUpLocation(location, touch.timestamp);
            kayokoResetSwipeUpTracking();
            break;
        case UITouchPhaseCancelled:
            kayokoResetSwipeUpTracking();
            break;
        default:
            break;
    }
}

@interface UIInputSwitcherItem : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *localizedTitle;
@property(nonatomic, copy) NSString *localizedSubtitle;
@property(nonatomic, strong) UIFont *titleFont;
@property(nonatomic, strong) UIFont *subtitleFont;
@property(assign, nonatomic) BOOL usesDeviceLanguage;
@property(nonatomic, strong) UISwitch *switchControl;
@property(nonatomic, copy) id switchIsOnBlock;
@property(nonatomic, copy) id switchToggleBlock;
- (instancetype)initWithIdentifier:(NSString *)identifier;
@end

%group KayokoActivationGlobe

%hook UIInputSwitcherView

- (void)_reloadInputSwitcherItems {
    %orig;
    BOOL isForDictation = MSHookIvar<BOOL>(self, "m_isForDictation");
    if (isForDictation) {
        return;
    }
    NSArray *items = MSHookIvar<NSArray *>(self, "m_inputSwitcherItems");
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:items];
    UIInputSwitcherItem *item = [[%c(UIInputSwitcherItem) alloc] initWithIdentifier:@ITEM_ID];
    [item setLocalizedTitle:[[PasteboardManager localizationBundle] localizedStringForKey:@"Kayoko"
                                                                                    value:nil
                                                                                    table:@"Tweak"]];
    if (item) {
        [newItems insertObject:item atIndex:newItems.count - 1];
    }
    MSHookIvar<NSArray *>(self, "m_inputSwitcherItems") = newItems;
}

- (void)didSelectItemAtIndex:(unsigned long long)index {
    NSArray *items = MSHookIvar<NSArray *>(self, "m_inputSwitcherItems");
    UIInputSwitcherItem *item = items[index];
    if ([item.identifier isEqualToString:@ITEM_ID]) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
    }
    %orig;
}

%end

%end // KayokoActivationGlobe

%group KayokoActivationDictation

%hook UIKeyboardDockItem

- (id)initWithImageName:(id)arg1 identifier:(id)arg2 {
    if ([arg1 isEqualToString:@"mic"]) {
        if (@available(iOS 16, *)) {
            arg1 = @"list.clipboard";
        } else {
            arg1 = @"doc.on.clipboard";
        }
    }
    return %orig;
}

- (void)setImageName:(NSString *)arg1 {
    if ([arg1 isEqualToString:@"mic"]) {
        if (@available(iOS 16, *)) {
            arg1 = @"list.clipboard";
        } else {
            arg1 = @"doc.on.clipboard";
        }
    }
    %orig;
}

%end

%hook UIKeyboardDockItemButton

- (CGRect)imageRectForContentRect:(CGRect)arg1 {
    CGRect origRect = %orig;
    if (@available(iOS 16, *)) {
        if (ABS(origRect.size.width - origRect.size.height) > 1.0) {
            CGSize newSize = CGSizeMake(origRect.size.width * 0.92, origRect.size.height * 0.92);
            CGPoint newOrigin = CGPointMake(origRect.origin.x + (origRect.size.width - newSize.width) / 2, origRect.origin.y + (origRect.size.height - newSize.height) / 2);
            return CGRectMake(newOrigin.x, newOrigin.y, newSize.width, newSize.height);
        }
    } else {
        if (ABS(origRect.size.width - origRect.size.height) > 1.0) {
            CGSize newSize = CGSizeMake(origRect.size.width * 0.86, origRect.size.height * 0.86);
            CGPoint newOrigin = CGPointMake(origRect.origin.x + (origRect.size.width - newSize.width) / 2, origRect.origin.y + (origRect.size.height - newSize.height) / 2);
            return CGRectMake(newOrigin.x, newOrigin.y, newSize.width, newSize.height);
        }
    }
    return origRect;
}

%end

%hook UISystemKeyboardDockController

- (void)dictationItemButtonWasPressed:(id)arg1 withEvent:(id)arg2 isRunningButton:(BOOL)arg3 {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
}

%end

%end // KayokoActivationDictation

%group KayokoActivationSwipeUp

%hook UIInputSetHostView

- (void)didMoveToWindow {
    %orig;

    if (!self.window) {
        return;
    }

    UISwipeGestureRecognizer *recognizer = objc_getAssociatedObject(self, &kKayokoSwipeUpGestureRecognizerKey);
    if (recognizer) {
        return;
    }

    recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(kayoko_handleSwipeUpGesture:)];
    recognizer.direction = UISwipeGestureRecognizerDirectionUp;
    recognizer.numberOfTouchesRequired = 1;
    recognizer.cancelsTouchesInView = NO;
    recognizer.delegate = (id<UIGestureRecognizerDelegate>)self;
    [self addGestureRecognizer:recognizer];
    objc_setAssociatedObject(self, &kKayokoSwipeUpGestureRecognizerKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer != objc_getAssociatedObject(self, &kKayokoSwipeUpGestureRecognizerKey)) {
        return YES;
    }

    return kayokoPointIsInsideAllowedSwipeRegion(self, [touch locationInView:self]);
}

%new
- (void)kayoko_handleSwipeUpGesture:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateRecognized) {
        return;
    }

    kayokoShowKayokoAndCancelTouches();
}

%end

%end // KayokoActivationSwipeUp

%group KayokoActivationSwipeUpKeyboardExtension

%hook _UIHostedWindow

- (void)sendEvent:(UIEvent *)event {
    kayokoTrackSwipeUpInKeyboardWindow(self, event);
    %orig;
}

%end

%end // KayokoActivationSwipeUpKeyboardExtension


void EnableKayokoActivationGlobe(void) {
    %init(KayokoActivationGlobe);
}

void EnableKayokoActivationDictation(void) {
    %init(KayokoActivationDictation);
}

void EnableKayokoActivationSwipeUp(void) {
    %init(KayokoActivationSwipeUp);
}

void EnableKayokoActivationSwipeUpForKeyboardExtension(void) {
    %init(KayokoActivationSwipeUpKeyboardExtension);
}
