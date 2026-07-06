//
//  KayokoSearchTokenCollectionViewCell.m
//  Kayoko
//

#import "KayokoSearchTokenCollectionViewCell.h"

#import <QuartzCore/QuartzCore.h>

static CGFloat const kKayokoSearchTokenCellIconSize = 20;

@interface KayokoSearchTokenCollectionViewCell ()
@property(nonatomic, strong) UIImageView *iconView;
@property(nonatomic, strong) UILabel *titleLabel;
@end

@implementation KayokoSearchTokenCollectionViewCell

+ (NSString *)reuseIdentifier {
    return @"KayokoSearchTokenCollectionViewCell";
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [[self contentView] setBackgroundColor:[UIColor tertiarySystemFillColor]];
        [[[self contentView] layer] setCornerRadius:8];
        [[[self contentView] layer] setCornerCurve:kCACornerCurveContinuous];

        _iconView = [[UIImageView alloc] init];
        [_iconView setContentMode:UIViewContentModeScaleAspectFit];
        [_iconView setTintColor:[UIColor labelColor]];
        [[self contentView] addSubview:_iconView];

        _titleLabel = [[UILabel alloc] init];
        [_titleLabel setFont:[UIFont systemFontOfSize:14 weight:UIFontWeightMedium]];
        [_titleLabel setTextColor:[UIColor labelColor]];
        [_titleLabel setLineBreakMode:NSLineBreakByTruncatingTail];
        [[self contentView] addSubview:_titleLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect bounds = [[self contentView] bounds];
    CGFloat iconX = 12;
    CGFloat iconY = floor((CGRectGetHeight(bounds) - kKayokoSearchTokenCellIconSize) / 2.0);
    [[self iconView] setFrame:CGRectMake(iconX, iconY, kKayokoSearchTokenCellIconSize, kKayokoSearchTokenCellIconSize)];

    CGFloat titleX = CGRectGetMaxX([[self iconView] frame]) + 8;
    [[self titleLabel] setFrame:CGRectMake(titleX, 0, CGRectGetWidth(bounds) - titleX - 10, CGRectGetHeight(bounds))];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [[self iconView] setImage:nil];
    [[self titleLabel] setText:nil];
}

- (void)configureWithTitle:(NSString *)title icon:(nullable UIImage *)icon {
    [[self titleLabel] setText:title];
    [[self iconView] setImage:icon];
}

@end
