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
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import "KayokoPreviewView.h"
#import "KayokoPreviewViewController.h"
#import "KayokoSearchController.h"
#import "KayokoTagCatalog.h"
#import "KayokoWordSelectionView.h"
#import "KayokoWordSelectionViewController.h"

static CGFloat const kKayokoTransientEdgeBackHorizontalDominance = 1.2;
static CGFloat const kKayokoTransientEdgeBackCompletionProgress = 0.35;
static CGFloat const kKayokoTransientEdgeBackCompletionVelocity = 650;
static NSTimeInterval const kKayokoTransientEdgeBackMinimumAnimationDuration = 0.08;
static NSTimeInterval const kKayokoTransientEdgeBackMaximumAnimationDuration = 0.22;

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openSensitiveURL:(NSURL *)url withOptions:(NSDictionary *)options error:(NSError **)error;
@end

NS_ASSUME_NONNULL_BEGIN

@interface KayokoMainViewController () <KayokoClearConfirmationViewControllerDelegate, KayokoHistoryControllerDelegate,
                                        KayokoPanelPresentationControllerDelegate, KayokoSearchControllerDelegate,
                                        KayokoHistoryListViewControllerDelegate,
                                        KayokoWordSelectionViewControllerDelegate, UIGestureRecognizerDelegate>
#pragma mark - Views

@property(nonatomic, strong) KayokoMainView *mainView;
@property(nonatomic, strong) KayokoEmptyStateView *historyEmptyStateView;
@property(nonatomic, strong) KayokoEmptyStateView *favoritesEmptyStateView;
@property(nonatomic, strong) KayokoEmptyStateView *storageErrorView;
@property(nonatomic, strong) KayokoEmptyStateView *authorizationRequiredView;

#pragma mark - Child Controllers

@property(nonatomic, strong) KayokoHistoryListViewController *historyListViewController;
@property(nonatomic, strong) KayokoHistoryListViewController *favoritesListViewController;
@property(nonatomic, strong) KayokoClearConfirmationViewController *clearConfirmationViewController;
@property(nonatomic, strong) KayokoPreviewViewController *previewViewController;
@property(nonatomic, strong) KayokoWordSelectionViewController *wordSelectionViewController;

#pragma mark - Coordinators

@property(nonatomic, strong) KayokoHistoryController *historyController;
@property(nonatomic, strong) KayokoPanelPresentationController *panelPresentationController;
@property(nonatomic, strong) KayokoSearchController *searchController;

#pragma mark - State

@property(nonatomic, copy, nullable) NSString *clearConfirmationHistoryKey;
@property(nonatomic, strong, nullable) NSError *storageError;
@property(nonatomic, assign) BOOL preparingToShow;
@property(nonatomic, assign) NSUInteger showRequestIdentifier;
@property(nonatomic, assign, getter=isDismissingPanel) BOOL dismissingPanel;

#pragma mark - Transient Content

