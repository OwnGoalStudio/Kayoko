//
//  KayokoTableViewCell.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoTableViewCell.h"
#import "KayokoTableViewCellContent.h"
#import "KayokoTagColorFormatter.h"

static CGFloat const kKayokoTableViewCellTagDotSize = 7;
static CGFloat const kKayokoTableViewCellContentImageWidth = 70;
static CGFloat const kKayokoTableViewCellContentImageSingleLineHeight = 40;
static CGFloat const kKayokoTableViewCellContentImageAdditionalLineHeight = 15;
static NSUInteger const kKayokoTableViewCellMaximumPreviewLineCount = 3;

@interface KayokoTableViewCell ()
@property(nonatomic, copy, nullable) NSString *representedImageName;
@end

@implementation KayokoTableViewCell

+ (CGSize)contentImageViewSizeForPreviewLineCount:(NSUInteger)previewLineCount {
    NSUInteger lineCount = MIN(MAX(previewLineCount, 1), kKayokoTableViewCellMaximumPreviewLineCount);
    CGFloat height = kKayokoTableViewCellContentImageSingleLineHeight +
                     (lineCount - 1) * kKayokoTableViewCellContentImageAdditionalLineHeight;
    return CGSizeMake(kKayokoTableViewCellContentImageWidth, height);
}

+ (CGSize)contentImageThumbnailSize {
    CGSize maximumViewSize = [self contentImageViewSizeForPreviewLineCount:kKayokoTableViewCellMaximumPreviewLineCount];
    CGFloat sideLength = MAX(maximumViewSize.width, maximumViewSize.height);
    return CGSizeMake(sideLength, sideLength);
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                      content:(KayokoTableViewCellContent *)content
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

    if (self) {
        NSUInteger lineCount = MIN(MAX([content previewLineCount], 1), kKayokoTableViewCellMaximumPreviewLineCount);
        CGSize contentImageViewSize = [[self class] contentImageViewSizeForPreviewLineCount:lineCount];
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
                [[[self contentImageView] widthAnchor] constraintEqualToConstant:contentImageViewSize.width],
                [[[self contentImageView] heightAnchor] constraintEqualToConstant:contentImageViewSize.height],
                [[[self contentImageView] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
                [[[self contentImageView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor] constant:-24]
            ]];
        }

        [self setHeaderLabel:[[UILabel alloc] init]];
        [[self headerLabel] setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightMedium]];
        [[self headerLabel] setTextColor:[UIColor labelColor]];
        [[self headerLabel] setLineBreakMode:NSLineBreakByTruncatingTail];
        if ([content attributedDisplayName]) {
            NSMutableAttributedString *attributedDisplayName = [[content attributedDisplayName] mutableCopy];
            NSRange fullRange = NSMakeRange(0, [attributedDisplayName length]);
            [attributedDisplayName addAttribute:NSFontAttributeName value:[[self headerLabel] font] range:fullRange];
            [attributedDisplayName addAttribute:NSForegroundColorAttributeName
                                          value:[[self headerLabel] textColor]
                                          range:fullRange];
            [[self headerLabel] setAttributedText:attributedDisplayName];
        } else {
            [[self headerLabel] setText:[content displayName]];
        }
        [[self headerLabel] setContentHuggingPriority:UILayoutPriorityDefaultHigh
                                              forAxis:UILayoutConstraintAxisHorizontal];
        [[self headerLabel] setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                            forAxis:UILayoutConstraintAxisHorizontal];
        [self addSubview:[self headerLabel]];

        [[self headerLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self headerLabel] topAnchor] constraintEqualToAnchor:[self topAnchor] constant:12],
            [[[self headerLabel] leadingAnchor] constraintEqualToAnchor:[[self iconImageView] trailingAnchor]
                                                               constant:16]
        ]];

        NSLayoutXAxisAnchor *textTrailingAnchor =
            [self contentImageView] ? [[self contentImageView] leadingAnchor] : [self trailingAnchor];
        CGFloat textTrailingConstant = [self contentImageView] ? -16 : -24;

        if ([[content tagHexColor] length] > 0) {
            [self setTagDotView:[[UIView alloc] init]];
            [[self tagDotView]
                setBackgroundColor:[KayokoTagColorFormatter visibleColorFromHexColor:[content tagHexColor]]];
            [[[self tagDotView] layer] setCornerRadius:kKayokoTableViewCellTagDotSize / 2.0];
            [self addSubview:[self tagDotView]];
            [[self tagDotView] setTranslatesAutoresizingMaskIntoConstraints:NO];
            [NSLayoutConstraint activateConstraints:@[
                [[[self tagDotView] leadingAnchor] constraintEqualToAnchor:[[self headerLabel] trailingAnchor]
                                                                  constant:6],
                [[[self tagDotView] widthAnchor] constraintEqualToConstant:kKayokoTableViewCellTagDotSize],
                [[[self tagDotView] heightAnchor] constraintEqualToConstant:kKayokoTableViewCellTagDotSize],
                [[[self tagDotView] centerYAnchor] constraintEqualToAnchor:[[self headerLabel] centerYAnchor]],
                [[[self tagDotView] trailingAnchor] constraintLessThanOrEqualToAnchor:textTrailingAnchor
                                                                             constant:textTrailingConstant]
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[ [[[self headerLabel] trailingAnchor]
                                                        constraintEqualToAnchor:textTrailingAnchor
                                                                       constant:textTrailingConstant] ]];
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
            [[[self contentLabel] trailingAnchor] constraintEqualToAnchor:textTrailingAnchor
                                                                 constant:textTrailingConstant]
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
