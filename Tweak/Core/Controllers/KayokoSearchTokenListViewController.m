//
//  KayokoSearchTokenListViewController.m
//  Kayoko
//

#import "KayokoSearchTokenListViewController.h"

#import "KayokoApplicationMetadataProvider.h"
#import "KayokoPasteboardManager.h"
#import "KayokoSearchCriteria.h"
#import "KayokoSearchTokenCollectionView.h"
#import "KayokoSearchTokenCollectionViewCell.h"
#import "KayokoSearchTokenSectionView.h"

static CGFloat const kKayokoSearchTokenTopInset = 12;
static CGFloat const kKayokoSearchTokenBottomInset = 16;
static CGFloat const kKayokoSearchTokenSectionSpacing = 16;
static NSUInteger const kKayokoSearchTokenMaximumVerticalAppTokenCount = 2;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchTokenListViewController () <UICollectionViewDataSource, UICollectionViewDelegate>
@property(nonatomic, strong) KayokoSearchTokenSectionView *categorySectionView;
@property(nonatomic, strong) KayokoSearchTokenSectionView *appSectionView;
@property(nonatomic, strong) NSArray<KayokoSearchToken *> *categoryTokens;
@property(nonatomic, strong) NSArray<KayokoSearchToken *> *appTokens;
@property(nonatomic, strong) KayokoSearchCriteria *searchCriteria;
@property(nonatomic, strong) KayokoApplicationMetadataProvider *metadataProvider;
@property(nonatomic, assign) CGFloat lastPreferredHeight;
@property(nonatomic, assign) BOOL needsCategoryContentOffsetReset;
@property(nonatomic, assign) BOOL needsAppContentOffsetReset;
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
        _needsCategoryContentOffsetReset = YES;
        _needsAppContentOffsetReset = YES;
    }
    return self;
}

- (void)loadView {
    UIView *view = [[UIView alloc] init];
    [view setBackgroundColor:[UIColor clearColor]];
    [self setView:view];

    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    _categorySectionView = [[KayokoSearchTokenSectionView alloc]
        initWithTitle:[bundle localizedStringForKey:@"Categories" value:nil table:@"Tweak"]];
    _appSectionView = [[KayokoSearchTokenSectionView alloc] initWithTitle:[bundle localizedStringForKey:@"Applications"
                                                                                                  value:nil
                                                                                                  table:@"Tweak"]];
    [view addSubview:_categorySectionView];
    [view addSubview:_appSectionView];

    [self configureCollectionView:[_categorySectionView collectionView]];
    [self configureCollectionView:[_appSectionView collectionView]];
}

- (void)configureCollectionView:(UICollectionView *)collectionView {
    [collectionView setDataSource:self];
    [collectionView setDelegate:self];
    [collectionView registerClass:[KayokoSearchTokenCollectionViewCell class]
        forCellWithReuseIdentifier:[KayokoSearchTokenCollectionViewCell reuseIdentifier]];
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
    [self setNeedsCategoryContentOffsetReset:YES];
    [self setNeedsAppContentOffsetReset:YES];
    [self configureAppSectionForWidth:CGRectGetWidth([[self view] bounds])];
    [[[self categorySectionView] collectionView] reloadData];
    [[[self appSectionView] collectionView] reloadData];
    [self updateSectionVisibility];
    [[self view] setNeedsLayout];
    [self notifyContentHeightIfNeeded];
}

- (void)updateSectionVisibility {
    BOOL showsCategory = [self showsCategorySection];
    BOOL showsApp = [self showsAppSection];
    [[self categorySectionView] setHidden:!showsCategory];
    [[self appSectionView] setHidden:!showsApp];
}

- (BOOL)usesHorizontalScrollingLayoutForAppSection {
    return [[self appTokens] count] > kKayokoSearchTokenMaximumVerticalAppTokenCount;
}

- (void)configureAppSectionForWidth:(CGFloat)width {
    BOOL usesHorizontalScrollingLayout = [self usesHorizontalScrollingLayoutForAppSection];
    NSUInteger numberOfRows = [KayokoSearchTokenSectionView numberOfRowsForItemCount:[[self appTokens] count]
                                                                               width:width
                                                           horizontalScrollingLayout:usesHorizontalScrollingLayout];
    [[self appSectionView] setHorizontalScrollingLayout:usesHorizontalScrollingLayout];
    if (numberOfRows > 0) {
        [[self appSectionView] setNumberOfRows:numberOfRows];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutSectionsForWidth:CGRectGetWidth([[self view] bounds])];
    [self resetPendingCollectionViewContentOffsetsIfNeeded];
    [self updateVisibleEdgeFadeMasks];
    [self notifyContentHeightIfNeeded];
}

