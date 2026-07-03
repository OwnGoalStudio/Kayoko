//
//  KayokoEmptyStateView.m
//  Kayoko
//

#import "KayokoEmptyStateView.h"
#import "KayokoPasteboardManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoEmptyStateView ()
@property(nonatomic, strong) UILabel *messageLabel;
@property(nonatomic, strong) NSLayoutConstraint *messageLabelCenterYConstraint;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoEmptyStateView

- (instancetype)init {
    self = [super init];

    if (self) {
        [self setMessageLabel:[[UILabel alloc] init]];
        [[self messageLabel] setFont:[UIFont systemFontOfSize:17 weight:UIFontWeightMedium]];
        [[self messageLabel] setTextColor:[UIColor secondaryLabelColor]];
        [[self messageLabel] setTextAlignment:NSTextAlignmentCenter];
        [[self messageLabel] setNumberOfLines:0];
        [self addSubview:[self messageLabel]];

        [[self messageLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self setMessageLabelCenterYConstraint:[[[self messageLabel] centerYAnchor]
                                                   constraintEqualToAnchor:[self centerYAnchor]]];
        [NSLayoutConstraint activateConstraints:@[
            [[[self messageLabel] centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [self messageLabelCenterYConstraint],
            [[[self messageLabel] leadingAnchor] constraintGreaterThanOrEqualToAnchor:[self leadingAnchor] constant:24],
            [[[self messageLabel] trailingAnchor] constraintLessThanOrEqualToAnchor:[self trailingAnchor] constant:-24],
            [[[self messageLabel] widthAnchor] constraintLessThanOrEqualToAnchor:[self widthAnchor] constant:-48]
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
    [[self messageLabelCenterYConstraint] setConstant:-keyboardBottomInset / 2.0];
    [self setNeedsLayout];
}

- (void)updateWithHistoryKey:(NSString *)historyKey {
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

@end
