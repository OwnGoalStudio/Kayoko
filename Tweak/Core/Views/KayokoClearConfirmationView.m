//
//  KayokoClearConfirmationView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoClearConfirmationView.h"
#import "PasteboardManager.h"

@interface KayokoClearConfirmationView ()
@property(nonatomic, strong) UILabel *confirmationLabel;
@property(nonatomic, strong, readwrite) UIButton *cancelButton;
@property(nonatomic, strong, readwrite) UIButton *confirmButton;
@end

@implementation KayokoClearConfirmationView

- (instancetype)init {
    self = [super init];

    if (self) {
        UIStackView *stackView = [[UIStackView alloc] init];
        [stackView setAxis:UILayoutConstraintAxisVertical];
        [stackView setAlignment:UIStackViewAlignmentCenter];
        [stackView setSpacing:18];
        [self addSubview:stackView];

        [stackView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[stackView centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [[stackView centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
            [[stackView leadingAnchor] constraintGreaterThanOrEqualToAnchor:[self leadingAnchor] constant:24],
            [[stackView trailingAnchor] constraintLessThanOrEqualToAnchor:[self trailingAnchor] constant:-24]
        ]];

        [self setConfirmationLabel:[[UILabel alloc] init]];
        [[self confirmationLabel] setFont:[UIFont systemFontOfSize:17 weight:UIFontWeightMedium]];
        [[self confirmationLabel] setTextColor:[UIColor secondaryLabelColor]];
        [[self confirmationLabel] setTextAlignment:NSTextAlignmentCenter];
        [[self confirmationLabel] setNumberOfLines:0];
        [stackView addArrangedSubview:[self confirmationLabel]];

        [[self confirmationLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self confirmationLabel] widthAnchor] constraintLessThanOrEqualToAnchor:[self widthAnchor] constant:-48]
        ]];

        UIStackView *buttonStackView = [[UIStackView alloc] init];
        [buttonStackView setAxis:UILayoutConstraintAxisHorizontal];
        [buttonStackView setAlignment:UIStackViewAlignmentCenter];
        [buttonStackView setDistribution:UIStackViewDistributionFillEqually];
        [buttonStackView setSpacing:12];
        [stackView addArrangedSubview:buttonStackView];

        [buttonStackView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[buttonStackView widthAnchor] constraintEqualToConstant:184],
            [[buttonStackView heightAnchor] constraintEqualToConstant:36]
        ]];

        [self setCancelButton:[UIButton buttonWithType:UIButtonTypeSystem]];
        [[self cancelButton] setTitle:[[PasteboardManager localizationBundle] localizedStringForKey:@"Cancel"
                                                                                               value:nil
                                                                                               table:@"Tweak"]
                              forState:UIControlStateNormal];
        [[self cancelButton] setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        [[[self cancelButton] titleLabel] setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightMedium]];
        [[self cancelButton] setBackgroundColor:[UIColor tertiarySystemFillColor]];
        [[[self cancelButton] layer] setCornerRadius:8];
        [[self cancelButton] setClipsToBounds:YES];
        [buttonStackView addArrangedSubview:[self cancelButton]];

        [self setConfirmButton:[UIButton buttonWithType:UIButtonTypeSystem]];
        [[self confirmButton] setTitle:[[PasteboardManager localizationBundle] localizedStringForKey:@"Clear"
                                                                                                value:nil
                                                                                                table:@"Tweak"]
                               forState:UIControlStateNormal];
        [[self confirmButton] setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
        [[[self confirmButton] titleLabel] setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold]];
        [[self confirmButton] setBackgroundColor:[[UIColor systemRedColor] colorWithAlphaComponent:0.14]];
        [[[self confirmButton] layer] setCornerRadius:8];
        [[self confirmButton] setClipsToBounds:YES];
        [buttonStackView addArrangedSubview:[self confirmButton]];
    }

    return self;
}

- (void)updateWithHistoryKey:(NSString *)historyKey {
    NSString *localizationKey = [historyKey isEqualToString:kHistoryKeyFavorites] ? @"Clear Favorites Confirmation"
                                                                                 : @"Clear History Confirmation";
    [[self confirmationLabel] setText:[[PasteboardManager localizationBundle] localizedStringForKey:localizationKey
                                                                                              value:nil
                                                                                              table:@"Tweak"]];
}

@end
