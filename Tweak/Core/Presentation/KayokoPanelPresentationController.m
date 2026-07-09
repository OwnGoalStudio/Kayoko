//
//  KayokoPanelPresentationController.m
//  Kayoko
//

#import "KayokoPanelPresentationController.h"

#import "KayokoHeaderView.h"
#import "KayokoMainView.h"

static CGFloat const kKayokoPanelPanScrollViewTopTolerance = 0.5;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPanelPresentationController () <UIGestureRecognizerDelegate>

#pragma mark - Views

@property(nonatomic, weak) KayokoMainView *panelView;
@property(nonatomic, strong, nullable) UIControl *outsideDismissOverlayView;

#pragma mark - Gestures

@property(nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property(nonatomic, weak, nullable) UIView *panGestureTouchView;
@property(nonatomic, strong) NSHashTable<KayokoHeaderView *> *headerViews;
@property(nonatomic, strong)
    NSHashTable<UIGestureRecognizer *> *scrollViewPanGestureRecognizersRequiringPanelPanFailure;

#pragma mark - Feedback

@property(nonatomic, strong, nullable) UIImpactFeedbackGenerator *feedbackGenerator;

#pragma mark - Dismissal State

@property(nonatomic, assign) BOOL panGestureDidReachZeroAlpha;
@property(nonatomic, assign) CGFloat pendingDismissTranslationY;
@property(nonatomic, assign) CGFloat pendingDismissVelocityY;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoPanelPresentationController

#pragma mark - Lifecycle

- (instancetype)initWithPanelView:(KayokoMainView *)panelView {
    self = [super init];
    if (self) {
        _panelView = panelView;
        _presentationMode = KayokoPanelPresentationModePortraitDrawer;
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(handlePanGestureRecognizer:)];
        [_panGestureRecognizer setDelegate:self];
        [panelView addGestureRecognizer:_panGestureRecognizer];
        _headerViews = [NSHashTable weakObjectsHashTable];
        _scrollViewPanGestureRecognizersRequiringPanelPanFailure = [NSHashTable weakObjectsHashTable];
        [self registerHeaderView:[panelView headerView]];
    }
    return self;
}

- (void)registerHeaderView:(KayokoHeaderView *)headerView {
    if (!headerView || [[self headerViews] containsObject:headerView]) {
        return;
    }

    [[self headerViews] addObject:headerView];
    UITapGestureRecognizer *recognizer =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleGrabberTapGestureRecognizer:)];
    [recognizer setCancelsTouchesInView:NO];
    [recognizer setDelegate:self];
    [headerView addGestureRecognizer:recognizer];
}

#pragma mark - State

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

#pragma mark - Dismissal Preparation

- (void)prepareStandardDismissAnimation {
    CGFloat targetTranslationY = MAX([[self panelView] bounds].size.height / 3, 120);
    [self setPendingDismissTranslationY:targetTranslationY];
    [self setPendingDismissVelocityY:0];
}

#pragma mark - Outside Dismiss Overlay

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

#pragma mark - Pan Gesture

- (void)preparePanDismissAnimationWithTranslation:(CGPoint)translation velocity:(CGPoint)velocity {
    CGFloat visibleTranslationY = MAX([[self panelView] transform].ty, 0);
    CGFloat startingTranslationY = MAX(MAX(translation.y, visibleTranslationY), 0);
    CGFloat targetTranslationY = startingTranslationY + MAX([[self panelView] bounds].size.height / 3, 120);
    [self setPendingDismissTranslationY:targetTranslationY];
    [self setPendingDismissVelocityY:MAX(velocity.y, 0)];
}

- (UIView *)viewForPanelPanGestureRecognizer:(UIPanGestureRecognizer *)recognizer {
    UIView *touchView = [self panGestureTouchView];
    if (touchView) {
        return touchView;
    }

    return [[self panelView] hitTest:[recognizer locationInView:[self panelView]] withEvent:nil];
}

- (BOOL)scrollViewParticipatesInVerticalPanelPanGate:(UIScrollView *)scrollView {
    if (![scrollView isScrollEnabled]) {
        return NO;
    }

    UIEdgeInsets adjustedInset = [scrollView adjustedContentInset];
    CGFloat visibleHeight = CGRectGetHeight([scrollView bounds]) - adjustedInset.top - adjustedInset.bottom;
    CGFloat contentHeight = [scrollView contentSize].height;
    return [scrollView alwaysBounceVertical] || contentHeight > visibleHeight + kKayokoPanelPanScrollViewTopTolerance;
}

- (nullable UIScrollView *)verticalPanelPanGateScrollViewFromView:(UIView *)view {
    UIView *currentView = view;
    while (currentView && currentView != [self panelView]) {
        if ([currentView isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *)currentView;
            if ([self scrollViewParticipatesInVerticalPanelPanGate:scrollView]) {
                return scrollView;
            }
        }
        currentView = [currentView superview];
    }

    return nil;
}

- (void)makeScrollViewPanGestureRecognizerWaitForPanelPanIfNeeded:(UIScrollView *)scrollView {
    UIGestureRecognizer *scrollViewPanGestureRecognizer = [scrollView panGestureRecognizer];
    if (!scrollViewPanGestureRecognizer || [[self scrollViewPanGestureRecognizersRequiringPanelPanFailure]
                                               containsObject:scrollViewPanGestureRecognizer]) {
        return;
    }

    [scrollViewPanGestureRecognizer requireGestureRecognizerToFail:[self panGestureRecognizer]];
    [[self scrollViewPanGestureRecognizersRequiringPanelPanFailure] addObject:scrollViewPanGestureRecognizer];
}

