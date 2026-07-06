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
static NSUInteger const kKayokoSearchTokenSectionDefaultRowCount = 2;

@interface KayokoSearchTokenSectionView ()
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong, readwrite) KayokoSearchTokenCollectionView *collectionView;
@end

@implementation KayokoSearchTokenSectionView

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _numberOfRows = kKayokoSearchTokenSectionDefaultRowCount;
        _horizontalScrollingLayout = YES;
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

+ (NSUInteger)normalizedNumberOfRows:(NSUInteger)numberOfRows {
    return MAX(numberOfRows, 1);
}

+ (CGFloat)collectionHeightForNumberOfRows:(NSUInteger)numberOfRows {
    NSUInteger normalizedNumberOfRows = [self normalizedNumberOfRows:numberOfRows];
    return normalizedNumberOfRows * kKayokoSearchTokenSectionItemHeight +
           (normalizedNumberOfRows - 1) * kKayokoSearchTokenSectionItemSpacing;
}

+ (CGFloat)preferredHeight {
    return [self preferredHeightForNumberOfRows:kKayokoSearchTokenSectionDefaultRowCount];
}

+ (CGFloat)preferredHeightForNumberOfRows:(NSUInteger)numberOfRows {
    return kKayokoSearchTokenSectionTitleHeight + kKayokoSearchTokenSectionTitleBottomSpacing +
           [self collectionHeightForNumberOfRows:numberOfRows];
}

+ (NSUInteger)numberOfColumnsForWidth:(CGFloat)width {
    if (width <= 0) {
        return 2;
    }

    CGFloat availableWidth = MAX(width - kKayokoSearchTokenSectionHorizontalInset * 2, 0);
    CGFloat columnWidth = kKayokoSearchTokenSectionItemWidth + kKayokoSearchTokenSectionItemSpacing;
    return MAX((NSUInteger)floor((availableWidth + kKayokoSearchTokenSectionItemSpacing) / columnWidth), 1);
}

+ (NSUInteger)numberOfRowsForItemCount:(NSUInteger)itemCount
                                 width:(CGFloat)width
             horizontalScrollingLayout:(BOOL)horizontalScrollingLayout {
    if (itemCount == 0) {
        return 0;
    }
    if (horizontalScrollingLayout) {
        return kKayokoSearchTokenSectionDefaultRowCount;
    }

    NSUInteger columns = [self numberOfColumnsForWidth:width];
    return (itemCount + columns - 1) / columns;
}

+ (CGFloat)preferredHeightForItemCount:(NSUInteger)itemCount
                                 width:(CGFloat)width
             horizontalScrollingLayout:(BOOL)horizontalScrollingLayout {
    NSUInteger numberOfRows = [self numberOfRowsForItemCount:itemCount
                                                       width:width
                                   horizontalScrollingLayout:horizontalScrollingLayout];
    if (numberOfRows == 0) {
        return 0;
    }

    return [self preferredHeightForNumberOfRows:numberOfRows];
}

- (CGFloat)preferredHeight {
    return [[self class] preferredHeightForNumberOfRows:[self numberOfRows]];
}

- (void)setNumberOfRows:(NSUInteger)numberOfRows {
    numberOfRows = [[self class] normalizedNumberOfRows:numberOfRows];
    if (_numberOfRows == numberOfRows) {
        return;
    }

    _numberOfRows = numberOfRows;
    [[self collectionView] setNeedsLayout];
    [[[self collectionView] collectionViewLayout] invalidateLayout];
    [self setNeedsLayout];
}

- (void)setHorizontalScrollingLayout:(BOOL)horizontalScrollingLayout {
    if (_horizontalScrollingLayout == horizontalScrollingLayout) {
        return;
    }

    _horizontalScrollingLayout = horizontalScrollingLayout;
    [[self collectionView] setHorizontalScrollingLayout:horizontalScrollingLayout];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth([self bounds]);
    CGFloat contentWidth = MAX(width - kKayokoSearchTokenSectionHorizontalInset * 2, 0);
    CGFloat collectionHeight = [[self class] collectionHeightForNumberOfRows:[self numberOfRows]];
    [[self titleLabel] setFrame:CGRectMake(kKayokoSearchTokenSectionHorizontalInset, 0, contentWidth,
                                           kKayokoSearchTokenSectionTitleHeight)];
    [[self collectionView]
        setFrame:CGRectMake(0, kKayokoSearchTokenSectionTitleHeight + kKayokoSearchTokenSectionTitleBottomSpacing,
                            width, collectionHeight)];
}

@end
