//
//  KayokoMainView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoMainView.h"

#import "KayokoHeaderView.h"
#import "KayokoHeaderButtonStyle.h"
#import "KayokoPasteboardManager.h"

@interface KayokoMainView ()

#pragma mark - Header Constraints

@property(nonatomic, strong) NSLayoutConstraint *headerTopConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerSafeAreaTopConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerLeadingConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerSafeAreaLeadingConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerTrailingConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerSafeAreaTrailingConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerHeightConstraint;

#pragma mark - Content Constraints

@property(nonatomic, strong) NSLayoutConstraint *contentTopConstraint;
@property(nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *contentLeadingConstraints;
@property(nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *contentSafeAreaLeadingConstraints;
@property(nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *contentTrailingConstraints;
@property(nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *contentSafeAreaTrailingConstraints;
@property(nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *contentBottomConstraints;
@property(nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *contentSafeAreaBottomConstraints;
@end

@implementation KayokoMainView

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        [self setHidden:YES];
        [self setContentLeadingConstraints:[[NSMutableArray alloc] init]];
        [self setContentSafeAreaLeadingConstraints:[[NSMutableArray alloc] init]];
        [self setContentTrailingConstraints:[[NSMutableArray alloc] init]];
        [self setContentSafeAreaTrailingConstraints:[[NSMutableArray alloc] init]];
        [self setContentBottomConstraints:[[NSMutableArray alloc] init]];
        [self setContentSafeAreaBottomConstraints:[[NSMutableArray alloc] init]];

        [[self layer] setShadowColor:[[UIColor blackColor] CGColor]];
        [[self layer] setShadowOffset:CGSizeMake(0, -4)];
        [[self layer] setShadowRadius:18];
        [[self layer] setShadowOpacity:0.18];

        [self setBlurEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular]];
        [self setBlurEffectView:[[UIVisualEffectView alloc] initWithEffect:[self blurEffect]]];
        [self addSubview:[self blurEffectView]];

        [[self blurEffectView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self blurEffectView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self blurEffectView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self blurEffectView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self blurEffectView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        NSString *historyTitle = [[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"History"
                                                                                                 value:nil
                                                                                                 table:@"Tweak"];
        [self setHeaderView:[[KayokoHeaderView alloc] initWithTitle:historyTitle]];
        [self addSubview:[self headerView]];

        [[self headerView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self setHeaderTopConstraint:[[[self headerView] topAnchor] constraintEqualToAnchor:[self topAnchor]]];
        [self setHeaderSafeAreaTopConstraint:[[[self headerView] topAnchor]
                                                 constraintEqualToAnchor:[[self safeAreaLayoutGuide] topAnchor]]];
        [self setHeaderLeadingConstraint:[[[self headerView] leadingAnchor]
                                             constraintEqualToAnchor:[self leadingAnchor]]];
        [self
            setHeaderSafeAreaLeadingConstraint:[[[self headerView] leadingAnchor]
                                                   constraintEqualToAnchor:[[self safeAreaLayoutGuide] leadingAnchor]]];
        [self setHeaderTrailingConstraint:[[[self headerView] trailingAnchor]
                                              constraintEqualToAnchor:[self trailingAnchor]]];
        [self setHeaderSafeAreaTrailingConstraint:[[[self headerView] trailingAnchor]
                                                      constraintEqualToAnchor:[[self safeAreaLayoutGuide]
                                                                                  trailingAnchor]]];
        [self setHeaderHeightConstraint:[[[self headerView] heightAnchor]
                                            constraintEqualToConstant:[KayokoHeaderView preferredHeight]]];
        [NSLayoutConstraint activateConstraints:@[
            [self headerHeightConstraint], [self headerTopConstraint], [self headerLeadingConstraint],
            [self headerTrailingConstraint]
        ]];

        [[self headerView] updateStyleForButton:[[self headerView] leadingButton]
                                  withImageName:@"heart"
                                       imageSize:kKayokoFavoritesButtonImageSize
                                      tintColor:[UIColor labelColor]];
        [[self headerView] updateStyleForButton:[[self headerView] trailingButton]
                                  withImageName:@"trash"
                                       imageSize:kKayokoClearButtonImageSize
                                      tintColor:[UIColor labelColor]];
        [[self headerView] updateStyleForButton:[[self headerView] alternateTrailingButton]
                                  withImageName:@"arrowshape.turn.up.backward"
                                       imageSize:kKayokoBackButtonImageSize
                                      tintColor:[UIColor labelColor]];

        [self setContentContainerView:[[UIView alloc] init]];
        [[self contentContainerView] setClipsToBounds:YES];
        [self addSubview:[self contentContainerView]];

        [[self contentContainerView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        NSLayoutConstraint *leadingConstraint =
            [[[self contentContainerView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]];
        NSLayoutConstraint *safeAreaLeadingConstraint = [[[self contentContainerView] leadingAnchor]
            constraintEqualToAnchor:[[self safeAreaLayoutGuide] leadingAnchor]];
        NSLayoutConstraint *trailingConstraint =
            [[[self contentContainerView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]];
        NSLayoutConstraint *safeAreaTrailingConstraint = [[[self contentContainerView] trailingAnchor]
            constraintEqualToAnchor:[[self safeAreaLayoutGuide] trailingAnchor]];
        NSLayoutConstraint *bottomConstraint =
            [[[self contentContainerView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]];
        NSLayoutConstraint *safeAreaBottomConstraint = [[[self contentContainerView] bottomAnchor]
            constraintEqualToAnchor:[[self safeAreaLayoutGuide] bottomAnchor]];
        [[self contentLeadingConstraints] addObject:leadingConstraint];
        [[self contentSafeAreaLeadingConstraints] addObject:safeAreaLeadingConstraint];
        [[self contentTrailingConstraints] addObject:trailingConstraint];
        [[self contentSafeAreaTrailingConstraints] addObject:safeAreaTrailingConstraint];
        [[self contentBottomConstraints] addObject:bottomConstraint];
        [[self contentSafeAreaBottomConstraints] addObject:safeAreaBottomConstraint];
        [self setContentTopConstraint:[[[self contentContainerView] topAnchor]
                                          constraintEqualToAnchor:[[self headerView] bottomAnchor]
                                                         constant:kKayokoHeaderContentSpacing]];
        [NSLayoutConstraint activateConstraints:@[
            [self contentTopConstraint], [self contentRespectsSafeArea] ? safeAreaLeadingConstraint : leadingConstraint,
            [self contentRespectsSafeArea] ? safeAreaTrailingConstraint : trailingConstraint, bottomConstraint
        ]];
    }

    return self;
}

#pragma mark - Layout

- (void)setSearchTitleRowCollapsed:(BOOL)searchTitleRowCollapsed {
    if (_searchTitleRowCollapsed == searchTitleRowCollapsed) {
        return;
    }

    _searchTitleRowCollapsed = searchTitleRowCollapsed;
    [[self headerHeightConstraint] setConstant:searchTitleRowCollapsed ? 0 : [KayokoHeaderView preferredHeight]];
    [[self contentTopConstraint] setConstant:searchTitleRowCollapsed ? 0 : kKayokoHeaderContentSpacing];
    [[self headerView] setUserInteractionEnabled:!searchTitleRowCollapsed];
    [self setNeedsLayout];
}

#pragma mark - Content Installation

- (void)constrainContentView:(UIView *)contentView {
    [contentView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[
        [[contentView topAnchor] constraintEqualToAnchor:[[self contentContainerView] topAnchor]],
        [[contentView leadingAnchor] constraintEqualToAnchor:[[self contentContainerView] leadingAnchor]],
        [[contentView trailingAnchor] constraintEqualToAnchor:[[self contentContainerView] trailingAnchor]],
        [[contentView bottomAnchor] constraintEqualToAnchor:[[self contentContainerView] bottomAnchor]]
    ]];
}

- (void)installContentView:(UIView *)contentView hidden:(BOOL)hidden {
    [contentView setHidden:hidden];
    [[self contentContainerView] addSubview:contentView];
    [self constrainContentView:contentView];
}

- (void)installFullContentView:(UIView *)contentView headerView:(KayokoHeaderView *)headerView hidden:(BOOL)hidden {
    [contentView setHidden:hidden];
    [self addSubview:contentView];
    [contentView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[
        [[contentView topAnchor] constraintEqualToAnchor:[self topAnchor]],
        [[contentView leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
        [[contentView trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
        [[contentView bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]],
        [[headerView topAnchor] constraintEqualToAnchor:[[self headerView] topAnchor]],
        [[headerView leadingAnchor] constraintEqualToAnchor:[[self headerView] leadingAnchor]],
        [[headerView trailingAnchor] constraintEqualToAnchor:[[self headerView] trailingAnchor]]
    ]];
}

#pragma mark - Content Safe Area

- (UIEdgeInsets)effectiveContentSafeAreaInsets {
    UIEdgeInsets safeAreaInsets = [self safeAreaInsets];
    UIEdgeInsets additionalInsets = [self contentSafeAreaAdditionalInsets];
    safeAreaInsets.top += additionalInsets.top;
    safeAreaInsets.left += additionalInsets.left;
    safeAreaInsets.bottom += additionalInsets.bottom;
    safeAreaInsets.right += additionalInsets.right;
    return safeAreaInsets;
}

- (CGFloat)sceneSafeAreaBottomInsetForWindow:(UIWindow *)window {
    UIWindowScene *windowScene = [window windowScene];
    CGSize targetBoundsSize = [window bounds].size;
    CGFloat firstVisibleBottomInset = 0;
    CGFloat matchingVisibleBottomInset = 0;
    for (UIWindow *sceneWindow in [windowScene windows]) {
        if ([sceneWindow isHidden]) {
            continue;
        }

        CGFloat bottomInset = MAX([sceneWindow safeAreaInsets].bottom, 0);
        if (bottomInset > 0) {
            if (firstVisibleBottomInset <= 0) {
                firstVisibleBottomInset = bottomInset;
            }

            CGSize sceneWindowBoundsSize = [sceneWindow bounds].size;
            if (fabs(sceneWindowBoundsSize.width - targetBoundsSize.width) <= 0.5 &&
                fabs(sceneWindowBoundsSize.height - targetBoundsSize.height) <= 0.5) {
                matchingVisibleBottomInset = MAX(matchingVisibleBottomInset, bottomInset);
            }
        }
    }

    return matchingVisibleBottomInset > 0 ? matchingVisibleBottomInset : firstVisibleBottomInset;
}

- (CGFloat)safeAreaBottomInsetForContentView:(nullable UIView *)contentView {
    UIView *referenceView = contentView ?: self;
    if (contentView && [contentView isDescendantOfView:[self contentContainerView]]) {
        // Content transitions temporarily offset installed content views; the safe-area overlap belongs to the
        // stable content container.
        referenceView = [self contentContainerView];
    }

    UIWindow *window = [referenceView window] ?: [self window];
    CGFloat viewBottomSafeAreaInset = MAX([referenceView safeAreaInsets].bottom, 0);
    CGFloat windowBottomSafeAreaInset =
        MAX(MAX([window safeAreaInsets].bottom, [self sceneSafeAreaBottomInsetForWindow:window]), 0);
    if (!referenceView || !window) {
        return viewBottomSafeAreaInset;
    }
    if (windowBottomSafeAreaInset <= 0) {
        return viewBottomSafeAreaInset;
    }

    CGRect referenceBoundsInWindow = [referenceView convertRect:[referenceView bounds] toView:window];
    CGFloat safeAreaBottomY = CGRectGetMaxY([window bounds]) - windowBottomSafeAreaInset;
    CGFloat unsafeBottomOverlap = CGRectGetMaxY(referenceBoundsInWindow) - safeAreaBottomY;
    return ceil(MIN(MAX(unsafeBottomOverlap, 0), windowBottomSafeAreaInset));
}

- (UIEdgeInsets)contentSafeAreaAdditionalInsetsRemovingRedundantSystemInsets:(UIEdgeInsets)additionalInsets {
    UIEdgeInsets safeAreaInsets = [self safeAreaInsets];
    if (safeAreaInsets.top > 0) {
        additionalInsets.top = 0;
    }
    if (safeAreaInsets.left > 0) {
        additionalInsets.left = 0;
    }
    if (safeAreaInsets.bottom > 0) {
        additionalInsets.bottom = 0;
    }
    if (safeAreaInsets.right > 0) {
        additionalInsets.right = 0;
    }
    return additionalInsets;
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    UIEdgeInsets normalizedInsets =
        [self contentSafeAreaAdditionalInsetsRemovingRedundantSystemInsets:[self contentSafeAreaAdditionalInsets]];
    if (!UIEdgeInsetsEqualToEdgeInsets(normalizedInsets, [self contentSafeAreaAdditionalInsets])) {
        [self setContentSafeAreaAdditionalInsets:normalizedInsets];
    }
}

- (void)applyContentSafeAreaAdditionalInsets {
    UIEdgeInsets insets = [self contentSafeAreaAdditionalInsets];
    [[self headerSafeAreaTopConstraint] setConstant:insets.top];
    [[self headerSafeAreaLeadingConstraint] setConstant:insets.left];
    [[self headerSafeAreaTrailingConstraint] setConstant:-insets.right];
    for (NSLayoutConstraint *constraint in [self contentSafeAreaLeadingConstraints]) {
        [constraint setConstant:insets.left];
    }
    for (NSLayoutConstraint *constraint in [self contentSafeAreaTrailingConstraints]) {
        [constraint setConstant:-insets.right];
    }
    for (NSLayoutConstraint *constraint in [self contentSafeAreaBottomConstraints]) {
        [constraint setConstant:-insets.bottom];
    }
}

- (void)setContentSafeAreaAdditionalInsets:(UIEdgeInsets)contentSafeAreaAdditionalInsets {
    contentSafeAreaAdditionalInsets =
        [self contentSafeAreaAdditionalInsetsRemovingRedundantSystemInsets:contentSafeAreaAdditionalInsets];
    if (UIEdgeInsetsEqualToEdgeInsets(_contentSafeAreaAdditionalInsets, contentSafeAreaAdditionalInsets)) {
        return;
    }

    _contentSafeAreaAdditionalInsets = contentSafeAreaAdditionalInsets;
    [self applyContentSafeAreaAdditionalInsets];
    [self setNeedsLayout];
}

- (void)setContentRespectsSafeArea:(BOOL)contentRespectsSafeArea {
    if (_contentRespectsSafeArea == contentRespectsSafeArea) {
        return;
    }

    _contentRespectsSafeArea = contentRespectsSafeArea;
    [self applyContentSafeAreaAdditionalInsets];
    [[self headerTopConstraint] setActive:!contentRespectsSafeArea];
    [[self headerSafeAreaTopConstraint] setActive:contentRespectsSafeArea];
    [[self headerLeadingConstraint] setActive:!contentRespectsSafeArea];
    [[self headerSafeAreaLeadingConstraint] setActive:contentRespectsSafeArea];
    [[self headerTrailingConstraint] setActive:!contentRespectsSafeArea];
    [[self headerSafeAreaTrailingConstraint] setActive:contentRespectsSafeArea];
    for (NSLayoutConstraint *constraint in [self contentLeadingConstraints]) {
        [constraint setActive:!contentRespectsSafeArea];
    }
    for (NSLayoutConstraint *constraint in [self contentSafeAreaLeadingConstraints]) {
        [constraint setActive:contentRespectsSafeArea];
    }
    for (NSLayoutConstraint *constraint in [self contentTrailingConstraints]) {
        [constraint setActive:!contentRespectsSafeArea];
    }
    for (NSLayoutConstraint *constraint in [self contentSafeAreaTrailingConstraints]) {
        [constraint setActive:contentRespectsSafeArea];
    }
    for (NSLayoutConstraint *constraint in [self contentBottomConstraints]) {
        [constraint setActive:YES];
    }
    for (NSLayoutConstraint *constraint in [self contentSafeAreaBottomConstraints]) {
        [constraint setActive:NO];
    }
    [self setNeedsLayout];
}

- (void)setTitleText:(NSString *)title {
    [[self headerView] setTitleText:title];
}

- (void)setClearButtonEnabledForItemCount:(NSUInteger)itemCount {
    BOOL enabled = itemCount > 0;
    [[[self headerView] trailingButton] setEnabled:enabled];
    [[[self headerView] trailingButton] setAlpha:enabled ? 1.0 : 0.35];
}

#pragma mark - Content Transitions

- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(NSString *)title
              direction:(KayokoContentTransitionDirection)direction {
    [self showContentView:viewToShow hideContentView:viewToHide title:title direction:direction completion:nil];
}

- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(NSString *)title
              direction:(KayokoContentTransitionDirection)direction
             completion:(void (^)(void))completion {
    [self showContentView:viewToShow
          hideContentView:viewToHide
                    title:title
                direction:direction
      alongsideAnimations:nil
               completion:completion];
}

- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(NSString *)title
              direction:(KayokoContentTransitionDirection)direction
    alongsideAnimations:(void (^)(void))alongsideAnimations
             completion:(void (^)(void))completion {
    [self showContentView:viewToShow
          hideContentView:viewToHide
                    title:title
             updatesTitle:YES
                direction:direction
      alongsideAnimations:alongsideAnimations
               completion:completion];
}

- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(NSString *)title
           updatesTitle:(BOOL)updatesTitle
              direction:(KayokoContentTransitionDirection)direction
    alongsideAnimations:(void (^)(void))alongsideAnimations
             completion:(void (^)(void))completion {
    if (updatesTitle) {
        [UIView transitionWithView:[[self headerView] titleLabel]
                          duration:0.1
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
                          [self setTitleText:title];
                        }
                        completion:nil];
    }

    [self showContentView:viewToShow
        transitioningView:viewToShow
          hideContentView:viewToHide
        transitioningView:viewToHide
                direction:direction
      alongsideAnimations:alongsideAnimations
               completion:completion];
}

- (void)showContentView:(UIView *)viewToShow
      transitioningView:(UIView *)viewToShowTransition
        hideContentView:(UIView *)viewToHide
      transitioningView:(UIView *)viewToHideTransition
              direction:(KayokoContentTransitionDirection)direction
    alongsideAnimations:(void (^)(void))alongsideAnimations
             completion:(void (^)(void))completion {
    CGAffineTransform viewToShowTransform = CGAffineTransformIdentity;
    CGAffineTransform viewToHideTransform = CGAffineTransformIdentity;
    [self preparedTransformsForDirection:direction
                     viewToShowTransform:&viewToShowTransform
                     viewToHideTransform:&viewToHideTransform];

    [viewToShowTransition setTransform:viewToShowTransform];
    [viewToShowTransition setAlpha:0];
    if (viewToShow != viewToShowTransition) {
        [viewToShow setTransform:CGAffineTransformIdentity];
        [viewToShow setAlpha:1];
    }
    [viewToShow setHidden:NO];
    [self setAnimating:YES];

    [UIView animateWithDuration:0.3
        delay:0
        usingSpringWithDamping:1
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          if (alongsideAnimations) {
              alongsideAnimations();
          }
          [viewToShowTransition setTransform:CGAffineTransformIdentity];
          [viewToShowTransition setAlpha:1];
          [viewToHideTransition setTransform:viewToHideTransform];
          [viewToHideTransition setAlpha:0];
        }
        completion:^(__unused BOOL finished) {
          [self completePreparedContentTransitionHidingView:viewToHide completion:completion];
        }];
}

- (void)preparedTransformsForDirection:(KayokoContentTransitionDirection)direction
                   viewToShowTransform:(CGAffineTransform *)viewToShowTransform
                   viewToHideTransform:(CGAffineTransform *)viewToHideTransform {
    *viewToShowTransform = CGAffineTransformIdentity;
    *viewToHideTransform = CGAffineTransformIdentity;
    switch (direction) {
    case KayokoContentTransitionDirectionForward:
    case KayokoContentTransitionDirectionModalPresenting:
        *viewToShowTransform = CGAffineTransformMakeTranslation(0, -10);
        *viewToHideTransform = CGAffineTransformMakeTranslation(0, 10);
        break;
    case KayokoContentTransitionDirectionBackward:
    case KayokoContentTransitionDirectionModalDismissing:
        *viewToShowTransform = CGAffineTransformMakeTranslation(0, 10);
        *viewToHideTransform = CGAffineTransformMakeTranslation(0, -10);
        break;
    case KayokoContentTransitionDirectionSiblingForward:
        *viewToShowTransform = CGAffineTransformMakeTranslation(10, 0);
        *viewToHideTransform = CGAffineTransformMakeTranslation(-10, 0);
        break;
    case KayokoContentTransitionDirectionSiblingBackward:
        *viewToShowTransform = CGAffineTransformMakeTranslation(-10, 0);
        *viewToHideTransform = CGAffineTransformMakeTranslation(10, 0);
        break;
    }
}

- (void)prepareContentTransitionToView:(UIView *)viewToShow
                       hideContentView:(UIView *)viewToHide
                                 title:(NSString *)title
                             direction:(KayokoContentTransitionDirection)direction {
    [self prepareContentTransitionToView:viewToShow
                         hideContentView:viewToHide
                                   title:title
                            updatesTitle:YES
                               direction:direction];
}

- (void)prepareContentTransitionToView:(UIView *)viewToShow
                       hideContentView:(UIView *)viewToHide
                                 title:(NSString *)title
                          updatesTitle:(BOOL)updatesTitle
                             direction:(KayokoContentTransitionDirection)direction {
    if (updatesTitle) {
        [UIView transitionWithView:[[self headerView] titleLabel]
                          duration:0.1
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
                          [self setTitleText:title];
                        }
                        completion:nil];
    }

    CGAffineTransform viewToShowTransform = CGAffineTransformIdentity;
    CGAffineTransform viewToHideTransform = CGAffineTransformIdentity;
    [self preparedTransformsForDirection:direction
                     viewToShowTransform:&viewToShowTransform
                     viewToHideTransform:&viewToHideTransform];

    [viewToShow setTransform:viewToShowTransform];
    [viewToShow setAlpha:0];
    [viewToShow setHidden:NO];

    [self setAnimating:YES];
}

- (void)applyPreparedContentTransitionToView:(UIView *)viewToShow
                             hideContentView:(UIView *)viewToHide
                                   direction:(KayokoContentTransitionDirection)direction {
    CGAffineTransform viewToShowTransform = CGAffineTransformIdentity;
    CGAffineTransform viewToHideTransform = CGAffineTransformIdentity;
    [self preparedTransformsForDirection:direction
                     viewToShowTransform:&viewToShowTransform
                     viewToHideTransform:&viewToHideTransform];

    [viewToShow setTransform:CGAffineTransformIdentity];
    [viewToShow setAlpha:1];

    [viewToHide setTransform:viewToHideTransform];
    [viewToHide setAlpha:0];
}

- (void)completePreparedContentTransitionHidingView:(UIView *)viewToHide completion:(void (^)(void))completion {
    [viewToHide setHidden:YES];
    [self setAnimating:NO];
    if (completion) {
        completion();
    }
}

- (CGFloat)clampedInteractiveContentTransitionProgress:(CGFloat)progress {
    return MIN(MAX(progress, 0), 1);
}

#pragma mark - Interactive Back Transition

- (void)applyInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                    alongsideViewToShow:(UIView *)viewToShowAlongside
                                        hideContentView:(UIView *)viewToHide
                                               progress:(CGFloat)progress {
    CGFloat clampedProgress = [self clampedInteractiveContentTransitionProgress:progress];
    CGFloat width = CGRectGetWidth([[self contentContainerView] bounds]);
    CGAffineTransform viewToShowTransform = CGAffineTransformMakeTranslation(width * (clampedProgress - 1), 0);

    [viewToShow setTransform:viewToShowTransform];
    [viewToShow setAlpha:1];
    [viewToShowAlongside setTransform:viewToShowTransform];
    [viewToShowAlongside setAlpha:1];

    [viewToHide setTransform:CGAffineTransformMakeTranslation(width * clampedProgress, 0)];
    [viewToHide setAlpha:1];
}

- (void)beginInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                    alongsideViewToShow:(UIView *)viewToShowAlongside
                                        hideContentView:(UIView *)viewToHide {
    [viewToShow setHidden:NO];
    [viewToShowAlongside setHidden:NO];
    [self setAnimating:YES];
    [self applyInteractiveBackwardContentTransitionToView:viewToShow
                                      alongsideViewToShow:viewToShowAlongside
                                          hideContentView:viewToHide
                                                 progress:0];
}

- (void)updateInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                     alongsideViewToShow:(UIView *)viewToShowAlongside
                                         hideContentView:(UIView *)viewToHide
                                                progress:(CGFloat)progress {
    [self applyInteractiveBackwardContentTransitionToView:viewToShow
                                      alongsideViewToShow:viewToShowAlongside
                                          hideContentView:viewToHide
                                                 progress:progress];
}

- (void)finishInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                     alongsideViewToShow:(UIView *)viewToShowAlongside
                                         hideContentView:(UIView *)viewToHide
                                                duration:(NSTimeInterval)duration
                                     alongsideAnimations:(void (^)(void))alongsideAnimations
                                              completion:(void (^)(void))completion {
    [UIView animateWithDuration:duration
        delay:0
        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          if (alongsideAnimations) {
              alongsideAnimations();
          }
          [self applyInteractiveBackwardContentTransitionToView:viewToShow
                                            alongsideViewToShow:viewToShowAlongside
                                                hideContentView:viewToHide
                                                       progress:1];
        }
        completion:^(__unused BOOL finished) {
          [viewToShow setTransform:CGAffineTransformIdentity];
          [viewToShow setAlpha:1];
          [viewToShowAlongside setTransform:CGAffineTransformIdentity];
          [viewToShowAlongside setAlpha:1];
          [viewToHide setHidden:YES];
          [viewToHide setTransform:CGAffineTransformIdentity];
          [viewToHide setAlpha:1];
          [self setAnimating:NO];
          if (completion) {
              completion();
          }
        }];
}

- (void)cancelInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                     alongsideViewToShow:(UIView *)viewToShowAlongside
                                         hideContentView:(UIView *)viewToHide
                                                duration:(NSTimeInterval)duration
                                              completion:(void (^)(void))completion {
    [UIView animateWithDuration:duration
        delay:0
        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          [self applyInteractiveBackwardContentTransitionToView:viewToShow
                                            alongsideViewToShow:viewToShowAlongside
                                                hideContentView:viewToHide
                                                       progress:0];
        }
        completion:^(__unused BOOL finished) {
          [viewToShow setHidden:YES];
          [viewToShow setTransform:CGAffineTransformIdentity];
          [viewToShow setAlpha:1];
          [viewToShowAlongside setHidden:YES];
          [viewToShowAlongside setTransform:CGAffineTransformIdentity];
          [viewToShowAlongside setAlpha:1];
          [viewToHide setTransform:CGAffineTransformIdentity];
          [viewToHide setAlpha:1];
          [self setAnimating:NO];
          if (completion) {
              completion();
          }
        }];
}

@end
