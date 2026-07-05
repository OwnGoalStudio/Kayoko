//
//  KayokoSearchTokenListViewController.m
//  Kayoko
//

#import "KayokoSearchTokenListViewController.h"

#import "KayokoApplicationMetadataProvider.h"
#import "KayokoPasteboardManager.h"
#import "KayokoSearchCriteria.h"

#import <QuartzCore/QuartzCore.h>

static CGFloat const kKayokoSearchTokenHorizontalInset = 24;
static CGFloat const kKayokoSearchTokenSectionSpacing = 12;
static CGFloat const kKayokoSearchTokenTitleHeight = 20;
static CGFloat const kKayokoSearchTokenItemHeight = 38;
static CGFloat const kKayokoSearchTokenItemSpacing = 8;
static CGFloat const kKayokoSearchTokenIconSize = 20;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchTokenCollectionViewCell : UICollectionViewCell
@property(nonatomic, strong) UIImageView *iconView;
@property(nonatomic, strong) UILabel *titleLabel;
- (void)configureWithToken:(KayokoSearchToken *)token icon:(nullable UIImage *)icon;
@end

@implementation KayokoSearchTokenCollectionViewCell

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
    CGFloat iconY = floor((CGRectGetHeight(bounds) - kKayokoSearchTokenIconSize) / 2.0);
    [[self iconView] setFrame:CGRectMake(iconX, iconY, kKayokoSearchTokenIconSize, kKayokoSearchTokenIconSize)];

    CGFloat titleX = CGRectGetMaxX([[self iconView] frame]) + 8;
    [[self titleLabel] setFrame:CGRectMake(titleX, 0, CGRectGetWidth(bounds) - titleX - 10, CGRectGetHeight(bounds))];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [[self iconView] setImage:nil];
    [[self titleLabel] setText:nil];
}

- (void)configureWithToken:(KayokoSearchToken *)token icon:(nullable UIImage *)icon {
    [[self titleLabel] setText:[token title]];
    [[self iconView] setImage:icon];
}

@end

@interface KayokoSearchTokenListViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property(nonatomic, strong) UILabel *categoryTitleLabel;
@property(nonatomic, strong) UILabel *appTitleLabel;
@property(nonatomic, strong) UICollectionView *categoryCollectionView;
@property(nonatomic, strong) UICollectionView *appCollectionView;
@property(nonatomic, strong) NSArray<KayokoSearchToken *> *categoryTokens;
@property(nonatomic, strong) NSArray<KayokoSearchToken *> *appTokens;
@property(nonatomic, strong) KayokoSearchCriteria *searchCriteria;
@property(nonatomic, strong) KayokoApplicationMetadataProvider *metadataProvider;
@property(nonatomic, assign) CGFloat lastPreferredHeight;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSearchTokenListViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _searchCriteria = [KayokoSearchCriteria emptyCriteria];
        _categoryTokens = [self newCategoryTokens];
        _appTokens = @[];
        _metadataProvider = [[KayokoApplicationMetadataProvider alloc] init];
    }
    return self;
}

- (void)loadView {
    UIView *view = [[UIView alloc] init];
    [view setBackgroundColor:[UIColor clearColor]];
    [self setView:view];

    _categoryTitleLabel = [self
        newSectionTitleLabelWithText:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Categories"
                                                                                                   value:nil
                                                                                                   table:@"Tweak"]];
    [view addSubview:_categoryTitleLabel];

    _appTitleLabel = [self
        newSectionTitleLabelWithText:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Applications"
                                                                                                   value:nil
                                                                                                   table:@"Tweak"]];
    [view addSubview:_appTitleLabel];

    _categoryCollectionView = [self newCollectionView];
    _appCollectionView = [self newCollectionView];
    [view addSubview:_categoryCollectionView];
    [view addSubview:_appCollectionView];
}

- (UILabel *)newSectionTitleLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    [label setText:text];
    [label setTextColor:[UIColor secondaryLabelColor]];
    [label setFont:[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]];
    return label;
}

