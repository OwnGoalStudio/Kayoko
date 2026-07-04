//
//  KayokoLinkCell.m
//  Akarii Utils
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoLinkCell.h"

@implementation KayokoLinkCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];

    if (self) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];

        NSString *localizationTable = [specifier propertyForKey:@"localizationTable"] ?: @"Root";
        [self setTitle:[bundle localizedStringForKey:[specifier propertyForKey:@"label"]
                                               value:nil
                                               table:localizationTable]];
        [self setSubtitle:[bundle localizedStringForKey:[specifier propertyForKey:@"subtitle"]
                                                  value:nil
                                                  table:localizationTable]];
        [self setUrl:[specifier propertyForKey:@"url"]];
        [self setMarkOpenedDefaults:[specifier propertyForKey:@"markOpenedDefaults"]];
        [self setMarkOpenedKey:[specifier propertyForKey:@"markOpenedKey"]];
        UILayoutGuide *margins = [self layoutMarginsGuide];

        [self setIndicatorImageView:[[UIImageView alloc] init]];
        [[self indicatorImageView] setImage:[UIImage systemImageNamed:@"safari"]];
        [[self indicatorImageView] setTintColor:[UIColor tertiaryLabelColor]];
        [[self contentView] addSubview:[self indicatorImageView]];

        [[self indicatorImageView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self indicatorImageView] widthAnchor] constraintEqualToConstant:20],
            [[[self indicatorImageView] heightAnchor] constraintEqualToConstant:20],
            [[[self indicatorImageView] centerYAnchor] constraintEqualToAnchor:[[self contentView] centerYAnchor]],
            [[[self indicatorImageView] trailingAnchor] constraintEqualToAnchor:[margins trailingAnchor]]
        ]];

        [self setLabel:[[UILabel alloc] init]];
        [[self label] setText:[self title]];
        [[self label] setFont:[UIFont systemFontOfSize:15 weight:UIFontWeightMedium]];
        [[self label] setTextColor:[UIColor systemBlueColor]];
        [[self contentView] addSubview:[self label]];

        [[self label] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self label] centerYAnchor] constraintEqualToAnchor:[[self contentView] centerYAnchor] constant:-8],
            [[[self label] leadingAnchor] constraintEqualToAnchor:[margins leadingAnchor]],
            [[[self label] trailingAnchor] constraintEqualToAnchor:[[self indicatorImageView] leadingAnchor]
                                                          constant:-16]
        ]];

        [self setSubtitleLabel:[[UILabel alloc] init]];
        [[self subtitleLabel] setText:[NSString stringWithFormat:@"%@", [self subtitle]]];
        [[self subtitleLabel] setFont:[UIFont systemFontOfSize:12]];
        [[self subtitleLabel] setTextColor:[[UIColor labelColor] colorWithAlphaComponent:0.6]];
        [[self contentView] addSubview:[self subtitleLabel]];

        [[self subtitleLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self subtitleLabel] centerYAnchor] constraintEqualToAnchor:[[self contentView] centerYAnchor]
                                                                 constant:10],
            [[[self subtitleLabel] leadingAnchor] constraintEqualToAnchor:[margins leadingAnchor]],
            [[[self subtitleLabel] trailingAnchor] constraintEqualToAnchor:[[self indicatorImageView] leadingAnchor]
                                                                  constant:-16]
        ]];

        [self setTapRecognizerView:[[UIView alloc] init]];
        [[self contentView] addSubview:[self tapRecognizerView]];

        [[self tapRecognizerView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self tapRecognizerView] topAnchor] constraintEqualToAnchor:[[self contentView] topAnchor]],
            [[[self tapRecognizerView] leadingAnchor] constraintEqualToAnchor:[[self contentView] leadingAnchor]],
            [[[self tapRecognizerView] trailingAnchor] constraintEqualToAnchor:[[self contentView] trailingAnchor]],
            [[[self tapRecognizerView] bottomAnchor] constraintEqualToAnchor:[[self contentView] bottomAnchor]]
        ]];

        [self setTap:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openUrl)]];
        [[self tapRecognizerView] addGestureRecognizer:[self tap]];
    }

    return self;
}

- (void)openUrl {
    if ([[self markOpenedKey] length] > 0) {
        NSUserDefaults *defaults = [[self markOpenedDefaults] length] > 0
                                       ? [[NSUserDefaults alloc] initWithSuiteName:[self markOpenedDefaults]]
                                       : [NSUserDefaults standardUserDefaults];
        [defaults setBool:YES forKey:[self markOpenedKey]];
        [defaults synchronize];
    }

    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[self url]] options:@{} completionHandler:nil];
}

@end
