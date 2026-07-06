//
//  KayokoPanelPresentationController.m
//  Kayoko
//

#import "KayokoPanelPresentationController.h"

#import "KayokoMainView.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPanelPresentationController () <UIGestureRecognizerDelegate>
@property(nonatomic, weak) KayokoMainView *panelView;
@property(nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property(nonatomic, strong) UITapGestureRecognizer *grabberTapGestureRecognizer;
@property(nonatomic, strong, nullable) UIControl *outsideDismissOverlayView;
@property(nonatomic, strong, nullable) UIImpactFeedbackGenerator *feedbackGenerator;
@property(nonatomic, assign) BOOL panGestureDidReachZeroAlpha;
@property(nonatomic, assign) CGFloat pendingDismissTranslationY;
@property(nonatomic, assign) CGFloat pendingDismissVelocityY;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoPanelPresentationController

- (instancetype)initWithPanelView:(KayokoMainView *)panelView {
    self = [super init];
    if (self) {
        _panelView = panelView;
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(handlePanGestureRecognizer:)];
        [[panelView headerView] addGestureRecognizer:_panGestureRecognizer];
        _grabberTapGestureRecognizer =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleGrabberTapGestureRecognizer:)];
        [_grabberTapGestureRecognizer setCancelsTouchesInView:NO];
        [_grabberTapGestureRecognizer setDelegate:self];
        [[panelView headerView] addGestureRecognizer:_grabberTapGestureRecognizer];
    }
    return self;
}

- (BOOL)isAnimating {
    return [[self panelView] isAnimating];
}

- (void)setAnimating:(BOOL)animating {
    [[self panelView] setAnimating:animating];
}

- (void)setOutsideDismissOverlayView:(UIControl *)outsideDismissOverlayView {
    if (_outsideDismissOverlayView == outsideDismissOverlayView) {
        return;
    }

    [_outsideDismissOverlayView removeTarget:self
                                      action:@selector(handleOutsideDismissOverlayTouchDown)
                            forControlEvents:UIControlEventTouchDown];

    _outsideDismissOverlayView = outsideDismissOverlayView;
    [_outsideDismissOverlayView addTarget:self
                                   action:@selector(handleOutsideDismissOverlayTouchDown)
                         forControlEvents:UIControlEventTouchDown];
    if ([self isDismissOnOutsideTouch] && ![[self panelView] isHidden]) {
        [self prepareOutsideDismissOverlayForShow];
        [[self outsideDismissOverlayView] setAlpha:1.0];
        [self finishOutsideDismissOverlayShow];
    } else {
        [self hideOutsideDismissOverlay];
    }
}

- (void)setDismissOnOutsideTouch:(BOOL)dismissOnOutsideTouch {
    _dismissOnOutsideTouch = dismissOnOutsideTouch;
    if (dismissOnOutsideTouch && ![[self panelView] isHidden]) {
        [self prepareOutsideDismissOverlayForShow];
        [[self outsideDismissOverlayView] setAlpha:1.0];
        [self finishOutsideDismissOverlayShow];
    } else {
        [self hideOutsideDismissOverlay];
    }
}

- (void)prepareStandardDismissAnimation {
    CGFloat targetTranslationY = MAX([[self panelView] bounds].size.height / 3, 120);
    [self setPendingDismissTranslationY:targetTranslationY];
    [self setPendingDismissVelocityY:0];
}

- (void)handleOutsideDismissOverlayTouchDown {
    if ([self isDismissOnOutsideTouch] && ![[self panelView] isHidden] && ![self isAnimating]) {
        [self prepareStandardDismissAnimation];
        [[self delegate] panelPresentationControllerDidRequestDismiss:self];
    }
}

- (void)layoutOutsideDismissOverlayView {
    UIView *superview = [[self outsideDismissOverlayView] superview];
    if (!superview) {
        return;
    }

    [[self outsideDismissOverlayView] setFrame:[superview bounds]];
}

- (void)prepareOutsideDismissOverlayForShow {
    UIControl *overlayView = [self outsideDismissOverlayView];
    if (!overlayView || ![self isDismissOnOutsideTouch]) {
        return;
    }

    [self layoutOutsideDismissOverlayView];
    [overlayView setHidden:NO];
    [overlayView setUserInteractionEnabled:NO];
    [overlayView setAlpha:0];
    [[[self panelView] superview] bringSubviewToFront:overlayView];
    [[[self panelView] superview] bringSubviewToFront:[self panelView]];
}