- (CGFloat)preferredContentHeightForWidth:(CGFloat)width {
    (void)width;
    BOOL showsCategory = [self showsCategorySection];
    BOOL showsApp = [self showsAppSection];
    if (!showsCategory && !showsApp) {
        return 0;
    }

    CGFloat height = kKayokoSearchTokenTopInset + kKayokoSearchTokenBottomInset;
    if (showsCategory) {
        height += [KayokoSearchTokenSectionView preferredHeight];
    }
    if (showsApp) {
        if (showsCategory) {
            height += kKayokoSearchTokenSectionSpacing;
        }
        height += [KayokoSearchTokenSectionView
            preferredHeightForItemCount:[[self appTokens] count]
                                  width:width
              horizontalScrollingLayout:[self usesHorizontalScrollingLayoutForAppSection]];
    }
    return height;
}

- (void)layoutSectionsForWidth:(CGFloat)width {
    CGFloat y = 0;
    BOOL didLayoutSection = NO;
    if ([self showsCategorySection]) {
        y += kKayokoSearchTokenTopInset;
        CGFloat sectionHeight = [KayokoSearchTokenSectionView preferredHeight];
        [[self categorySectionView] setFrame:CGRectMake(0, y, width, sectionHeight)];
        [[self categorySectionView] layoutIfNeeded];
        y += sectionHeight;
        didLayoutSection = YES;
    }
    if ([self showsAppSection]) {
        [self configureAppSectionForWidth:width];
        y += didLayoutSection ? kKayokoSearchTokenSectionSpacing : kKayokoSearchTokenTopInset;
        CGFloat sectionHeight = [[self appSectionView] preferredHeight];
        [[self appSectionView] setFrame:CGRectMake(0, y, width, sectionHeight)];
        [[self appSectionView] layoutIfNeeded];
    }
}

- (void)updateVisibleEdgeFadeMasks {
    if (![[self categorySectionView] isHidden]) {
        [[[self categorySectionView] collectionView] updateEdgeFadeMask];
    }
    if (![[self appSectionView] isHidden]) {
        [[[self appSectionView] collectionView] updateEdgeFadeMask];
    }
}

- (void)resetPendingCollectionViewContentOffsetsIfNeeded {
    if ([self needsCategoryContentOffsetReset] && ![[self categorySectionView] isHidden]) {
        [[[self categorySectionView] collectionView] resetContentOffsetToLeadingEdge];
        [self setNeedsCategoryContentOffsetReset:NO];
    }
    if ([self needsAppContentOffsetReset] && ![[self appSectionView] isHidden]) {
        [[[self appSectionView] collectionView] resetContentOffsetToLeadingEdge];
        [self setNeedsAppContentOffsetReset:NO];
    }
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
    return collectionView == [[self appSectionView] collectionView] ? [self appTokens] : [self categoryTokens];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    (void)section;
    return (NSInteger)[[self tokensForCollectionView:collectionView] count];
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    KayokoSearchTokenCollectionViewCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:[KayokoSearchTokenCollectionViewCell reuseIdentifier]
                                                  forIndexPath:indexPath];
    KayokoSearchToken *token = [self tokensForCollectionView:collectionView][(NSUInteger)[indexPath item]];
    UIImage *icon = nil;
    if ([[token type] isEqualToString:kKayokoSearchTokenTypeApp]) {
        icon = [[self metadataProvider] smallIconForBundleIdentifier:[token value]];
    } else if ([[token imageName] length] > 0) {
        icon = [UIImage systemImageNamed:[token imageName]];
    }
    [cell configureWithTitle:[token title] icon:icon];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<KayokoSearchToken *> *tokens = [self tokensForCollectionView:collectionView];
    if ((NSUInteger)[indexPath item] >= [tokens count]) {
        return;
    }
    [[self delegate] searchTokenListViewController:self didSelectToken:tokens[(NSUInteger)[indexPath item]]];
}

@end