- (UICollectionView *)newCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    [layout setMinimumInteritemSpacing:kKayokoSearchTokenItemSpacing];
    [layout setMinimumLineSpacing:kKayokoSearchTokenItemSpacing];
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    [collectionView setBackgroundColor:[UIColor clearColor]];
    [collectionView setScrollEnabled:NO];
    [collectionView setDataSource:self];
    [collectionView setDelegate:self];
    [collectionView registerClass:[KayokoSearchTokenCollectionViewCell class]
        forCellWithReuseIdentifier:@"KayokoSearchTokenCollectionViewCell"];
    return collectionView;
}

- (NSArray<KayokoSearchToken *> *)newCategoryTokens {
    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    return @[
        [KayokoSearchToken tokenWithType:kKayokoSearchTokenTypeCategory
                                   value:kKayokoSearchCategoryText
                                   title:[bundle localizedStringForKey:@"Text" value:nil table:@"Tweak"]
                               imageName:@"text.alignleft"],
        [KayokoSearchToken tokenWithType:kKayokoSearchTokenTypeCategory
                                   value:kKayokoSearchCategoryLink
                                   title:[bundle localizedStringForKey:@"Links" value:nil table:@"Tweak"]
                               imageName:@"link"],
        [KayokoSearchToken tokenWithType:kKayokoSearchTokenTypeCategory
                                   value:kKayokoSearchCategoryPhone
                                   title:[bundle localizedStringForKey:@"Phone Numbers" value:nil table:@"Tweak"]
                               imageName:@"phone.fill"],
        [KayokoSearchToken tokenWithType:kKayokoSearchTokenTypeCategory
                                   value:kKayokoSearchCategoryDate
                                   title:[bundle localizedStringForKey:@"Dates" value:nil table:@"Tweak"]
                               imageName:@"calendar"],
        [KayokoSearchToken tokenWithType:kKayokoSearchTokenTypeCategory
                                   value:kKayokoSearchCategoryFlight
                                   title:[bundle localizedStringForKey:@"Flights" value:nil table:@"Tweak"]
                               imageName:@"airplane"],
        [KayokoSearchToken tokenWithType:kKayokoSearchTokenTypeCategory
                                   value:kKayokoSearchCategoryAddress
                                   title:[bundle localizedStringForKey:@"Addresses" value:nil table:@"Tweak"]
                               imageName:@"mappin.and.ellipse"],
        [KayokoSearchToken tokenWithType:kKayokoSearchTokenTypeCategory
                                   value:kKayokoSearchCategoryImage
                                   title:[bundle localizedStringForKey:@"Images" value:nil table:@"Tweak"]
                               imageName:@"photo.fill"]
    ];
}

- (BOOL)showsCategorySection {
    return ![[self searchCriteria] hasCategoryToken];
}

- (BOOL)showsAppSection {
    return ![[self searchCriteria] hasAppToken] && [[self appTokens] count] > 0;
}

- (void)updateWithSearchCriteria:(KayokoSearchCriteria *)searchCriteria
                       appTokens:(NSArray<KayokoSearchToken *> *)appTokens {
    [self setSearchCriteria:searchCriteria ?: [KayokoSearchCriteria emptyCriteria]];
    [self setAppTokens:appTokens ?: @[]];
    [[self categoryCollectionView] reloadData];
    [[self appCollectionView] reloadData];
    [self updateSectionVisibility];
    [self notifyContentHeightIfNeeded];
}

- (void)updateSectionVisibility {
    BOOL showsCategory = [self showsCategorySection];
    BOOL showsApp = [self showsAppSection];
    [[self categoryTitleLabel] setHidden:!showsCategory];
    [[self categoryCollectionView] setHidden:!showsCategory];
    [[self appTitleLabel] setHidden:!showsApp];
    [[self appCollectionView] setHidden:!showsApp];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutSectionsForWidth:CGRectGetWidth([[self view] bounds])];
    [self notifyContentHeightIfNeeded];
}

- (CGFloat)collectionHeightForItemCount:(NSUInteger)itemCount {
    if (itemCount == 0) {
        return 0;
    }
    NSUInteger rowCount = (itemCount + 1) / 2;
    return rowCount * kKayokoSearchTokenItemHeight + (rowCount - 1) * kKayokoSearchTokenItemSpacing;
}