- (void)finishOutsideDismissOverlayShow {
    BOOL enabled = [self isDismissOnOutsideTouch] && ![[self panelView] isHidden] && ![self isAnimating];
    [[self outsideDismissOverlayView] setUserInteractionEnabled:enabled];
}

- (void)hideOutsideDismissOverlay {
    [[self outsideDismissOverlayView] setUserInteractionEnabled:NO];
    [[self outsideDismissOverlayView] setAlpha:0];
    [[self outsideDismissOverlayView] setHidden:YES];
}

- (void)preparePanDismissAnimationWithTranslation:(CGPoint)translation velocity:(CGPoint)velocity {
    CGFloat visibleTranslationY = MAX([[self panelView] transform].ty, 0);
    CGFloat startingTranslationY = MAX(MAX(translation.y, visibleTranslationY), 0);
    CGFloat targetTranslationY = startingTranslationY + MAX([[self panelView] bounds].size.height / 3, 120);
    [self setPendingDismissTranslationY:targetTranslationY];
    [self setPendingDismissVelocityY:MAX(velocity.y, 0)];
}

- (void)handlePanGestureRecognizer:(UIPanGestureRecognizer *)recognizer {
    if ([[self delegate] panelPresentationControllerShouldHandleFullscreenSearchPan:self]) {
        [[self delegate] panelPresentationController:self handleFullscreenSearchPanGestureRecognizer:recognizer];
        return;
    }

    CGPoint translation = [recognizer translationInView:[self panelView]];
    CGFloat const kFadeOutDistance = 100;
    CGFloat const kFastDismissVelocity = 900;

    if ([recognizer state] == UIGestureRecognizerStateBegan) {
        [self setPanGestureDidReachZeroAlpha:NO];
        [[self outsideDismissOverlayView] setUserInteractionEnabled:NO];
    } else if ([recognizer state] == UIGestureRecognizerStateChanged) {
        [[self outsideDismissOverlayView] setUserInteractionEnabled:NO];

        if (translation.y < 0 && ![self panGestureDidReachZeroAlpha]) {
            return;
        }

        CGFloat fadeProgress = MIN(MAX(translation.y / kFadeOutDistance, 0), 1);
        if ([self panGestureDidReachZeroAlpha] || fadeProgress >= 1) {
            [self setPanGestureDidReachZeroAlpha:YES];
            fadeProgress = 1;
            translation.y = MAX(translation.y, kFadeOutDistance);
        }

        [UIView animateWithDuration:0.1
                              delay:0
             usingSpringWithDamping:0.7
              initialSpringVelocity:0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                           [[self panelView] setTransform:CGAffineTransformMakeTranslation(0, translation.y)];
                           [[self panelView] setAlpha:1 - fadeProgress];
                           [[self outsideDismissOverlayView] setAlpha:1 - fadeProgress];
                         }
                         completion:nil];
    } else if ([recognizer state] == UIGestureRecognizerStateEnded ||
               [recognizer state] == UIGestureRecognizerStateCancelled ||
               [recognizer state] == UIGestureRecognizerStateFailed) {
        BOOL shouldDismiss = [self panGestureDidReachZeroAlpha];
        BOOL shouldUseFastDismissAnimation = NO;
        CGPoint velocity = CGPointZero;
        if ([recognizer state] == UIGestureRecognizerStateEnded) {
            velocity = [recognizer velocityInView:[self panelView]];
            shouldUseFastDismissAnimation =
                ![self panGestureDidReachZeroAlpha] && translation.y > 0 && velocity.y >= kFastDismissVelocity;
            shouldDismiss = shouldDismiss || shouldUseFastDismissAnimation;
        }

        if (!shouldDismiss) {
            [UIView animateWithDuration:0.4
                delay:0
                usingSpringWithDamping:1
                initialSpringVelocity:0
                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                animations:^{
                  [[self panelView] setTransform:CGAffineTransformIdentity];
                  [[self panelView] setAlpha:1];
                  [[self outsideDismissOverlayView] setAlpha:1];
                }
                completion:^(__unused BOOL finished) {
                  [self finishOutsideDismissOverlayShow];
                }];
        } else {
            if (shouldUseFastDismissAnimation) {
                [self preparePanDismissAnimationWithTranslation:translation velocity:velocity];
            }
            [[self delegate] panelPresentationControllerDidRequestDismiss:self];
        }
    }
}

