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
#import "KayokoTagColorFormatter.h"

static CGFloat const kKayokoSearchTokenTopInset = 12;
static CGFloat const kKayokoSearchTokenBottomInset = 20;
static CGFloat const kKayokoSearchTokenSectionSpacing = 16;
static NSUInteger const kKayokoSearchTokenMaximumVerticalAppTokenCount = 2;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchTokenListViewController () <UICollectionViewDataSource, UICollectionViewDelegate>
#pragma mark - Views

@property(nonatomic, strong) KayokoSearchTokenSectionView *categorySectionView;
@property(nonatomic, strong) KayokoSearchTokenSectionView *tagSectionView;
@property(nonatomic, strong) KayokoSearchTokenSectionView *appSectionView;

#pragma mark - Data

@property(nonatomic, strong) NSArray<KayokoSearchToken *> *categoryTokens;
@property(nonatomic, strong) NSArray<KayokoSearchToken *> *tagTokens;
@property(nonatomic, strong) NSArray<KayokoSearchToken *> *appTokens;
@property(nonatomic, strong) KayokoSearchCriteria *searchCriteria;
@property(nonatomic, strong) KayokoApplicationMetadataProvider *metadataProvider;

#pragma mark - Layout State

@property(nonatomic, assign) CGFloat lastPreferredHeight;
@property(nonatomic, assign) BOOL needsCategoryContentOffsetReset;
@property(nonatomic, assign) BOOL needsTagContentOffsetReset;
@property(nonatomic, assign) BOOL needsAppContentOffsetReset;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSearchTokenListViewController

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _searchCriteria = [KayokoSearchCriteria emptyCriteria];
        _categoryTokens = [self newCategoryTokens];
        _tagTokens = @[];
        _appTokens = @[];
        _metadataProvider = [[KayokoApplicationMetadataProvider alloc] init];
        _needsCategoryContentOffsetReset = YES;
        _needsTagContentOffsetReset = YES;
        _needsAppContentOffsetReset = YES;
    }
    return self;
}

#pragma mark - View Setup

- (void)loadView {
    UIView *view = [[UIView alloc] init];
    [view setBackgroundColor:[UIColor clearColor]];
    [self setView:view];

    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    _categorySectionView = [[KayokoSearchTokenSectionView alloc]
        initWithTitle:[bundle localizedStringForKey:@"Categories" value:nil table:@"Tweak"]];
    _tagSectionView = [[KayokoSearchTokenSectionView alloc] initWithTitle:[bundle localizedStringForKey:@"Tags"
                                                                                                  value:nil
                                                                                                  table:@"Tweak"]];
    _appSectionView = [[KayokoSearchTokenSectionView alloc] initWithTitle:[bundle localizedStringForKey:@"Applications"
                                                                                                  value:nil
                                                                                                  table:@"Tweak"]];
    [view addSubview:_categorySectionView];
    [view addSubview:_tagSectionView];
    [view addSubview:_appSectionView];

    [self configureCollectionView:[_categorySectionView collectionView]];
    [self configureCollectionView:[_tagSectionView collectionView]];
    [self configureCollectionView:[_appSectionView collectionView]];
}

- (void)configureCollectionView:(UICollectionView *)collectionView {
    [collectionView setDataSource:self];
    [collectionView setDelegate:self];
    [collectionView registerClass:[KayokoSearchTokenCollectionViewCell class]
        forCellWithReuseIdentifier:[KayokoSearchTokenCollectionViewCell reuseIdentifier]];
}

#pragma mark - Token Sources

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

#pragma mark - State

- (BOOL)showsCategorySection {
    return ![[self searchCriteria] hasCategoryToken];
}

- (BOOL)showsAppSection {
    return ![[self searchCriteria] hasAppToken] && [[self appTokens] count] > 0;
}

- (BOOL)showsTagSection {
    return ![[self searchCriteria] hasTagToken] && [[self tagTokens] count] > 0;
}

