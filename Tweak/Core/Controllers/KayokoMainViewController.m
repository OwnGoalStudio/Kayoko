//
//  KayokoMainViewController.m
//  Kayoko
//

#import "KayokoMainViewController.h"

#import "KayokoClearConfirmationView.h"
#import "KayokoClearConfirmationViewController.h"
#import "KayokoEmptyStateView.h"
#import "KayokoHeaderButtonStyle.h"
#import "KayokoHistoryController.h"
#import "KayokoHistoryListView.h"
#import "KayokoHistoryListViewController.h"
#import "KayokoMainView.h"
#import "KayokoPanelPresentationController.h"
#import "KayokoPreviewView.h"
#import "KayokoPreviewViewController.h"
#import "KayokoSearchController.h"
#import "KayokoWordSelectionViewController.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

static NSString *kayokoMainPreviewTextByTrimmingBoundaryNewlines(NSString *text) {
    return [(text ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

NS_ASSUME_NONNULL_BEGIN

@interface KayokoMainViewController () <KayokoClearConfirmationViewControllerDelegate, KayokoHistoryControllerDelegate,
                                        KayokoPanelPresentationControllerDelegate, KayokoSearchControllerDelegate,
                                        KayokoHistoryListViewControllerDelegate,
                                        KayokoWordSelectionViewControllerDelegate>
@property(nonatomic, strong) KayokoMainView *mainView;
@property(nonatomic, copy, nullable) NSString *clearConfirmationHistoryKey;
@property(nonatomic, strong) KayokoHistoryController *historyController;
@property(nonatomic, strong) KayokoHistoryListViewController *historyListViewController;
@property(nonatomic, strong) KayokoHistoryListViewController *favoritesListViewController;
@property(nonatomic, strong) KayokoEmptyStateView *historyEmptyStateView;
@property(nonatomic, strong) KayokoEmptyStateView *favoritesEmptyStateView;
@property(nonatomic, strong) KayokoPanelPresentationController *panelPresentationController;
@property(nonatomic, strong) KayokoClearConfirmationViewController *clearConfirmationViewController;
@property(nonatomic, strong) KayokoPreviewViewController *previewViewController;
@property(nonatomic, strong) KayokoWordSelectionViewController *wordSelectionViewController;
@property(nonatomic, strong) KayokoSearchController *searchController;
@property(nonatomic, assign) BOOL preparingToShow;
@property(nonatomic, assign) NSUInteger showRequestIdentifier;
@property(nonatomic, assign, getter=isDismissingPanel) BOOL dismissingPanel;
@property(nonatomic, weak, nullable) UIView *activeSourceContentView;

- (void)showContentForItem:(PasteboardItem *)item;
- (void)hideWordSelection;
- (void)restoreActiveSourceContentView;
- (void)refreshSearchAfterEndingTransientContentIfNeeded;
- (BOOL)isPreviewActive;
- (BOOL)isWordSelectionActive;
- (void)updateFavoritesButtonForHistoryKey:(NSString *)historyKey;
- (void)handleTitleTapControlPressed;
- (KayokoEmptyStateView *)emptyStateViewForHistoryKey:(NSString *)historyKey;
- (BOOL)cancelSearchForEmptyActiveHistoryIfNeededHidingView:(UIView *)viewToHide
                                                  direction:(KayokoContentTransitionDirection)direction
                                                 completion:(nullable void (^)(void))completion;
- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
              direction:(KayokoContentTransitionDirection)direction
             completion:(nullable void (^)(void))completion;
- (void)handlePasteboardItemDictionary:(NSDictionary<NSString *, id> *)dictionary
                   movedFromHistoryKey:(NSString *)sourceHistoryKey
                          toHistoryKey:(NSString *)destinationHistoryKey;
- (void)updateContentState;
- (void)updateContentStateMaintainingSearchBarVisibility:(BOOL)maintainsSearchBarVisibility;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoMainViewController

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _mainView = [[KayokoMainView alloc] initWithFrame:frame];
        [self setView:_mainView];
        _historyListViewController = [[KayokoHistoryListViewController alloc]
            initWithName:[[PasteboardManager localizationBundle] localizedStringForKey:@"History"
                                                                                 value:nil
                                                                                 table:@"Tweak"]
              historyKey:kKayokoHistoryKeyHistory];
        [_historyListViewController setDelegate:self];
        [self addChildViewController:_historyListViewController];
        [_mainView installContentView:[_historyListViewController tableView] hidden:NO];
        [_historyListViewController didMoveToParentViewController:self];

        _favoritesListViewController = [[KayokoHistoryListViewController alloc]
            initWithName:[[PasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
                                                                                 value:nil
                                                                                 table:@"Tweak"]
              historyKey:kKayokoHistoryKeyFavorites];
        [_favoritesListViewController setDelegate:self];
        [self addChildViewController:_favoritesListViewController];
        [_mainView installContentView:[_favoritesListViewController tableView] hidden:YES];
        [_favoritesListViewController didMoveToParentViewController:self];

        _historyController =
            [[KayokoHistoryController alloc] initWithHistoryListViewController:_historyListViewController
                                                   favoritesListViewController:_favoritesListViewController];
        [_historyController setDelegate:self];

        __weak typeof(self) weakSelf = self;
        [_mainView setLayoutHandler:^{
          [weakSelf handleViewLayout];
        }];
        [[_mainView favoritesButton] addTarget:self
                                        action:@selector(handleFavoritesButtonPressed)
                              forControlEvents:UIControlEventTouchUpInside];
        [[_mainView clearButton] addTarget:self
                                    action:@selector(handleClearButtonPressed)
                          forControlEvents:UIControlEventTouchUpInside];
        [[_mainView backButton] addTarget:self
                                   action:@selector(handlePreviewActionButtonPressed)
                         forControlEvents:UIControlEventTouchUpInside];
        [[_mainView titleTapControl] addTarget:self
                                        action:@selector(handleTitleTapControlPressed)
                              forControlEvents:UIControlEventTouchUpInside];

        _panelPresentationController = [[KayokoPanelPresentationController alloc] initWithPanelView:_mainView];
        [_panelPresentationController setDelegate:self];

        _clearConfirmationViewController = [[KayokoClearConfirmationViewController alloc] init];
        [_clearConfirmationViewController setDelegate:self];
        [self addChildViewController:_clearConfirmationViewController];
        [_mainView installContentView:[_clearConfirmationViewController confirmationView] hidden:YES];
        [_clearConfirmationViewController didMoveToParentViewController:self];

        _historyEmptyStateView = [[KayokoEmptyStateView alloc] init];
        [_historyEmptyStateView updateWithHistoryKey:kKayokoHistoryKeyHistory];
        [_mainView installContentView:_historyEmptyStateView hidden:YES];

        _favoritesEmptyStateView = [[KayokoEmptyStateView alloc] init];
        [_favoritesEmptyStateView updateWithHistoryKey:kKayokoHistoryKeyFavorites];
        [_mainView installContentView:_favoritesEmptyStateView hidden:YES];

        _previewViewController =
            [[KayokoPreviewViewController alloc] initWithFavoritesButton:[_mainView favoritesButton]
                                                              backButton:[_mainView backButton]
                                                             clearButton:[_mainView clearButton]];
        [self addChildViewController:_previewViewController];
        [_mainView installContentView:[_previewViewController previewView] hidden:YES];
        [_previewViewController didMoveToParentViewController:self];

        _wordSelectionViewController = [[KayokoWordSelectionViewController alloc]
               initWithName:[[PasteboardManager localizationBundle] localizedStringForKey:@"Preview"
                                                                                    value:nil
                                                                                    table:@"Tweak"]
            favoritesButton:[_mainView favoritesButton]
                 backButton:[_mainView backButton]
                clearButton:[_mainView clearButton]];
        [_wordSelectionViewController setDelegate:self];
        [self addChildViewController:_wordSelectionViewController];
        [_mainView installContentView:[_wordSelectionViewController view] hidden:YES];
        [_wordSelectionViewController didMoveToParentViewController:self];

        _searchController =
            [[KayokoSearchController alloc] initWithContainerView:_mainView
                                                       headerView:[_mainView headerView]
                                        historyListViewController:_historyListViewController
                                      favoritesListViewController:_favoritesListViewController
                                             panGestureRecognizer:[_panelPresentationController panGestureRecognizer]];
        [_searchController setDelegate:self];
    }
    return self;
}

- (BOOL)isHidden {
    return [[self mainView] isHidden];
}

- (void)setOutsideDismissOverlayView:(UIControl *)outsideDismissOverlayView {
    [[self panelPresentationController] setOutsideDismissOverlayView:outsideDismissOverlayView];
}

- (void)applyUserInterfaceStyle:(UIUserInterfaceStyle)style {
    [self setOverrideUserInterfaceStyle:style];
    [[self view] setOverrideUserInterfaceStyle:style];

    for (UIViewController *childViewController in [self childViewControllers]) {
        [childViewController setOverrideUserInterfaceStyle:style];
        [[childViewController view] setOverrideUserInterfaceStyle:style];
    }

    [[self historyEmptyStateView] setOverrideUserInterfaceStyle:style];
    [[self favoritesEmptyStateView] setOverrideUserInterfaceStyle:style];
}

- (void)setDismissOnOutsideTouch:(BOOL)dismissOnOutsideTouch {
    _dismissOnOutsideTouch = dismissOnOutsideTouch;
    [[self panelPresentationController] setDismissOnOutsideTouch:dismissOnOutsideTouch];
}

- (void)setPreviewLineCount:(NSUInteger)previewLineCount {
    _previewLineCount = previewLineCount;
    [[self historyListViewController] setPreviewLineCount:previewLineCount];
    [[self favoritesListViewController] setPreviewLineCount:previewLineCount];
}

- (void)setShouldPlayFeedback:(BOOL)shouldPlayFeedback {
    _shouldPlayFeedback = shouldPlayFeedback;
    [[self panelPresentationController] setShouldPlayFeedback:shouldPlayFeedback];
}

- (void)handleViewLayout {
    [[self searchController] layout];
}

- (NSString *)effectiveActiveHistoryKey {
    return [[self historyController]
        effectiveActiveHistoryKeyWithClearConfirmationHistoryKey:[self clearConfirmationHistoryKey]];
}

- (KayokoHistoryListView *)activeTableView {
    return [[self historyController] activeTableViewWithClearConfirmationHistoryKey:[self clearConfirmationHistoryKey]];
}

- (KayokoHistoryListViewController *)activeListViewController {
    return [[self historyController] listViewControllerForHistoryKey:[self effectiveActiveHistoryKey]];
}

- (KayokoHistoryListViewController *)listViewControllerForHistoryKey:(NSString *)historyKey {
    return [[self historyController] listViewControllerForHistoryKey:historyKey];
}

- (KayokoHistoryListViewController *)activeListViewControllerForSearchController:
    (KayokoSearchController *)searchController {
    return [self activeListViewController];
}

- (void)searchControllerWillAnimateSearchState:(KayokoSearchController *)searchController {
    [[self mainView] setAnimating:YES];
    [[self panelPresentationController] finishOutsideDismissOverlayShow];
}

- (void)searchControllerDidFinishAnimatingSearchState:(KayokoSearchController *)searchController {
    [[self mainView] setAnimating:NO];
    [[self panelPresentationController] finishOutsideDismissOverlayShow];
}

- (void)searchController:(KayokoSearchController *)searchController
    didUpdateKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    [[[self clearConfirmationViewController] confirmationView] setKeyboardBottomInset:keyboardBottomInset];
    [[self historyEmptyStateView] setKeyboardBottomInset:keyboardBottomInset];
    [[self favoritesEmptyStateView] setKeyboardBottomInset:keyboardBottomInset];
}

- (void)panelPresentationControllerDidRequestDismiss:(KayokoPanelPresentationController *)controller {
    [self hideRestoringFocus];
}

- (void)panelPresentationControllerDidTapGrabberArea:(KayokoPanelPresentationController *)controller {
    if ([[self searchController] isSearchActive]) {
        [[self searchController] cancelSearchWithCompletion:nil];
    } else {
        [self hideRestoringFocus];
    }
}

- (BOOL)panelPresentationControllerShouldHandleFullscreenSearchPan:(KayokoPanelPresentationController *)controller {
    return [[self searchController] isSearchActive];
}

- (BOOL)isFullscreenSearchActive {
    return [[self searchController] isSearchActive];
}

- (void)panelPresentationController:(KayokoPanelPresentationController *)controller
    handleFullscreenSearchPanGestureRecognizer:(UIPanGestureRecognizer *)recognizer {
    [[self searchController] handleFullscreenPanGestureRecognizer:recognizer];
}

- (BOOL)historyControllerIsPanelVisible:(KayokoHistoryController *)controller {
    return ![self isHidden];
}

- (BOOL)historyControllerShouldSuppressVisibleUpdates:(KayokoHistoryController *)controller {
    return [self isDismissingPanel];
}

- (void)historyControllerNeedsVisibleReload:(KayokoHistoryController *)controller {
    [self reload];
}

- (void)historyController:(KayokoHistoryController *)controller
    didUpdateActiveTableView:(KayokoHistoryListView *)tableView {
    [self updateActiveTableViewState:tableView];
}

- (void)historyListViewControllerDidRequestHide:(KayokoHistoryListViewController *)controller {
    [self hideRestoringFocus];
}

- (void)historyListViewController:(KayokoHistoryListViewController *)controller
         didRequestPreviewForItem:(PasteboardItem *)item {
    [self showContentForItem:item];
}

- (void)historyListViewController:(KayokoHistoryListViewController *)controller
    didChangeContentStateMaintainingSearchBarVisibility:(BOOL)maintainsSearchBarVisibility {
    [self updateContentStateMaintainingSearchBarVisibility:maintainsSearchBarVisibility];
}

- (void)historyListViewController:(KayokoHistoryListViewController *)controller
            didMoveItemDictionary:(NSDictionary<NSString *, id> *)dictionary
               fromHistoryWithKey:(NSString *)sourceHistoryKey
                 toHistoryWithKey:(NSString *)destinationHistoryKey {
    [self handlePasteboardItemDictionary:dictionary
                     movedFromHistoryKey:sourceHistoryKey
                            toHistoryKey:destinationHistoryKey];
}

- (KayokoHistoryListView *)tableViewForHistoryKey:(NSString *)historyKey {
    return [[self historyController] tableViewForHistoryKey:historyKey];
}

- (KayokoEmptyStateView *)emptyStateViewForHistoryKey:(NSString *)historyKey {
    return [historyKey isEqualToString:kKayokoHistoryKeyFavorites] ? [self favoritesEmptyStateView]
                                                                   : [self historyEmptyStateView];
}

- (UIView *)contentViewForHistoryKey:(NSString *)historyKey {
    KayokoHistoryListViewController *listViewController = [self listViewControllerForHistoryKey:historyKey];
    if ([[listViewController items] count] > 0) {
        return [listViewController tableView];
    }

    KayokoEmptyStateView *emptyStateView = [self emptyStateViewForHistoryKey:historyKey];
    [emptyStateView setKeyboardBottomInset:[[self searchController] keyboardBottomInset]];
    return emptyStateView;
}

- (UIView *)activeHistoryContentView {
    if (![[[self historyListViewController] tableView] isHidden]) {
        return [[self historyListViewController] tableView];
    }

    if (![[[self favoritesListViewController] tableView] isHidden]) {
        return [[self favoritesListViewController] tableView];
    }

    if (![[self historyEmptyStateView] isHidden]) {
        return [self historyEmptyStateView];
    }

    if (![[self favoritesEmptyStateView] isHidden]) {
        return [self favoritesEmptyStateView];
    }

    return [self emptyStateViewForHistoryKey:[self effectiveActiveHistoryKey]];
}

- (NSString *)titleForContentView:(UIView *)view {
    if (view == [[self clearConfirmationViewController] confirmationView]) {
        return [[[[self mainView] titleLabel] text] copy];
    }

    if (view == [[self previewViewController] previewView]) {
        return [[[self previewViewController] previewView] name];
    }

    if (view == [[self wordSelectionViewController] view]) {
        return [[self wordSelectionViewController] name];
    }

    if (view == [[self historyListViewController] tableView]) {
        return [[self historyListViewController] name];
    }

    if (view == [[self favoritesListViewController] tableView]) {
        return [[self favoritesListViewController] name];
    }

    if (view == [self historyEmptyStateView]) {
        return [[self historyEmptyStateView] name];
    }

    if (view == [self favoritesEmptyStateView]) {
        return [[self favoritesEmptyStateView] name];
    }

    return nil;
}

- (void)setHistoryContentVisibleForKey:(NSString *)historyKey {
    [[self historyController] setActiveHistoryKey:historyKey];
    UIView *contentView = [self contentViewForHistoryKey:historyKey];
    [[[self historyListViewController] tableView]
        setHidden:contentView != [[self historyListViewController] tableView]];
    [[[self favoritesListViewController] tableView]
        setHidden:contentView != [[self favoritesListViewController] tableView]];
    [[self historyEmptyStateView] setHidden:contentView != [self historyEmptyStateView]];
    [[self favoritesEmptyStateView] setHidden:contentView != [self favoritesEmptyStateView]];
    [contentView setAlpha:1];
    [contentView setTransform:CGAffineTransformIdentity];
    [[self searchController] attachToListViewController:[self listViewControllerForHistoryKey:historyKey]
                                         hidesSearchBar:![[self searchController] isSearchActive]];
    [[self searchController] refreshForListViewController:[self activeListViewController]];
    [[self mainView] setTitleText:[self titleForContentView:contentView]];
    [self updateFavoritesButtonForHistoryKey:historyKey];
}

- (void)markHistoryKeyLoaded:(NSString *)historyKey {
    [[self historyController] markHistoryKeyLoaded:historyKey];
}

- (void)updateActiveTableViewState:(KayokoHistoryListView *)tableView {
    if (tableView == [self activeTableView]) {
        KayokoHistoryListViewController *activeListViewController = [self activeListViewController];
        if ([self cancelSearchForEmptyActiveHistoryIfNeededHidingView:[self activeHistoryContentView]
                                                            direction:KayokoContentTransitionDirectionForward
                                                           completion:nil]) {
            return;
        }
        if ([[self searchController] isSearchActive] || [activeListViewController hasActiveSearch]) {
            [[self searchController] refreshForListViewController:activeListViewController];
        }
        [[self mainView] setClearButtonEnabledForItemCount:[[[self activeListViewController] items] count]];
        if ([self activeHistoryContentView] != [self contentViewForHistoryKey:[self effectiveActiveHistoryKey]]) {
            [self updateContentStateMaintainingSearchBarVisibility:NO];
        }
    }
}

- (void)handleHistoryChanged {
    [[self historyController] handleHistoryChanged];
}

- (void)reloadTableViewForHistoryKey:(NSString *)historyKey
              animatingTopInsertions:(BOOL)animatingTopInsertions
                          completion:(void (^)(KayokoHistoryListView *tableView))completion {
    [[self historyController] reloadTableViewForHistoryKey:historyKey
                                    animatingTopInsertions:animatingTopInsertions
                                                completion:completion];
}

- (void)reloadTableViewForHistoryKey:(NSString *)historyKey
                          completion:(void (^)(KayokoHistoryListView *tableView))completion {
    [[self historyController] reloadTableViewForHistoryKey:historyKey completion:completion];
}

- (void)showClearConfirmationForHistoryKey:(NSString *)historyKey {
    [[self historyController] setActiveHistoryKey:historyKey];
    [self setClearConfirmationHistoryKey:historyKey];
    [[self clearConfirmationViewController] beginWithHistoryKey:historyKey];
    [[[self clearConfirmationViewController] confirmationView]
        setKeyboardBottomInset:[[self searchController] keyboardBottomInset]];
    [[[self mainView] clearButton] setHidden:YES];

    [[self mainView]
        showContentView:[[self clearConfirmationViewController] confirmationView]
        hideContentView:[self activeHistoryContentView]
                  title:[self titleForContentView:[[self clearConfirmationViewController] confirmationView]]
              direction:KayokoContentTransitionDirectionModalPresenting];
}

- (void)finishHidingClearConfirmationForHistoryKey:(NSString *)historyKey {
    [self setClearConfirmationHistoryKey:nil];
    [[[self mainView] clearButton] setHidden:NO];
    [[self mainView]
        setClearButtonEnabledForItemCount:[[[self listViewControllerForHistoryKey:historyKey] items] count]];
    UIView *contentView = [self contentViewForHistoryKey:historyKey];
    [[self mainView] showContentView:contentView
                     hideContentView:[[self clearConfirmationViewController] confirmationView]
                               title:[self titleForContentView:contentView]
                           direction:KayokoContentTransitionDirectionModalDismissing];
}

- (void)hideClearConfirmationWithReload:(BOOL)reload {
    if ([[[self clearConfirmationViewController] confirmationView] isHidden] || ![self clearConfirmationHistoryKey]) {
        return;
    }

    NSString *historyKey = [self clearConfirmationHistoryKey];
    if (reload) {
        [[self listViewControllerForHistoryKey:historyKey] clearItems];
        [self markHistoryKeyLoaded:historyKey];
        if ([[self effectiveActiveHistoryKey] isEqualToString:historyKey]) {
            [self setClearConfirmationHistoryKey:nil];
            [[[self mainView] clearButton] setHidden:NO];
            [[self mainView] setClearButtonEnabledForItemCount:0];
            if ([self
                    cancelSearchForEmptyActiveHistoryIfNeededHidingView:[[self clearConfirmationViewController]
                                                                            confirmationView]
                                                              direction:KayokoContentTransitionDirectionModalDismissing
                                                             completion:nil]) {
                return;
            }
            [[self searchController] refreshForListViewController:[self activeListViewController]];
        }
    }
    [self finishHidingClearConfirmationForHistoryKey:historyKey];
}

- (void)resetClearConfirmationIfNeeded {
    if (![self clearConfirmationHistoryKey]) {
        return;
    }

    [[[self clearConfirmationViewController] confirmationView] setHidden:YES];
    [[[self clearConfirmationViewController] confirmationView] setAlpha:1];
    [[[self clearConfirmationViewController] confirmationView] setTransform:CGAffineTransformIdentity];
    [self setHistoryContentVisibleForKey:[self clearConfirmationHistoryKey]];
    [[[self mainView] clearButton] setHidden:NO];
    [self setClearConfirmationHistoryKey:nil];
    [self updateClearButtonState];
}

- (BOOL)isShowingClearConfirmation {
    return [self clearConfirmationHistoryKey] && ![[[self clearConfirmationViewController] confirmationView] isHidden];
}

- (void)updateClearButtonState {
    [[self mainView] setClearButtonEnabledForItemCount:[[[self activeListViewController] items] count]];
}

- (void)updateContentState {
    [self updateContentStateMaintainingSearchBarVisibility:YES];
}

- (BOOL)isPreviewActive {
    return ![[[self previewViewController] previewView] isHidden] || [[self previewViewController] previewItem] != nil;
}

- (BOOL)isWordSelectionActive {
    return ![[[self wordSelectionViewController] view] isHidden] ||
           [[self wordSelectionViewController] sourceItem] != nil;
}

- (void)restoreActiveSourceContentView {
    UIView *sourceContentView = [self activeSourceContentView];
    if (!sourceContentView) {
        return;
    }

    [sourceContentView setHidden:NO];
    [sourceContentView setAlpha:1];
    [sourceContentView setTransform:CGAffineTransformIdentity];
}

- (void)refreshSearchAfterEndingTransientContentIfNeeded {
    if ([[self searchController] isSearchActive]) {
        [[self searchController] refreshForListViewController:[self activeListViewController]];
    }
}

- (void)updateFavoritesButtonForHistoryKey:(NSString *)historyKey {
    BOOL showingFavorites = [historyKey isEqualToString:kKayokoHistoryKeyFavorites];
    NSString *imageName = showingFavorites ? @"heart.fill" : @"heart";
    UIColor *tintColor = showingFavorites ? [UIColor systemPinkColor] : [UIColor labelColor];
    [[self mainView] updateStyleForHeaderButton:[[self mainView] favoritesButton]
                                  withImageName:imageName
                                   andImageSize:kKayokoFavoritesButtonImageSize
                                   andTintColor:tintColor];
}

- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
              direction:(KayokoContentTransitionDirection)direction
             completion:(nullable void (^)(void))completion {
    [[self mainView] showContentView:viewToShow
                     hideContentView:viewToHide
                               title:[self titleForContentView:viewToShow]
                           direction:direction
                          completion:completion];
}

- (BOOL)cancelSearchForEmptyActiveHistoryIfNeededHidingView:(UIView *)viewToHide
                                                  direction:(KayokoContentTransitionDirection)direction
                                                 completion:(void (^)(void))completion {
    if (![[self searchController] isSearchActive] || [[[self activeListViewController] items] count] > 0) {
        return NO;
    }

    [[self mainView] setClearButtonEnabledForItemCount:0];
    UIView *viewToShow = [self contentViewForHistoryKey:[self effectiveActiveHistoryKey]];
    if (viewToShow == viewToHide) {
        [[self searchController] cancelSearchWithCompletion:completion];
        return YES;
    }

    [[self mainView] prepareContentTransitionToView:viewToShow
                                    hideContentView:viewToHide
                                              title:[self titleForContentView:viewToShow]
                                          direction:direction];
    [[self searchController]
        cancelSearchWithAnimations:^{
          [[self mainView] applyPreparedContentTransitionToView:viewToShow
                                                hideContentView:viewToHide
                                                      direction:direction];
        }
        completion:^{
          [[self mainView] completePreparedContentTransitionHidingView:viewToHide completion:completion];
        }];
    return YES;
}

- (void)updateContentStateMaintainingSearchBarVisibility:(BOOL)maintainsSearchBarVisibility {
    if (![self isShowingClearConfirmation] && [[[self previewViewController] previewView] isHidden] &&
        [[[self wordSelectionViewController] view] isHidden]) {
        if ([self cancelSearchForEmptyActiveHistoryIfNeededHidingView:[self activeHistoryContentView]
                                                            direction:KayokoContentTransitionDirectionForward
                                                           completion:nil]) {
            return;
        }

        UIView *viewToHide = [self activeHistoryContentView];
        UIView *viewToShow = [self contentViewForHistoryKey:[self effectiveActiveHistoryKey]];

        if (viewToShow != viewToHide) {
            [[self mainView] showContentView:viewToShow
                             hideContentView:viewToHide
                                       title:[self titleForContentView:viewToShow]
                                   direction:KayokoContentTransitionDirectionForward];
        } else {
            [[self mainView] setTitleText:[self titleForContentView:viewToShow]];
        }
    }

    [self updateClearButtonState];
    if (maintainsSearchBarVisibility) {
        [[self searchController] maintainSearchBarVisibilityForListViewController:[self activeListViewController]];
    }
}

- (void)handleFavoritesButtonPressed {
    if ([[self panelPresentationController] isAnimating]) {
        return;
    }

    if ([self isShowingClearConfirmation]) {
        [self hideClearConfirmationWithReload:NO];
        [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
        return;
    }

    if (![[[self previewViewController] previewView] isHidden]) {
        [self hidePreview];
        [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
        return;
    }

    if (![[[self wordSelectionViewController] view] isHidden]) {
        [self hideWordSelection];
        [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
        return;
    }

    NSString *historyKey = [self effectiveActiveHistoryKey];
    BOOL showingFavorites = [historyKey isEqualToString:kKayokoHistoryKeyFavorites];
    NSString *targetKey = showingFavorites ? kKayokoHistoryKeyHistory : kKayokoHistoryKeyFavorites;
    UIView *viewToHide = [self activeHistoryContentView];
    KayokoContentTransitionDirection direction = showingFavorites ? KayokoContentTransitionDirectionSiblingBackward
                                                                  : KayokoContentTransitionDirectionSiblingForward;

    [self reloadTableViewForHistoryKey:targetKey
                            completion:^(KayokoHistoryListView *targetTableView) {
                              if (![[self effectiveActiveHistoryKey] isEqualToString:historyKey] ||
                                  [[self panelPresentationController] isAnimating]) {
                                  return;
                              }

                              if ([[[self listViewControllerForHistoryKey:targetKey] items] count] == 0 &&
                                  [[self searchController] isSearchActive]) {
                                  UIView *viewToShow = [self contentViewForHistoryKey:targetKey];
                                  [[self mainView] setClearButtonEnabledForItemCount:0];
                                  [[self mainView] prepareContentTransitionToView:viewToShow
                                                                  hideContentView:viewToHide
                                                                            title:[self titleForContentView:viewToShow]
                                                                        direction:direction];
                                  [[self searchController]
                                      cancelSearchWithAnimations:^{
                                        [[self historyController] setActiveHistoryKey:targetKey];
                                        [[self searchController]
                                            attachToListViewController:[self listViewControllerForHistoryKey:targetKey]
                                                        hidesSearchBar:YES];
                                        [[self searchController]
                                            refreshForListViewController:[self activeListViewController]];
                                        [[self mainView] applyPreparedContentTransitionToView:viewToShow
                                                                              hideContentView:viewToHide
                                                                                    direction:direction];
                                      }
                                      completion:^{
                                        [[self mainView] completePreparedContentTransitionHidingView:viewToHide
                                                                                          completion:nil];
                                      }];
                                  [self updateFavoritesButtonForHistoryKey:targetKey];
                                  [[self panelPresentationController]
                                      triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
                                  return;
                              }

                              [[self historyController] setActiveHistoryKey:targetKey];
                              [[self searchController]
                                  attachToListViewController:[self listViewControllerForHistoryKey:targetKey]
                                              hidesSearchBar:![[self searchController] isSearchActive]];
                              [[self searchController] refreshForListViewController:[self activeListViewController]];
                              [[self mainView]
                                  setClearButtonEnabledForItemCount:[[[self listViewControllerForHistoryKey:targetKey]
                                                                        items] count]];

                              UIView *viewToShow = [self contentViewForHistoryKey:targetKey];
                              if (viewToShow != viewToHide) {
                                  [[self mainView] showContentView:viewToShow
                                                   hideContentView:viewToHide
                                                             title:[self titleForContentView:viewToShow]
                                                         direction:direction];
                              } else {
                                  [[self mainView] setTitleText:[self titleForContentView:viewToShow]];
                              }

                              [self updateFavoritesButtonForHistoryKey:targetKey];
                              [[self panelPresentationController]
                                  triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
                            }];
}

- (void)handlePreviewActionButtonPressed {
    if (![[[self wordSelectionViewController] view] isHidden]) {
        [[self wordSelectionViewController] handleActionButtonWithAutomaticallyPaste:[self automaticallyPaste]];
    }
}

- (void)handleClearButtonPressed {
    if ([[self panelPresentationController] isAnimating] || ![[[self previewViewController] previewView] isHidden] ||
        ![[[self wordSelectionViewController] view] isHidden] || [self isShowingClearConfirmation]) {
        return;
    }

    [self showClearConfirmationForHistoryKey:[self effectiveActiveHistoryKey]];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)handleTitleTapControlPressed {
    if ([[self panelPresentationController] isAnimating] || [[self mainView] isAnimating]) {
        return;
    }

    if (![[[self wordSelectionViewController] view] isHidden]) {
        [[self wordSelectionViewController] scrollToTopAnimated:YES];
        return;
    }

    if (![[[self previewViewController] previewView] isHidden]) {
        [[self previewViewController] scrollToTopAnimated:YES];
        return;
    }

    [[self activeListViewController] scrollToTopAnimated:YES];
}

- (void)handlePasteboardItemDictionary:(NSDictionary<NSString *, id> *)dictionary
                   movedFromHistoryKey:(NSString *)sourceHistoryKey
                          toHistoryKey:(NSString *)destinationHistoryKey {
    [[self historyController] handlePasteboardItemDictionary:dictionary
                                         movedFromHistoryKey:sourceHistoryKey
                                                toHistoryKey:destinationHistoryKey];
}

- (void)showContentForItem:(PasteboardItem *)item {
    [[self searchController] resignSearchFirstResponder];
    NSString *historyKey = [self effectiveActiveHistoryKey];
    KayokoHistoryListView *sourceTableView = [self tableViewForHistoryKey:historyKey];
    [self setActiveSourceContentView:sourceTableView];
    NSString *previewText = kayokoMainPreviewTextByTrimmingBoundaryNewlines([item content]);
    BOOL canUseWordSelection = [self swipeToSelectWords] && [[item imageName] isEqualToString:@""] &&
                               [[self wordSelectionViewController] canShowText:previewText];
    if (canUseWordSelection) {
        [[self wordSelectionViewController] showWordSelectionWithItem:item
                                                     sourceHistoryKey:historyKey
                                                   automaticallyPaste:[self automaticallyPaste]];
        [self showContentView:[[self wordSelectionViewController] view]
              hideContentView:sourceTableView
                    direction:KayokoContentTransitionDirectionForward
                   completion:nil];
        [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
        return;
    }

    [[self previewViewController] showPreviewWithItem:item sourceHistoryKey:historyKey];
    [self showContentView:[[self previewViewController] previewView]
          hideContentView:sourceTableView
                direction:KayokoContentTransitionDirectionForward
               completion:nil];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)hidePreview {
    if ([[[self previewViewController] previewView] isHidden] || [[self panelPresentationController] isAnimating]) {
        return;
    }

    UIView *sourceView = [self activeSourceContentView];
    UIView *previewView = [[self previewViewController] previewView];
    [[self previewViewController] prepareToHidePreview];
    if (!sourceView) {
        [[self previewViewController] resetPreviewState];
        [self setActiveSourceContentView:nil];
        [self refreshSearchAfterEndingTransientContentIfNeeded];
        return;
    }

    [self showContentView:sourceView
          hideContentView:previewView
                direction:KayokoContentTransitionDirectionBackward
               completion:^{
                 [[self previewViewController] hidePreview];
                 [self setActiveSourceContentView:nil];
                 [self refreshSearchAfterEndingTransientContentIfNeeded];
               }];
}

- (void)hideWordSelection {
    if ([[[self wordSelectionViewController] view] isHidden] || [[self panelPresentationController] isAnimating]) {
        return;
    }

    UIView *sourceView = [self activeSourceContentView];
    UIView *wordSelectionView = [[self wordSelectionViewController] view];
    [[self wordSelectionViewController] prepareToHideWordSelection];
    if (!sourceView) {
        [[self wordSelectionViewController] resetWordSelectionState];
        [self setActiveSourceContentView:nil];
        [self refreshSearchAfterEndingTransientContentIfNeeded];
        return;
    }

    [self showContentView:sourceView
          hideContentView:wordSelectionView
                direction:KayokoContentTransitionDirectionBackward
               completion:^{
                 [[self wordSelectionViewController] hideWordSelection];
                 [self setActiveSourceContentView:nil];
                 [self refreshSearchAfterEndingTransientContentIfNeeded];
               }];
}

- (void)clearConfirmationViewControllerDidCancel:(KayokoClearConfirmationViewController *)controller {
    if ([[self panelPresentationController] isAnimating]) {
        return;
    }

    [self hideClearConfirmationWithReload:NO];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
}

- (void)clearConfirmationViewControllerDidClearHistoryKey:(NSString *)historyKey {
    [self hideClearConfirmationWithReload:YES];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleHeavy];
}

- (void)clearConfirmationViewController:(KayokoClearConfirmationViewController *)controller
              didFailClearingHistoryKey:(NSString *)historyKey {
}

- (void)wordSelectionViewControllerDidRequestHideContainer:(KayokoWordSelectionViewController *)controller {
    [self hideRestoringFocus];
}

- (void)wordSelectionViewController:(KayokoWordSelectionViewController *)controller
     triggerHapticFeedbackWithStyle:(UIImpactFeedbackStyle)style {
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:style];
}

- (void)reload {
    NSString *historyKey = [self effectiveActiveHistoryKey];
    [self reloadTableViewForHistoryKey:historyKey
                animatingTopInsertions:![self isHidden] && [historyKey isEqualToString:kKayokoHistoryKeyHistory]
                            completion:^(KayokoHistoryListView *tableView) {
                              if (![[self effectiveActiveHistoryKey] isEqualToString:historyKey]) {
                                  return;
                              }
                              if ([self isShowingClearConfirmation] ||
                                  ![[[self previewViewController] previewView] isHidden] ||
                                  ![[[self wordSelectionViewController] view] isHidden]) {
                                  return;
                              }
                              [self setHistoryContentVisibleForKey:historyKey];
                              [[self searchController] refreshForListViewController:[self activeListViewController]];
                              [[self mainView]
                                  setClearButtonEnabledForItemCount:[[[self activeListViewController] items] count]];
                            }];
}

- (void)preloadHistoryIfNeeded {
    [[self historyController] preloadHistoryWithCompletion:nil];
}

- (void)show {
    if ([[self panelPresentationController] isAnimating] || [self preparingToShow]) {
        return;
    }

    [self setDismissingPanel:NO];
    [self setPreparingToShow:YES];
    NSUInteger showRequestIdentifier = [self showRequestIdentifier] + 1;
    [self setShowRequestIdentifier:showRequestIdentifier];
    [self resetClearConfirmationIfNeeded];

    [[self historyListViewController] setAutomaticallyPaste:[self automaticallyPaste]];
    [[self favoritesListViewController] setAutomaticallyPaste:[self automaticallyPaste]];

    NSString *historyKey = [self effectiveActiveHistoryKey];
    [self reloadTableViewForHistoryKey:historyKey
                animatingTopInsertions:NO
                            completion:^(KayokoHistoryListView *tableView) {
                              if ([self showRequestIdentifier] != showRequestIdentifier) {
                                  return;
                              }
                              [self setPreparingToShow:NO];
                              if (![[self effectiveActiveHistoryKey] isEqualToString:historyKey] || ![self isHidden] ||
                                  [[self panelPresentationController] isAnimating]) {
                                  return;
                              }

                              [self setHistoryContentVisibleForKey:historyKey];
                              [[self searchController] attachToListViewController:[self activeListViewController]
                                                                   hidesSearchBar:YES];
                              [[self mainView]
                                  setClearButtonEnabledForItemCount:[[[self activeListViewController] items] count]];
                              [[self panelPresentationController] showPanelWithCompletion:nil];
                            }];
}

- (void)hide {
    [self hideWithCompletion:nil];
}

- (void)hideRestoringFocus {
    [self hideWithCompletion:^{
      if ([self focusRestoreRequestHandler]) {
          [self focusRestoreRequestHandler]();
      }
    }];
}

- (void)completeHideAfterShowingTransientContent:(BOOL)wasShowingTransientContent
                                      completion:(void (^)(void))completion {
    [self restoreActiveSourceContentView];
    [[self previewViewController] resetPreviewState];
    [[self wordSelectionViewController] resetWordSelectionState];
    [self setActiveSourceContentView:nil];
    [self setDismissingPanel:NO];
    if (wasShowingTransientContent) {
        [self refreshSearchAfterEndingTransientContentIfNeeded];
    }
    if (completion) {
        completion();
    }
}

- (void)hideWithCompletion:(void (^)(void))completion {
    [self setShowRequestIdentifier:[self showRequestIdentifier] + 1];
    [self setPreparingToShow:NO];

    if ([[self panelPresentationController] isAnimating]) {
        return;
    }

    [self setDismissingPanel:YES];
    BOOL wasShowingTransientContent = [self isPreviewActive] || [self isWordSelectionActive];
    [[self searchController] resetBeforeHide];
    [[self panelPresentationController] hidePanelWithCompletion:^{
      [self completeHideAfterShowingTransientContent:wasShowingTransientContent completion:completion];
    }];
}

- (void)hideImmediately {
    [self setShowRequestIdentifier:[self showRequestIdentifier] + 1];
    [self setPreparingToShow:NO];

    if ([self isHidden]) {
        return;
    }

    [self setDismissingPanel:YES];
    BOOL wasShowingTransientContent = [self isPreviewActive] || [self isWordSelectionActive];
    [[self searchController] resetBeforeHide];
    [[self panelPresentationController] hidePanelImmediatelyWithCompletion:^{
      [self completeHideAfterShowingTransientContent:wasShowingTransientContent completion:nil];
    }];
}

@end
