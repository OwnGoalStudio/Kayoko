//
//  KayokoHeaderView.m
//  Kayoko
//

#import "KayokoHeaderView.h"

#import "KayokoGrabberView.h"
#import "KayokoHeaderButtonStyle.h"

static CGFloat const kKayokoHeaderHeight = 60;
static CGFloat const kKayokoTitleTapControlHeight = 44;
static CGFloat const kKayokoTitleTapControlTrailingSpacing = 8;

@interface KayokoHeaderView ()

@property(nonatomic, strong, readwrite) KayokoGrabberView *grabber;
@property(nonatomic, strong, readwrite) UILabel *titleLabel;
@property(nonatomic, strong, readwrite) UIControl *titleTapControl;
@property(nonatomic, strong, readwrite) UIButton *leadingButton;
@property(nonatomic, strong, readwrite) UIButton *trailingButton;
@property(nonatomic, strong, readwrite) UIButton *alternateTrailingButton;

@end

@implementation KayokoHeaderView

+ (CGFloat)preferredHeight {
    return kKayokoHeaderHeight;
}

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self setClipsToBounds:YES];

        _grabber = [[KayokoGrabberView alloc] init];
        [self addSubview:_grabber];
        [_grabber setTranslatesAutoresizingMaskIntoConstraints:NO];

        _leadingButton = [[UIButton alloc] init];
        [self addSubview:_leadingButton];
        [_leadingButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _titleLabel = [[UILabel alloc] init];
        [_titleLabel setFont:[UIFont systemFontOfSize:26 weight:UIFontWeightSemibold]];
        [_titleLabel setTextColor:[UIColor labelColor]];
        [self addSubview:_titleLabel];
        [_titleLabel setTranslatesAutoresizingMaskIntoConstraints:NO];

        _trailingButton = [[UIButton alloc] init];
        [self addSubview:_trailingButton];
        [_trailingButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _alternateTrailingButton = [[UIButton alloc] init];
        [_alternateTrailingButton setHidden:YES];
        [self addSubview:_alternateTrailingButton];
        [_alternateTrailingButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _titleTapControl = [[UIControl alloc] init];
        [_titleTapControl setBackgroundColor:[UIColor clearColor]];
        [_titleTapControl setAccessibilityTraits:[_titleTapControl accessibilityTraits] | UIAccessibilityTraitButton];
        [self addSubview:_titleTapControl];
        [_titleTapControl setTranslatesAutoresizingMaskIntoConstraints:NO];

        [NSLayoutConstraint activateConstraints:@[
            [[_grabber topAnchor] constraintEqualToAnchor:[self topAnchor] constant:12],
            [[_grabber centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [[_leadingButton bottomAnchor] constraintEqualToAnchor:[self bottomAnchor] constant:-2],
            [[_leadingButton centerXAnchor] constraintEqualToAnchor:[self leadingAnchor]
                                                           constant:kKayokoLeadingHeaderButtonCenterXInset],
            [[_titleLabel centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
            [[_titleLabel leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]
                                                        constant:kKayokoTitleLabelLeadingInset],
            [[_trailingButton centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
            [[_trailingButton centerXAnchor] constraintEqualToAnchor:[self trailingAnchor]
                                                            constant:-kKayokoTrailingHeaderButtonCenterXInset],
            [[_alternateTrailingButton centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
            [[_alternateTrailingButton centerXAnchor] constraintEqualToAnchor:[self trailingAnchor]
                                                                     constant:-kKayokoTrailingHeaderButtonCenterXInset],
            [[_titleTapControl leadingAnchor] constraintEqualToAnchor:[_titleLabel leadingAnchor]],
            [[_titleTapControl trailingAnchor] constraintEqualToAnchor:[_trailingButton leadingAnchor]
                                                              constant:-kKayokoTitleTapControlTrailingSpacing],
            [[_titleTapControl centerYAnchor] constraintEqualToAnchor:[_titleLabel centerYAnchor]],
            [[_titleTapControl heightAnchor] constraintEqualToConstant:kKayokoTitleTapControlHeight]
        ]];

        [self setTitleText:title];
    }
    return self;
}

- (void)setTitleText:(NSString *)title {
    if ([title length] == 0) {
        return;
    }

    [[self titleLabel] setText:title];
    [[self titleTapControl] setAccessibilityLabel:title];
}

- (void)setGrabberFoldProgress:(CGFloat)progress {
    _grabberFoldProgress = MIN(MAX(progress, 0), 1);
    [[self grabber] setFoldProgress:_grabberFoldProgress];
}

- (void)updateStyleForButton:(UIButton *)button
               withImageName:(NSString *)imageName
                    imageSize:(NSUInteger)imageSize
                   tintColor:(UIColor *)color {
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:imageSize weight:UIImageSymbolWeightMedium];
    UIImage *image = [UIImage systemImageNamed:imageName] ?: [UIImage systemImageNamed:@"doc.on.doc"];
    [button setImage:[image imageWithConfiguration:configuration] forState:UIControlStateNormal];
    [button setTintColor:color];
}

@end