@property(nonatomic, assign) BOOL restoresSearchFirstResponderAfterTransientContent;
@property(nonatomic, assign) BOOL hasSearchContentOffsetBeforeTransientContent;
@property(nonatomic, assign) CGPoint searchContentOffsetBeforeTransientContent;
@property(nonatomic, weak, nullable) UIView *activeSourceContentView;
@property(nonatomic, strong) UIScreenEdgePanGestureRecognizer *transientEdgeBackGestureRecognizer;
@property(nonatomic, weak, nullable) UIView *interactiveTransientReturnSourceView;
@property(nonatomic, weak, nullable) UIView *interactiveTransientReturnContentView;
@property(nonatomic, assign) BOOL interactiveTransientReturnWasPreview;
@property(nonatomic, assign) BOOL didRestoreSearchDuringInteractiveTransientReturn;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoMainViewController

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _authorizationPassed = YES;
        _mainView = [[KayokoMainView alloc] initWithFrame:frame];
        [self setView:_mainView];
        _historyListViewController = [[KayokoHistoryListViewController alloc]
            initWithName:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"History"
                                                                                       value:nil
                                                                                       table:@"Tweak"]
              historyKey:kKayokoHistoryKeyHistory];
        [_historyListViewController setDelegate:self];
        [self addChildViewController:_historyListViewController];
        [_mainView installContentView:[_historyListViewController tableView] hidden:NO];
        [_historyListViewController didMoveToParentViewController:self];

        _favoritesListViewController = [[KayokoHistoryListViewController alloc]
            initWithName:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
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

        _storageErrorView = [[KayokoEmptyStateView alloc] init];
        [_mainView installContentView:_storageErrorView hidden:YES];

        _authorizationRequiredView = [[KayokoEmptyStateView alloc] init];
        [_authorizationRequiredView updateWithAuthorizationRequiredActionHandler:^{
          [weakSelf openAuthorizationSettings];
        }];
        [_mainView installContentView:_authorizationRequiredView hidden:YES];

        _previewViewController =
            [[KayokoPreviewViewController alloc] initWithFavoritesButton:[_mainView favoritesButton]
                                                              backButton:[_mainView backButton]
                                                             clearButton:[_mainView clearButton]];
        [_previewViewController setTagAssignmentHandler:^(KayokoPasteboardItem *item, NSString *historyKey) {
          [weakSelf handleTagAssignmentForItem:item historyKey:historyKey];
        }];
        [self addChildViewController:_previewViewController];
        [_mainView installContentView:[_previewViewController previewView] hidden:YES];
        [_previewViewController didMoveToParentViewController:self];

        _wordSelectionViewController = [[KayokoWordSelectionViewController alloc]
               initWithName:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Preview"
                                                                                          value:nil
                                                                                          table:@"Tweak"]
            favoritesButton:[_mainView favoritesButton]
                 backButton:[_mainView backButton]
                clearButton:[_mainView clearButton]];
        [_wordSelectionViewController setDelegate:self];
        [_wordSelectionViewController setTagAssignmentHandler:^(KayokoPasteboardItem *item, NSString *historyKey) {
          [weakSelf handleTagAssignmentForItem:item historyKey:historyKey];
        }];
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

        _transientEdgeBackGestureRecognizer = [[UIScreenEdgePanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handleTransientEdgeBackGestureRecognizer:)];
        [_transientEdgeBackGestureRecognizer setEdges:UIRectEdgeLeft];
        [_transientEdgeBackGestureRecognizer setDelegate:self];
        [_mainView addGestureRecognizer:_transientEdgeBackGestureRecognizer];
        [[_previewViewController previewView]
            requireImagePanGestureRecognizerToFailGestureRecognizer:_transientEdgeBackGestureRecognizer];
        [[_wordSelectionViewController wordSelectionView]
            requireSelectionGestureRecognizerToFailGestureRecognizer:_transientEdgeBackGestureRecognizer];
    }
    return self;
}

#pragma mark - Configuration

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
    [[self storageErrorView] setOverrideUserInterfaceStyle:style];
    [[self authorizationRequiredView] setOverrideUserInterfaceStyle:style];
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

- (void)setAuthorizationPassed:(BOOL)authorizationPassed {
    if (_authorizationPassed == authorizationPassed) {
        return;
    }

    _authorizationPassed = authorizationPassed;
    if ([self isHidden]) {
        return;
    }

    if (authorizationPassed) {
        [self reload];
    } else {
        [self setHistoryContentVisibleForKey:[self effectiveActiveHistoryKey]];
    }
}

- (BOOL)isAuthorizationRequired {
    return ![self isAuthorizationPassed];
}

#pragma mark - Layout and Lookup

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

#pragma mark - KayokoSearchControllerDelegate

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
    [[self storageErrorView] setKeyboardBottomInset:keyboardBottomInset];
    [[self authorizationRequiredView] setKeyboardBottomInset:keyboardBottomInset];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == [self transientEdgeBackGestureRecognizer]) {
        return [self canBeginTransientEdgeBackGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)gestureRecognizer];
    }

    return YES;
}

#pragma mark - KayokoPanelPresentationControllerDelegate

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

- (BOOL)panelPresentationController:(KayokoPanelPresentationController *)controller
    shouldBeginExpandedPanelPanFromView:(nullable UIView *)view
                               velocity:(CGPoint)velocity {
    (void)controller;
    (void)view;
    (void)velocity;
    if ([self isHidden] || [[self panelPresentationController] isAnimating]) {
        return NO;
    }
    if ([self isShowingClearConfirmation] || [self isPreviewActive] || [self isWordSelectionActive]) {
        return NO;
    }

    UIView *activeContentView = [self activeHistoryContentView];
    return activeContentView == [[self historyListViewController] tableView] ||
           activeContentView == [[self favoritesListViewController] tableView] ||
           activeContentView == [self historyEmptyStateView] || activeContentView == [self favoritesEmptyStateView] ||
           activeContentView == [self storageErrorView] || activeContentView == [self authorizationRequiredView];
}

