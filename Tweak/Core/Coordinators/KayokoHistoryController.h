//
//  KayokoHistoryController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoHistoryController;
@class KayokoHistoryListViewController;
@class KayokoHistoryListView;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoHistoryControllerDelegate <NSObject>

- (BOOL)historyControllerIsPanelVisible:(KayokoHistoryController *)controller;
- (BOOL)historyControllerShouldSuppressVisibleUpdates:(KayokoHistoryController *)controller;
- (void)historyControllerNeedsVisibleReload:(KayokoHistoryController *)controller;
- (void)historyController:(KayokoHistoryController *)controller
    didUpdateActiveTableView:(KayokoHistoryListView *)tableView;

@end

@interface KayokoHistoryController : NSObject

@property(nonatomic, weak, nullable) id<KayokoHistoryControllerDelegate> delegate;
@property(nonatomic, copy) NSString *activeHistoryKey;

- (instancetype)initWithHistoryListViewController:(KayokoHistoryListViewController *)historyListViewController
                      favoritesListViewController:(KayokoHistoryListViewController *)favoritesListViewController;

- (NSString *)effectiveActiveHistoryKeyWithClearConfirmationHistoryKey:(nullable NSString *)clearConfirmationHistoryKey;
- (KayokoHistoryListViewController *)listViewControllerForHistoryKey:(NSString *)historyKey;
- (KayokoHistoryListView *)tableViewForHistoryKey:(NSString *)historyKey;
- (KayokoHistoryListView *)activeTableViewWithClearConfirmationHistoryKey:
    (nullable NSString *)clearConfirmationHistoryKey;

- (void)markHistoryKeyLoaded:(NSString *)historyKey;
- (void)handleHistoryChanged;
- (void)preloadHistoryWithCompletion:(nullable void (^)(void))completion;
- (void)reloadTableViewForHistoryKey:(NSString *)historyKey
              animatingTopInsertions:(BOOL)animatingTopInsertions
                          completion:(nullable void (^)(KayokoHistoryListView *tableView))completion;
- (void)reloadTableViewForHistoryKey:(NSString *)historyKey
                          completion:(nullable void (^)(KayokoHistoryListView *tableView))completion;
- (void)handlePasteboardItemDictionary:(NSDictionary<NSString *, id> *)dictionary
                   movedFromHistoryKey:(NSString *)sourceHistoryKey
                          toHistoryKey:(NSString *)destinationHistoryKey;

@end

NS_ASSUME_NONNULL_END
