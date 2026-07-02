//
//  KayokoTableViewCell.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoTableViewCell.h"
#import "KayokoTableViewCellContent.h"

@interface KayokoTableViewCell ()
@property(nonatomic, copy, nullable) NSString *representedImageName;
@end

@implementation KayokoTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                      content:(KayokoTableViewCellContent *)content
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

    if (self) {
        NSUInteger lineCount = MIN(MAX([content previewLineCount], 1), 3);
        [self setBackgroundColor:[UIColor clearColor]];
        UIView *selectedBackgroundView = [[UIView alloc] init];
        UIColor *selectedBackgroundColor =
            [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
              if ([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark) {
                  return [UIColor colorWithWhite:1 alpha:0.08];
              }

              return [UIColor colorWithWhite:0 alpha:0.055];
            }];
        [selectedBackgroundView setBackgroundColor:selectedBackgroundColor];
        [self setSelectedBackgroundView:selectedBackgroundView];

        [self setIconImageView:[[UIImageView alloc] init]];
        [[self iconImageView] setImage:[content icon]];

        [[self iconImageView] setContentMode:UIViewContentModeScaleAspectFit];
        [[self iconImageView] setClipsToBounds:YES];
        [[[self iconImageView] layer] setCornerRadius:10];
        [self addSubview:[self iconImageView]];

        [[self iconImageView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self iconImageView] widthAnchor] constraintEqualToConstant:40],
            [[[self iconImageView] heightAnchor] constraintEqualToConstant:40],
            [[[self iconImageView] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
            [[[self iconImageView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:24]
        ]];

        UIImage *contentImage = [content contentImage];
        NSString *thumbnailImageName = [content thumbnailImageName];
        BOOL hasContentImageSlot = contentImage || [thumbnailImageName length] > 0;
        [self setRepresentedImageName:thumbnailImageName];
        if (hasContentImageSlot) {
            [self setContentImageView:[[UIImageView alloc] init]];
            [[self contentImageView] setImage:contentImage];

            [[self contentImageView] setContentMode:UIViewContentModeScaleAspectFill];
            [[self contentImageView] setClipsToBounds:YES];
            [[self contentImageView]
                setBackgroundColor:contentImage ? [UIColor clearColor] : [UIColor tertiarySystemFillColor]];
            [[[self contentImageView] layer] setCornerRadius:4];
            [self addSubview:[self contentImageView]];

            [[self contentImageView] setTranslatesAutoresizingMaskIntoConstraints:NO];
            [NSLayoutConstraint activateConstraints:@[
                [[[self contentImageView] widthAnchor] constraintEqualToConstant:70],
                [[[self contentImageView] heightAnchor] constraintEqualToConstant:40],
                [[[self contentImageView] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
                [[[self contentImageView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor] constant:-24]
            ]];
        }

        [self setHeaderLabel:[[UILabel alloc] init]];
        [[self headerLabel] setText:[content displayName]];
        [[self headerLabel] setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightMedium]];
        [[self headerLabel] setTextColor:[UIColor labelColor]];
        [self addSubview:[self headerLabel]];

        [[self headerLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self headerLabel] topAnchor] constraintEqualToAnchor:[self topAnchor] constant:12],
            [[[self headerLabel] leadingAnchor] constraintEqualToAnchor:[[self iconImageView] trailingAnchor]
                                                               constant:16]
        ]];

        if ([self contentImageView]) {
            [NSLayoutConstraint activateConstraints:@[ [[[self headerLabel] trailingAnchor]
                                                        constraintEqualToAnchor:[[self contentImageView] leadingAnchor]
                                                                       constant:-16] ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[ [[[self headerLabel] trailingAnchor]
                                                        constraintEqualToAnchor:[self trailingAnchor]
                                                                       constant:-24] ]];
        }

        [self setContentLabel:[[UILabel alloc] init]];
        [[self contentLabel] setFont:[UIFont systemFontOfSize:14]];
        [[self contentLabel] setTextColor:[[UIColor labelColor] colorWithAlphaComponent:0.8]];
        [[self contentLabel] setLineBreakMode:NSLineBreakByTruncatingTail];
        [[self contentLabel] setNumberOfLines:lineCount];
        if ([content attributedContentText]) {
            NSMutableAttributedString *attributedText = [[content attributedContentText] mutableCopy];
            NSRange fullRange = NSMakeRange(0, [attributedText length]);
            [attributedText addAttribute:NSFontAttributeName value:[[self contentLabel] font] range:fullRange];
            [attributedText addAttribute:NSForegroundColorAttributeName
                                   value:[[self contentLabel] textColor]
                                   range:fullRange];
            [[self contentLabel] setAttributedText:attributedText];
        } else {
            [[self contentLabel] setText:[content contentText] ?: @""];
        }
        [self addSubview:[self contentLabel]];

        [[self contentLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self contentLabel] topAnchor] constraintEqualToAnchor:[[self headerLabel] bottomAnchor] constant:2],
            [[[self contentLabel] bottomAnchor] constraintLessThanOrEqualToAnchor:[self bottomAnchor] constant:-10],
            [[[self contentLabel] leadingAnchor] constraintEqualToAnchor:[[self headerLabel] leadingAnchor]],
            [[[self contentLabel] trailingAnchor] constraintEqualToAnchor:[[self headerLabel] trailingAnchor]]
        ]];
    }

    return self;
}

- (void)setContentImage:(UIImage *)image forImageName:(NSString *)imageName {
    if ([[self representedImageName] length] == 0 || ![[self representedImageName] isEqualToString:imageName]) {
        return;
    }

    if (![self contentImageView]) {
        return;
    }

    [[self contentImageView] setImage:image];
    [[self contentImageView] setBackgroundColor:image ? [UIColor clearColor] : [UIColor tertiarySystemFillColor]];
}

@end
