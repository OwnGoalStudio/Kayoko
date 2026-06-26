//
//  KayokoEmptyStateView.m
//  Kayoko
//
//  Created by Lessica
//

#import "KayokoEmptyStateView.h"
#import "PasteboardManager.h"

@interface KayokoEmptyStateView ()
@property(nonatomic, strong) UILabel *messageLabel;
@end

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
        [NSLayoutConstraint activateConstraints:@[
            [[[self messageLabel] centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [[[self messageLabel] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
            [[[self messageLabel] leadingAnchor] constraintGreaterThanOrEqualToAnchor:[self leadingAnchor] constant:24],
            [[[self messageLabel] trailingAnchor] constraintLessThanOrEqualToAnchor:[self trailingAnchor] constant:-24],
            [[[self messageLabel] widthAnchor] constraintLessThanOrEqualToAnchor:[self widthAnchor] constant:-48]
        ]];
    }

    return self;
}

- (void)updateWithHistoryKey:(NSString *)historyKey {
    NSString *localizationKey = [historyKey isEqualToString:kHistoryKeyFavorites] ? @"No Favorite Items"
                                                                                 : @"No History Items";
    NSString *titleKey = [historyKey isEqualToString:kHistoryKeyFavorites] ? @"favorites" : @"history";
    [self setName:[[PasteboardManager localizationBundle] localizedStringForKey:titleKey value:nil table:@"Tweak"]];
    [[self messageLabel] setText:[[PasteboardManager localizationBundle] localizedStringForKey:localizationKey
                                                                                        value:nil
                                                                                        table:@"Tweak"]];
}

@end
