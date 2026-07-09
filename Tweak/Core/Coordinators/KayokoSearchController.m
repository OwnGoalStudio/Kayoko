//
//  KayokoSearchController.m
//  Kayoko
//

#import "KayokoSearchController.h"

#import "KayokoApplicationMetadataProvider.h"
#import "KayokoHistoryListView.h"
#import "KayokoHistoryListViewController.h"
#import "KayokoPasteboardManager.h"
#import "KayokoSearchBar.h"
#import "KayokoSearchCriteria.h"
#import "KayokoSearchPresentationController.h"
#import "KayokoSearchTokenListViewController.h"
#import "KayokoTag.h"
#import "KayokoTagCatalog.h"
#import "KayokoTagColorFormatter.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchController () <UISearchBarDelegate, KayokoSearchPresentationControllerDelegate,
                                      KayokoSearchTokenListViewControllerDelegate>
#pragma mark - Presentation

@property(nonatomic, strong) KayokoSearchPresentationController *presentationController;
@property(nonatomic, weak) KayokoHistoryListViewController *historyListViewController;
@property(nonatomic, weak) KayokoHistoryListViewController *favoritesListViewController;
@property(nonatomic, strong) UISearchBar *historySearchBar;
@property(nonatomic, strong) UISearchBar *favoritesSearchBar;
@property(nonatomic, strong) KayokoSearchTokenListViewController *historyTokenListViewController;
@property(nonatomic, strong) KayokoSearchTokenListViewController *favoritesTokenListViewController;

#pragma mark - Tokens

@property(nonatomic, copy) NSArray<KayokoSearchToken *> *tagTokens;
@property(nonatomic, copy) NSArray<KayokoSearchToken *> *appTokens;
@property(nonatomic, strong) KayokoApplicationMetadataProvider *metadataProvider;

#pragma mark - State

@property(nonatomic, assign, getter=isSearchActive) BOOL searchActive;
@property(nonatomic, assign) BOOL isResettingSearch;
@property(nonatomic, assign) NSUInteger searchRequestIdentifier;
@property(nonatomic, assign) BOOL loadingAppTokens;
@property(nonatomic, assign) BOOL appTokensDirty;
@property(nonatomic, assign) BOOL needsAppTokenReloadAfterCurrentLoad;
@property(nonatomic, assign) NSUInteger appTokenLoadRequestIdentifier;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSearchController

#pragma mark - Lifecycle

