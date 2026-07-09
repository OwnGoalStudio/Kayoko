//
//  KayokoMainView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, KayokoContentTransitionDirection) {
    KayokoContentTransitionDirectionForward,
    KayokoContentTransitionDirectionBackward,
    KayokoContentTransitionDirectionSiblingForward,
    KayokoContentTransitionDirectionSiblingBackward,
    KayokoContentTransitionDirectionModalPresenting,
    KayokoContentTransitionDirectionModalDismissing,
};

@class KayokoHeaderView;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoMainView : UIView

@property(nonatomic, strong) UIBlurEffect *blurEffect;
@property(nonatomic, strong) UIVisualEffectView *blurEffectView;
@property(nonatomic, strong) KayokoHeaderView *headerView;
@property(nonatomic, strong) UIView *contentContainerView;
@property(nonatomic, assign, getter=isAnimating) BOOL animating;
@property(nonatomic, assign) BOOL contentRespectsSafeArea;
@property(nonatomic, assign) UIEdgeInsets contentSafeAreaAdditionalInsets;
@property(nonatomic, assign, getter=isSearchTitleRowCollapsed) BOOL searchTitleRowCollapsed;

- (void)setTitleText:(NSString *)title;
- (void)setClearButtonEnabledForItemCount:(NSUInteger)itemCount;
- (UIEdgeInsets)effectiveContentSafeAreaInsets;
- (CGFloat)safeAreaBottomInsetForContentView:(nullable UIView *)contentView;
- (void)installContentView:(UIView *)contentView hidden:(BOOL)hidden;
- (void)installFullContentView:(UIView *)contentView headerView:(KayokoHeaderView *)headerView hidden:(BOOL)hidden;
- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(NSString *)title
              direction:(KayokoContentTransitionDirection)direction;
- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(NSString *)title
              direction:(KayokoContentTransitionDirection)direction
             completion:(nullable void (^)(void))completion;
- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(NSString *)title
              direction:(KayokoContentTransitionDirection)direction
    alongsideAnimations:(nullable void (^)(void))alongsideAnimations
             completion:(nullable void (^)(void))completion;
- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(nullable NSString *)title
           updatesTitle:(BOOL)updatesTitle
              direction:(KayokoContentTransitionDirection)direction
    alongsideAnimations:(nullable void (^)(void))alongsideAnimations
             completion:(nullable void (^)(void))completion;
- (void)showContentView:(UIView *)viewToShow
      transitioningView:(UIView *)viewToShowTransition
        hideContentView:(UIView *)viewToHide
      transitioningView:(UIView *)viewToHideTransition
              direction:(KayokoContentTransitionDirection)direction
    alongsideAnimations:(nullable void (^)(void))alongsideAnimations
             completion:(nullable void (^)(void))completion;
- (void)prepareContentTransitionToView:(UIView *)viewToShow
                       hideContentView:(UIView *)viewToHide
                                 title:(NSString *)title
                             direction:(KayokoContentTransitionDirection)direction;
- (void)prepareContentTransitionToView:(UIView *)viewToShow
                       hideContentView:(UIView *)viewToHide
                                 title:(nullable NSString *)title
                          updatesTitle:(BOOL)updatesTitle
                             direction:(KayokoContentTransitionDirection)direction;
- (void)applyPreparedContentTransitionToView:(UIView *)viewToShow
                             hideContentView:(UIView *)viewToHide
                                   direction:(KayokoContentTransitionDirection)direction;
- (void)completePreparedContentTransitionHidingView:(UIView *)viewToHide completion:(nullable void (^)(void))completion;
- (void)beginInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                    alongsideViewToShow:(UIView *)viewToShowAlongside
                                        hideContentView:(UIView *)viewToHide;
- (void)updateInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                     alongsideViewToShow:(UIView *)viewToShowAlongside
                                         hideContentView:(UIView *)viewToHide
                                                progress:(CGFloat)progress;
- (void)finishInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                     alongsideViewToShow:(UIView *)viewToShowAlongside
                                         hideContentView:(UIView *)viewToHide
                                                duration:(NSTimeInterval)duration
                                     alongsideAnimations:(nullable void (^)(void))alongsideAnimations
                                              completion:(nullable void (^)(void))completion;
- (void)cancelInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                     alongsideViewToShow:(UIView *)viewToShowAlongside
                                         hideContentView:(UIView *)viewToHide
                                                duration:(NSTimeInterval)duration
                                              completion:(nullable void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
