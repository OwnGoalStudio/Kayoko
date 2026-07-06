//
//  KayokoSearchTokenSectionView.m
//  Kayoko
//

#import "KayokoSearchTokenSectionView.h"

#import "KayokoSearchTokenCollectionView.h"

static CGFloat const kKayokoSearchTokenSectionHorizontalInset = 24;
static CGFloat const kKayokoSearchTokenSectionTitleHeight = 20;
static CGFloat const kKayokoSearchTokenSectionTitleBottomSpacing = 8;
static CGFloat const kKayokoSearchTokenSectionItemWidth = 156;
static CGFloat const kKayokoSearchTokenSectionItemHeight = 38;
static CGFloat const kKayokoSearchTokenSectionItemSpacing = 8;
static CGFloat const kKayokoSearchTokenSectionCollectionHeight = 84;

@interface KayokoSearchTokenSectionView ()
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong, readwrite) KayokoSearchTokenCollectionView *collectionView;
@end

@implementation KayokoSearchTokenSectionView

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self setBackgroundColor:[UIColor clearColor]];

        _titleLabel = [[UILabel alloc] init];
        [_titleLabel setText:title];
        [_titleLabel setTextColor:[UIColor secondaryLabelColor]];
        [_titleLabel setFont:[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]];
        [self addSubview:_titleLabel];

        _collectionView = [[KayokoSearchTokenCollectionView alloc]
                  initWithItemSize:CGSizeMake(kKayokoSearchTokenSectionItemWidth, kKayokoSearchTokenSectionItemHeight)
                       itemSpacing:kKayokoSearchTokenSectionItemSpacing
            horizontalContentInset:kKayokoSearchTokenSectionHorizontalInset];
        [self addSubview:_collectionView];
    }
    return self;
}

+ (CGFloat)preferredHeight {
    return kKayokoSearchTokenSectionTitleHeight + kKayokoSearchTokenSectionTitleBottomSpacing +
           kKayokoSearchTokenSectionCollectionHeight;
}

- (CGFloat)preferredHeight {
    return [[self class] preferredHeight];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth([self bounds]);
    CGFloat contentWidth = MAX(width - kKayokoSearchTokenSectionHorizontalInset * 2, 0);
    [[self titleLabel] setFrame:CGRectMake(kKayokoSearchTokenSectionHorizontalInset, 0, contentWidth,
                                           kKayokoSearchTokenSectionTitleHeight)];
    [[self collectionView]
        setFrame:CGRectMake(0, kKayokoSearchTokenSectionTitleHeight + kKayokoSearchTokenSectionTitleBottomSpacing,
                            width, kKayokoSearchTokenSectionCollectionHeight)];
}

@end
