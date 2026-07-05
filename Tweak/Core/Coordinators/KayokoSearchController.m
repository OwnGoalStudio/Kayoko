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

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchController () <UISearchBarDelegate, KayokoSearchPresentationControllerDelegate,
                                      KayokoSearchTokenListViewControllerDelegate>
@property(nonatomic, strong) KayokoSearchPresentationController *presentationController;
@property(nonatomic, weak) KayokoHistoryListViewController *historyListViewController;
@property(nonatomic, weak) KayokoHistoryListViewController *favoritesListViewController;
@property(nonatomic, strong) UISearchBar *historySearchBar;
@property(nonatomic, strong) UISearchBar *favoritesSearchBar;
@property(nonatomic, strong) KayokoSearchTokenListViewController *historyTokenListViewController;
@property(nonatomic, strong) KayokoSearchTokenListViewController *favoritesTokenListViewController;
@property(nonatomic, copy) NSArray<KayokoSearchToken *> *appTokens;
@property(nonatomic, strong) KayokoApplicationMetadataProvider *metadataProvider;
@property(nonatomic, assign, getter=isSearchActive) BOOL searchActive;
@property(nonatomic, assign) BOOL isResettingSearch;
@property(nonatomic, assign) NSUInteger searchRequestIdentifier;
@property(nonatomic, assign) BOOL loadingAppTokens;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSearchController

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
        _appTokens = @[];
        _metadataProvider = [[KayokoApplicationMetadataProvider alloc] init];

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
    NSString *title = [[self metadataProvider] displayNameForBundleIdentifier:bundleIdentifier];
    return [KayokoSearchToken tokenWithType:kKayokoSearchTokenTypeApp value:bundleIdentifier title:title imageName:nil];
}

- (NSArray<UISearchToken *> *)searchFieldTokensForCriteria:(KayokoSearchCriteria *)criteria
                                       tokenListController:(KayokoSearchTokenListViewController *)tokenListController {
    NSMutableArray<UISearchToken *> *searchTokens = [[NSMutableArray alloc] init];
    NSArray<KayokoSearchToken *> *tokens = @[
        [self selectedCategoryTokenForCriteria:criteria tokenListController:tokenListController] ?: (id)[NSNull null],
        [self selectedAppTokenForCriteria:criteria] ?: (id)[NSNull null]
    ];
    for (id object in tokens) {
        if (![object isKindOfClass:[KayokoSearchToken class]]) {
            continue;
        }
        KayokoSearchToken *token = object;
        UIImage *icon = nil;
        if ([[token type] isEqualToString:kKayokoSearchTokenTypeApp]) {
            icon = [[self metadataProvider] smallIconForBundleIdentifier:[token value]];
        } else if ([[token imageName] length] > 0) {
            icon = [UIImage systemImageNamed:[token imageName]];
        }
        UISearchToken *searchToken = [UISearchToken tokenWithIcon:icon text:[token title]];
        [searchToken setRepresentedObject:token];
        [searchTokens addObject:searchToken];
    }
    return searchTokens;
}

- (void)syncSearchTokensForSearchBar:(UISearchBar *)searchBar criteria:(KayokoSearchCriteria *)criteria {
    UITextField *textField = [searchBar searchTextField];
    if (![textField respondsToSelector:@selector(setTokens:)]) {
        return;
    }
    KayokoSearchTokenListViewController *tokenListController = [self tokenListViewControllerForSearchBar:searchBar];
    [(UISearchTextField *)textField setTokens:[self searchFieldTokensForCriteria:criteria
                                                             tokenListController:tokenListController]];
}

- (KayokoSearchCriteria *)criteriaFromSearchBar:(UISearchBar *)searchBar
                             listViewController:(KayokoHistoryListViewController *)listViewController {
    KayokoSearchCriteria *criteria =
        [[listViewController searchCriteria] criteriaByReplacingSearchText:[searchBar text]];
    NSArray<UISearchToken *> *tokens = [(UISearchTextField *)[searchBar searchTextField] tokens];
    BOOL hasCategoryToken = NO;
    BOOL hasAppToken = NO;
    NSString *categoryValue = nil;
    NSString *appBundleIdentifier = nil;
    for (UISearchToken *searchToken in tokens) {
        KayokoSearchToken *token = [searchToken representedObject];
        if (![token isKindOfClass:[KayokoSearchToken class]]) {
            continue;
        }
        if ([[token type] isEqualToString:kKayokoSearchTokenTypeCategory] && !hasCategoryToken) {
            categoryValue = [token value];
            hasCategoryToken = YES;
        } else if ([[token type] isEqualToString:kKayokoSearchTokenTypeApp] && !hasAppToken) {
            appBundleIdentifier = [token value];
            hasAppToken = YES;
        }
    }
    return [KayokoSearchCriteria criteriaWithSearchText:[criteria searchText]
                                          categoryValue:categoryValue
                                    appBundleIdentifier:appBundleIdentifier];
}

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
    return !([criteria hasCategoryToken] && [criteria hasAppToken]);
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
    [tokenListController updateWithSearchCriteria:[listViewController searchCriteria] appTokens:[self appTokens]];
}

