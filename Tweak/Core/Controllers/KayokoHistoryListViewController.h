//
//  KayokoHistoryListViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoHistoryListViewController;
@class KayokoHistoryListView;
@class PasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoHistoryListViewControllerDelegate <NSObject>

- (void)historyListViewControllerDidRequestHide:(KayokoHistoryListViewController *)controller;
- (void)historyListViewController:(KayokoHistoryListViewController *)controller
         didRequestPreviewForItem:(PasteboardItem *)item;
- (void)historyListViewController:(KayokoHistoryListViewController *)controller
    didChangeContentStateMaintainingSearchBarVisibility:(BOOL)maintainsSearchBarVisibility;
- (void)historyListViewController:(KayokoHistoryListViewController *)controller
            didMoveItemDictionary:(NSDictionary<NSString *, id> *)dictionary
               fromHistoryWithKey:(NSString *)sourceHistoryKey
                 toHistoryWithKey:(NSString *)destinationHistoryKey;

@end

@interface KayokoHistoryListViewController : UIViewController

@property(nonatomic, weak, nullable) id<KayokoHistoryListViewControllerDelegate> delegate;
@property(nonatomic, strong, readonly) KayokoHistoryListView *tableView;
@property(nonatomic, copy, readonly) NSString *historyKey;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *items;
@property(nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *displayedItems;
@property(nonatomic, copy, readonly) NSString *searchText;
@property(nonatomic, assign, readonly) BOOL hasActiveSearch;
@property(nonatomic, assign) BOOL automaticallyPaste;
@property(nonatomic, assign) NSUInteger previewLineCount;

- (instancetype)initWithName:(NSString *)name historyKey:(NSString *)historyKey NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (nullable NSDictionary<NSString *, id> *)itemDictionaryAtIndexPath:(NSIndexPath *)indexPath;
- (void)reloadDataWithItems:(NSArray<NSDictionary<NSString *, id> *> *)items;
- (void)updateDataWithItems:(NSArray<NSDictionary<NSString *, id> *> *)items
     animatingTopInsertions:(BOOL)animatingTopInsertions;
- (void)applySearchText:(NSString *)searchText;
- (void)clearItems;
- (void)upsertItemDictionaryAtTop:(NSDictionary<NSString *, id> *)dictionary limit:(NSUInteger)limit;
- (void)upsertItemDictionaryAtTop:(NSDictionary<NSString *, id> *)dictionary
                            limit:(NSUInteger)limit
                        animating:(BOOL)animating;
- (void)removeItemDictionary:(NSDictionary<NSString *, id> *)dictionary;
- (void)removeItemAtIndexPath:(NSIndexPath *)indexPath completion:(nullable void (^)(BOOL success))completion;
- (void)scrollToTopAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
