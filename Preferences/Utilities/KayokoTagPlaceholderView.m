//
//  KayokoTagPlaceholderView.m
//  Kayoko
//

#import "KayokoTagPlaceholderView.h"

@interface KayokoTagPlaceholderView ()
@property(nonatomic, strong) UILabel *messageLabel;
@property(nonatomic, strong) NSLayoutConstraint *messageLabelCenterYConstraint;
@end

@implementation KayokoTagPlaceholderView

- (instancetype)initWithMessage:(NSString *)message {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self setUserInteractionEnabled:NO];
        [self configureMessageLabel];
        [self setMessage:message];
    }
    return self;
}

- (void)configureMessageLabel {
    _messageLabel = [[UILabel alloc] init];
    [_messageLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_messageLabel setFont:[UIFont systemFontOfSize:17.0 weight:UIFontWeightMedium]];
    [_messageLabel setTextColor:[UIColor secondaryLabelColor]];
    [_messageLabel setTextAlignment:NSTextAlignmentCenter];
    [_messageLabel setNumberOfLines:0];
    [self addSubview:_messageLabel];

    _messageLabelCenterYConstraint = [[_messageLabel centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]];
    [NSLayoutConstraint activateConstraints:@[
        [[_messageLabel centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]], _messageLabelCenterYConstraint,
        [[_messageLabel leadingAnchor] constraintGreaterThanOrEqualToAnchor:[self leadingAnchor] constant:24.0],
        [[_messageLabel trailingAnchor] constraintLessThanOrEqualToAnchor:[self trailingAnchor] constant:-24.0],
        [[_messageLabel widthAnchor] constraintLessThanOrEqualToAnchor:[self widthAnchor] constant:-48.0]
    ]];
}

- (void)setMessage:(NSString *)message {
    [[self messageLabel] setText:message];
}

- (void)setKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    keyboardBottomInset = MAX(keyboardBottomInset, 0.0);
    if (_keyboardBottomInset == keyboardBottomInset) {
        return;
    }

    _keyboardBottomInset = keyboardBottomInset;
    [[self messageLabelCenterYConstraint] setConstant:-keyboardBottomInset / 2.0];
    [self setNeedsLayout];
}

@end