- (BOOL)view:(UIView *)view isDescendantOfView:(UIView *)ancestorView {
    UIView *currentView = view;
    while (currentView) {
        if (currentView == ancestorView) {
            return YES;
        }
        currentView = [currentView superview];
    }

    return NO;
}

- (nullable KayokoHeaderView *)headerViewContainingView:(UIView *)view {
    for (KayokoHeaderView *headerView in [self headerViews]) {
        if ([self view:view isDescendantOfView:headerView]) {
            return headerView;
        }
    }
    return nil;
}

- (BOOL)isScrollViewAtTopBoundary:(UIScrollView *)scrollView {
    CGFloat topBoundary = -[scrollView adjustedContentInset].top;
    return [scrollView contentOffset].y <= topBoundary + kKayokoPanelPanScrollViewTopTolerance;
}

- (nullable KayokoHeaderView *)currentPanGestureHeaderView {
    return [self headerViewContainingView:[self panGestureTouchView]];
}

- (BOOL)shouldBeginPanelPanGestureRecognizer:(UIPanGestureRecognizer *)recognizer {
    if ([[self panelView] isHidden] || [self isAnimating]) {
        return NO;
    }

    CGPoint velocity = [recognizer velocityInView:[self panelView]];
    if (velocity.y <= 0 || fabs(velocity.x) >= fabs(velocity.y)) {
        return NO;
    }

    UIView *touchView = [self viewForPanelPanGestureRecognizer:recognizer];
    if ([self headerViewContainingView:touchView]) {
        return YES;
    }

    if (![[self delegate] panelPresentationController:self
                  shouldBeginExpandedPanelPanFromView:touchView
                                             velocity:velocity]) {
        return NO;
    }

    UIScrollView *scrollView = [self verticalPanelPanGateScrollViewFromView:touchView];
    return !scrollView || [self isScrollViewAtTopBoundary:scrollView];
}

- (void)handlePanGestureRecognizer:(UIPanGestureRecognizer *)recognizer {
    if ([[self delegate] panelPresentationControllerShouldHandleFullscreenSearchPan:self]) {
        [[self delegate] panelPresentationController:self
            handleFullscreenSearchPanGestureRecognizer:recognizer
                                            headerView:[self currentPanGestureHeaderView]];
        if ([recognizer state] == UIGestureRecognizerStateEnded ||
            [recognizer state] == UIGestureRecognizerStateCancelled ||
            [recognizer state] == UIGestureRecognizerStateFailed) {
            [self setPanGestureTouchView:nil];
        }
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
            shouldUseFastDismissAnimation = [self currentPanGestureHeaderView] != nil &&
                                            ![self panGestureDidReachZeroAlpha] && translation.y > 0 &&
                                            velocity.y >= kFastDismissVelocity;
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
        [self setPanGestureTouchView:nil];
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (CGRect)grabberTapTargetFrameInHeaderView:(KayokoHeaderView *)headerView {
    UIView *grabberView = (UIView *)[headerView grabber];
    CGRect grabberFrame = [grabberView convertRect:[grabberView bounds] toView:headerView];
    return CGRectInset(grabberFrame, -44, -16);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer == [self panGestureRecognizer]) {
        [self setPanGestureTouchView:[touch view]];
        UIScrollView *scrollView = [self verticalPanelPanGateScrollViewFromView:[touch view]];
        if (scrollView) {
            [self makeScrollViewPanGestureRecognizerWaitForPanelPanIfNeeded:scrollView];
        }
        return YES;
    }

    UIView *gestureView = [gestureRecognizer view];
    if (![gestureView isKindOfClass:[KayokoHeaderView class]] ||
        ![[self headerViews] containsObject:(KayokoHeaderView *)gestureView]) {
        return YES;
    }

    KayokoHeaderView *headerView = (KayokoHeaderView *)gestureView;
    CGPoint location = [touch locationInView:headerView];
    return CGRectContainsPoint([self grabberTapTargetFrameInHeaderView:headerView], location);
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == [self panGestureRecognizer]) {
        return [self shouldBeginPanelPanGestureRecognizer:(UIPanGestureRecognizer *)gestureRecognizer];
    }

    return YES;
}

- (void)handleGrabberTapGestureRecognizer:(UITapGestureRecognizer *)recognizer {
    if ([recognizer state] != UIGestureRecognizerStateEnded) {
        return;
    }

    [[self delegate] panelPresentationControllerDidTapGrabberArea:self];
}

#pragma mark - Presentation

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
    [self hidePanelWithAnimationStyle:KayokoPanelHideAnimationStyleDefault completion:completion];
}

- (void)hidePanelWithAnimationStyle:(KayokoPanelHideAnimationStyle)animationStyle
                         completion:(void (^)(void))completion {
    if ([self isAnimating]) {
        return;
    }

    [[self outsideDismissOverlayView] setUserInteractionEnabled:NO];
    CGFloat dismissTranslationY = [self pendingDismissTranslationY];
    CGFloat dismissVelocityY = [self pendingDismissVelocityY];
    [self setPendingDismissTranslationY:0];
    [self setPendingDismissVelocityY:0];

    if (animationStyle == KayokoPanelHideAnimationStyleFade) {
        dismissTranslationY = 0;
        dismissVelocityY = 0;
    }

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

#pragma mark - Feedback

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