- (BOOL)isFullscreenSearchActive {
    return [[self searchController] isSearchActive];
}

- (BOOL)shouldSuppressSystemMultitaskingGesture {
    if ([self isHidden]) {
        return NO;
    }

    KayokoPreviewView *previewView = [[self previewViewController] previewView];
    if (![previewView isHidden] && [previewView hasVisibleTagBar]) {
        return YES;
    }

    KayokoWordSelectionView *wordSelectionView = [[self wordSelectionViewController] wordSelectionView];
    return ![wordSelectionView isHidden] && [wordSelectionView hasVisibleTagBar];
}

- (void)panelPresentationController:(KayokoPanelPresentationController *)controller
    handleFullscreenSearchPanGestureRecognizer:(UIPanGestureRecognizer *)recognizer
                             beganInHeaderView:(BOOL)beganInHeaderView {
    [[self searchController] handleFullscreenPanGestureRecognizer:recognizer beganInHeaderView:beganInHeaderView];
}

#pragma mark - KayokoHistoryControllerDelegate

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
    [self setStorageError:nil];
    [self updateActiveTableViewState:tableView];
}

- (void)historyController:(KayokoHistoryController *)controller didFailLoadingHistoryWithError:(NSError *)error {
    [self showStorageError:error];
}

- (void)searchController:(KayokoSearchController *)searchController didFailLoadingSearchWithError:(NSError *)error {
    [self showStorageError:error];
}

- (void)handleApplicationMetadataChanged {
    [[self searchController] handleApplicationMetadataChanged];
}

#pragma mark - KayokoHistoryListViewControllerDelegate

- (void)historyListViewControllerDidRequestHide:(KayokoHistoryListViewController *)controller {
    [self hideRestoringFocus];
}

- (void)historyListViewControllerDidRequestHideAfterDirectPaste:(KayokoHistoryListViewController *)controller {
    [self hideAfterDirectPaste];
}

