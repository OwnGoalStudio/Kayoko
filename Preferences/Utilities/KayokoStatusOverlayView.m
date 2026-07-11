//
//  KayokoStatusOverlayView.m
//  Kayoko
//

#import "KayokoStatusOverlayView.h"

static NSTimeInterval const kKayokoStatusOverlayTransitionDuration = 0.25;

@interface KayokoStatusOverlayView ()
@property(nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@property(nonatomic, strong) UIImageView *statusImageView;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *subtitleLabel;
@property(nonatomic, strong) UITapGestureRecognizer *actionTapRecognizer;
@property(nonatomic, assign) BOOL hasConfiguredState;
@end

@implementation KayokoStatusOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor systemBackgroundColor];

        _activityIndicatorView =
            [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        [_activityIndicatorView setHidesWhenStopped:YES];

        _statusImageView = [[UIImageView alloc] init];
        _statusImageView.hidden = YES;
        _statusImageView.contentMode = UIViewContentModeScaleAspectFit;

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightSemibold];
        _titleLabel.textColor = [UIColor labelColor];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.numberOfLines = 0;

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
        _subtitleLabel.textColor = [UIColor secondaryLabelColor];
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
        _subtitleLabel.numberOfLines = 0;

        UIView *statusContainer = [[UIView alloc] init];
        [statusContainer addSubview:_activityIndicatorView];
        [statusContainer addSubview:_statusImageView];
        _activityIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
        _statusImageView.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [statusContainer.widthAnchor constraintEqualToConstant:64.0],
            [statusContainer.heightAnchor constraintEqualToConstant:64.0],
            [_activityIndicatorView.centerXAnchor constraintEqualToAnchor:statusContainer.centerXAnchor],
            [_activityIndicatorView.centerYAnchor constraintEqualToAnchor:statusContainer.centerYAnchor],
            [_statusImageView.centerXAnchor constraintEqualToAnchor:statusContainer.centerXAnchor],
            [_statusImageView.centerYAnchor constraintEqualToAnchor:statusContainer.centerYAnchor],
            [_statusImageView.widthAnchor constraintEqualToConstant:54.0],
            [_statusImageView.heightAnchor constraintEqualToConstant:54.0]
        ]];

        UIStackView *stackView =
            [[UIStackView alloc] initWithArrangedSubviews:@[ statusContainer, _titleLabel, _subtitleLabel ]];
        stackView.axis = UILayoutConstraintAxisVertical;
        stackView.alignment = UIStackViewAlignmentCenter;
        stackView.spacing = 10.0;
        stackView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:stackView];

        UILayoutGuide *margins = self.layoutMarginsGuide;
        [NSLayoutConstraint activateConstraints:@[
            [stackView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [stackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [stackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:margins.leadingAnchor constant:20.0],
            [stackView.trailingAnchor constraintLessThanOrEqualToAnchor:margins.trailingAnchor constant:-20.0],
            [_titleLabel.widthAnchor constraintLessThanOrEqualToAnchor:stackView.widthAnchor],
            [_subtitleLabel.widthAnchor constraintLessThanOrEqualToAnchor:stackView.widthAnchor]
        ]];

        _actionTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleActionTap)];
        _actionTapRecognizer.enabled = NO;
        [self addGestureRecognizer:_actionTapRecognizer];
    }
    return self;
}

- (void)setLoadingTitle:(NSString *)title subtitle:(NSString *)subtitle {
    [self performStateTransition:^{
      self.actionTapRecognizer.enabled = NO;
      self.titleLabel.text = title;
      self.subtitleLabel.text = [subtitle length] > 0 ? subtitle : @" ";
      self.statusImageView.hidden = YES;
      [self.activityIndicatorView startAnimating];
    }];
}

- (void)setFailureTitle:(NSString *)title subtitle:(NSString *)subtitle actionEnabled:(BOOL)actionEnabled {
    [self setStatusTitle:title
                subtitle:subtitle
               imageName:@"xmark.circle.fill"
               tintColor:[UIColor systemRedColor]
           actionEnabled:actionEnabled];
}

- (void)setSuccessTitle:(NSString *)title subtitle:(NSString *)subtitle actionEnabled:(BOOL)actionEnabled {
    [self setStatusTitle:title
                subtitle:subtitle
               imageName:@"checkmark.circle.fill"
               tintColor:[UIColor systemGreenColor]
           actionEnabled:actionEnabled];
}

- (void)setStatusTitle:(NSString *)title
              subtitle:(NSString *)subtitle
             imageName:(NSString *)imageName
             tintColor:(UIColor *)tintColor
         actionEnabled:(BOOL)actionEnabled {
    [self performStateTransition:^{
      self.actionTapRecognizer.enabled = actionEnabled;
      self.titleLabel.text = title;
      self.subtitleLabel.text = [subtitle length] > 0 ? subtitle : @" ";
      [self.activityIndicatorView stopAnimating];
      self.statusImageView.image = [UIImage systemImageNamed:imageName];
      self.statusImageView.tintColor = tintColor;
      self.statusImageView.hidden = NO;
    }];
}

- (void)performStateTransition:(void (^)(void))changes {
    BOOL animated = self.hasConfiguredState && self.superview;
    self.hasConfiguredState = YES;
    if (!animated) {
        changes();
        return;
    }

    [UIView transitionWithView:self
                      duration:kKayokoStatusOverlayTransitionDuration
                       options:UIViewAnimationOptionTransitionCrossDissolve |
                               UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowAnimatedContent
                    animations:changes
                    completion:nil];
}

- (void)animateAppearance {
    if (!self.superview || self.alpha >= 1.0) {
        return;
    }
    self.userInteractionEnabled = YES;
    [UIView transitionWithView:self.superview
                      duration:kKayokoStatusOverlayTransitionDuration
                       options:UIViewAnimationOptionTransitionCrossDissolve |
                               UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
                      self.alpha = 1.0;
                    }
                    completion:nil];
}

- (void)animateDisappearanceWithCompletion:(void (^)(void))completion {
    self.userInteractionEnabled = NO;
    UIView *containerView = self.superview ?: self;
    [UIView transitionWithView:containerView
        duration:kKayokoStatusOverlayTransitionDuration
        options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowAnimatedContent
        animations:^{
          self.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          (void)finished;
          if (completion) {
              completion();
          }
        }];
}

- (void)handleActionTap {
    if (self.tapHandler) {
        self.tapHandler();
    }
}

@end
