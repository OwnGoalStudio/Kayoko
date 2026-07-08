//
//  KayokoEmptyStateView.m
//  Kayoko
//

#import "KayokoEmptyStateView.h"
#import "KayokoPasteboardManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoEmptyStateView ()
@property(nonatomic, strong) UIStackView *contentStackView;
@property(nonatomic, strong) UIStackView *actionButtonStackView;
@property(nonatomic, strong) UILabel *messageLabel;
@property(nonatomic, strong) UIButton *actionButton;
@property(nonatomic, strong) NSLayoutConstraint *contentStackViewCenterYConstraint;
@property(nonatomic, copy, nullable) void (^actionHandler)(void);
@end

NS_ASSUME_NONNULL_END

@implementation KayokoEmptyStateView

- (instancetype)init {
    self = [super init];

    if (self) {
        [self setContentStackView:[[UIStackView alloc] init]];
        [[self contentStackView] setAxis:UILayoutConstraintAxisVertical];
        [[self contentStackView] setAlignment:UIStackViewAlignmentCenter];
        [[self contentStackView] setSpacing:18];
        [self addSubview:[self contentStackView]];

        [self setMessageLabel:[[UILabel alloc] init]];
        [[self messageLabel] setFont:[UIFont systemFontOfSize:17 weight:UIFontWeightMedium]];
        [[self messageLabel] setTextColor:[UIColor secondaryLabelColor]];
        [[self messageLabel] setTextAlignment:NSTextAlignmentCenter];
        [[self messageLabel] setNumberOfLines:0];
        [[self contentStackView] addArrangedSubview:[self messageLabel]];

        [self setActionButtonStackView:[[UIStackView alloc] init]];
        [[self actionButtonStackView] setAxis:UILayoutConstraintAxisHorizontal];
        [[self actionButtonStackView] setAlignment:UIStackViewAlignmentCenter];
        [[self actionButtonStackView] setDistribution:UIStackViewDistributionFillEqually];
        [[self actionButtonStackView] setSpacing:12];
        [[self actionButtonStackView] setHidden:YES];
        [[self contentStackView] addArrangedSubview:[self actionButtonStackView]];

        [self setActionButton:[UIButton buttonWithType:UIButtonTypeSystem]];
        [[self actionButton] setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        [[[self actionButton] titleLabel] setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold]];
        [[[self actionButton] titleLabel] setLineBreakMode:NSLineBreakByTruncatingTail];
        [[self actionButton] setBackgroundColor:[[UIColor systemBlueColor] colorWithAlphaComponent:0.14]];
        [[[self actionButton] layer] setCornerRadius:8];
        [[self actionButton] setClipsToBounds:YES];
        [[self actionButton] addTarget:self
                                action:@selector(handleActionButtonPressed)
                      forControlEvents:UIControlEventTouchUpInside];
        [[self actionButtonStackView] addArrangedSubview:[self actionButton]];

        [[self contentStackView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [[self actionButtonStackView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [[self messageLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [[self actionButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self setContentStackViewCenterYConstraint:[[[self contentStackView] centerYAnchor]
                                                       constraintEqualToAnchor:[self centerYAnchor]]];
        [NSLayoutConstraint activateConstraints:@[
            [[[self contentStackView] centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [self contentStackViewCenterYConstraint],
            [[[self contentStackView] leadingAnchor] constraintGreaterThanOrEqualToAnchor:[self leadingAnchor] constant:24],
            [[[self contentStackView] trailingAnchor] constraintLessThanOrEqualToAnchor:[self trailingAnchor] constant:-24],
            [[[self contentStackView] widthAnchor] constraintLessThanOrEqualToAnchor:[self widthAnchor] constant:-48],
            [[[self messageLabel] leadingAnchor] constraintGreaterThanOrEqualToAnchor:[self leadingAnchor] constant:24],
            [[[self messageLabel] trailingAnchor] constraintLessThanOrEqualToAnchor:[self trailingAnchor] constant:-24],
            [[[self messageLabel] widthAnchor] constraintLessThanOrEqualToAnchor:[self widthAnchor] constant:-48],
            [[[self actionButtonStackView] widthAnchor] constraintEqualToConstant:86],
            [[[self actionButtonStackView] heightAnchor] constraintEqualToConstant:36]
        ]];
    }

    return self;
}

- (void)setKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    keyboardBottomInset = MAX(keyboardBottomInset, 0);
    if (_keyboardBottomInset == keyboardBottomInset) {
        return;
    }

    _keyboardBottomInset = keyboardBottomInset;
    [[self contentStackViewCenterYConstraint] setConstant:-keyboardBottomInset / 2.0];
    [self setNeedsLayout];
}

- (void)clearActionButton {
    [self setActionHandler:nil];
    [[self actionButtonStackView] setHidden:YES];
    [[self actionButton] setTitle:nil forState:UIControlStateNormal];
}

- (void)updateWithHistoryKey:(NSString *)historyKey {
    [self clearActionButton];
    NSString *localizationKey =
        [historyKey isEqualToString:kKayokoHistoryKeyFavorites] ? @"No Favorite Items" : @"No History Items";
    NSString *titleKey = [historyKey isEqualToString:kKayokoHistoryKeyFavorites] ? @"Favorites" : @"History";
    [self setName:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:titleKey
                                                                                value:nil
                                                                                table:@"Tweak"]];
    [[self messageLabel] setText:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:localizationKey
                                                                                               value:nil
                                                                                               table:@"Tweak"]];
}

- (void)updateWithStorageError:(NSError *)error {
    [self clearActionButton];
    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    [self setName:[bundle localizedStringForKey:@"History" value:nil table:@"Tweak"]];
    NSString *title = [bundle localizedStringForKey:@"Unable to Load History" value:nil table:@"Tweak"];
    NSString *format = [bundle localizedStringForKey:@"%@\n%@" value:nil table:@"Tweak"];
    NSString *detail = [[error localizedDescription] length] > 0 ? [error localizedDescription] : [error description];
    [[self messageLabel] setText:[NSString stringWithFormat:format, title, detail ?: @""]];
}

- (void)updateWithAuthorizationRequiredActionHandler:(void (^)(void))actionHandler {
    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    [self setName:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Tweak"]];
    [[self messageLabel] setText:[bundle localizedStringForKey:@"Open Settings → “Kayoko” to complete verification."
                                                          value:nil
                                                          table:@"Tweak"]];
    [[self actionButton] setTitle:[bundle localizedStringForKey:@"Continue" value:nil table:@"Tweak"]
                         forState:UIControlStateNormal];
    [self setActionHandler:actionHandler];
    [[self actionButtonStackView] setHidden:NO];
}

- (void)handleActionButtonPressed {
    if ([self actionHandler]) {
        [self actionHandler]();
    }
}

@end
