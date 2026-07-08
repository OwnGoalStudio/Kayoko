//
//  KayokoMainView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoMainView.h"

#import "KayokoGrabberView.h"
#import "KayokoHeaderButtonStyle.h"
#import "KayokoPasteboardManager.h"

static CGFloat const kKayokoTitleTapControlHeight = 44;
static CGFloat const kKayokoTitleTapControlTrailingSpacing = 8;

@interface KayokoMainView ()

#pragma mark - Header Constraints

@property(nonatomic, strong) NSLayoutConstraint *headerTopConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerSafeAreaTopConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerLeadingConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerSafeAreaLeadingConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerTrailingConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerSafeAreaTrailingConstraint;

#pragma mark - Content Constraints

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

        [self setHeaderView:[[UIView alloc] init]];
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
        [NSLayoutConstraint activateConstraints:@[
            [[[self headerView] heightAnchor] constraintEqualToConstant:60], [self headerTopConstraint],
            [self headerLeadingConstraint], [self headerTrailingConstraint]
        ]];

        [self setGrabber:[[KayokoGrabberView alloc] init]];
        [[self headerView] addSubview:[self grabber]];

        [[self grabber] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self grabber] topAnchor] constraintEqualToAnchor:[[self headerView] topAnchor] constant:12],
            [[[self grabber] centerXAnchor] constraintEqualToAnchor:[[self headerView] centerXAnchor]]
        ]];

        [self setFavoritesButton:[[UIButton alloc] init]];
        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart"
                            andImageSize:kKayokoFavoritesButtonImageSize
                            andTintColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self favoritesButton]];

        [[self favoritesButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self favoritesButton] bottomAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor]
                                                                  constant:-2],
            [[[self favoritesButton] centerXAnchor] constraintEqualToAnchor:[[self headerView] leadingAnchor]
                                                                   constant:kKayokoLeadingHeaderButtonCenterXInset]
        ]];

        [self setTitleLabel:[[UILabel alloc] init]];
        [[self titleLabel] setText:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"History"
                                                                                                 value:nil
                                                                                                 table:@"Tweak"]];
        [[self titleLabel] setFont:[UIFont systemFontOfSize:26 weight:UIFontWeightSemibold]];
        [[self titleLabel] setTextColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self titleLabel]];

        [[self titleLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self titleLabel] centerYAnchor] constraintEqualToAnchor:[[self favoritesButton] centerYAnchor]],
            [[[self titleLabel] leadingAnchor] constraintEqualToAnchor:[[self headerView] leadingAnchor]
                                                              constant:kKayokoTitleLabelLeadingInset]
        ]];

        [self setClearButton:[[UIButton alloc] init]];
        [self updateStyleForHeaderButton:[self clearButton]
                           withImageName:@"trash"
                            andImageSize:kKayokoClearButtonImageSize
                            andTintColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self clearButton]];

        [[self clearButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self clearButton] centerYAnchor] constraintEqualToAnchor:[[self favoritesButton] centerYAnchor]],
            [[[self clearButton] centerXAnchor] constraintEqualToAnchor:[[self headerView] trailingAnchor]
                                                               constant:-kKayokoTrailingHeaderButtonCenterXInset]
        ]];

        [self setBackButton:[[UIButton alloc] init]];
        [self updateStyleForHeaderButton:[self backButton]
                           withImageName:@"arrowshape.turn.up.backward"
                            andImageSize:kKayokoBackButtonImageSize
                            andTintColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self backButton]];
        [[self backButton] setHidden:YES];

        [[self backButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self backButton] centerYAnchor] constraintEqualToAnchor:[[self favoritesButton] centerYAnchor]],
            [[[self backButton] centerXAnchor] constraintEqualToAnchor:[[self headerView] trailingAnchor]
                                                              constant:-kKayokoTrailingHeaderButtonCenterXInset]
        ]];

        [self setTitleTapControl:[[UIControl alloc] init]];
        [[self titleTapControl] setBackgroundColor:[UIColor clearColor]];
        [[self titleTapControl]
            setAccessibilityTraits:[[self titleTapControl] accessibilityTraits] | UIAccessibilityTraitButton];
        [[self titleTapControl] setAccessibilityLabel:[[self titleLabel] text]];
        [[self headerView] addSubview:[self titleTapControl]];

        [[self titleTapControl] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self titleTapControl] leadingAnchor] constraintEqualToAnchor:[[self titleLabel] leadingAnchor]],
            [[[self titleTapControl] trailingAnchor] constraintEqualToAnchor:[[self clearButton] leadingAnchor]
                                                                    constant:-kKayokoTitleTapControlTrailingSpacing],
            [[[self titleTapControl] centerYAnchor] constraintEqualToAnchor:[[self titleLabel] centerYAnchor]],
            [[[self titleTapControl] heightAnchor] constraintEqualToConstant:kKayokoTitleTapControlHeight]
        ]];

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
        [NSLayoutConstraint activateConstraints:@[
            [[[self contentContainerView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor]
                                                                    constant:8],
            [self contentRespectsSafeArea] ? safeAreaLeadingConstraint : leadingConstraint,
            [self contentRespectsSafeArea] ? safeAreaTrailingConstraint : trailingConstraint,
            [self contentRespectsSafeArea] ? safeAreaBottomConstraint : bottomConstraint
        ]];
    }

    return self;
}

#pragma mark - Layout

- (void)setGrabberFoldProgress:(CGFloat)progress {
    [[self grabber] setFoldProgress:progress];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if ([self layoutHandler]) {
        [self layoutHandler]();
    }
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
    for (UIWindow *sceneWindow in [windowScene windows]) {
        if ([sceneWindow isHidden]) {
            continue;
        }

        CGFloat bottomInset = MAX([sceneWindow safeAreaInsets].bottom, 0);
        if (bottomInset > 0) {
            return bottomInset;
        }
    }

    return 0;
}

