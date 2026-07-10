//
//  KayokoSearchPresentationController.m
//  Kayoko
//

#import "KayokoSearchPresentationController.h"

#import "KayokoHeaderView.h"
#import "KayokoHistoryListView.h"
#import "KayokoMainView.h"
#import "KayokoSearchBar.h"

static CGFloat const kKayokoSearchHeaderHeight = 56;
static CGFloat const kKayokoSearchBarHorizontalInset = 16;
static NSTimeInterval const kKayokoSearchFullscreenAnimationDuration = 0.42;
static CGFloat const kKayokoSearchFullscreenAnimationDamping = 0.86;
static CGFloat const kKayokoSearchFullscreenGrabberFoldDistance = 20;
static CGFloat const kKayokoSearchFullscreenCollapseVelocity = 900;
static CGFloat const kKayokoSearchFullscreenReboundVelocity = -450;
static CGFloat const kKayokoSearchFullscreenCollapseProgress = 0.32;
static NSTimeInterval const kKayokoSearchCompactLandscapeTitleRowAnimationDuration = 0.24;

static CGRect kayokoStatusBarFrameForWindow(UIWindow *window) {
    CGRect statusBarFrame = CGRectZero;
    UIWindowScene *windowScene = [window windowScene];
    if (windowScene) {
        statusBarFrame = [[windowScene statusBarManager] statusBarFrame];
    }

    if (CGRectIsEmpty(statusBarFrame)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
#pragma clang diagnostic pop
    }

    return statusBarFrame;
}

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchPresentationController ()

#pragma mark - Views

@property(nonatomic, weak) UIView *containerView;
@property(nonatomic, weak) KayokoHeaderView *headerView;

#pragma mark - Search Bars

@property(nonatomic, weak) UISearchBar *historySearchBar;
@property(nonatomic, weak) UISearchBar *favoritesSearchBar;
@property(nonatomic, weak) UIView *historySearchTokenView;
@property(nonatomic, weak) UIView *favoritesSearchTokenView;
@property(nonatomic, strong) UIView *historySearchHeaderView;
@property(nonatomic, strong) UIView *favoritesSearchHeaderView;

#pragma mark - Lists

@property(nonatomic, weak) KayokoHistoryListView *historyTableView;
@property(nonatomic, weak) KayokoHistoryListView *favoritesTableView;

#pragma mark - Gestures

@property(nonatomic, weak) UIPanGestureRecognizer *panGestureRecognizer;

#pragma mark - State

@property(nonatomic, assign, getter=isSearchActive) BOOL searchActive;
@property(nonatomic, assign) CGRect normalFrameBeforeSearch;
@property(nonatomic, assign) BOOL hasNormalFrameBeforeSearch;
@property(nonatomic, weak, nullable) KayokoHeaderView *fullscreenPanHeaderView;

#pragma mark - Keyboard

@property(nonatomic, assign, readwrite) CGFloat keyboardBottomInset;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSearchPresentationController

#pragma mark - Lifecycle

