//
//  KayokoSearchController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

#import "KayokoPanelPresentationMode.h"

@class KayokoSearchController;
@class KayokoHeaderView;
@class KayokoHistoryListViewController;
@class KayokoHistoryListView;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoSearchControllerDelegate <NSObject>

- (KayokoHistoryListViewController *)activeListViewControllerForSearchController:
    (KayokoSearchController *)searchController;
- (void)searchControllerWillBeginSearchInputTransition:(KayokoSearchController *)searchController;
- (void)searchControllerWillAnimateSearchState:(KayokoSearchController *)searchController;
- (void)searchControllerDidFinishAnimatingSearchState:(KayokoSearchController *)searchController;
- (void)searchController:(KayokoSearchController *)searchController
    didUpdateKeyboardBottomInset:(CGFloat)keyboardBottomInset;
- (void)searchController:(KayokoSearchController *)searchController didFailLoadingSearchWithError:(NSError *)error;

@end

@interface KayokoSearchController : NSObject

@property(nonatomic, weak, nullable) id<KayokoSearchControllerDelegate> delegate;
@property(nonatomic, assign) KayokoPanelPresentationMode presentationMode;
@property(nonatomic, assign, readonly, getter=isSearchActive) BOOL searchActive;
@property(nonatomic, assign, readonly) CGFloat keyboardBottomInset;

- (instancetype)initWithContainerView:(UIView *)containerView
                           headerView:(KayokoHeaderView *)headerView
            historyListViewController:(KayokoHistoryListViewController *)historyListViewController
          favoritesListViewController:(KayokoHistoryListViewController *)favoritesListViewController
                 panGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer;

- (void)layout;
- (void)attachToListViewController:(KayokoHistoryListViewController *)listViewController
                    hidesSearchBar:(BOOL)hidesSearchBar;
- (void)refreshForListViewController:(KayokoHistoryListViewController *)listViewController;
- (void)refreshAfterTransientContentForListViewController:(KayokoHistoryListViewController *)listViewController
                                   restoresFirstResponder:(BOOL)restoresFirstResponder
                                      targetContentOffset:(CGPoint)targetContentOffset;
- (void)cancelSearchWithCompletion:(nullable void (^)(void))completion;
- (void)cancelSearchWithAnimations:(nullable void (^)(void))animations completion:(nullable void (^)(void))completion;
- (BOOL)isActiveSearchFirstResponder;
- (void)resignSearchFirstResponder;
- (void)handleApplicationMetadataChanged;
- (void)handleFullscreenPanGestureRecognizer:(UIPanGestureRecognizer *)recognizer
                                  headerView:(nullable KayokoHeaderView *)headerView;
- (void)resetSearchState;
- (CGRect)resetSearchStatePreservingContainerFrame;

@end

NS_ASSUME_NONNULL_END