- (void)historyListViewController:(KayokoHistoryListViewController *)controller
         didRequestPreviewForItem:(KayokoPasteboardItem *)item {
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

#pragma mark - Content Lookup

- (KayokoHistoryListView *)tableViewForHistoryKey:(NSString *)historyKey {
    return [[self historyController] tableViewForHistoryKey:historyKey];
}

- (KayokoEmptyStateView *)emptyStateViewForHistoryKey:(NSString *)historyKey {
    return [historyKey isEqualToString:kKayokoHistoryKeyFavorites] ? [self favoritesEmptyStateView]
                                                                   : [self historyEmptyStateView];
}

- (UIView *)contentViewForHistoryKey:(NSString *)historyKey {
    if ([self isAuthorizationRequired]) {
        [[self authorizationRequiredView] setKeyboardBottomInset:[[self searchController] keyboardBottomInset]];
        return [self authorizationRequiredView];
    }

    if ([self storageError]) {
        [[self storageErrorView] updateWithStorageError:[self storageError]];
        [[self storageErrorView] setKeyboardBottomInset:[[self searchController] keyboardBottomInset]];
        return [self storageErrorView];
    }

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

    if (![[self storageErrorView] isHidden]) {
        return [self storageErrorView];
    }

    if (![[self authorizationRequiredView] isHidden]) {
        return [self authorizationRequiredView];
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

    if (view == [self storageErrorView]) {
        return [[self storageErrorView] name];
    }

    if (view == [self authorizationRequiredView]) {
        return [[self authorizationRequiredView] name];
    }

    return nil;
}

#pragma mark - History Content

- (void)setHistoryContentVisibleForKey:(NSString *)historyKey {
    [[self historyController] setActiveHistoryKey:historyKey];
    UIView *contentView = [self contentViewForHistoryKey:historyKey];
    BOOL showsAuthorizationRequired = contentView == [self authorizationRequiredView];
    [[[self historyListViewController] tableView]
        setHidden:contentView != [[self historyListViewController] tableView]];
    [[[self favoritesListViewController] tableView]
        setHidden:contentView != [[self favoritesListViewController] tableView]];
    [[self historyEmptyStateView] setHidden:contentView != [self historyEmptyStateView]];
    [[self favoritesEmptyStateView] setHidden:contentView != [self favoritesEmptyStateView]];
    [[self storageErrorView] setHidden:contentView != [self storageErrorView]];
    [[self authorizationRequiredView] setHidden:!showsAuthorizationRequired];
    [contentView setAlpha:1];
    [contentView setTransform:CGAffineTransformIdentity];
    if (showsAuthorizationRequired) {
        [[self searchController] resetBeforeHide];
        [self showAuthorizationRequiredHeaderIcon];
        [[[self mainView] clearButton] setHidden:YES];
        [[[self mainView] backButton] setHidden:YES];
        [[[self mainView] titleTapControl] setEnabled:NO];
        [[self mainView] setTitleText:[self titleForContentView:contentView]];
        [[self mainView] setClearButtonEnabledForItemCount:0];
        return;
    }

    [self restoreHistoryHeaderIconForHistoryKey:historyKey];
    [[[self mainView] clearButton] setHidden:NO];
    [[[self mainView] backButton] setHidden:YES];
    [[[self mainView] titleTapControl] setEnabled:YES];
    [[self searchController] attachToListViewController:[self listViewControllerForHistoryKey:historyKey]
                                         hidesSearchBar:![[self searchController] isSearchActive]];
    [[self searchController] refreshForListViewController:[self activeListViewController]];
    [[self mainView] setTitleText:[self titleForContentView:contentView]];
}

- (void)markHistoryKeyLoaded:(NSString *)historyKey {
    [[self historyController] markHistoryKeyLoaded:historyKey];
}

- (void)updateActiveTableViewState:(KayokoHistoryListView *)tableView {
    if ([self isAuthorizationRequired]) {
        return;
    }

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

- (nullable NSString *)historyKeyForInitialViewMode {
    switch ([self initialViewMode]) {
    case kKayokoInitialViewModeFavorites:
        return kKayokoHistoryKeyFavorites;
    case kKayokoInitialViewModeHistory:
        return kKayokoHistoryKeyHistory;
    case kKayokoInitialViewModePreviousSelection:
        return nil;
    }
    return nil;
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

#pragma mark - Clear Confirmation

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

#pragma mark - Content State

- (void)updateClearButtonState {
    if ([self isAuthorizationRequired]) {
        [[self mainView] setClearButtonEnabledForItemCount:0];
        return;
    }

    if ([self storageError]) {
        [[self mainView] setClearButtonEnabledForItemCount:0];
        return;
    }
    [[self mainView] setClearButtonEnabledForItemCount:[[[self activeListViewController] items] count]];
}

- (void)updateContentState {
    [self updateContentStateMaintainingSearchBarVisibility:YES];
}

- (void)showStorageError:(NSError *)error {
    if (!error) {
        return;
    }

    [self setStorageError:error];
    [[self storageErrorView] updateWithStorageError:error];
    [[self storageErrorView] setKeyboardBottomInset:[[self searchController] keyboardBottomInset]];
    [[self mainView] setClearButtonEnabledForItemCount:0];

    if ([self isHidden]) {
        return;
    }

    UIView *viewToHide = [self activeHistoryContentView];
    UIView *viewToShow = [self storageErrorView];
    if (viewToHide == viewToShow) {
        [[self mainView] setTitleText:[self titleForContentView:viewToShow]];
        return;
    }
    [[self mainView] showContentView:viewToShow
                     hideContentView:viewToHide
                               title:[self titleForContentView:viewToShow]
                           direction:KayokoContentTransitionDirectionForward];
}

#pragma mark - Transient Content

- (BOOL)isPreviewActive {
    return ![[[self previewViewController] previewView] isHidden] || [[self previewViewController] previewItem] != nil;
}

- (BOOL)isWordSelectionActive {
    return ![[[self wordSelectionViewController] view] isHidden] ||
           [[self wordSelectionViewController] sourceItem] != nil;
}

- (UIView *)activeTransientContentViewForEdgeBackGesture {
    UIView *previewView = [[self previewViewController] previewView];
    if (![previewView isHidden] && [[self previewViewController] previewItem]) {
        return previewView;
    }

    UIView *wordSelectionView = [[self wordSelectionViewController] view];
    if (![wordSelectionView isHidden] && [[self wordSelectionViewController] sourceItem]) {
        return wordSelectionView;
    }

    return nil;
}

- (BOOL)canBeginTransientEdgeBackGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)recognizer {
    if ([self isHidden] || [[self mainView] isAnimating] || [[self panelPresentationController] isAnimating]) {
        return NO;
    }

    UIView *sourceView = [self activeSourceContentView];
    UIView *contentView = [self activeTransientContentViewForEdgeBackGesture];
    if (!sourceView || !contentView) {
        return NO;
    }

    CGPoint velocity = [recognizer velocityInView:[self mainView]];
    if (velocity.x <= 0 || fabs(velocity.x) <= fabs(velocity.y) * kKayokoTransientEdgeBackHorizontalDominance) {
        return NO;
    }

    if (contentView == [[self previewViewController] previewView] &&
        ![[[self previewViewController] previewView] canBeginEdgeBackGesture]) {
        return NO;
    }

    return YES;
}

- (CGFloat)progressForTransientEdgeBackGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)recognizer {
    CGFloat width = MAX(CGRectGetWidth([[[self mainView] contentContainerView] bounds]), 1);
    CGFloat progress = [recognizer translationInView:[self mainView]].x / width;
    return MIN(MAX(progress, 0), 1);
}

- (NSTimeInterval)transientEdgeBackAnimationDurationWithProgress:(CGFloat)progress finishing:(BOOL)finishing {
    CGFloat remainingProgress = finishing ? 1 - progress : progress;
    NSTimeInterval duration = kKayokoTransientEdgeBackMaximumAnimationDuration * remainingProgress;
    return MIN(MAX(duration, kKayokoTransientEdgeBackMinimumAnimationDuration),
               kKayokoTransientEdgeBackMaximumAnimationDuration);
}

- (void)resetInteractiveTransientReturnState {
    [self setInteractiveTransientReturnSourceView:nil];
    [self setInteractiveTransientReturnContentView:nil];
    [self setInteractiveTransientReturnWasPreview:NO];
    [self setDidRestoreSearchDuringInteractiveTransientReturn:NO];
}

- (void)clearSearchAfterTransientContentState {
    [self setRestoresSearchFirstResponderAfterTransientContent:NO];
    [self setHasSearchContentOffsetBeforeTransientContent:NO];
}

- (BOOL)restoreSearchAfterTransientContentIfNeededClearingState:(BOOL)clearsState {
    BOOL didRestore = NO;
    if ([[self searchController] isSearchActive]) {
        CGPoint targetContentOffset = [[[self activeListViewController] tableView] contentOffset];
        if ([self hasSearchContentOffsetBeforeTransientContent]) {
            targetContentOffset = [self searchContentOffsetBeforeTransientContent];
        }
        [[self searchController]
            refreshAfterTransientContentForListViewController:[self activeListViewController]
                                       restoresFirstResponder:[self restoresSearchFirstResponderAfterTransientContent]
                                          targetContentOffset:targetContentOffset];
        didRestore = YES;
    }

    if (clearsState) {
        [self clearSearchAfterTransientContentState];
    }
    return didRestore;
}

- (void)beginInteractiveTransientReturnWithGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)recognizer {
    UIView *sourceView = [self activeSourceContentView];
    UIView *contentView = [self activeTransientContentViewForEdgeBackGesture];
    if (!sourceView || !contentView) {
        return;
    }

    [self setInteractiveTransientReturnSourceView:sourceView];
    [self setInteractiveTransientReturnContentView:contentView];
    [self setInteractiveTransientReturnWasPreview:(contentView == [[self previewViewController] previewView])];
    [[self mainView] beginInteractiveBackwardContentTransitionToView:sourceView hideContentView:contentView];
    [[self mainView]
        updateInteractiveBackwardContentTransitionToView:sourceView
                                         hideContentView:contentView
                                                progress:[self
                                                             progressForTransientEdgeBackGestureRecognizer:recognizer]];
    [self setDidRestoreSearchDuringInteractiveTransientReturn:
              [self restoreSearchAfterTransientContentIfNeededClearingState:NO]];
}

- (void)updateInteractiveTransientReturnWithGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)recognizer {
    UIView *sourceView = [self interactiveTransientReturnSourceView];
    UIView *contentView = [self interactiveTransientReturnContentView];
    if (!sourceView || !contentView) {
        return;
    }

    [[self mainView]
        updateInteractiveBackwardContentTransitionToView:sourceView
                                         hideContentView:contentView
                                                progress:[self
                                                             progressForTransientEdgeBackGestureRecognizer:recognizer]];
}