- (void)updateAllTokenLists {
    [self updateTokenListForListViewController:[self historyListViewController]];
    [self updateTokenListForListViewController:[self favoritesListViewController]];
    [self updateSearchTokenHeaderHeights];
}

- (void)loadAppTokensIfNeeded {
    if ([self loadingAppTokens]) {
        return;
    }
    [self setLoadingAppTokens:YES];
    __weak typeof(self) weakSelf = self;
    [[KayokoPasteboardManager sharedInstance]
        availableSearchAppBundleIdentifiersWithCompletion:^(NSArray<NSString *> *bundleIdentifiers, NSError *error) {
          __strong typeof(weakSelf) strongSelf = weakSelf;
          if (!strongSelf) {
              return;
          }
          [strongSelf setLoadingAppTokens:NO];
          if (error) {
              [[strongSelf delegate] searchController:strongSelf didFailLoadingSearchWithError:error];
              return;
          }

          NSArray<NSString *> *sortedBundleIdentifiers =
              [bundleIdentifiers sortedArrayUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
                NSString *leftName = [[strongSelf metadataProvider] displayNameForBundleIdentifier:left];
                NSString *rightName = [[strongSelf metadataProvider] displayNameForBundleIdentifier:right];
                NSComparisonResult result = [leftName localizedStandardCompare:rightName];
                return result == NSOrderedSame ? [left localizedStandardCompare:right] : result;
              }];
          NSMutableArray<KayokoSearchToken *> *appTokens =
              [[NSMutableArray alloc] initWithCapacity:[sortedBundleIdentifiers count]];
          for (NSString *bundleIdentifier in sortedBundleIdentifiers) {
              [appTokens addObject:[KayokoSearchToken tokenWithType:kKayokoSearchTokenTypeApp
                                                              value:bundleIdentifier
                                                              title:[[strongSelf metadataProvider]
                                                                        displayNameForBundleIdentifier:bundleIdentifier]
                                                          imageName:nil]];
          }
          [strongSelf setAppTokens:appTokens];
          [strongSelf updateAllTokenLists];
        }];
}

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
        [listViewController showSearchTokensOnlyWithCriteria:criteria];
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

- (void)refreshForListViewController:(KayokoHistoryListViewController *)listViewController {
    [self attachToListViewController:listViewController hidesSearchBar:![self isSearchActive]];
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

- (void)resignSearchFirstResponder {
    [[self activeSearchBar] resignFirstResponder];
}

- (void)beginSearchIfNeeded {
    if ([self isSearchActive]) {
        return;
    }

    [self setSearchActive:YES];
    [self loadAppTokensIfNeeded];
    [[self historySearchBar] setShowsCancelButton:NO animated:NO];
    [[self favoritesSearchBar] setShowsCancelButton:NO animated:NO];
    [[self activeSearchBar] setShowsCancelButton:YES animated:YES];
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
    if (![self isSearchActive] && !clearsSearch) {
        if (animations) {
            animations();
        }
        if (completion) {
            completion();
        }
        return;
    }

    [self setIsResettingSearch:YES];
    [self setSearchActive:NO];
    UISearchBar *activeSearchBar = [self activeSearchBar];
    [activeSearchBar resignFirstResponder];
    [[self historySearchBar] setShowsCancelButton:NO animated:YES];
    [[self favoritesSearchBar] setShowsCancelButton:NO animated:YES];
    if (clearsSearch) {
        [self clearSearchForListViewController:[self historyListViewController]];
        [self clearSearchForListViewController:[self favoritesListViewController]];
    }
    [[self presentationController] resetKeyboardInsets];
    [self applySearchToActiveTableView];
    [self setIsResettingSearch:NO];

    [[self delegate] searchControllerWillAnimateSearchState:self];
    [[self presentationController] endSearchRestoringFrame:restoresFrame
                                           activeTableView:[[self activeListViewController] tableView]
                                                animations:animations
                                              panVelocityY:panVelocityY
                                                completion:^{
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

- (void)handleFullscreenPanGestureRecognizer:(UIPanGestureRecognizer *)recognizer {
    [[self presentationController] handleFullscreenPanGestureRecognizer:recognizer
                                                        activeTableView:[self activeTableView]];
}

- (void)resetBeforeHide {
    BOOL hasSearch =
        [[self historyListViewController] hasActiveSearch] || [[self favoritesListViewController] hasActiveSearch];
    if (![self isSearchActive] && !hasSearch) {
        return;
    }

    [self clearSearchForListViewController:[self historyListViewController]];
    [self clearSearchForListViewController:[self favoritesListViewController]];
    [self endSearchRestoringFrame:NO clearsSearch:NO];
}

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

- (void)searchPresentationController:(KayokoSearchPresentationController *)controller
        didUpdateKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    [[self delegate] searchController:self didUpdateKeyboardBottomInset:keyboardBottomInset];
}

- (void)searchPresentationController:(KayokoSearchPresentationController *)controller
    didRequestCollapseFromFullscreenPanWithVelocity:(CGFloat)velocityY {
    [self collapseSearchFromFullscreenPanWithVelocity:velocityY];
}

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
    [self endSearchRestoringFrame:YES clearsSearch:YES];
}

@end
