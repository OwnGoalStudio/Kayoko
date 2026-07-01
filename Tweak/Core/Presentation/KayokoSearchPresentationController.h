//
//  KayokoSearchPresentationController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoHistoryListView;
@class KayokoSearchPresentationController;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoSearchPresentationControllerDelegate <NSObject>

- (void)searchPresentationController:(KayokoSearchPresentationController *)controller
        didUpdateKeyboardBottomInset:(CGFloat)keyboardBottomInset;
- (void)searchPresentationController:(KayokoSearchPresentationController *)controller
    didRequestCollapseFromFullscreenPanWithVelocity:(CGFloat)velocityY;

@end

@interface KayokoSearchPresentationController : NSObject

@property(nonatomic, weak, nullable) id<KayokoSearchPresentationControllerDelegate> delegate;
@property(nonatomic, assign, readonly, getter=isSearchActive) BOOL searchActive;
@property(nonatomic, assign, readonly) CGFloat keyboardBottomInset;

- (instancetype)initWithContainerView:(UIView *)containerView
                           headerView:(UIView *)headerView
                     historySearchBar:(UISearchBar *)historySearchBar
                   favoritesSearchBar:(UISearchBar *)favoritesSearchBar
                     historyTableView:(KayokoHistoryListView *)historyTableView
                   favoritesTableView:(KayokoHistoryListView *)favoritesTableView
                 panGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer;

- (CGFloat)searchHeaderHeight;
- (void)layout;
- (void)attachToTableView:(KayokoHistoryListView *)tableView hidesSearchBar:(BOOL)hidesSearchBar;
- (void)maintainSearchBarVisibilityForTableView:(KayokoHistoryListView *)tableView;
- (void)hideSearchBarInTableView:(nullable KayokoHistoryListView *)tableView animated:(BOOL)animated;
- (void)revealSearchBarInTableView:(nullable KayokoHistoryListView *)tableView animated:(BOOL)animated;
- (void)beginSearchWithActiveTableView:(KayokoHistoryListView *)activeTableView
                            completion:(nullable void (^)(void))completion;
- (void)endSearchRestoringFrame:(BOOL)restoresFrame
                activeTableView:(KayokoHistoryListView *)activeTableView
                     completion:(nullable void (^)(void))completion;
- (void)endSearchRestoringFrame:(BOOL)restoresFrame
                activeTableView:(KayokoHistoryListView *)activeTableView
                     animations:(nullable void (^)(void))animations
                     completion:(nullable void (^)(void))completion;
- (void)endSearchRestoringFrame:(BOOL)restoresFrame
                activeTableView:(KayokoHistoryListView *)activeTableView
                     animations:(nullable void (^)(void))animations
                   panVelocityY:(CGFloat)panVelocityY
                     completion:(nullable void (^)(void))completion;
- (void)handleFullscreenPanGestureRecognizer:(UIPanGestureRecognizer *)recognizer
                             activeTableView:(KayokoHistoryListView *)activeTableView;
- (void)resetKeyboardInsets;

@end

NS_ASSUME_NONNULL_END