- (void)finishInteractiveTransientReturnWithDuration:(NSTimeInterval)duration {
    UIView *sourceView = [self interactiveTransientReturnSourceView];
    UIView *contentView = [self interactiveTransientReturnContentView];
    if (!sourceView || !contentView) {
        [self resetInteractiveTransientReturnState];
        return;
    }

    BOOL wasPreview = [self interactiveTransientReturnWasPreview];
    if (wasPreview) {
        [[self previewViewController] prepareToHidePreview];
    } else {
        [[self wordSelectionViewController] prepareToHideWordSelection];
    }
    if ([self didRestoreSearchDuringInteractiveTransientReturn]) {
        [self clearSearchAfterTransientContentState];
    } else {
        [self restoreSearchAfterTransientContentIfNeededClearingState:YES];
    }
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];

    [[self mainView] finishInteractiveBackwardContentTransitionToView:sourceView
                                                      hideContentView:contentView
                                                                title:[self titleForContentView:sourceView]
                                                             duration:duration
                                                           completion:^{
                                                             if (wasPreview) {
                                                                 [[self previewViewController] hidePreview];
                                                             } else {
                                                                 [[self wordSelectionViewController] hideWordSelection];
                                                             }
                                                             [self setActiveSourceContentView:nil];
                                                             [self resetInteractiveTransientReturnState];
                                                           }];
}

