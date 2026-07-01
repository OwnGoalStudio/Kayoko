//
//  KayokoWordTokenView.m
//  Kayoko
//

#import "KayokoWordTokenView.h"

@implementation KayokoWordTokenView {
    NSString *_title;
    UIColor *_titleColor;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        _titleLabel = [[UILabel alloc] init];
        [_titleLabel setTextAlignment:NSTextAlignmentCenter];
        [self addSubview:_titleLabel];
    }

    return self;
}

- (void)setTitle:(NSString *)title forState:(UIControlState)state {
    if (state != UIControlStateNormal) {
        return;
    }

    _title = [title copy];
    [[self titleLabel] setText:_title];
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state {
    if (state != UIControlStateNormal) {
        return;
    }

    _titleColor = color;
    [[self titleLabel] setTextColor:_titleColor];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [[self titleLabel] setFrame:UIEdgeInsetsInsetRect([self bounds], [self kayokoContentInsets])];
}

- (CGSize)sizeThatFits:(CGSize)size {
    UIEdgeInsets contentInsets = [self kayokoContentInsets];
    CGFloat availableWidth = MAX(size.width - contentInsets.left - contentInsets.right, 0);
    CGFloat availableHeight = MAX(size.height - contentInsets.top - contentInsets.bottom, 0);
    CGSize titleSize = [[self titleLabel] sizeThatFits:CGSizeMake(availableWidth, availableHeight)];
    return CGSizeMake(titleSize.width + contentInsets.left + contentInsets.right,
                      titleSize.height + contentInsets.top + contentInsets.bottom);
}

- (CGSize)intrinsicContentSize {
    return [self sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
}

@end