- (instancetype)initWithContainerView:(UIView *)containerView
                           headerView:(KayokoHeaderView *)headerView
                     historySearchBar:(UISearchBar *)historySearchBar
                   favoritesSearchBar:(UISearchBar *)favoritesSearchBar
               historySearchTokenView:(UIView *)historySearchTokenView
             favoritesSearchTokenView:(UIView *)favoritesSearchTokenView
                     historyTableView:(KayokoHistoryListView *)historyTableView
                   favoritesTableView:(KayokoHistoryListView *)favoritesTableView
                 panGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer {
    self = [super init];
    if (self) {
        _presentationMode = KayokoPanelPresentationModePortraitDrawer;
        _containerView = containerView;
        _headerView = headerView;
        _historySearchBar = historySearchBar;
        _favoritesSearchBar = favoritesSearchBar;
        _historySearchTokenView = historySearchTokenView;
        _favoritesSearchTokenView = favoritesSearchTokenView;
        _historyTableView = historyTableView;
        _favoritesTableView = favoritesTableView;
        _panGestureRecognizer = panGestureRecognizer;
        [self installSearchBarForTableView:historyTableView];
        [self installSearchBarForTableView:favoritesTableView];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardWillChangeFrameNotification:)
                                                     name:UIKeyboardWillChangeFrameNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardWillHideNotification:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Layout

- (CGFloat)searchHeaderHeight {
    return kKayokoSearchHeaderHeight;
}

- (void)layout {
    [self layoutSearchBarForTableView:[self historyTableView]];
    [self layoutSearchBarForTableView:[self favoritesTableView]];
    [self applyBottomInsetsToTableViews];
}

- (void)updateSearchTokenViews {
    [self layout];
}

- (void)layoutSearchBarForTableView:(KayokoHistoryListView *)tableView {
    [tableView updateNoSearchResultsPlaceholderLayout];
    [tableView setSearchBarSnapHeight:kKayokoSearchHeaderHeight];

    UISearchBar *searchBar = [self searchBarForTableView:tableView];
    UIView *headerView = [self searchHeaderViewForTableView:tableView];
    if ([tableView tableHeaderView] != headerView) {
        return;
    }

    CGFloat width = CGRectGetWidth([tableView bounds]);
    UIView *tokenView = [self searchTokenViewForTableView:tableView];
    CGFloat tokenHeight = (tokenView && ![tokenView isHidden]) ? CGRectGetHeight([tokenView frame]) : 0;
    CGFloat headerHeight = kKayokoSearchHeaderHeight + tokenHeight;
    CGRect headerFrame = CGRectMake(0, 0, width, headerHeight);
    CGRect searchBarFrame = CGRectMake(0, 0, width, kKayokoSearchHeaderHeight);
    CGRect tokenFrame = CGRectMake(0, kKayokoSearchHeaderHeight, width, tokenHeight);

    BOOL needsTableHeaderUpdate = !CGRectEqualToRect([headerView frame], headerFrame);
    [headerView setFrame:headerFrame];
    [searchBar setFrame:searchBarFrame];
    [tokenView setFrame:tokenFrame];
    if (needsTableHeaderUpdate) {
        [tableView setTableHeaderView:headerView];
    }
}

#pragma mark - Search Header Views

- (UISearchBar *)searchBarForTableView:(KayokoHistoryListView *)tableView {
    return tableView == [self favoritesTableView] ? [self favoritesSearchBar] : [self historySearchBar];
}

- (UIView *)searchTokenViewForTableView:(KayokoHistoryListView *)tableView {
    return tableView == [self favoritesTableView] ? [self favoritesSearchTokenView] : [self historySearchTokenView];
}

- (UIView *)searchHeaderViewForTableView:(KayokoHistoryListView *)tableView {
    return tableView == [self favoritesTableView] ? [self favoritesSearchHeaderView] : [self historySearchHeaderView];
}

- (void)setSearchHeaderView:(UIView *)headerView forTableView:(KayokoHistoryListView *)tableView {
    if (tableView == [self favoritesTableView]) {
        [self setFavoritesSearchHeaderView:headerView];
    } else {
        [self setHistorySearchHeaderView:headerView];
    }
}

- (void)installSearchBarForTableView:(KayokoHistoryListView *)tableView {
    if (!tableView) {
        return;
    }

    UISearchBar *searchBar = [self searchBarForTableView:tableView];
    UIView *headerView = [self searchHeaderViewForTableView:tableView];
    UIView *tokenView = [self searchTokenViewForTableView:tableView];

    if ([searchBar respondsToSelector:@selector(setKayokoHorizontalFrameInset:)]) {
        [(KayokoSearchBar *)searchBar setKayokoHorizontalFrameInset:kKayokoSearchBarHorizontalInset];
    }

    if (!headerView) {
        headerView = [[UIView alloc] initWithFrame:CGRectZero];
        [headerView setBackgroundColor:[UIColor clearColor]];
        [headerView setClipsToBounds:YES];
        [self setSearchHeaderView:headerView forTableView:tableView];
    }
    if ([searchBar superview] != headerView) {
        [searchBar removeFromSuperview];
        [headerView addSubview:searchBar];
    }
    if (tokenView && [tokenView superview] != headerView) {
        [tokenView removeFromSuperview];
        [headerView addSubview:tokenView];
    }
    if ([tableView tableHeaderView] != headerView) {
        [tableView setTableHeaderView:headerView];
    }
    [self layoutSearchBarForTableView:tableView];
}

#pragma mark - Search Bar Visibility

- (void)setContentOffset:(CGPoint)contentOffset
            forTableView:(KayokoHistoryListView *)tableView
                animated:(BOOL)animated {
    if (!animated) {
        [tableView setContentOffset:contentOffset animated:NO];
        return;
    }

    if ([UIView inheritedAnimationDuration] > 0) {
        [tableView setContentOffset:contentOffset];
    } else {
        [tableView setContentOffset:contentOffset animated:YES];
    }
}

- (CGFloat)hiddenSearchHeaderOffsetForTableView:(KayokoHistoryListView *)tableView {
    UIView *headerView = [self searchHeaderViewForTableView:tableView];
    if ([tableView tableHeaderView] == headerView) {
        return CGRectGetHeight([headerView frame]);
    }

    return [self searchHeaderHeight];
}

- (void)attachToTableView:(KayokoHistoryListView *)tableView hidesSearchBar:(BOOL)hidesSearchBar {
    [self installSearchBarForTableView:[self historyTableView]];
    [self installSearchBarForTableView:[self favoritesTableView]];
    [self layout];

    if (!tableView) {
        return;
    }

    if (hidesSearchBar && ![self isSearchActive]) {
        [self hideSearchBarInTableView:tableView animated:NO];
    } else if ([self isSearchActive]) {
        [self revealSearchBarInTableView:tableView animated:NO];
    }
}

- (void)hideSearchBarInTableView:(KayokoHistoryListView *)tableView animated:(BOOL)animated {
    UIView *headerView = [self searchHeaderViewForTableView:tableView];
    if (!tableView || [tableView tableHeaderView] != headerView || [self isSearchActive]) {
        return;
    }

    [self applyBottomInsetToTableView:tableView];

    CGPoint contentOffset = [tableView contentOffset];
    contentOffset.y = [self hiddenSearchHeaderOffsetForTableView:tableView];
    [self setContentOffset:contentOffset forTableView:tableView animated:animated];
}

- (void)revealSearchBarInTableView:(KayokoHistoryListView *)tableView animated:(BOOL)animated {
    UIView *headerView = [self searchHeaderViewForTableView:tableView];
    if (!tableView || [tableView tableHeaderView] != headerView) {
        return;
    }

    [self applyBottomInsetToTableView:tableView];

    CGPoint contentOffset = [tableView contentOffset];
    contentOffset.y = 0;
    [self setContentOffset:contentOffset forTableView:tableView animated:animated];
}

#pragma mark - Fullscreen Geometry

- (UIEdgeInsets)contentSafeAreaAdditionalInsetsForFullscreenSuperview:(UIView *)superview {
    UIView *containerView = [self containerView];
    UIEdgeInsets safeAreaInsets = [superview safeAreaInsets];
    UIEdgeInsets additionalInsets = UIEdgeInsetsZero;
    if (safeAreaInsets.top > 0) {
        return additionalInsets;
    }

    CGRect statusBarFrame = kayokoStatusBarFrameForWindow([containerView window]);
    if (CGRectIsEmpty(statusBarFrame)) {
        return additionalInsets;
    }

    CGRect statusBarFrameInSuperview = [superview convertRect:statusBarFrame fromView:nil];
    CGFloat statusBarBottom = CGRectGetMaxY(statusBarFrameInSuperview) - CGRectGetMinY([superview bounds]);
    additionalInsets.top = ceil(MAX(statusBarBottom, 0));
    return additionalInsets;
}

- (void)setGrabberFoldProgress:(CGFloat)progress headerView:(nullable KayokoHeaderView *)headerView {
    [(headerView ?: [self headerView]) setGrabberFoldProgress:progress];
}

- (void)setGrabberFoldProgress:(CGFloat)progress {
    [self setGrabberFoldProgress:progress headerView:nil];
}

- (void)resetGrabberFoldState {
    KayokoHeaderView *fullscreenPanHeaderView = [self fullscreenPanHeaderView];
    [self setGrabberFoldProgress:0];
    if (fullscreenPanHeaderView && fullscreenPanHeaderView != [self headerView]) {
        [self setGrabberFoldProgress:0 headerView:fullscreenPanHeaderView];
    }
    [self setFullscreenPanHeaderView:nil];
}

- (CGRect)fullscreenFrame {
    UIView *superview = [[self containerView] superview];
    return superview ? [superview bounds] : [[self containerView] frame];
}

- (CGRect)collapsedFrame {
    return [self hasNormalFrameBeforeSearch] ? [self normalFrameBeforeSearch] : [[self containerView] frame];
}

- (CGRect)frameFromFullscreenFrame:(CGRect)fullscreenFrame
                    collapsedFrame:(CGRect)collapsedFrame
                          progress:(CGFloat)progress {
    progress = MIN(MAX(progress, 0), 1);
    return CGRectMake(fullscreenFrame.origin.x + (collapsedFrame.origin.x - fullscreenFrame.origin.x) * progress,
                      fullscreenFrame.origin.y + (collapsedFrame.origin.y - fullscreenFrame.origin.y) * progress,
                      fullscreenFrame.size.width + (collapsedFrame.size.width - fullscreenFrame.size.width) * progress,
                      fullscreenFrame.size.height +
                          (collapsedFrame.size.height - fullscreenFrame.size.height) * progress);
}

- (CGFloat)fullscreenCollapseProgressForTranslation:(CGFloat)translationY {
    CGRect fullscreenFrame = [self fullscreenFrame];
    CGRect collapsedFrame = [self collapsedFrame];
    CGFloat collapseDistance = CGRectGetMinY(collapsedFrame) - CGRectGetMinY(fullscreenFrame);
    if (collapseDistance <= 0) {
        return 0;
    }

    return MIN(MAX(translationY / collapseDistance, 0), 1);
}

- (NSTimeInterval)fullscreenPanAnimationDurationToFrame:(CGRect)targetFrame velocityY:(CGFloat)velocityY {
    CGFloat distance = fabs(CGRectGetMinY(targetFrame) - CGRectGetMinY([[self containerView] frame]));
    if (distance <= 1) {
        return 0.12;
    }

    CGFloat effectiveVelocity = MAX(fabs(velocityY), kKayokoSearchFullscreenCollapseVelocity);
    return MIN(MAX(distance / effectiveVelocity, 0.12), kKayokoSearchFullscreenAnimationDuration);
}

#pragma mark - Search Presentation

- (void)beginSearchWithActiveTableView:(KayokoHistoryListView *)activeTableView completion:(void (^)(void))completion {
    if ([self isSearchActive]) {
        return;
    }

    [self setSearchActive:YES];
    [self setNormalFrameBeforeSearch:[[self containerView] frame]];
    [self setHasNormalFrameBeforeSearch:YES];

    if ([self presentationMode] == KayokoPanelPresentationModeCompactLandscapeFullscreen) {
        UIView *containerView = [self containerView];
        [containerView layoutIfNeeded];
        [activeTableView layoutIfNeeded];
        if ([containerView isKindOfClass:[KayokoMainView class]]) {
            [(KayokoMainView *)containerView setSearchTitleRowCollapsed:YES];
        }
        [UIView animateWithDuration:kKayokoSearchCompactLandscapeTitleRowAnimationDuration
            delay:0
            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction |
                    UIViewAnimationOptionCurveEaseInOut
            animations:^{
              [self revealSearchBarInTableView:activeTableView animated:YES];
              [containerView layoutIfNeeded];
              [activeTableView layoutIfNeeded];
            }
            completion:^(__unused BOOL finished) {
              if (completion) {
                  completion();
              }
            }];
        return;
    }

    [self revealSearchBarInTableView:activeTableView animated:YES];

    [self setGrabberFoldProgress:1];

    UIView *superview = [[self containerView] superview];
    if (!superview) {
        if (completion) {
            completion();
        }
        return;
    }

    UIView *containerView = [self containerView];
    [containerView layoutIfNeeded];
    if ([containerView isKindOfClass:[KayokoMainView class]]) {
        KayokoMainView *mainView = (KayokoMainView *)containerView;
        [mainView
            setContentSafeAreaAdditionalInsets:[self contentSafeAreaAdditionalInsetsForFullscreenSuperview:superview]];
        [mainView setContentRespectsSafeArea:YES];
    }

    CGRect fullscreenBounds = [superview bounds];
    [UIView animateWithDuration:kKayokoSearchFullscreenAnimationDuration
        delay:0
        usingSpringWithDamping:kKayokoSearchFullscreenAnimationDamping
        initialSpringVelocity:0
        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
        animations:^{
          [containerView setTransform:CGAffineTransformIdentity];
          [containerView setFrame:fullscreenBounds];
          [containerView setNeedsLayout];
          [containerView layoutIfNeeded];
        }
        completion:^(__unused BOOL finished) {
          if (completion) {
              completion();
          }
        }];
}

- (void)endSearchRestoringFrame:(BOOL)restoresFrame
                activeTableView:(KayokoHistoryListView *)activeTableView
                     completion:(void (^)(void))completion {
    [self endSearchRestoringFrame:restoresFrame activeTableView:activeTableView animations:nil completion:completion];
}

- (void)endSearchRestoringFrame:(BOOL)restoresFrame
                activeTableView:(KayokoHistoryListView *)activeTableView
                     animations:(void (^)(void))animations
                     completion:(void (^)(void))completion {
    [self endSearchRestoringFrame:restoresFrame
                  activeTableView:activeTableView
                       animations:animations
                     panVelocityY:0
                       completion:completion];
}

- (void)endSearchRestoringFrame:(BOOL)restoresFrame
                activeTableView:(KayokoHistoryListView *)activeTableView
                     animations:(void (^)(void))animations
                   panVelocityY:(CGFloat)panVelocityY
                     completion:(void (^)(void))completion {
    [self setSearchActive:NO];
    [self resetKeyboardInsets];

    CGRect targetFrame =
        [self hasNormalFrameBeforeSearch] ? [self normalFrameBeforeSearch] : [[self containerView] frame];
    [self setHasNormalFrameBeforeSearch:NO];

    UIView *containerView = [self containerView];
    [containerView layoutIfNeeded];
    if ([containerView isKindOfClass:[KayokoMainView class]]) {
        KayokoMainView *mainView = (KayokoMainView *)containerView;
        BOOL keepsFullscreenSafeArea = [self presentationMode] == KayokoPanelPresentationModeCompactLandscapeFullscreen;
        if (!keepsFullscreenSafeArea) {
            [self resetGrabberFoldState];
            [mainView setContentRespectsSafeArea:NO];
            [mainView setContentSafeAreaAdditionalInsets:UIEdgeInsetsZero];
        }
    }

    if ([self presentationMode] == KayokoPanelPresentationModeCompactLandscapeFullscreen) {
        [containerView layoutIfNeeded];
        [activeTableView layoutIfNeeded];
        if ([containerView isKindOfClass:[KayokoMainView class]]) {
            [(KayokoMainView *)containerView setSearchTitleRowCollapsed:NO];
        }
        [self setHasNormalFrameBeforeSearch:NO];
        [UIView animateWithDuration:kKayokoSearchCompactLandscapeTitleRowAnimationDuration
            delay:0
            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction |
                    UIViewAnimationOptionCurveEaseInOut
            animations:^{
              [self hideSearchBarInTableView:activeTableView animated:YES];
              if (animations) {
                  animations();
              }
              [containerView layoutIfNeeded];
              [activeTableView layoutIfNeeded];
            }
            completion:^(__unused BOOL finished) {
              if (completion) {
                  completion();
              }
            }];
        return;
    }

    if (restoresFrame && !CGRectEqualToRect([[self containerView] frame], targetFrame)) {
        NSTimeInterval duration = panVelocityY == 0
                                      ? kKayokoSearchFullscreenAnimationDuration
                                      : [self fullscreenPanAnimationDurationToFrame:targetFrame velocityY:panVelocityY];
        CGFloat initialSpringVelocity = 0;
        CGFloat remainingDistance = fabs(CGRectGetMinY(targetFrame) - CGRectGetMinY([containerView frame]));
        if (panVelocityY != 0 && remainingDistance > 1) {
            initialSpringVelocity = fabs(panVelocityY) / remainingDistance;
        }

        [UIView animateWithDuration:duration
            delay:0
            usingSpringWithDamping:kKayokoSearchFullscreenAnimationDamping
            initialSpringVelocity:initialSpringVelocity
            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
            animations:^{
              [containerView setFrame:targetFrame];
              [containerView setNeedsLayout];
              [containerView layoutIfNeeded];
              [self hideSearchBarInTableView:activeTableView animated:NO];
              if (animations) {
                  animations();
              }
            }
            completion:^(__unused BOOL finished) {
              if (completion) {
                  completion();
              }
            }];
    } else {
        [containerView setFrame:targetFrame];
        [containerView setNeedsLayout];
        [containerView layoutIfNeeded];
        [self hideSearchBarInTableView:activeTableView animated:NO];
        [self resetGrabberFoldState];
        if (animations) {
            animations();
        }
        if (completion) {
            completion();
        }
    }
}

#pragma mark - Fullscreen Pan

- (void)handleFullscreenPanGestureRecognizer:(UIPanGestureRecognizer *)recognizer
                             activeTableView:(KayokoHistoryListView *)activeTableView
                                  headerView:(nullable KayokoHeaderView *)headerView {
    if (![self isSearchActive]) {
        return;
    }

    BOOL beganInHeaderView = headerView != nil;
    KayokoHeaderView *grabberHeaderView = headerView ?: [self headerView];
    [self setFullscreenPanHeaderView:grabberHeaderView];
    UIView *trackingView = [[self containerView] superview] ?: [self containerView];
    CGPoint translation = [recognizer translationInView:trackingView];
    CGFloat progress = [self fullscreenCollapseProgressForTranslation:translation.y];
    CGFloat grabberFoldProgress = 1 - MIN(MAX(translation.y / kKayokoSearchFullscreenGrabberFoldDistance, 0), 1);

    if ([recognizer state] == UIGestureRecognizerStateBegan || [recognizer state] == UIGestureRecognizerStateChanged) {
        CGRect fullscreenFrame = [self fullscreenFrame];
        CGRect collapsedFrame = [self collapsedFrame];
        CGRect frame = [self frameFromFullscreenFrame:fullscreenFrame collapsedFrame:collapsedFrame progress:progress];
        UIView *containerView = [self containerView];
        [containerView setTransform:CGAffineTransformIdentity];
        [containerView setFrame:frame];
        [containerView setNeedsLayout];
        [containerView layoutIfNeeded];
        [self setGrabberFoldProgress:grabberFoldProgress headerView:grabberHeaderView];
        return;
    }

    if ([recognizer state] != UIGestureRecognizerStateEnded) {
        UIView *containerView = [self containerView];
        CGRect fullscreenFrame = [self fullscreenFrame];
        [UIView animateWithDuration:kKayokoSearchFullscreenAnimationDuration
                              delay:0
             usingSpringWithDamping:kKayokoSearchFullscreenAnimationDamping
              initialSpringVelocity:0
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                           [containerView setFrame:fullscreenFrame];
                           [containerView setNeedsLayout];
                           [containerView layoutIfNeeded];
                           [self setGrabberFoldProgress:1 headerView:grabberHeaderView];
                         }
                         completion:^(__unused BOOL finished) {
                           if ([self fullscreenPanHeaderView] == grabberHeaderView) {
                               [self setFullscreenPanHeaderView:nil];
                           }
                         }];
        return;
    }

    CGPoint velocity = [recognizer velocityInView:trackingView];
    BOOL shouldCollapse =
        translation.y > 0 && ((beganInHeaderView && velocity.y >= kKayokoSearchFullscreenCollapseVelocity) ||
                              progress >= kKayokoSearchFullscreenCollapseProgress);
    if (velocity.y <= kKayokoSearchFullscreenReboundVelocity) {
        shouldCollapse = NO;
    }

    if (shouldCollapse) {
        [[self delegate] searchPresentationController:self didRequestCollapseFromFullscreenPanWithVelocity:velocity.y];
        return;
    }

    UIView *containerView = [self containerView];
    CGRect fullscreenFrame = [self fullscreenFrame];
    NSTimeInterval duration = [self fullscreenPanAnimationDurationToFrame:fullscreenFrame velocityY:velocity.y];
    [UIView animateWithDuration:duration
                          delay:0
         usingSpringWithDamping:kKayokoSearchFullscreenAnimationDamping
          initialSpringVelocity:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                       [containerView setFrame:fullscreenFrame];
                       [containerView setNeedsLayout];
                       [containerView layoutIfNeeded];
                       [self setGrabberFoldProgress:1 headerView:grabberHeaderView];
                     }
                     completion:^(__unused BOOL finished) {
                       if ([self fullscreenPanHeaderView] == grabberHeaderView) {
                           [self setFullscreenPanHeaderView:nil];
                       }
                     }];
}