- (BOOL)tokenArray:(NSArray<KayokoSearchToken *> *)left
    isDisplayEqualToTokenArray:(NSArray<KayokoSearchToken *> *)right {
    if ([left count] != [right count]) {
        return NO;
    }

    for (NSUInteger index = 0; index < [left count]; index++) {
        if (![left[index] isDisplayEqualToToken:right[index]]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)searchCriteria:(KayokoSearchCriteria *)left
    hasSameSelectedTokensAsSearchCriteria:(KayokoSearchCriteria *)right {
    return [([left categoryValue] ?: @"") isEqualToString:([right categoryValue] ?: @"")] &&
           [([left tagUUID] ?: @"") isEqualToString:([right tagUUID] ?: @"")] &&
           [([left appBundleIdentifier] ?: @"") isEqualToString:([right appBundleIdentifier] ?: @"")];
}

- (void)updateWithSearchCriteria:(KayokoSearchCriteria *)searchCriteria
                       tagTokens:(NSArray<KayokoSearchToken *> *)tagTokens
                       appTokens:(NSArray<KayokoSearchToken *> *)appTokens {
    KayokoSearchCriteria *newSearchCriteria = searchCriteria ?: [KayokoSearchCriteria emptyCriteria];
    NSArray<KayokoSearchToken *> *newTagTokens = tagTokens ?: @[];
    NSArray<KayokoSearchToken *> *newAppTokens = appTokens ?: @[];

    BOOL oldShowsCategory = [self showsCategorySection];
    BOOL oldShowsTag = [self showsTagSection];
    BOOL oldShowsApp = [self showsAppSection];
    BOOL oldTagUsesHorizontalLayout = [self usesHorizontalScrollingLayoutForTagSection];
    BOOL oldAppUsesHorizontalLayout = [self usesHorizontalScrollingLayoutForAppSection];

    BOOL selectedTokensChanged = ![self searchCriteria:[self searchCriteria]
                 hasSameSelectedTokensAsSearchCriteria:newSearchCriteria];
    BOOL tagTokensChanged = ![self tokenArray:[self tagTokens] isDisplayEqualToTokenArray:newTagTokens];
    BOOL appTokensChanged = ![self tokenArray:[self appTokens] isDisplayEqualToTokenArray:newAppTokens];

    [self setSearchCriteria:newSearchCriteria];
    if (tagTokensChanged) {
        [self setTagTokens:newTagTokens];
    }
    if (appTokensChanged) {
        [self setAppTokens:newAppTokens];
    }

    CGFloat width = CGRectGetWidth([[self view] bounds]);
    BOOL tagLayoutChanged = oldTagUsesHorizontalLayout != [self usesHorizontalScrollingLayoutForTagSection];
    BOOL appLayoutChanged = oldAppUsesHorizontalLayout != [self usesHorizontalScrollingLayoutForAppSection];
    if (tagTokensChanged || tagLayoutChanged) {
        [self setNeedsTagContentOffsetReset:YES];
        [self configureTagSectionForWidth:width];
        [[[self tagSectionView] collectionView] reloadData];
    }
    if (appTokensChanged || appLayoutChanged) {
        [self setNeedsAppContentOffsetReset:YES];
        [self configureAppSectionForWidth:width];
        [[[self appSectionView] collectionView] reloadData];
    }

    [self updateSectionVisibility];

    BOOL visibilityChanged = oldShowsCategory != [self showsCategorySection] || oldShowsTag != [self showsTagSection] ||
                             oldShowsApp != [self showsAppSection];
    if (selectedTokensChanged || tagTokensChanged || appTokensChanged || tagLayoutChanged || appLayoutChanged ||
        visibilityChanged) {
        [[self view] setNeedsLayout];
        [self notifyContentHeightIfNeeded];
    }
}

#pragma mark - Layout

- (void)updateSectionVisibility {
    BOOL showsCategory = [self showsCategorySection];
    BOOL showsTag = [self showsTagSection];
    BOOL showsApp = [self showsAppSection];
    [[self categorySectionView] setHidden:!showsCategory];
    [[self tagSectionView] setHidden:!showsTag];
    [[self appSectionView] setHidden:!showsApp];
}

- (BOOL)usesHorizontalScrollingLayoutForAppSection {
    return [[self appTokens] count] > kKayokoSearchTokenMaximumVerticalAppTokenCount;
}

- (BOOL)usesHorizontalScrollingLayoutForTagSection {
    return [[self tagTokens] count] > kKayokoSearchTokenMaximumVerticalAppTokenCount;
}

- (void)configureTagSectionForWidth:(CGFloat)width {
    BOOL usesHorizontalScrollingLayout = [self usesHorizontalScrollingLayoutForTagSection];
    NSUInteger numberOfRows = [KayokoSearchTokenSectionView numberOfRowsForItemCount:[[self tagTokens] count]
                                                                               width:width
                                                           horizontalScrollingLayout:usesHorizontalScrollingLayout];
    [[self tagSectionView] setHorizontalScrollingLayout:usesHorizontalScrollingLayout];
    if (numberOfRows > 0) {
        [[self tagSectionView] setNumberOfRows:numberOfRows];
    }
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
    BOOL showsTag = [self showsTagSection];
    BOOL showsApp = [self showsAppSection];
    if (!showsCategory && !showsTag && !showsApp) {
        return 0;
    }

    CGFloat height = kKayokoSearchTokenTopInset + kKayokoSearchTokenBottomInset;
    BOOL didAddSection = NO;
    if (showsCategory) {
        height += [KayokoSearchTokenSectionView preferredHeight];
        didAddSection = YES;
    }
    if (showsTag) {
        if (didAddSection) {
            height += kKayokoSearchTokenSectionSpacing;
        }
        height += [KayokoSearchTokenSectionView
            preferredHeightForItemCount:[[self tagTokens] count]
                                  width:width
              horizontalScrollingLayout:[self usesHorizontalScrollingLayoutForTagSection]];
        didAddSection = YES;
    }
    if (showsApp) {
        if (didAddSection) {
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
    if ([self showsTagSection]) {
        [self configureTagSectionForWidth:width];
        y += didLayoutSection ? kKayokoSearchTokenSectionSpacing : kKayokoSearchTokenTopInset;
        CGFloat sectionHeight = [[self tagSectionView] preferredHeight];
        [[self tagSectionView] setFrame:CGRectMake(0, y, width, sectionHeight)];
        [[self tagSectionView] layoutIfNeeded];
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
    if (![[self tagSectionView] isHidden]) {
        [[[self tagSectionView] collectionView] updateEdgeFadeMask];
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
    if ([self needsTagContentOffsetReset] && ![[self tagSectionView] isHidden]) {
        [[[self tagSectionView] collectionView] resetContentOffsetToLeadingEdge];
        [self setNeedsTagContentOffsetReset:NO];
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

#pragma mark - UICollectionViewDataSource

- (NSArray<KayokoSearchToken *> *)tokensForCollectionView:(UICollectionView *)collectionView {
    if (collectionView == [[self appSectionView] collectionView]) {
        return [self appTokens];
    }
    if (collectionView == [[self tagSectionView] collectionView]) {
        return [self tagTokens];
    }
    return [self categoryTokens];
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
    UIColor *dotColor = nil;
    UIColor *dotBorderColor = nil;
    if ([[token type] isEqualToString:kKayokoSearchTokenTypeApp]) {
        icon = [[self metadataProvider] smallIconForBundleIdentifier:[token value]];
    } else if ([[token type] isEqualToString:kKayokoSearchTokenTypeTag]) {
        dotColor = [KayokoTagColorFormatter visibleColorFromHexColor:[token displaySignature]];
        dotBorderColor = [KayokoTagColorFormatter borderColorFromHexColor:[token displaySignature]];
    } else if ([[token imageName] length] > 0) {
        icon = [UIImage systemImageNamed:[token imageName]];
    }
    [cell configureWithTitle:[token title] icon:icon dotColor:dotColor dotBorderColor:dotBorderColor];
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<KayokoSearchToken *> *tokens = [self tokensForCollectionView:collectionView];
    if ((NSUInteger)[indexPath item] >= [tokens count]) {
        return;
    }
    [[self delegate] searchTokenListViewController:self didSelectToken:tokens[(NSUInteger)[indexPath item]]];
}

@end