- (void)cancelInteractiveTransientReturnWithDuration:(NSTimeInterval)duration {
    UIView *sourceView = [self interactiveTransientReturnSourceView];
    UIView *contentView = [self interactiveTransientReturnContentView];
    if (!sourceView || !contentView) {
        [self resetInteractiveTransientReturnState];
        return;
    }

    if ([self didRestoreSearchDuringInteractiveTransientReturn]) {
        [[self searchController] resignSearchFirstResponder];
    }

    [[self mainView] cancelInteractiveBackwardContentTransitionToView:sourceView
                                                      hideContentView:contentView
                                                             duration:duration
                                                           completion:^{
                                                             [self resetInteractiveTransientReturnState];
                                                           }];
}

- (void)finishOrCancelInteractiveTransientReturnWithGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)recognizer {
    if ([recognizer state] == UIGestureRecognizerStateCancelled ||
        [recognizer state] == UIGestureRecognizerStateFailed) {
        CGFloat progress = [self progressForTransientEdgeBackGestureRecognizer:recognizer];
        [self cancelInteractiveTransientReturnWithDuration:[self transientEdgeBackAnimationDurationWithProgress:progress
                                                                                                      finishing:NO]];
        return;
    }

    CGFloat progress = [self progressForTransientEdgeBackGestureRecognizer:recognizer];
    CGPoint velocity = [recognizer velocityInView:[self mainView]];
    BOOL shouldFinish = progress >= kKayokoTransientEdgeBackCompletionProgress ||
                        velocity.x >= kKayokoTransientEdgeBackCompletionVelocity;
    NSTimeInterval duration = [self transientEdgeBackAnimationDurationWithProgress:progress finishing:shouldFinish];
    if (shouldFinish) {
        [self finishInteractiveTransientReturnWithDuration:duration];
    } else {
        [self cancelInteractiveTransientReturnWithDuration:duration];
    }
}

- (void)handleTransientEdgeBackGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)recognizer {
    switch ([recognizer state]) {
    case UIGestureRecognizerStateBegan:
        [self beginInteractiveTransientReturnWithGestureRecognizer:recognizer];
        break;
    case UIGestureRecognizerStateChanged:
        [self updateInteractiveTransientReturnWithGestureRecognizer:recognizer];
        break;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed:
        [self finishOrCancelInteractiveTransientReturnWithGestureRecognizer:recognizer];
        break;
    default:
        break;
    }
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
    [self restoreSearchAfterTransientContentIfNeededClearingState:YES];
}

#pragma mark - Header State

- (void)updateFavoritesButtonForHistoryKey:(NSString *)historyKey {
    BOOL showingFavorites = [historyKey isEqualToString:kKayokoHistoryKeyFavorites];
    NSString *imageName = showingFavorites ? @"heart.fill" : @"heart";
    UIColor *tintColor = showingFavorites ? [UIColor systemPinkColor] : [UIColor labelColor];
    [[self mainView] updateStyleForHeaderButton:[[self mainView] favoritesButton]
                                  withImageName:imageName
                                   andImageSize:kKayokoFavoritesButtonImageSize
                                   andTintColor:tintColor];
}