#pragma mark - Bottom Insets

- (CGFloat)hiddenSearchBottomInsetForTableView:(KayokoHistoryListView *)tableView {
    if ([self isSearchActive]) {
        return 0;
    }

    return [tableView minimumBottomInsetForMaintainingHiddenHeaderWithAdditionalContentHeightReduction:0];
}

- (CGFloat)safeAreaBottomInsetForTableView:(KayokoHistoryListView *)tableView {
    UIView *containerView = [self containerView];
    if ([containerView isKindOfClass:[KayokoMainView class]]) {
        return [(KayokoMainView *)containerView safeAreaBottomInsetForContentView:tableView];
    }

    return MAX([tableView safeAreaInsets].bottom, 0);
}

- (void)applyBottomInsetToTableView:(KayokoHistoryListView *)tableView {
    [tableView setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentNever];
    [tableView setKeyboardBottomInset:[self keyboardBottomInset]];
    [tableView updateNoSearchResultsPlaceholderLayout];

    UIEdgeInsets contentInset = [tableView contentInset];
    CGFloat keyboardBottomInset = [self keyboardBottomInset];
    CGFloat hiddenSearchBottomInset = [self hiddenSearchBottomInsetForTableView:tableView];
    CGFloat safeAreaBottomInset = [self safeAreaBottomInsetForTableView:tableView];
    CGFloat obscuredBottomInset = MAX(keyboardBottomInset, safeAreaBottomInset);
    contentInset.bottom = MAX(hiddenSearchBottomInset, obscuredBottomInset);
    [tableView setContentInset:contentInset];

    [tableView setAutomaticallyAdjustsScrollIndicatorInsets:NO];
    UIEdgeInsets indicatorInsets = UIEdgeInsetsMake(0, 0, obscuredBottomInset, 0);
    [tableView setVerticalScrollIndicatorInsets:indicatorInsets];
}