- (CGFloat)safeAreaBottomInsetForContentView:(nullable UIView *)contentView {
    CGFloat bottomInset = MAX([contentView safeAreaInsets].bottom, 0);
    if (bottomInset > 0) {
        return bottomInset;
    }

    UIView *referenceView = contentView ?: self;
    UIWindow *window = [referenceView window] ?: [self window];
    CGFloat windowBottomSafeAreaInset =
        MAX(MAX([window safeAreaInsets].bottom, [self sceneSafeAreaBottomInsetForWindow:window]), 0);
    if (!referenceView || !window || windowBottomSafeAreaInset <= 0) {
        return 0;
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
        [constraint setActive:!contentRespectsSafeArea];
    }
    for (NSLayoutConstraint *constraint in [self contentSafeAreaBottomConstraints]) {
        [constraint setActive:contentRespectsSafeArea];
    }
    [self setNeedsLayout];
}

#pragma mark - Header

- (void)updateStyleForHeaderButton:(UIButton *)button
                     withImageName:(NSString *)imageName
                      andImageSize:(NSUInteger)imageSize
                      andTintColor:(UIColor *)color {
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:imageSize weight:UIImageSymbolWeightMedium];
    UIImage *image = [UIImage systemImageNamed:imageName] ?: [UIImage systemImageNamed:@"doc.on.doc"];
    [button setImage:[image imageWithConfiguration:configuration] forState:UIControlStateNormal];
    [button setTintColor:color];
}

- (void)setTitleText:(NSString *)title {
    if ([title length] > 0) {
        [[self titleLabel] setText:title];
        [[self titleTapControl] setAccessibilityLabel:title];
    }
}

- (void)setClearButtonEnabledForItemCount:(NSUInteger)itemCount {
    BOOL enabled = itemCount > 0;
    [[self clearButton] setEnabled:enabled];
    [[self clearButton] setAlpha:enabled ? 1.0 : 0.35];
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
              willAnimate:nil
               completion:completion];
}

- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(NSString *)title
              direction:(KayokoContentTransitionDirection)direction
            willAnimate:(void (^)(void))willAnimate
             completion:(void (^)(void))completion {
    [self prepareContentTransitionToView:viewToShow hideContentView:viewToHide title:title direction:direction];
    if (willAnimate) {
        willAnimate();
    }

    [UIView animateWithDuration:0.3
        delay:0
        usingSpringWithDamping:1
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          [self applyPreparedContentTransitionToView:viewToShow hideContentView:viewToHide direction:direction];
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
    [UIView transitionWithView:[self titleLabel]
                      duration:0.1
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                      [self setTitleText:title];
                    }
                    completion:nil];

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
                                        hideContentView:(UIView *)viewToHide
                                               progress:(CGFloat)progress {
    CGFloat clampedProgress = [self clampedInteractiveContentTransitionProgress:progress];
    CGFloat width = CGRectGetWidth([[self contentContainerView] bounds]);

    [viewToShow setTransform:CGAffineTransformMakeTranslation(width * (clampedProgress - 1), 0)];
    [viewToShow setAlpha:1];

    [viewToHide setTransform:CGAffineTransformMakeTranslation(width * clampedProgress, 0)];
    [viewToHide setAlpha:1];
}

- (void)beginInteractiveBackwardContentTransitionToView:(UIView *)viewToShow hideContentView:(UIView *)viewToHide {
    [viewToShow setHidden:NO];
    [self setAnimating:YES];
    [self applyInteractiveBackwardContentTransitionToView:viewToShow hideContentView:viewToHide progress:0];
}

- (void)updateInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                         hideContentView:(UIView *)viewToHide
                                                progress:(CGFloat)progress {
    [self applyInteractiveBackwardContentTransitionToView:viewToShow hideContentView:viewToHide progress:progress];
}

- (void)finishInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                         hideContentView:(UIView *)viewToHide
                                                   title:(NSString *)title
                                                duration:(NSTimeInterval)duration
                                              completion:(void (^)(void))completion {
    [UIView transitionWithView:[self titleLabel]
                      duration:MIN(duration, 0.12)
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
                      [self setTitleText:title];
                    }
                    completion:nil];

    [UIView animateWithDuration:duration
        delay:0
        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          [self applyInteractiveBackwardContentTransitionToView:viewToShow hideContentView:viewToHide progress:1];
        }
        completion:^(__unused BOOL finished) {
          [viewToShow setTransform:CGAffineTransformIdentity];
          [viewToShow setAlpha:1];
          [viewToHide setHidden:YES];
          [self setAnimating:NO];
          if (completion) {
              completion();
          }
        }];
}

- (void)cancelInteractiveBackwardContentTransitionToView:(UIView *)viewToShow
                                         hideContentView:(UIView *)viewToHide
                                                duration:(NSTimeInterval)duration
                                              completion:(void (^)(void))completion {
    [UIView animateWithDuration:duration
        delay:0
        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          [self applyInteractiveBackwardContentTransitionToView:viewToShow hideContentView:viewToHide progress:0];
        }
        completion:^(__unused BOOL finished) {
          [viewToShow setHidden:YES];
          [viewToShow setTransform:CGAffineTransformIdentity];
          [viewToShow setAlpha:1];
          [viewToHide setTransform:CGAffineTransformIdentity];
          [viewToHide setAlpha:1];
          [self setAnimating:NO];
          if (completion) {
              completion();
          }
        }];
}

@end