- (nullable UIImage *)authorizationHeaderIconImage {
    UIImage *bundleIcon = [UIImage imageNamed:@"Icon"
                                     inBundle:[KayokoPasteboardManager localizationBundle]
                compatibleWithTraitCollection:nil];
    if (bundleIcon) {
        return [bundleIcon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }

    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:kKayokoFavoritesButtonImageSize
                                                        weight:UIImageSymbolWeightMedium];
    return [[UIImage systemImageNamed:@"keyboard"] imageWithConfiguration:configuration];
}

- (void)showAuthorizationRequiredHeaderIcon {
    UIButton *favoritesButton = [[self mainView] favoritesButton];
    UIImage *icon = [self authorizationHeaderIconImage];
    [favoritesButton setHidden:NO];
    [favoritesButton setEnabled:YES];
    [favoritesButton setUserInteractionEnabled:NO];
    [favoritesButton setTintColor:[UIColor labelColor]];
    [favoritesButton setImage:icon forState:UIControlStateNormal];
    [[[favoritesButton imageView] layer] setCornerRadius:6];
    [[favoritesButton imageView] setClipsToBounds:YES];
}

- (void)restoreHistoryHeaderIconForHistoryKey:(NSString *)historyKey {
    UIButton *favoritesButton = [[self mainView] favoritesButton];
    [favoritesButton setHidden:NO];
    [favoritesButton setEnabled:YES];
    [favoritesButton setUserInteractionEnabled:YES];
    [[[favoritesButton imageView] layer] setCornerRadius:0];
    [[favoritesButton imageView] setClipsToBounds:NO];
    [self updateFavoritesButtonForHistoryKey:historyKey];
}

#pragma mark - Content Presentation

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
    if ([self isAuthorizationRequired]) {
        [self setHistoryContentVisibleForKey:[self effectiveActiveHistoryKey]];
        return;
    }

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

#pragma mark - Actions