- (instancetype)initWithContainerView:(UIView *)containerView
                           headerView:(UIView *)headerView
            historyListViewController:(KayokoHistoryListViewController *)historyListViewController
          favoritesListViewController:(KayokoHistoryListViewController *)favoritesListViewController
                 panGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer {
    self = [super init];
    if (self) {
        _historyListViewController = historyListViewController;
        _favoritesListViewController = favoritesListViewController;
        _historySearchBar = [self newSearchBar];
        _favoritesSearchBar = [self newSearchBar];
        _historyTokenListViewController = [[KayokoSearchTokenListViewController alloc] init];
        _favoritesTokenListViewController = [[KayokoSearchTokenListViewController alloc] init];
        [_historyTokenListViewController setDelegate:self];
        [_favoritesTokenListViewController setDelegate:self];
        __weak typeof(self) weakSelf = self;
        [_historyTokenListViewController setContentHeightDidChange:^{
          [weakSelf updateSearchTokenHeaderHeights];
        }];
        [_favoritesTokenListViewController setContentHeightDidChange:^{
          [weakSelf updateSearchTokenHeaderHeights];
        }];
        _tagTokens = @[];
        _appTokens = @[];
        _metadataProvider = [[KayokoApplicationMetadataProvider alloc] init];
        _appTokensDirty = YES;

        _presentationController =
            [[KayokoSearchPresentationController alloc] initWithContainerView:containerView
                                                                   headerView:headerView
                                                             historySearchBar:_historySearchBar
                                                           favoritesSearchBar:_favoritesSearchBar
                                                       historySearchTokenView:[_historyTokenListViewController view]
                                                     favoritesSearchTokenView:[_favoritesTokenListViewController view]
                                                             historyTableView:[historyListViewController tableView]
                                                           favoritesTableView:[favoritesListViewController tableView]
                                                         panGestureRecognizer:panGestureRecognizer];
        [_presentationController setDelegate:self];

        [self attachToListViewController:historyListViewController hidesSearchBar:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleHistoryDidChangeNotification:)
                                                     name:kKayokoPasteboardManagerHistoryDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (UISearchBar *)newSearchBar {
    UISearchBar *searchBar = [[KayokoSearchBar alloc] initWithFrame:CGRectZero];
    [searchBar setPlaceholder:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Search"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    [searchBar setSearchBarStyle:UISearchBarStyleMinimal];
    [searchBar setBackgroundImage:[[UIImage alloc] init]];
    [searchBar setTintColor:[UIColor labelColor]];
    [searchBar setDelegate:self];
    [[searchBar searchTextField] addTarget:self
                                    action:@selector(handleSearchTextFieldEditingChanged:)
                          forControlEvents:UIControlEventEditingChanged];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSearchTextFieldTextDidChangeNotification:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:[searchBar searchTextField]];
    return searchBar;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications

- (void)handleHistoryDidChangeNotification:(NSNotification *)notification {
    (void)notification;
    [self invalidateAppTokensAndReloadIfActive];
}

- (void)handleApplicationMetadataChanged {
    [self invalidateAppTokensAndReloadIfActive];
}

#pragma mark - View Lookup

- (void)setPresentationMode:(KayokoPanelPresentationMode)presentationMode {
    _presentationMode = presentationMode;
    [[self presentationController] setPresentationMode:presentationMode];
}

- (KayokoHistoryListViewController *)activeListViewController {
    return [[self delegate] activeListViewControllerForSearchController:self];
}

- (KayokoHistoryListView *)activeTableView {
    return [[self activeListViewController] tableView];
}

- (CGFloat)searchHeaderHeight {
    return [[self presentationController] searchHeaderHeight];
}

- (CGFloat)keyboardBottomInset {
    return [[self presentationController] keyboardBottomInset];
}

- (UISearchBar *)searchBarForTableView:(KayokoHistoryListView *)tableView {
    return tableView == [[self favoritesListViewController] tableView] ? [self favoritesSearchBar]
                                                                       : [self historySearchBar];
}

- (KayokoHistoryListViewController *)listViewControllerForSearchBar:(UISearchBar *)searchBar {
    return searchBar == [self favoritesSearchBar] ? [self favoritesListViewController]
                                                  : [self historyListViewController];
}

- (UISearchBar *)activeSearchBar {
    return [self searchBarForTableView:[self activeTableView]];
}

- (KayokoSearchTokenListViewController *)tokenListViewControllerForSearchBar:(UISearchBar *)searchBar {
    return searchBar == [self favoritesSearchBar] ? [self favoritesTokenListViewController]
                                                  : [self historyTokenListViewController];
}

- (KayokoSearchTokenListViewController *)tokenListViewControllerForListViewController:
    (KayokoHistoryListViewController *)listViewController {
    return listViewController == [self favoritesListViewController] ? [self favoritesTokenListViewController]
                                                                    : [self historyTokenListViewController];
}

#pragma mark - Token Matching

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

- (KayokoSearchToken *)tokenWithType:(NSString *)type
                               value:(NSString *)value
                            inTokens:(NSArray<KayokoSearchToken *> *)tokens {
    if ([value length] == 0) {
        return nil;
    }

    for (KayokoSearchToken *token in tokens) {
        if ([[token type] isEqualToString:type] && [[token value] isEqualToString:value]) {
            return token;
        }
    }
    return nil;
}

- (NSString *)appDisplaySignatureForBundleIdentifier:(NSString *)bundleIdentifier title:(NSString *)title {
    BOOL installed = [[self metadataProvider] hasApplicationForBundleIdentifier:bundleIdentifier];
    return [NSString stringWithFormat:@"installed=%@;title=%@", installed ? @"1" : @"0", title ?: @""];
}

- (KayokoSearchToken *)selectedCategoryTokenForCriteria:(KayokoSearchCriteria *)criteria
                                    tokenListController:(KayokoSearchTokenListViewController *)tokenListController {
    (void)tokenListController;
    NSString *categoryValue = [criteria categoryValue];
    if ([categoryValue length] == 0) {
        return nil;
    }

    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *metadata = @{
        kKayokoSearchCategoryText :
            @{@"title" : [bundle localizedStringForKey:@"Text" value:nil table:@"Tweak"], @"image" : @"text.alignleft"},
        kKayokoSearchCategoryLink :
            @{@"title" : [bundle localizedStringForKey:@"Links" value:nil table:@"Tweak"], @"image" : @"link"},
        kKayokoSearchCategoryPhone : @{
            @"title" : [bundle localizedStringForKey:@"Phone Numbers" value:nil table:@"Tweak"],
            @"image" : @"phone.fill"
        },
        kKayokoSearchCategoryDate :
            @{@"title" : [bundle localizedStringForKey:@"Dates" value:nil table:@"Tweak"], @"image" : @"calendar"},
        kKayokoSearchCategoryFlight :
            @{@"title" : [bundle localizedStringForKey:@"Flights" value:nil table:@"Tweak"], @"image" : @"airplane"},
        kKayokoSearchCategoryAddress : @{
            @"title" : [bundle localizedStringForKey:@"Addresses" value:nil table:@"Tweak"],
            @"image" : @"mappin.and.ellipse"
        },
        kKayokoSearchCategoryImage :
            @{@"title" : [bundle localizedStringForKey:@"Images" value:nil table:@"Tweak"], @"image" : @"photo.fill"}
    };
    NSDictionary<NSString *, NSString *> *tokenMetadata = metadata[categoryValue];
    if (!tokenMetadata) {
        return nil;
    }
    return [KayokoSearchToken tokenWithType:kKayokoSearchTokenTypeCategory
                                      value:categoryValue
                                      title:tokenMetadata[@"title"]
                                  imageName:tokenMetadata[@"image"]];
}

- (KayokoSearchToken *)selectedAppTokenForCriteria:(KayokoSearchCriteria *)criteria {
    NSString *bundleIdentifier = [criteria appBundleIdentifier];
    if ([bundleIdentifier length] == 0) {
        return nil;
    }
    return [self tokenWithType:kKayokoSearchTokenTypeApp value:bundleIdentifier inTokens:[self appTokens]];
}

- (KayokoSearchToken *)selectedTagTokenForCriteria:(KayokoSearchCriteria *)criteria {
    NSString *tagUUID = [criteria tagUUID];
    if ([tagUUID length] == 0) {
        return nil;
    }
    return [self tokenWithType:kKayokoSearchTokenTypeTag value:tagUUID inTokens:[self tagTokens]];
}

- (UIImage *)iconForSearchToken:(KayokoSearchToken *)token {
    if ([[token type] isEqualToString:kKayokoSearchTokenTypeApp]) {
        return [[self metadataProvider] smallIconForBundleIdentifier:[token value]];
    }
    if ([[token type] isEqualToString:kKayokoSearchTokenTypeTag]) {
        return [KayokoTagColorFormatter dotImageWithHexColor:[token displaySignature]
                                                    diameter:14.0
                                              canvasDiameter:20
                                                 borderWidth:1.25];
    }
    if ([[token imageName] length] > 0) {
        return [UIImage systemImageNamed:[token imageName]];
    }
    return nil;
}

#pragma mark - Search Token Sync

- (NSArray<KayokoSearchToken *> *)searchTokensForCriteria:(KayokoSearchCriteria *)criteria
                                      tokenListController:(KayokoSearchTokenListViewController *)tokenListController {
    NSMutableArray<KayokoSearchToken *> *searchTokens = [[NSMutableArray alloc] init];
    NSArray<KayokoSearchToken *> *tokens = @[
        [self selectedCategoryTokenForCriteria:criteria tokenListController:tokenListController] ?: (id)[NSNull null],
        [self selectedTagTokenForCriteria:criteria] ?: (id)[NSNull null],
        [self selectedAppTokenForCriteria:criteria] ?: (id)[NSNull null]
    ];
    for (id object in tokens) {
        if ([object isKindOfClass:[KayokoSearchToken class]]) {
            [searchTokens addObject:object];
        }
    }
    return searchTokens;
}

- (NSArray<UISearchToken *> *)searchFieldTokensForSearchTokens:(NSArray<KayokoSearchToken *> *)tokens {
    NSMutableArray<UISearchToken *> *searchTokens = [[NSMutableArray alloc] init];
    for (KayokoSearchToken *token in tokens) {
        UIImage *icon = [self iconForSearchToken:token];
        UISearchToken *searchToken = [UISearchToken tokenWithIcon:icon text:[token title]];
        [searchToken setRepresentedObject:token];
        [searchTokens addObject:searchToken];
    }
    return searchTokens;
}

- (BOOL)searchTextField:(UISearchTextField *)textField hasSearchTokens:(NSArray<KayokoSearchToken *> *)tokens {
    NSArray<UISearchToken *> *currentSearchTokens = [textField tokens];
    if ([currentSearchTokens count] != [tokens count]) {
        return NO;
    }

    for (NSUInteger index = 0; index < [currentSearchTokens count]; index++) {
        id representedObject = [currentSearchTokens[index] representedObject];
        if (![representedObject isKindOfClass:[KayokoSearchToken class]] ||
            ![(KayokoSearchToken *)representedObject isDisplayEqualToToken:tokens[index]]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)syncSearchTokensForSearchBar:(UISearchBar *)searchBar criteria:(KayokoSearchCriteria *)criteria {
    UITextField *textField = [searchBar searchTextField];
    if (![textField respondsToSelector:@selector(setTokens:)]) {
        return NO;
    }
    KayokoSearchTokenListViewController *tokenListController = [self tokenListViewControllerForSearchBar:searchBar];
    NSArray<KayokoSearchToken *> *tokens = [self searchTokensForCriteria:criteria
                                                     tokenListController:tokenListController];
    UISearchTextField *searchTextField = (UISearchTextField *)textField;
    if ([self searchTextField:searchTextField hasSearchTokens:tokens]) {
        return NO;
    }

    [searchTextField setTokens:[self searchFieldTokensForSearchTokens:tokens]];
    return YES;
}

- (KayokoSearchCriteria *)criteriaFromSearchBar:(UISearchBar *)searchBar
                             listViewController:(KayokoHistoryListViewController *)listViewController {
    KayokoSearchCriteria *criteria =
        [[listViewController searchCriteria] criteriaByReplacingSearchText:[searchBar text]];
    NSArray<UISearchToken *> *tokens = [(UISearchTextField *)[searchBar searchTextField] tokens];
    BOOL hasCategoryToken = NO;
    BOOL hasTagToken = NO;
    BOOL hasAppToken = NO;
    NSString *categoryValue = nil;
    NSString *tagUUID = nil;
    NSString *appBundleIdentifier = nil;
    for (UISearchToken *searchToken in tokens) {
        KayokoSearchToken *token = [searchToken representedObject];
        if (![token isKindOfClass:[KayokoSearchToken class]]) {
            continue;
        }
        if ([[token type] isEqualToString:kKayokoSearchTokenTypeCategory] && !hasCategoryToken) {
            categoryValue = [token value];
            hasCategoryToken = YES;
        } else if ([[token type] isEqualToString:kKayokoSearchTokenTypeTag] && !hasTagToken) {
            tagUUID = [token value];
            hasTagToken = YES;
        } else if ([[token type] isEqualToString:kKayokoSearchTokenTypeApp] && !hasAppToken) {
            appBundleIdentifier = [token value];
            hasAppToken = YES;
        }
    }
    return [KayokoSearchCriteria criteriaWithSearchText:[criteria searchText]
                                          categoryValue:categoryValue
                                    appBundleIdentifier:appBundleIdentifier
                                                tagUUID:tagUUID];
}

#pragma mark - Layout

- (void)layout {
    [[self presentationController] layout];
}

- (void)attachToListViewController:(KayokoHistoryListViewController *)listViewController
                    hidesSearchBar:(BOOL)hidesSearchBar {
    [[self presentationController] attachToTableView:[listViewController tableView] hidesSearchBar:hidesSearchBar];
}

- (BOOL)shouldShowTokenListForCriteria:(KayokoSearchCriteria *)criteria {
    if (![self isSearchActive]) {
        return NO;
    }
    if ([criteria hasSearchText]) {
        return NO;
    }
    return !([criteria hasCategoryToken] && [criteria hasTagToken] && [criteria hasAppToken]);
}

- (void)updateSearchTokenHeaderHeights {
    [self updateSearchTokenHeaderHeightForListViewController:[self historyListViewController]];
    [self updateSearchTokenHeaderHeightForListViewController:[self favoritesListViewController]];
    [[self presentationController] updateSearchTokenViews];
}

- (void)updateSearchTokenHeaderHeightForListViewController:(KayokoHistoryListViewController *)listViewController {
    KayokoSearchTokenListViewController *tokenListController =
        [self tokenListViewControllerForListViewController:listViewController];
    UIView *tokenView = [tokenListController view];
    BOOL showsTokenList = [self shouldShowTokenListForCriteria:[listViewController searchCriteria]];
    CGFloat width = CGRectGetWidth([[listViewController tableView] bounds]);
    CGFloat height = showsTokenList ? [tokenListController preferredContentHeightForWidth:width] : 0;
    [tokenView setHidden:height <= 0];
    [tokenView setFrame:CGRectMake(0, 0, width, height)];
}

- (void)updateTokenListForListViewController:(KayokoHistoryListViewController *)listViewController {
    KayokoSearchTokenListViewController *tokenListController =
        [self tokenListViewControllerForListViewController:listViewController];
    [tokenListController updateWithSearchCriteria:[listViewController searchCriteria]
                                        tagTokens:[self tagTokens]
                                        appTokens:[self appTokens]];
}

- (void)updateAllTokenLists {
    [self updateTokenListForListViewController:[self historyListViewController]];
    [self updateTokenListForListViewController:[self favoritesListViewController]];
    [self updateSearchTokenHeaderHeights];
}

- (void)resetSearchSessionState {
    [[self historyTokenListViewController] resetSearchSessionState];
    [[self favoritesTokenListViewController] resetSearchSessionState];
}

- (void)syncSearchBarsAfterTokenSourceChange {
    if (![self isSearchActive]) {
        return;
    }

    [self syncSearchBarForListViewController:[self historyListViewController]];
    [self syncSearchBarForListViewController:[self favoritesListViewController]];

    KayokoHistoryListViewController *activeListViewController = [self activeListViewController];
    UISearchBar *activeSearchBar = [self searchBarForTableView:[activeListViewController tableView]];
    KayokoSearchCriteria *criteria = [self criteriaFromSearchBar:activeSearchBar
                                              listViewController:activeListViewController];
    if (![criteria isEqualToCriteria:[activeListViewController searchCriteria]]) {
        [self applySearchCriteria:criteria toListViewController:activeListViewController];
        return;
    }

    [self updateTokenListForListViewController:activeListViewController];
    [self updateSearchTokenHeaderHeights];
}

#pragma mark - Token Loading

- (BOOL)reloadTagTokens {
    NSArray<KayokoTag *> *tags = [[KayokoTagCatalog sharedCatalog] reloadTags];
    NSMutableArray<KayokoSearchToken *> *tagTokens = [[NSMutableArray alloc] initWithCapacity:[tags count]];
    for (KayokoTag *tag in tags) {
        if ([[tag uuid] length] == 0) {
            continue;
        }
        [tagTokens addObject:[KayokoSearchToken tokenWithType:kKayokoSearchTokenTypeTag
                                                        value:[tag uuid]
                                                        title:[tag title]
                                                    imageName:nil
                                             displaySignature:([KayokoTag normalizedHexColorFromString:[tag hexColor]]
                                                                   ?: @"#00000000")]];
    }
    if ([self tokenArray:[self tagTokens] isDisplayEqualToTokenArray:tagTokens]) {
        return NO;
    }
    [self setTagTokens:tagTokens];
    return YES;
}

- (NSArray<KayokoSearchToken *> *)appTokensFromBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers {
    NSMutableArray<NSString *> *installedBundleIdentifiers = [[NSMutableArray alloc] init];
    for (NSString *bundleIdentifier in bundleIdentifiers) {
        if ([[self metadataProvider] hasApplicationForBundleIdentifier:bundleIdentifier]) {
            [installedBundleIdentifiers addObject:bundleIdentifier];
        }
    }

    NSArray<NSString *> *sortedBundleIdentifiers =
        [installedBundleIdentifiers sortedArrayUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
          NSString *leftName = [[self metadataProvider] displayNameForBundleIdentifier:left];
          NSString *rightName = [[self metadataProvider] displayNameForBundleIdentifier:right];
          NSComparisonResult result = [leftName localizedStandardCompare:rightName];
          return result == NSOrderedSame ? [left localizedStandardCompare:right] : result;
        }];
    NSMutableArray<KayokoSearchToken *> *appTokens =
        [[NSMutableArray alloc] initWithCapacity:[sortedBundleIdentifiers count]];
    for (NSString *bundleIdentifier in sortedBundleIdentifiers) {
        NSString *title = [[self metadataProvider] displayNameForBundleIdentifier:bundleIdentifier];
        [appTokens
            addObject:[KayokoSearchToken tokenWithType:kKayokoSearchTokenTypeApp
                                                 value:bundleIdentifier
                                                 title:title
                                             imageName:nil
                                      displaySignature:[self appDisplaySignatureForBundleIdentifier:bundleIdentifier
                                                                                              title:title]]];
    }
    return appTokens;
}

- (void)finishLoadingAppTokensAndReloadIfNeeded {
    BOOL shouldReload = [self needsAppTokenReloadAfterCurrentLoad] || [self appTokensDirty];
    [self setNeedsAppTokenReloadAfterCurrentLoad:NO];
    if (shouldReload) {
        [self setAppTokensDirty:YES];
        [self loadAppTokensIfNeeded];
    }
}

- (void)invalidateAppTokensAndReloadIfActive {
    [self setAppTokensDirty:YES];
    if ([self loadingAppTokens]) {
        [self setNeedsAppTokenReloadAfterCurrentLoad:YES];
        return;
    }
    if ([self isSearchActive]) {
        [self loadAppTokensIfNeeded];
    }
}

- (void)loadAppTokensIfNeeded {
    if (![self appTokensDirty]) {
        return;
    }
    if ([self loadingAppTokens]) {
        [self setNeedsAppTokenReloadAfterCurrentLoad:YES];
        return;
    }
    [self setAppTokensDirty:NO];
    [self setLoadingAppTokens:YES];
    NSUInteger requestIdentifier = [self appTokenLoadRequestIdentifier] + 1;
    [self setAppTokenLoadRequestIdentifier:requestIdentifier];
    __weak typeof(self) weakSelf = self;
    [[KayokoPasteboardManager sharedInstance]
        availableSearchAppBundleIdentifiersWithCompletion:^(NSArray<NSString *> *bundleIdentifiers, NSError *error) {
          __strong typeof(weakSelf) strongSelf = weakSelf;
          if (!strongSelf) {
              return;
          }
          [strongSelf setLoadingAppTokens:NO];
          if ([strongSelf appTokenLoadRequestIdentifier] != requestIdentifier) {
              return;
          }
          if (error) {
              [strongSelf setAppTokensDirty:YES];
              [[strongSelf delegate] searchController:strongSelf didFailLoadingSearchWithError:error];
              return;
          }

          NSArray<KayokoSearchToken *> *appTokens = [strongSelf appTokensFromBundleIdentifiers:bundleIdentifiers];
          if (![strongSelf tokenArray:[strongSelf appTokens] isDisplayEqualToTokenArray:appTokens]) {
              [strongSelf setAppTokens:appTokens];
              [strongSelf updateAllTokenLists];
              [strongSelf syncSearchBarsAfterTokenSourceChange];
          }
          [strongSelf finishLoadingAppTokensAndReloadIfNeeded];
        }];
}

#pragma mark - Search Application

- (void)invalidatePendingSearchRequests {
    [self setSearchRequestIdentifier:[self searchRequestIdentifier] + 1];
}

- (void)applySearchCriteria:(KayokoSearchCriteria *)criteria
       toListViewController:(KayokoHistoryListViewController *)listViewController {
    if (![self isSearchActive]) {
        [self invalidatePendingSearchRequests];
        [listViewController clearSearch];
        [self updateTokenListForListViewController:listViewController];
        [self updateSearchTokenHeaderHeights];
        return;
    }

    if (![criteria hasActiveFilters]) {
        [self invalidatePendingSearchRequests];
        [listViewController showSearchTokensWithFullListForCriteria:criteria];
        [self updateTokenListForListViewController:listViewController];
        [self updateSearchTokenHeaderHeights];
        return;
    }

    NSUInteger requestIdentifier = [self searchRequestIdentifier] + 1;
    [self setSearchRequestIdentifier:requestIdentifier];
    [listViewController beginApplyingSearchCriteria:criteria];
    [self updateTokenListForListViewController:listViewController];
    [self updateSearchTokenHeaderHeights];
    __weak typeof(self) weakSelf = self;
    [[KayokoPasteboardManager sharedInstance]
        getItemsFromHistoryWithKey:[listViewController historyKey]
                    searchCriteria:criteria
                        completion:^(NSMutableArray<NSDictionary<NSString *, id> *> *items, NSError *error) {
                          __strong typeof(weakSelf) strongSelf = weakSelf;
                          if (!strongSelf || [strongSelf searchRequestIdentifier] != requestIdentifier) {
                              return;
                          }
                          if (error) {
                              [[strongSelf delegate] searchController:strongSelf didFailLoadingSearchWithError:error];
                              return;
                          }
                          [listViewController applySearchCriteria:criteria filteredItems:items];
                          [strongSelf updateTokenListForListViewController:listViewController];
                          [strongSelf updateSearchTokenHeaderHeights];
                        }];
}

- (void)applySearchFromSearchBar:(UISearchBar *)searchBar {
    KayokoHistoryListViewController *listViewController = [self listViewControllerForSearchBar:searchBar];
    KayokoSearchCriteria *criteria = [self criteriaFromSearchBar:searchBar listViewController:listViewController];
    [self syncSearchTokensForSearchBar:searchBar criteria:criteria];
    [self applySearchCriteria:criteria toListViewController:listViewController];
}

- (void)applySearchToActiveTableView {
    [self applySearchFromSearchBar:[self activeSearchBar]];
}

- (void)syncSearchBarForListViewController:(KayokoHistoryListViewController *)listViewController {
    UISearchBar *searchBar = [self searchBarForTableView:[listViewController tableView]];
    BOOL wasResettingSearch = [self isResettingSearch];
    [self setIsResettingSearch:YES];
    [searchBar setText:[listViewController searchText]];
    [self syncSearchTokensForSearchBar:searchBar criteria:[listViewController searchCriteria]];
    [self setIsResettingSearch:wasResettingSearch];
}

- (void)restoreContentOffset:(CGPoint)contentOffset
       forListViewController:(KayokoHistoryListViewController *)listViewController {
    [[listViewController tableView] setContentOffset:contentOffset animated:NO];
}

- (void)refreshForListViewController:(KayokoHistoryListViewController *)listViewController {
    [self attachToListViewController:listViewController hidesSearchBar:![self isSearchActive]];
    if ([self isSearchActive]) {
        [self reloadTagTokens];
    }
    [self syncSearchBarForListViewController:listViewController];
    [self updateTokenListForListViewController:listViewController];
    [self applySearchFromSearchBar:[self searchBarForTableView:[listViewController tableView]]];
    if ([self isSearchActive] && listViewController == [self activeListViewController]) {
        [[self historySearchBar] setShowsCancelButton:NO animated:NO];
        [[self favoritesSearchBar] setShowsCancelButton:NO animated:NO];
        [[self activeSearchBar] setShowsCancelButton:YES animated:NO];
        [[self activeSearchBar] becomeFirstResponder];
    }
}

- (void)refreshAfterTransientContentForListViewController:(KayokoHistoryListViewController *)listViewController
                                   restoresFirstResponder:(BOOL)restoresFirstResponder
                                      targetContentOffset:(CGPoint)targetContentOffset {
    CGPoint currentContentOffset = [[listViewController tableView] contentOffset];
    [[self presentationController] layout];
    if ([self isSearchActive]) {
        [self reloadTagTokens];
    }
    [self syncSearchBarForListViewController:listViewController];
    [self updateTokenListForListViewController:listViewController];
    [self updateSearchTokenHeaderHeights];
    [self restoreContentOffset:currentContentOffset forListViewController:listViewController];
    if ([self isSearchActive] && listViewController == [self activeListViewController]) {
        [[self historySearchBar] setShowsCancelButton:NO animated:NO];
        [[self favoritesSearchBar] setShowsCancelButton:NO animated:NO];
        [[self activeSearchBar] setShowsCancelButton:YES animated:NO];
        if (restoresFirstResponder) {
            [[listViewController tableView] beginTransientContentOffsetPreservationAtContentOffset:targetContentOffset];
            [[self activeSearchBar] becomeFirstResponder];
        }
    }
}

#pragma mark - Search Session

- (void)setSearchBarsShowCancelButton:(BOOL)showsCancelButton animated:(BOOL)animated {
    [[self historySearchBar] setShowsCancelButton:NO animated:animated];
    [[self favoritesSearchBar] setShowsCancelButton:NO animated:animated];
    if (showsCancelButton) {
        [[self activeSearchBar] setShowsCancelButton:YES animated:animated];
    }
}

- (void)resignSearchFirstResponder {
    [[self activeSearchBar] resignFirstResponder];
}

- (BOOL)isActiveSearchFirstResponder {
    UISearchBar *searchBar = [self activeSearchBar];
    UITextField *searchTextField = [searchBar searchTextField];
    return [searchBar isFirstResponder] || [searchTextField isFirstResponder];
}

- (void)beginSearchIfNeeded {
    if ([self isSearchActive]) {
        return;
    }

    [self setSearchActive:YES];
    [self reloadTagTokens];
    [self loadAppTokensIfNeeded];
    [self setSearchBarsShowCancelButton:YES animated:YES];
    [self applySearchFromSearchBar:[self activeSearchBar]];
    [[self delegate] searchControllerWillAnimateSearchState:self];
    [[self presentationController]
        beginSearchWithActiveTableView:[[self activeListViewController] tableView]
                            completion:^{
                              [[self delegate] searchControllerDidFinishAnimatingSearchState:self];
                            }];
}

- (void)endSearchRestoringFrame:(BOOL)restoresFrame
                   clearsSearch:(BOOL)clearsSearch
                     animations:(void (^)(void))animations
                     completion:(void (^)(void))completion {
    [self endSearchRestoringFrame:restoresFrame
                     clearsSearch:clearsSearch
                       animations:animations
                     panVelocityY:0
                       completion:completion];
}

- (void)endSearchRestoringFrame:(BOOL)restoresFrame
                   clearsSearch:(BOOL)clearsSearch
                     animations:(void (^)(void))animations
                   panVelocityY:(CGFloat)panVelocityY
                     completion:(void (^)(void))completion {
    [self endSearchRestoringFrame:restoresFrame
                         clearsSearch:clearsSearch
                           animations:animations
                         panVelocityY:panVelocityY
        coordinatesVisibleSearchReset:NO
                           completion:completion];
}

- (void)finishDeferredVisibleSearchResetClearingSearch:(BOOL)clearsSearch {
    [self setSearchActive:NO];
    [self setSearchBarsShowCancelButton:NO animated:NO];
    if (clearsSearch) {
        [self clearSearchForListViewController:[self historyListViewController]];
        [self clearSearchForListViewController:[self favoritesListViewController]];
    }
    [self applySearchToActiveTableView];
    [[self presentationController] hideSearchBarInTableView:[self activeTableView] animated:NO];
    [self setIsResettingSearch:NO];
}

- (void)endSearchRestoringFrame:(BOOL)restoresFrame
                     clearsSearch:(BOOL)clearsSearch
                       animations:(void (^)(void))animations
                     panVelocityY:(CGFloat)panVelocityY
    coordinatesVisibleSearchReset:(BOOL)coordinatesVisibleSearchReset
                       completion:(void (^)(void))completion {
    if (![self isSearchActive] && !clearsSearch) {
        if (animations) {
            animations();
        }
        [self resetSearchSessionState];
        if (completion) {
            completion();
        }
        return;
    }

    BOOL defersVisibleSearchReset = coordinatesVisibleSearchReset && clearsSearch &&
                                    [self presentationMode] == KayokoPanelPresentationModeCompactLandscapeFullscreen;
    [self setIsResettingSearch:YES];
    UISearchBar *activeSearchBar = [self activeSearchBar];
    if (!defersVisibleSearchReset) {
        [self setSearchActive:NO];
    }
    [activeSearchBar resignFirstResponder];
    if (!defersVisibleSearchReset) {
        [self setSearchBarsShowCancelButton:NO animated:YES];
    }
    if (clearsSearch && !defersVisibleSearchReset) {
        [self clearSearchForListViewController:[self historyListViewController]];
        [self clearSearchForListViewController:[self favoritesListViewController]];
    }
    [[self presentationController] resetKeyboardInsets];
    if (!defersVisibleSearchReset) {
        [self applySearchToActiveTableView];
        [self setIsResettingSearch:NO];
    }

    [[self delegate] searchControllerWillAnimateSearchState:self];
    [[self presentationController]
        endSearchRestoringFrame:restoresFrame
                activeTableView:[[self activeListViewController] tableView]
                     animations:animations
                   panVelocityY:panVelocityY
                     completion:^{
                       if (defersVisibleSearchReset) {
                           [self finishDeferredVisibleSearchResetClearingSearch:clearsSearch];
                       }
                       [self resetSearchSessionState];
                       [[self delegate] searchControllerDidFinishAnimatingSearchState:self];
                       if (completion) {
                           completion();
                       }
                     }];
}

- (void)endSearchRestoringFrame:(BOOL)restoresFrame
                   clearsSearch:(BOOL)clearsSearch
                     completion:(void (^)(void))completion {
    [self endSearchRestoringFrame:restoresFrame clearsSearch:clearsSearch animations:nil completion:completion];
}

- (void)endSearchRestoringFrame:(BOOL)restoresFrame clearsSearch:(BOOL)clearsSearch {
    [self endSearchRestoringFrame:restoresFrame clearsSearch:clearsSearch completion:nil];
}

- (void)cancelSearchWithCompletion:(void (^)(void))completion {
    [self endSearchRestoringFrame:YES clearsSearch:YES completion:completion];
}

- (void)cancelSearchWithAnimations:(void (^)(void))animations completion:(void (^)(void))completion {
    [self endSearchRestoringFrame:YES clearsSearch:YES animations:animations completion:completion];
}

- (void)collapseSearchFromFullscreenPanWithVelocity:(CGFloat)velocityY {
    [self endSearchRestoringFrame:YES clearsSearch:YES animations:nil panVelocityY:velocityY completion:nil];
}

- (void)handleFullscreenPanGestureRecognizer:(UIPanGestureRecognizer *)recognizer
                           beganInHeaderView:(BOOL)beganInHeaderView {
    [[self presentationController] handleFullscreenPanGestureRecognizer:recognizer
                                                        activeTableView:[self activeTableView]
                                                      beganInHeaderView:beganInHeaderView];
}

- (void)resetSearchState {
    BOOL hasSearch =
        [[self historyListViewController] hasActiveSearch] || [[self favoritesListViewController] hasActiveSearch];
    if (![self isSearchActive] && !hasSearch) {
        [self resetSearchSessionState];
        return;
    }

    [self setIsResettingSearch:YES];
    [self setSearchActive:NO];
    [[self historySearchBar] resignFirstResponder];
    [[self favoritesSearchBar] resignFirstResponder];
    [self setSearchBarsShowCancelButton:NO animated:NO];
    [self clearSearchForListViewController:[self historyListViewController]];
    [self clearSearchForListViewController:[self favoritesListViewController]];
    [self applySearchToActiveTableView];
    [[self presentationController] resetAfterSearchStateClearedWithActiveTableView:[self activeTableView]];
    [self resetSearchSessionState];
    [self setIsResettingSearch:NO];
}

#pragma mark - Clearing

- (void)clearSearchForListViewController:(KayokoHistoryListViewController *)listViewController {
    UISearchBar *searchBar = [self searchBarForTableView:[listViewController tableView]];
    BOOL wasResettingSearch = [self isResettingSearch];
    [self setIsResettingSearch:YES];
    [searchBar setText:@""];
    [(UISearchTextField *)[searchBar searchTextField] setTokens:@[]];
    [self invalidatePendingSearchRequests];
    [listViewController clearSearch];
    [self updateTokenListForListViewController:listViewController];
    [self updateSearchTokenHeaderHeights];
    [self setIsResettingSearch:wasResettingSearch];
}

- (void)maintainSearchBarVisibilityForListViewController:(KayokoHistoryListViewController *)listViewController {
    [[self presentationController] maintainSearchBarVisibilityForTableView:[listViewController tableView]];
}

#pragma mark - KayokoSearchPresentationControllerDelegate

- (void)searchPresentationController:(KayokoSearchPresentationController *)controller
        didUpdateKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    [[self delegate] searchController:self didUpdateKeyboardBottomInset:keyboardBottomInset];
}

- (void)searchPresentationController:(KayokoSearchPresentationController *)controller
    didRequestCollapseFromFullscreenPanWithVelocity:(CGFloat)velocityY {
    [self collapseSearchFromFullscreenPanWithVelocity:velocityY];
}

#pragma mark - KayokoSearchTokenListViewControllerDelegate

- (void)searchTokenListViewController:(KayokoSearchTokenListViewController *)controller
                       didSelectToken:(KayokoSearchToken *)token {
    KayokoHistoryListViewController *listViewController = controller == [self favoritesTokenListViewController]
                                                              ? [self favoritesListViewController]
                                                              : [self historyListViewController];
    if (listViewController != [self activeListViewController]) {
        return;
    }

    UISearchBar *searchBar = [self searchBarForTableView:[listViewController tableView]];
    KayokoSearchCriteria *criteria = [[[listViewController searchCriteria]
        criteriaByReplacingSearchText:[searchBar text]] criteriaBySelectingToken:token];
    BOOL wasResettingSearch = [self isResettingSearch];
    [self setIsResettingSearch:YES];
    [self syncSearchTokensForSearchBar:searchBar criteria:criteria];
    [self setIsResettingSearch:wasResettingSearch];
    [self applySearchCriteria:criteria toListViewController:listViewController];
}

#pragma mark - Search Text Events

- (void)handleSearchTextFieldEditingChanged:(UITextField *)textField {
    if ([self isResettingSearch]) {
        return;
    }
    UISearchBar *searchBar =
        textField == [[self favoritesSearchBar] searchTextField] ? [self favoritesSearchBar] : [self historySearchBar];
    if ([self listViewControllerForSearchBar:searchBar] != [self activeListViewController]) {
        return;
    }
    [self applySearchFromSearchBar:searchBar];
}

- (void)handleSearchTextFieldTextDidChangeNotification:(NSNotification *)notification {
    if ([self isResettingSearch]) {
        return;
    }
    UITextField *textField = [notification object];
    UISearchBar *searchBar =
        textField == [[self favoritesSearchBar] searchTextField] ? [self favoritesSearchBar] : [self historySearchBar];
    if ([self listViewControllerForSearchBar:searchBar] != [self activeListViewController]) {
        return;
    }
    [self applySearchFromSearchBar:searchBar];
}

#pragma mark - UISearchBarDelegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    if ([self listViewControllerForSearchBar:searchBar] == [self activeListViewController]) {
        [[self delegate] searchControllerWillBeginSearchInputTransition:self];
    }
    return YES;
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    if ([self listViewControllerForSearchBar:searchBar] != [self activeListViewController]) {
        return;
    }
    [self beginSearchIfNeeded];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([self isResettingSearch]) {
        return;
    }
    if ([self listViewControllerForSearchBar:searchBar] != [self activeListViewController]) {
        return;
    }
    [self applySearchFromSearchBar:searchBar];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    if ([self listViewControllerForSearchBar:searchBar] != [self activeListViewController]) {
        return;
    }
    [self endSearchRestoringFrame:YES
                         clearsSearch:YES
                           animations:nil
                         panVelocityY:0
        coordinatesVisibleSearchReset:YES
                           completion:nil];
}

@end
