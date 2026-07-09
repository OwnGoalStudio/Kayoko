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

@class KayokoGrabberView;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoMainView : UIView

@property(nonatomic, strong) UIBlurEffect *blurEffect;
@property(nonatomic, strong) UIVisualEffectView *blurEffectView;
@property(nonatomic, strong) UIView *headerView;
@property(nonatomic, strong) UIView *contentContainerView;
@property(nonatomic, strong) KayokoGrabberView *grabber;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIControl *titleTapControl;
@property(nonatomic, strong) UIButton *clearButton;
@property(nonatomic, strong) UIButton *backButton;
@property(nonatomic, strong) UIButton *favoritesButton;
@property(nonatomic, assign, getter=isAnimating) BOOL animating;
@property(nonatomic, assign) BOOL contentRespectsSafeArea;
@property(nonatomic, assign) UIEdgeInsets contentSafeAreaAdditionalInsets;
@property(nonatomic, assign, getter=isSearchTitleRowCollapsed) BOOL searchTitleRowCollapsed;

- (void)updateStyleForHeaderButton:(UIButton *)button
                     withImageName:(NSString *)imageName
                      andImageSize:(NSUInteger)imageSize
                      andTintColor:(UIColor *)color;
- (void)setTitleText:(NSString *)title;
- (void)setClearButtonEnabledForItemCount:(NSUInteger)itemCount;
- (void)setGrabberFoldProgress:(CGFloat)progress;
- (UIEdgeInsets)effectiveContentSafeAreaInsets;
- (CGFloat)safeAreaBottomInsetForContentView:(nullable UIView *)contentView;
- (void)installContentView:(UIView *)contentView hidden:(BOOL)hidden;
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
            willAnimate:(nullable void (^)(void))willAnimate
             completion:(nullable void (^)(void))completion;
- (void)prepareContentTransitionToView:(UIView *)viewToShow
                       hideContentView:(UIView *)viewToHide
                                 title:(NSString *)title
                             direction:(KayokoContentTransitionDirection)direction;
- (void)applyPreparedContentTransitionToView:(UIView *)viewToShow
                             hideContentView:(UIView *)viewToHide
                                   direction:(KayokoContentTransitionDirection)direction;
- (void)completePreparedContentTransitionHidingView:(UIView *)viewToHide completion:(nullable void (^)(void))completion;
- (void)beginInteractiveBackwardContentTransitionToView:(UIView *)viewToShow hideContentView:(UIView *)viewToHide;
- (void)updateInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                         hideContentView:(UIView *)viewToHide
                                                progress:(CGFloat)progress;
- (void)finishInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                         hideContentView:(UIView *)viewToHide
                                                   title:(NSString *)title
                                                duration:(NSTimeInterval)duration
                                              completion:(nullable void (^)(void))completion;
- (void)cancelInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                         hideContentView:(UIView *)viewToHide
                                                duration:(NSTimeInterval)duration
                                              completion:(nullable void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