- (void)handleFavoritesButtonPressed {
    if ([[self panelPresentationController] isAnimating]) {
        return;
    }

    if ([self isAuthorizationRequired]) {
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
        return;
    }

    if (![[[self previewViewController] previewView] isHidden]) {
        [[self previewViewController] handleActionButtonWithCompletion:^(BOOL success) {
          if (success) {
              [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
              [self hideAfterDirectPaste];
          }
        }];
    }
}

- (void)handleClearButtonPressed {
    if ([[self panelPresentationController] isAnimating] || ![[[self previewViewController] previewView] isHidden] ||
        ![[[self wordSelectionViewController] view] isHidden] || [self isShowingClearConfirmation] ||
        [self isAuthorizationRequired]) {
        return;
    }

    [self showClearConfirmationForHistoryKey:[self effectiveActiveHistoryKey]];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)handleTitleTapControlPressed {
    if ([[self panelPresentationController] isAnimating] || [[self mainView] isAnimating]) {
        return;
    }

    if ([self isAuthorizationRequired]) {
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

#pragma mark - Item Handling

- (void)handlePasteboardItemDictionary:(NSDictionary<NSString *, id> *)dictionary
                   movedFromHistoryKey:(NSString *)sourceHistoryKey
                          toHistoryKey:(NSString *)destinationHistoryKey {
    [[self historyController] handlePasteboardItemDictionary:dictionary
                                         movedFromHistoryKey:sourceHistoryKey
                                                toHistoryKey:destinationHistoryKey];
}

- (void)handleTagAssignmentForItem:(KayokoPasteboardItem *)item historyKey:(NSString *)historyKey {
    if (!item || [historyKey length] == 0) {
        return;
    }
    [[self listViewControllerForHistoryKey:historyKey] updateTagUUID:[item tagUUID] forItem:item];
}

#pragma mark - Transient Presentation

- (void)showContentForItem:(KayokoPasteboardItem *)item {
    BOOL restoresSearchFirstResponder = [[self searchController] isActiveSearchFirstResponder];
    [self setRestoresSearchFirstResponderAfterTransientContent:restoresSearchFirstResponder];
    if (restoresSearchFirstResponder) {
        [self setSearchContentOffsetBeforeTransientContent:[[[self activeListViewController] tableView] contentOffset]];
        [self setHasSearchContentOffsetBeforeTransientContent:YES];
    } else {
        [self setHasSearchContentOffsetBeforeTransientContent:NO];
    }
    [[self searchController] resignSearchFirstResponder];
    NSString *historyKey = [self effectiveActiveHistoryKey];
    KayokoHistoryListView *sourceTableView = [self tableViewForHistoryKey:historyKey];
    [self setActiveSourceContentView:sourceTableView];
    NSString *previewText =
        [([item content] ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
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

    [[self mainView] showContentView:sourceView
        hideContentView:previewView
        title:[self titleForContentView:sourceView]
        direction:KayokoContentTransitionDirectionBackward
        willAnimate:^{
          [self refreshSearchAfterEndingTransientContentIfNeeded];
        }
        completion:^{
          [[self previewViewController] hidePreview];
          [self setActiveSourceContentView:nil];
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

    [[self mainView] showContentView:sourceView
        hideContentView:wordSelectionView
        title:[self titleForContentView:sourceView]
        direction:KayokoContentTransitionDirectionBackward
        willAnimate:^{
          [self refreshSearchAfterEndingTransientContentIfNeeded];
        }
        completion:^{
          [[self wordSelectionViewController] hideWordSelection];
          [self setActiveSourceContentView:nil];
        }];
}

#pragma mark - KayokoClearConfirmationViewControllerDelegate

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

#pragma mark - KayokoWordSelectionViewControllerDelegate

- (void)wordSelectionViewController:(KayokoWordSelectionViewController *)controller
    didRequestHideContainerAfterDirectPaste:(BOOL)directPaste {
    if (directPaste) {
        [self hideAfterDirectPaste];
    } else {
        [self hideRestoringFocus];
    }
}

- (void)wordSelectionViewController:(KayokoWordSelectionViewController *)controller
     triggerHapticFeedbackWithStyle:(UIImpactFeedbackStyle)style {
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:style];
}

#pragma mark - Authorization

- (void)openAuthorizationSettings {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      NSURL *URL = [NSURL URLWithString:@"prefs:root=Kayoko"];
      Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
      if (!URL || ![workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
          NSLog(@"Kayoko: LSApplicationWorkspace is unavailable for opening Settings");
          return;
      }

      LSApplicationWorkspace *workspace = [workspaceClass defaultWorkspace];
      if (![workspace respondsToSelector:@selector(openSensitiveURL:withOptions:error:)]) {
          NSLog(@"Kayoko: LSApplicationWorkspace cannot open sensitive URLs");
          return;
      }

      NSError *error = nil;
      if (![workspace openSensitiveURL:URL withOptions:@{} error:&error]) {
          NSLog(@"Kayoko: Failed to open Kayoko Settings: %@", error);
      }
    });
}

#pragma mark - Public API

- (void)reload {
    if ([self isAuthorizationRequired]) {
        [self setHistoryContentVisibleForKey:[self effectiveActiveHistoryKey]];
        return;
    }

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
    if (![self isHidden]) {
        return;
    }

    [self setDismissingPanel:NO];
    [self setPreparingToShow:YES];
    [[KayokoTagCatalog sharedCatalog] reloadTags];
    NSUInteger showRequestIdentifier = [self showRequestIdentifier] + 1;
    [self setShowRequestIdentifier:showRequestIdentifier];
    [self resetClearConfirmationIfNeeded];

    [[self historyListViewController] setAutomaticallyPaste:[self automaticallyPaste]];
    [[self favoritesListViewController] setAutomaticallyPaste:[self automaticallyPaste]];

    NSString *initialHistoryKey = [self historyKeyForInitialViewMode];
    if ([initialHistoryKey length] > 0) {
        [[self historyController] setActiveHistoryKey:initialHistoryKey];
    }

    if ([self isAuthorizationRequired]) {
        [self setPreparingToShow:NO];
        [self setHistoryContentVisibleForKey:[self effectiveActiveHistoryKey]];
        [[self panelPresentationController] showPanelWithCompletion:nil];
        return;
    }

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

#pragma mark - Hiding

- (void)hide {
    [self hideWithCompletion:nil];
}

- (void)hideAfterDirectPaste {
    BOOL shouldRestoreFocusAfterHide = [self isFullscreenSearchActive];
    [self hideWithCompletion:^{
      if (!shouldRestoreFocusAfterHide || ![self focusRestoreRequestHandler]) {
          return;
      }
      [self focusRestoreRequestHandler]();
    }];
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