- (void)applyBottomInsetsToTableViews {
    [self applyBottomInsetToTableView:[self historyTableView]];
    [self applyBottomInsetToTableView:[self favoritesTableView]];
}

#pragma mark - Keyboard Notifications

- (void)setKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    keyboardBottomInset = MAX(keyboardBottomInset, 0);
    if (_keyboardBottomInset == keyboardBottomInset) {
        return;
    }

    _keyboardBottomInset = keyboardBottomInset;
    [[self delegate] searchPresentationController:self didUpdateKeyboardBottomInset:keyboardBottomInset];
}

- (void)resetKeyboardInsets {
    [self setKeyboardBottomInset:0];
    [self applyBottomInsetsToTableViews];
}

- (void)resetAfterSearchStateClearedWithActiveTableView:(KayokoHistoryListView *)activeTableView {
    [self resetAfterSearchStateClearedWithActiveTableView:activeTableView restoresContainerFrame:YES];
}

- (CGRect)resetAfterSearchStateClearedWithActiveTableView:(KayokoHistoryListView *)activeTableView
                                   restoresContainerFrame:(BOOL)restoresContainerFrame {
    [self setSearchActive:NO];
    [self resetKeyboardInsets];

    UIView *containerView = [self containerView];
    CGRect targetFrame = [self hasNormalFrameBeforeSearch] ? [self normalFrameBeforeSearch] : [containerView frame];
    [self setHasNormalFrameBeforeSearch:NO];
    if (restoresContainerFrame) {
        [containerView setFrame:targetFrame];
    }
    [containerView setNeedsLayout];

    if ([containerView isKindOfClass:[KayokoMainView class]]) {
        KayokoMainView *mainView = (KayokoMainView *)containerView;
        BOOL keepsFullscreenSafeArea = [self presentationMode] == KayokoPanelPresentationModeCompactLandscapeFullscreen;
        [mainView setSearchTitleRowCollapsed:NO];
        [self resetGrabberFoldState];
        [mainView setContentSafeAreaAdditionalInsets:UIEdgeInsetsZero];
        if (!keepsFullscreenSafeArea) {
            [mainView setContentRespectsSafeArea:NO];
        }
    }

    [containerView layoutIfNeeded];
    [self hideSearchBarInTableView:activeTableView animated:NO];
    [activeTableView layoutIfNeeded];
    return targetFrame;
}