- (CGRect)grabberTapTargetFrame {
    UIView *grabberView = (UIView *)[[self panelView] grabber];
    CGRect grabberFrame = [grabberView frame];
    return CGRectInset(grabberFrame, -44, -16);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer != [self grabberTapGestureRecognizer]) {
        return YES;
    }

    CGPoint location = [touch locationInView:[[self panelView] headerView]];
    return CGRectContainsPoint([self grabberTapTargetFrame], location);
}

- (void)handleGrabberTapGestureRecognizer:(UITapGestureRecognizer *)recognizer {
    if ([recognizer state] != UIGestureRecognizerStateEnded) {
        return;
    }

    [[self delegate] panelPresentationControllerDidTapGrabberArea:self];
}

- (void)showPanelWithCompletion:(void (^)(void))completion {
    if ([self isAnimating]) {
        return;
    }

    [[self panelView] setTransform:CGAffineTransformMakeTranslation(0, [[self panelView] bounds].size.height / 3)];
    [[self panelView] setAlpha:0];
    [[self panelView] setHidden:NO];
    [self prepareOutsideDismissOverlayForShow];

    [self setAnimating:YES];
    [UIView animateWithDuration:0.33
        delay:0
        usingSpringWithDamping:1
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          [[self panelView] setTransform:CGAffineTransformIdentity];
          [[self panelView] setAlpha:1];
          [[self outsideDismissOverlayView] setAlpha:1];
        }
        completion:^(__unused BOOL finished) {
          [self setAnimating:NO];
          [self finishOutsideDismissOverlayShow];
          if (completion) {
              completion();
          }
        }];
}

- (void)hidePanelWithCompletion:(void (^)(void))completion {
    if ([self isAnimating]) {
        return;
    }

    [[self outsideDismissOverlayView] setUserInteractionEnabled:NO];
    CGFloat dismissTranslationY = [self pendingDismissTranslationY];
    CGFloat dismissVelocityY = [self pendingDismissVelocityY];
    [self setPendingDismissTranslationY:0];
    [self setPendingDismissVelocityY:0];

    [self setAnimating:YES];
    CGFloat animationDuration = 0.33;
    CGFloat initialSpringVelocity = 0;
    if (dismissTranslationY > 0 && dismissVelocityY > 0) {
        CGFloat currentTranslationY = MAX([[self panelView] transform].ty, 0);
        CGFloat remainingDistance = MAX(dismissTranslationY - currentTranslationY, 1);
        CGFloat effectiveVelocityY = MAX(dismissVelocityY, 900);
        animationDuration = MIN(MAX(remainingDistance / effectiveVelocityY, 0.12), 0.33);
        initialSpringVelocity = effectiveVelocityY / remainingDistance;
    }

    [UIView animateWithDuration:animationDuration
        delay:0
        usingSpringWithDamping:1
        initialSpringVelocity:initialSpringVelocity
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          if (dismissTranslationY > 0) {
              [[self panelView] setTransform:CGAffineTransformMakeTranslation(0, dismissTranslationY)];
          }
          [[self panelView] setAlpha:0];
          [[self outsideDismissOverlayView] setAlpha:0];
        }
        completion:^(__unused BOOL finished) {
          [[self panelView] setHidden:YES];
          [self hideOutsideDismissOverlay];
          [self setAnimating:NO];
          if (completion) {
              completion();
          }
        }];
}

- (void)hidePanelImmediatelyWithCompletion:(void (^)(void))completion {
    [[[self panelView] layer] removeAllAnimations];
    [[[self outsideDismissOverlayView] layer] removeAllAnimations];
    [[self outsideDismissOverlayView] setUserInteractionEnabled:NO];
    [self setPendingDismissTranslationY:0];
    [self setPendingDismissVelocityY:0];
    [self setAnimating:NO];

    [[self panelView] setTransform:CGAffineTransformIdentity];
    [[self panelView] setAlpha:0];
    [[self panelView] setHidden:YES];
    [self hideOutsideDismissOverlay];

    if (completion) {
        completion();
    }
}

- (void)triggerHapticFeedbackWithStyle:(UIImpactFeedbackStyle)style {
    if (![self shouldPlayFeedback]) {
        return;
    }
    [self setFeedbackGenerator:[[UIImpactFeedbackGenerator alloc] initWithStyle:style]];
    [[self feedbackGenerator] prepare];
    [[self feedbackGenerator] impactOccurred];
    [self setFeedbackGenerator:nil];
}

@end
