//
//  KayokoAuthorizationOverlayView.m
//  Kayoko
//

#import "KayokoAuthorizationOverlayView.h"

@interface KayokoAuthorizationOverlayView ()
@property(nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@property(nonatomic, strong) UIImageView *statusImageView;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *subtitleLabel;
@property(nonatomic, strong) UITapGestureRecognizer *retryTapRecognizer;
@end

@implementation KayokoAuthorizationOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor systemBackgroundColor];

        _activityIndicatorView =
            [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        [_activityIndicatorView setHidesWhenStopped:YES];

        _statusImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"xmark.circle.fill"]];
        _statusImageView.tintColor = [UIColor systemRedColor];
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

        _retryTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleRetryTap)];
        _retryTapRecognizer.enabled = NO;
        [self addGestureRecognizer:_retryTapRecognizer];
    }
    return self;
}

- (void)setCheckingTitle:(NSString *)title subtitle:(NSString *)subtitle {
    self.retryTapRecognizer.enabled = NO;
    self.titleLabel.text = title;
    self.subtitleLabel.text = [subtitle length] > 0 ? subtitle : @" ";
    self.statusImageView.hidden = YES;
    [self.activityIndicatorView startAnimating];
}

- (void)setFailureTitle:(NSString *)title subtitle:(NSString *)subtitle retryEnabled:(BOOL)retryEnabled {
    self.retryTapRecognizer.enabled = retryEnabled;
    self.titleLabel.text = title;
    self.subtitleLabel.text = [subtitle length] > 0 ? subtitle : @" ";
    [self.activityIndicatorView stopAnimating];
    self.statusImageView.hidden = NO;
}

- (void)handleRetryTap {
    if (self.retryHandler) {
        self.retryHandler();
    }
}

@end