- (BOOL)shouldHandleSearchKeyboardNotification:(NSNotification *)notification {
    if (![self isSearchActive]) {
        return NO;
    }

    BOOL isLocal = [notification.userInfo[UIKeyboardIsLocalUserInfoKey] boolValue];
    if (!isLocal) {
        return NO;
    }

    return YES;
}

- (void)updateKeyboardBottomInset:(CGFloat)keyboardBottomInset
          withAnimationParametersFromNotification:(NSNotification *)notification {
    keyboardBottomInset = MAX(keyboardBottomInset, 0);
    if (fabs([self keyboardBottomInset] - keyboardBottomInset) <= 0.5) {
        return;
    }

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve =
        (UIViewAnimationCurve)[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    UIViewAnimationOptions options = (UIViewAnimationOptions)(curve << 16) |
                                     UIViewAnimationOptionBeginFromCurrentState |
                                     UIViewAnimationOptionAllowUserInteraction;
    void (^updates)(void) = ^{
      [self setKeyboardBottomInset:keyboardBottomInset];
      [self applyBottomInsetsToTableViews];
      [[self containerView] layoutIfNeeded];
    };

    if (duration <= 0) {
        updates();
        return;
    }

    [[self containerView] layoutIfNeeded];
    [UIView animateWithDuration:duration delay:0 options:options animations:updates completion:nil];
}

- (void)handleKeyboardWillChangeFrameNotification:(NSNotification *)notification {
    if (![self shouldHandleSearchKeyboardNotification:notification]) {
        return;
    }

    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameInView = [[self containerView] convertRect:keyboardEndFrame fromView:nil];
    CGFloat keyboardBottomInset =
        MAX(CGRectGetMaxY([[self containerView] bounds]) - CGRectGetMinY(keyboardFrameInView), 0);
    [self updateKeyboardBottomInset:keyboardBottomInset withAnimationParametersFromNotification:notification];
}

- (void)handleKeyboardWillHideNotification:(NSNotification *)notification {
    if (![self isSearchActive]) {
        return;
    }

    [self updateKeyboardBottomInset:0 withAnimationParametersFromNotification:notification];
}

@end
