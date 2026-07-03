//
//  KayokoSearchController.m
//  Kayoko
//

#import "KayokoSearchController.h"

#import "KayokoHistoryListView.h"
#import "KayokoHistoryListViewController.h"
#import "KayokoPasteboardManager.h"
#import "KayokoSearchBar.h"
#import "KayokoSearchPresentationController.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchController () <UISearchBarDelegate, KayokoSearchPresentationControllerDelegate>
@property(nonatomic, strong) KayokoSearchPresentationController *presentationController;
@property(nonatomic, weak) KayokoHistoryListViewController *historyListViewController;
@property(nonatomic, weak) KayokoHistoryListViewController *favoritesListViewController;
@property(nonatomic, strong) UISearchBar *historySearchBar;
@property(nonatomic, strong) UISearchBar *favoritesSearchBar;
@property(nonatomic, assign, getter=isSearchActive) BOOL searchActive;
@property(nonatomic, assign) BOOL isResettingSearch;
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

        _presentationController =
            [[KayokoSearchPresentationController alloc] initWithContainerView:containerView
                                                                   headerView:headerView
                                                             historySearchBar:_historySearchBar
                                                           favoritesSearchBar:_favoritesSearchBar
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
    if (@available(iOS 13.0, *)) {
        [[searchBar searchTextField] addTarget:self
                                        action:@selector(handleSearchTextFieldEditingChanged:)
                              forControlEvents:UIControlEventEditingChanged];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSearchTextFieldTextDidChangeNotification:)
                                                     name:UITextFieldTextDidChangeNotification
                                                   object:[searchBar searchTextField]];
    }
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

- (void)layout {
    [[self presentationController] layout];
}

- (void)attachToListViewController:(KayokoHistoryListViewController *)listViewController
                    hidesSearchBar:(BOOL)hidesSearchBar {
    [[self presentationController] attachToTableView:[listViewController tableView] hidesSearchBar:hidesSearchBar];
}

- (void)applySearchFromSearchBar:(UISearchBar *)searchBar {
    KayokoHistoryListViewController *listViewController = [self listViewControllerForSearchBar:searchBar];
    [listViewController applySearchText:[searchBar text]];
}

- (void)applySearchToActiveTableView {
    [self applySearchFromSearchBar:[self activeSearchBar]];
}

- (void)syncSearchBarForListViewController:(KayokoHistoryListViewController *)listViewController {
    UISearchBar *searchBar = [self searchBarForTableView:[listViewController tableView]];
    BOOL wasResettingSearch = [self isResettingSearch];
    [self setIsResettingSearch:YES];
    [searchBar setText:[listViewController searchText]];
    [self setIsResettingSearch:wasResettingSearch];
}

- (void)refreshForListViewController:(KayokoHistoryListViewController *)listViewController {
    [self attachToListViewController:listViewController hidesSearchBar:![self isSearchActive]];
    [self syncSearchBarForListViewController:listViewController];
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
    [[self historySearchBar] setShowsCancelButton:NO animated:NO];
    [[self favoritesSearchBar] setShowsCancelButton:NO animated:NO];
    [[self activeSearchBar] setShowsCancelButton:YES animated:YES];
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
        [self clearSearchForListViewController:[self activeListViewController]];
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
    [listViewController applySearchText:@""];
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
