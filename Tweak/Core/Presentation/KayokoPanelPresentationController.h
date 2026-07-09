//
//  KayokoPanelPresentationController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

#import "KayokoPanelPresentationMode.h"

@class KayokoPanelPresentationController;
@class KayokoHeaderView;
@class KayokoMainView;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoPanelPresentationControllerDelegate <NSObject>

- (void)panelPresentationControllerDidRequestDismiss:(KayokoPanelPresentationController *)controller;
- (void)panelPresentationControllerDidTapGrabberArea:(KayokoPanelPresentationController *)controller;
- (BOOL)panelPresentationControllerShouldHandleFullscreenSearchPan:(KayokoPanelPresentationController *)controller;
- (BOOL)panelPresentationController:(KayokoPanelPresentationController *)controller
    shouldBeginExpandedPanelPanFromView:(nullable UIView *)view
                               velocity:(CGPoint)velocity;
- (void)panelPresentationController:(KayokoPanelPresentationController *)controller
    handleFullscreenSearchPanGestureRecognizer:(UIPanGestureRecognizer *)recognizer
                                    headerView:(nullable KayokoHeaderView *)headerView;

@end

@interface KayokoPanelPresentationController : NSObject

@property(nonatomic, weak, nullable) id<KayokoPanelPresentationControllerDelegate> delegate;
@property(nonatomic, assign, getter=isDismissOnOutsideTouch) BOOL dismissOnOutsideTouch;
@property(nonatomic, assign) BOOL shouldPlayFeedback;
@property(nonatomic, assign) KayokoPanelPresentationMode presentationMode;
@property(nonatomic, strong, readonly) UIPanGestureRecognizer *panGestureRecognizer;
@property(nonatomic, assign, readonly, getter=isAnimating) BOOL animating;

- (instancetype)initWithPanelView:(KayokoMainView *)panelView;
- (void)registerHeaderView:(KayokoHeaderView *)headerView;
- (void)setOutsideDismissOverlayView:(nullable UIControl *)outsideDismissOverlayView;
- (void)prepareStandardDismissAnimation;
- (void)showPanelWithCompletion:(nullable void (^)(void))completion;
- (void)hidePanelWithCompletion:(nullable void (^)(void))completion;
- (void)hidePanelWithAnimationStyle:(KayokoPanelHideAnimationStyle)animationStyle
                         completion:(nullable void (^)(void))completion;
- (void)hidePanelImmediatelyWithCompletion:(nullable void (^)(void))completion;
- (void)finishOutsideDismissOverlayShow;
- (void)triggerHapticFeedbackWithStyle:(UIImpactFeedbackStyle)style;

@end

NS_ASSUME_NONNULL_END