- (CGFloat)preferredContentHeightForWidth:(CGFloat)width {
    (void)width;
    CGFloat height = 0;
    if ([self showsCategorySection]) {
        height += kKayokoSearchTokenSectionSpacing + kKayokoSearchTokenTitleHeight + 8 +
                  [self collectionHeightForItemCount:[[self categoryTokens] count]];
    }
    if ([self showsAppSection]) {
        height += kKayokoSearchTokenSectionSpacing + kKayokoSearchTokenTitleHeight + 8 +
                  [self collectionHeightForItemCount:[[self appTokens] count]];
    }
    return height > 0 ? height + kKayokoSearchTokenSectionSpacing : 0;
}

- (void)layoutSectionsForWidth:(CGFloat)width {
    CGFloat y = 0;
    CGFloat contentWidth = MAX(width - kKayokoSearchTokenHorizontalInset * 2, 0);
    if ([self showsCategorySection]) {
        y += kKayokoSearchTokenSectionSpacing;
        [[self categoryTitleLabel]
            setFrame:CGRectMake(kKayokoSearchTokenHorizontalInset, y, contentWidth, kKayokoSearchTokenTitleHeight)];
        y += kKayokoSearchTokenTitleHeight + 8;
        CGFloat collectionHeight = [self collectionHeightForItemCount:[[self categoryTokens] count]];
        [[self categoryCollectionView]
            setFrame:CGRectMake(kKayokoSearchTokenHorizontalInset, y, contentWidth, collectionHeight)];
        y += collectionHeight;
    }
    if ([self showsAppSection]) {
        y += kKayokoSearchTokenSectionSpacing;
        [[self appTitleLabel]
            setFrame:CGRectMake(kKayokoSearchTokenHorizontalInset, y, contentWidth, kKayokoSearchTokenTitleHeight)];
        y += kKayokoSearchTokenTitleHeight + 8;
        CGFloat collectionHeight = [self collectionHeightForItemCount:[[self appTokens] count]];
        [[self appCollectionView]
            setFrame:CGRectMake(kKayokoSearchTokenHorizontalInset, y, contentWidth, collectionHeight)];
    }
    [[[self categoryCollectionView] collectionViewLayout] invalidateLayout];
    [[[self appCollectionView] collectionViewLayout] invalidateLayout];
}

- (void)notifyContentHeightIfNeeded {
    CGFloat preferredHeight = [self preferredContentHeightForWidth:CGRectGetWidth([[self view] bounds])];
    if (fabs(preferredHeight - [self lastPreferredHeight]) < 0.5) {
        return;
    }
    [self setLastPreferredHeight:preferredHeight];
    if ([self contentHeightDidChange]) {
        [self contentHeightDidChange]();
    }
}

- (NSArray<KayokoSearchToken *> *)tokensForCollectionView:(UICollectionView *)collectionView {
    return collectionView == [self appCollectionView] ? [self appTokens] : [self categoryTokens];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    (void)section;
    return (NSInteger)[[self tokensForCollectionView:collectionView] count];
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    KayokoSearchTokenCollectionViewCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:@"KayokoSearchTokenCollectionViewCell"
                                                  forIndexPath:indexPath];
    KayokoSearchToken *token = [self tokensForCollectionView:collectionView][(NSUInteger)[indexPath item]];
    UIImage *icon = nil;
    if ([[token type] isEqualToString:kKayokoSearchTokenTypeApp]) {
        icon = [[self metadataProvider] smallIconForBundleIdentifier:[token value]];
    } else if ([[token imageName] length] > 0) {
        icon = [UIImage systemImageNamed:[token imageName]];
    }
    [cell configureWithToken:token icon:icon];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                    layout:(UICollectionViewLayout *)collectionViewLayout
    sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    (void)collectionViewLayout;
    (void)indexPath;
    CGFloat width = floor((CGRectGetWidth([collectionView bounds]) - kKayokoSearchTokenItemSpacing) / 2.0);
    return CGSizeMake(MAX(width, 1), kKayokoSearchTokenItemHeight);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<KayokoSearchToken *> *tokens = [self tokensForCollectionView:collectionView];
    if ((NSUInteger)[indexPath item] >= [tokens count]) {
        return;
    }
    [[self delegate] searchTokenListViewController:self didSelectToken:tokens[(NSUInteger)[indexPath item]]];
}

@end
