//
//  KayokoHistoryListViewController.m
//  Kayoko
//

#import "KayokoHistoryListViewController.h"
#import "KayokoFavoritesTableView.h"
#import "KayokoHistoryItemActionHandler.h"
#import "KayokoHistoryListView.h"
#import "KayokoHistoryTableView.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import "KayokoSearchCriteria.h"
#import "KayokoTableDataStore.h"
#import "KayokoTableViewCell.h"
#import "KayokoTableViewCellContent.h"
#import "KayokoTableViewCellContentProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHistoryListViewController () <UITableViewDelegate, UITableViewDataSource>

#pragma mark - Views

@property(nonatomic, strong, readwrite) KayokoHistoryListView *tableView;

#pragma mark - State

@property(nonatomic, copy, readwrite) NSString *historyKey;
@property(nonatomic, copy, readwrite) NSString *name;

#pragma mark - Data

@property(nonatomic, strong) KayokoTableDataStore *dataStore;
@property(nonatomic, strong) KayokoTableViewCellContentProvider *cellContentProvider;
@property(nonatomic, strong) KayokoHistoryItemActionHandler *actionHandler;

- (KayokoTableViewCell *)newCellForItem:(KayokoPasteboardItem *)item addsPreviewGesture:(BOOL)addsPreviewGesture;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoHistoryListViewController

#pragma mark - Lifecycle

- (instancetype)initWithName:(NSString *)name historyKey:(NSString *)historyKey {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _name = [name copy] ?: @"";
        _historyKey = [historyKey copy] ?: kKayokoHistoryKeyHistory;
        if ([_historyKey isEqualToString:kKayokoHistoryKeyFavorites]) {
            _tableView = [[KayokoFavoritesTableView alloc] initWithName:_name];
        } else {
            _tableView = [[KayokoHistoryTableView alloc] initWithName:_name];
        }
        _dataStore = [[KayokoTableDataStore alloc] init];
        _cellContentProvider = [[KayokoTableViewCellContentProvider alloc] init];
        _actionHandler = [[KayokoHistoryItemActionHandler alloc] init];
        [_tableView setName:_name];
        [_tableView setDelegate:self];
        [_tableView setDataSource:self];
    }
    return self;
}

- (void)loadView {
    [self setView:[self tableView]];
}

#pragma mark - State

- (NSArray<NSDictionary<NSString *, id> *> *)items {
    return [[self dataStore] items];
}

- (NSArray<NSDictionary<NSString *, id> *> *)displayedItems {
    return [[self dataStore] displayedItems];
}

- (NSString *)searchText {
    return [[self dataStore] searchText];
}

- (KayokoSearchCriteria *)searchCriteria {
    return [[self dataStore] searchCriteria];
}

- (BOOL)isBrowsingSearchTokens {
    return [[self dataStore] isBrowsingSearchTokens];
}

- (BOOL)hasActiveSearch {
    return [[self dataStore] hasActiveSearch];
}

- (void)setPreviewLineCount:(NSUInteger)previewLineCount {
    [[self tableView] setPreviewLineCount:previewLineCount];
}

- (NSUInteger)previewLineCount {
    return [[self tableView] previewLineCount];
}

- (void)refreshSearchPlaceholder {
    BOOL showsNoSearchResults = [self hasActiveSearch] && ![self isBrowsingSearchTokens] && [[self items] count] > 0 &&
                                [[self displayedItems] count] == 0;
    [[self tableView] setShowsNoSearchResultsPlaceholder:showsNoSearchResults];
}

- (void)reloadTableView {
    [[self tableView] reloadData];
    [self refreshSearchPlaceholder];
}

- (void)scrollToTopAnimated:(BOOL)animated {
    [[self tableView] scrollToTopAnimated:animated];
}

#pragma mark - Diffing

- (NSArray<NSIndexPath *> *)indexPathsFromRow:(NSUInteger)startRow count:(NSUInteger)count {
    NSMutableArray<NSIndexPath *> *indexPaths = [[NSMutableArray alloc] initWithCapacity:count];
    for (NSUInteger row = startRow; row < startRow + count; row++) {
        [indexPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
    }
    return indexPaths;
}

- (BOOL)canUpdateFromItems:(NSArray<NSDictionary<NSString *, id> *> *)oldItems
                   toItems:(NSArray<NSDictionary<NSString *, id> *> *)newItems
      withTopInsertedCount:(NSUInteger *)insertedCount
        bottomRemovedCount:(NSUInteger *)removedCount {
    NSUInteger oldCount = [oldItems count];
    NSUInteger newCount = [newItems count];

    if (newCount == 0 || [oldItems isEqualToArray:newItems]) {
        return NO;
    }

    if (oldCount == 0) {
        if (insertedCount) {
            *insertedCount = newCount;
        }
        if (removedCount) {
            *removedCount = 0;
        }
        return YES;
    }

    for (NSUInteger candidateInsertedCount = 1; candidateInsertedCount <= newCount; candidateInsertedCount++) {
        NSUInteger retainedCount = MIN(oldCount, newCount - candidateInsertedCount);
        if (retainedCount == 0 || candidateInsertedCount + retainedCount != newCount) {
            continue;
        }

        NSArray<NSDictionary<NSString *, id> *> *newRetainedItems =
            [newItems subarrayWithRange:NSMakeRange(candidateInsertedCount, retainedCount)];
        NSArray<NSDictionary<NSString *, id> *> *oldRetainedItems =
            [oldItems subarrayWithRange:NSMakeRange(0, retainedCount)];
        if (![newRetainedItems isEqualToArray:oldRetainedItems]) {
            continue;
        }

        if (insertedCount) {
            *insertedCount = candidateInsertedCount;
        }
        if (removedCount) {
            *removedCount = oldCount - retainedCount;
        }
        return YES;
    }

    return NO;
}

- (NSUInteger)normalizedLimit:(NSUInteger)limit {
    return limit == 0 ? NSUIntegerMax : limit;
}

- (BOOL)shouldRestoreContentOffsetAfterTopInsertionFromOffset:(CGPoint)contentOffset {
    return ![self hasActiveSearch] && [[self tableView] isContentOffsetAtHiddenSearchHeaderBoundary:contentOffset];
}

- (BOOL)shouldRestoreContentOffsetAfterTopRowRemovalAtIndexPath:(NSIndexPath *)indexPath
                                                     fromOffset:(CGPoint)contentOffset {
    if ([indexPath row] != 0) {
        return NO;
    }

    return [[self tableView] isSearchHeaderExposedAtContentOffset:contentOffset] ||
           [[self tableView] isContentOffsetAtHiddenSearchHeaderBoundary:contentOffset];
}

- (BOOL)shouldRestoreContentOffsetAfterMovingRowToTopFromOffset:(CGPoint)contentOffset {
    return ![self hasActiveSearch] && ([[self tableView] isSearchHeaderExposedAtContentOffset:contentOffset] ||
                                       [[self tableView] isContentOffsetAtHiddenSearchHeaderBoundary:contentOffset]);
}

- (UITableViewRowAnimation)rowAnimationForTopInsertionFromContentOffset:(CGPoint)contentOffset {
    if ([[self tableView] isSearchHeaderExposedAtContentOffset:contentOffset]) {
        return UITableViewRowAnimationFade;
    }

    return UITableViewRowAnimationTop;
}

- (nullable NSDictionary<NSString *, id> *)itemDictionaryAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSDictionary<NSString *, id> *> *displayedItems = [self displayedItems];
    if ([indexPath row] >= [displayedItems count]) {
        return nil;
    }
    return displayedItems[[indexPath row]];
}

#pragma mark - Data Updates

- (void)setItems:(NSArray<NSDictionary<NSString *, id> *> *)items {
    [[self dataStore] setItems:items];
}

- (void)reloadDataWithItems:(NSArray<NSDictionary<NSString *, id> *> *)items {
    [self updateDataWithItems:items animatingTopInsertions:NO];
}

- (void)updateDataWithItems:(NSArray<NSDictionary<NSString *, id> *> *)items
     animatingTopInsertions:(BOOL)animatingTopInsertions {
    NSArray<NSDictionary<NSString *, id> *> *oldItems = [self items] ?: @[];
    NSArray<NSDictionary<NSString *, id> *> *newItems = items ?: @[];
    if ([oldItems isEqualToArray:newItems] && [[self tableView] numberOfRowsInSection:0] == [oldItems count]) {
        return;
    }

    NSUInteger insertedCount = 0;
    NSUInteger removedCount = 0;
    BOOL canAnimateTopInsertion = ![self hasActiveSearch] && animatingTopInsertions &&
                                  [[self tableView] numberOfRowsInSection:0] == [oldItems count] &&
                                  [self canUpdateFromItems:oldItems
                                                   toItems:newItems
                                      withTopInsertedCount:&insertedCount
                                        bottomRemovedCount:&removedCount];

    if (!canAnimateTopInsertion) {
        [self setItems:newItems];
        [self reloadTableView];
        return;
    }

    NSArray<NSIndexPath *> *insertedIndexPaths = [self indexPathsFromRow:0 count:insertedCount];
    NSArray<NSIndexPath *> *removedIndexPaths = [self indexPathsFromRow:[oldItems count] - removedCount
                                                                  count:removedCount];
    UITableViewRowAnimation insertionAnimation =
        [self rowAnimationForTopInsertionFromContentOffset:[[self tableView] contentOffset]];

    [[self tableView]
        performBatchUpdates:^{
          [self setItems:newItems];
          if ([insertedIndexPaths count] > 0) {
              [[self tableView] insertRowsAtIndexPaths:insertedIndexPaths withRowAnimation:insertionAnimation];
          }
          if ([removedIndexPaths count] > 0) {
              [[self tableView] deleteRowsAtIndexPaths:removedIndexPaths withRowAnimation:UITableViewRowAnimationFade];
          }
        }
        completion:^(__unused BOOL finished) {
          [self refreshSearchPlaceholder];
        }];
}

#pragma mark - Search

- (void)applySearchText:(NSString *)searchText {
    [[self dataStore] applySearchText:searchText];
    [self reloadTableView];
}

- (void)beginApplyingSearchCriteria:(KayokoSearchCriteria *)searchCriteria {
    [[self dataStore] beginApplyingSearchCriteria:searchCriteria];
    [self refreshSearchPlaceholder];
}

- (void)applySearchCriteria:(KayokoSearchCriteria *)searchCriteria
              filteredItems:(NSArray<NSDictionary<NSString *, id> *> *)filteredItems {
    [[self dataStore] applySearchCriteria:searchCriteria filteredItems:filteredItems];
    [self reloadTableView];
}

- (void)showSearchTokensWithFullListForCriteria:(KayokoSearchCriteria *)searchCriteria {
    [[self dataStore] showSearchTokensWithFullListForCriteria:searchCriteria];
    [self reloadTableView];
}

- (void)clearSearch {
    [[self dataStore] clearSearch];
    [self reloadTableView];
}

#pragma mark - Item Mutations

- (void)clearItems {
    NSArray<NSDictionary<NSString *, id> *> *oldItems = [self items] ?: @[];
    if ([oldItems count] == 0) {
        return;
    }

    [self setItems:@[]];
    [self reloadTableView];
}

- (void)upsertItemDictionaryAtTop:(NSDictionary<NSString *, id> *)dictionary limit:(NSUInteger)limit {
    [self upsertItemDictionaryAtTop:dictionary limit:limit animating:YES];
}

- (void)upsertItemDictionaryAtTop:(NSDictionary<NSString *, id> *)dictionary
                            limit:(NSUInteger)limit
                        animating:(BOOL)animating {
    if (!dictionary || [dictionary[kKayokoItemKeyContent] length] == 0) {
        return;
    }

    NSArray<NSDictionary<NSString *, id> *> *oldItems = [self items] ?: @[];
    NSMutableArray<NSDictionary<NSString *, id> *> *newItems = [oldItems mutableCopy];
    NSUInteger existingIndex = [[self dataStore] indexOfItemMatchingDictionary:dictionary inItems:newItems];
    NSUInteger normalizedLimit = [self normalizedLimit:limit];

    if (existingIndex != NSNotFound) {
        [newItems removeObjectAtIndex:existingIndex];
    }
    [newItems insertObject:dictionary atIndex:0];
    while ([newItems count] > normalizedLimit) {
        [newItems removeLastObject];
    }

    if ([oldItems isEqualToArray:newItems] &&
        [[self tableView] numberOfRowsInSection:0] == [[self displayedItems] count]) {
        return;
    }

    if (!animating) {
        [self updateDataWithItems:newItems animatingTopInsertions:NO];
        return;
    }

    if ([self hasActiveSearch] || [[self tableView] numberOfRowsInSection:0] != [oldItems count]) {
        [self updateDataWithItems:newItems animatingTopInsertions:YES];
        return;
    }

    if (existingIndex == 0) {
        [self setItems:newItems];
        [[self tableView] reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:0 inSection:0] ]
                                withRowAnimation:UITableViewRowAnimationNone];
        [self refreshSearchPlaceholder];
        return;
    }

    if (existingIndex != NSNotFound && existingIndex < [oldItems count] && [newItems count] == [oldItems count]) {
        CGPoint contentOffsetBeforeMove = [[self tableView] contentOffset];
        BOOL restoresContentOffsetAfterMove =
            [self shouldRestoreContentOffsetAfterMovingRowToTopFromOffset:contentOffsetBeforeMove];

        [[self tableView]
            performBatchUpdates:^{
              [self setItems:newItems];
              [[self tableView] moveRowAtIndexPath:[NSIndexPath indexPathForRow:existingIndex inSection:0]
                                       toIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            }
            completion:^(__unused BOOL finished) {
              if (restoresContentOffsetAfterMove) {
                  [[self tableView] setContentOffset:contentOffsetBeforeMove animated:NO];
              }
              [self refreshSearchPlaceholder];
            }];
        return;
    }

    NSUInteger removedCount = [oldItems count] + 1 > [newItems count] ? [oldItems count] + 1 - [newItems count] : 0;
    NSMutableArray<NSIndexPath *> *removedIndexPaths = [[NSMutableArray alloc] initWithCapacity:removedCount];
    for (NSUInteger row = [oldItems count] - removedCount; row < [oldItems count]; row++) {
        [removedIndexPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
    }

    CGPoint contentOffsetBeforeInsertion = [[self tableView] contentOffset];
    BOOL restoresContentOffsetAfterInsertion =
        [self shouldRestoreContentOffsetAfterTopInsertionFromOffset:contentOffsetBeforeInsertion];
    UITableViewRowAnimation insertionAnimation =
        [self rowAnimationForTopInsertionFromContentOffset:contentOffsetBeforeInsertion];

    [[self tableView]
        performBatchUpdates:^{
          [self setItems:newItems];
          [[self tableView] insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:0 inSection:0] ]
                                  withRowAnimation:insertionAnimation];
          if ([removedIndexPaths count] > 0) {
              [[self tableView] deleteRowsAtIndexPaths:removedIndexPaths withRowAnimation:UITableViewRowAnimationFade];
          }
        }
        completion:^(__unused BOOL finished) {
          if (restoresContentOffsetAfterInsertion) {
              [[self tableView] setContentOffset:contentOffsetBeforeInsertion animated:NO];
          }
          [self refreshSearchPlaceholder];
        }];
}

- (void)removeItemDictionary:(NSDictionary<NSString *, id> *)dictionary {
    NSArray<NSDictionary<NSString *, id> *> *oldItems = [self items] ?: @[];
    NSUInteger existingIndex = [[self dataStore] indexOfItemMatchingDictionary:dictionary inItems:oldItems];
    if (existingIndex == NSNotFound) {
        return;
    }

    [self removeItemAtIndexPath:[NSIndexPath indexPathForRow:existingIndex inSection:0] completion:nil];
}

- (void)removeItemAtIndexPath:(NSIndexPath *)indexPath completion:(void (^)(BOOL success))completion {
    NSDictionary<NSString *, id> *dictionary = [self itemDictionaryAtIndexPath:indexPath];
    NSUInteger existingIndex = [[self dataStore] indexOfItemMatchingDictionary:dictionary inItems:[self items] ?: @[]];
    if (!dictionary || existingIndex == NSNotFound) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    CGPoint contentOffsetBeforeRemoval = [[self tableView] contentOffset];
    BOOL restoresContentOffsetAfterRemoval =
        [self shouldRestoreContentOffsetAfterTopRowRemovalAtIndexPath:indexPath fromOffset:contentOffsetBeforeRemoval];

    [[self tableView] prepareHiddenHeaderInsetsForRemovingRowAtIndexPath:indexPath];

    [[self tableView]
        performBatchUpdates:^{
          NSMutableArray<NSDictionary<NSString *, id> *> *items = [[self items] mutableCopy];
          [items removeObjectAtIndex:existingIndex];
          [self setItems:items];
          [[self tableView] deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        completion:^(__unused BOOL finished) {
          if (restoresContentOffsetAfterRemoval) {
              [[self tableView] setContentOffset:contentOffsetBeforeRemoval animated:NO];
          }
          [self refreshSearchPlaceholder];
          if (completion) {
              completion(YES);
          }
        }];
}

- (void)updateTagUUID:(NSString *)tagUUID forItem:(KayokoPasteboardItem *)item {
    if (!item) {
        return;
    }

    NSDictionary<NSString *, id> *dictionary = [item dictionaryRepresentation];
    __block KayokoTableDataStoreDisplayedItemUpdate update = KayokoTableDataStoreDisplayedItemUpdateNotFound;
    __block NSUInteger displayedIndex = NSNotFound;

    [[self tableView]
        performBatchUpdates:^{
          update = [[self dataStore] updateTagUUID:tagUUID
                         forItemMatchingDictionary:dictionary
                                displayedItemIndex:&displayedIndex];
          if (displayedIndex == NSNotFound) {
              return;
          }

          NSIndexPath *indexPath = [NSIndexPath indexPathForRow:displayedIndex inSection:0];
          if (update == KayokoTableDataStoreDisplayedItemUpdateRemove) {
              [[self tableView] deleteRowsAtIndexPaths:@[ indexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
          } else if (update == KayokoTableDataStoreDisplayedItemUpdateReload) {
              [[self tableView] reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
          }
        }
        completion:^(__unused BOOL finished) {
          [self refreshSearchPlaceholder];
        }];
}

- (void)updateNote:(NSString *)note
            forItem:(KayokoPasteboardItem *)item
         completion:(void (^)(void))completion {
    if (!item) {
        if (completion) {
            completion();
        }
        return;
    }

    NSDictionary<NSString *, id> *dictionary = [item dictionaryRepresentation];
    __block KayokoTableDataStoreDisplayedItemUpdate update = KayokoTableDataStoreDisplayedItemUpdateNotFound;
    __block NSUInteger displayedIndex = NSNotFound;

    [[self tableView]
        performBatchUpdates:^{
          update = [[self dataStore] updateNote:note
                         forItemMatchingDictionary:dictionary
                                displayedItemIndex:&displayedIndex];
          if (displayedIndex == NSNotFound) {
              return;
          }

          NSIndexPath *indexPath = [NSIndexPath indexPathForRow:displayedIndex inSection:0];
          if (update == KayokoTableDataStoreDisplayedItemUpdateRemove) {
              [[self tableView] deleteRowsAtIndexPaths:@[ indexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
          } else if (update == KayokoTableDataStoreDisplayedItemUpdateReload) {
              [[self tableView] reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
          }
        }
        completion:^(__unused BOOL finished) {
          [self refreshSearchPlaceholder];
          if (completion) {
              completion();
          }
        }];
}

- (nullable KayokoTableViewCell *)visibleCellForItem:(KayokoPasteboardItem *)item {
    if (!item) {
        return nil;
    }

    NSUInteger displayedIndex = [[self dataStore] indexOfItemMatchingDictionary:[item dictionaryRepresentation]
                                                                         inItems:[self displayedItems]];
    if (displayedIndex == NSNotFound) {
        return nil;
    }
    return (KayokoTableViewCell *)[[self tableView]
        cellForRowAtIndexPath:[NSIndexPath indexPathForRow:displayedIndex inSection:0]];
}

- (KayokoTableViewCell *)presentationCellForItem:(KayokoPasteboardItem *)item {
    return [self newCellForItem:item addsPreviewGesture:NO];
}

- (nullable KayokoTableViewCell *)scrollItemToVisible:(KayokoPasteboardItem *)item {
    if (!item) {
        return nil;
    }

    NSUInteger displayedIndex = [[self dataStore] indexOfItemMatchingDictionary:[item dictionaryRepresentation]
                                                                         inItems:[self displayedItems]];
    if (displayedIndex == NSNotFound) {
        return nil;
    }

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:displayedIndex inSection:0];
    KayokoHistoryListView *tableView = [self tableView];
    [tableView layoutIfNeeded];
    [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    [tableView layoutIfNeeded];
    return (KayokoTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView != [self tableView]) {
        return 0;
    }
    return [[self displayedItems] count];
}

- (KayokoTableViewCell *)newCellForItem:(KayokoPasteboardItem *)item addsPreviewGesture:(BOOL)addsPreviewGesture {
    KayokoTableViewCellContent *content = [[self cellContentProvider] cellContentForItem:item
                                                                        previewLineCount:[self previewLineCount]
                                                                              searchText:[self searchText]];

    KayokoTableViewCell *cell = [[KayokoTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                                   content:content
                                                           reuseIdentifier:@"KayokoTableViewCell"];

    NSString *imageName = [[item imageName] copy];
    if ([imageName length] > 0) {
        __weak KayokoTableViewCell *weakCell = cell;
        [[self cellContentProvider] loadThumbnailForItem:item
                                              targetSize:[KayokoTableViewCell contentImageThumbnailSize]
                                              completion:^(UIImage *_Nullable image) {
                                                [weakCell setContentImage:image forImageName:imageName];
                                              }];
    }

    if (addsPreviewGesture) {
        UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handleLongPressGestureRecognizer:)];
        [cell addGestureRecognizer:gesture];
    }
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary<NSString *, id> *dictionary = [self itemDictionaryAtIndexPath:indexPath];
    KayokoPasteboardItem *item = [KayokoPasteboardItem itemFromDictionary:dictionary];
    return [self newCellForItem:item addsPreviewGesture:YES];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];

    KayokoPasteboardItem *item = [KayokoPasteboardItem itemFromDictionary:[self itemDictionaryAtIndexPath:indexPath]];
    [[self actionHandler] activateItem:item
                            historyKey:[self historyKey]
                            completion:^(BOOL success) {
                              if (success) {
                                  if ([self automaticallyPaste]) {
                                      [[self delegate] historyListViewControllerDidRequestHideAfterDirectPaste:self];
                                  } else {
                                      [[self delegate] historyListViewControllerDidRequestHide:self];
                                  }
                              }
                            }];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                      withVelocity:(CGPoint)velocity
               targetContentOffset:(inout CGPoint *)targetContentOffset {
    (void)velocity;
    if (scrollView != [self tableView] || [self hasActiveSearch]) {
        return;
    }

    [[self tableView] adjustTargetContentOffsetForSearchBarSnap:targetContentOffset];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray<UIContextualAction *> *actions = [[NSMutableArray alloc] init];
    NSDictionary<NSString *, id> *dictionary = [self itemDictionaryAtIndexPath:indexPath];
    KayokoPasteboardItem *item = [KayokoPasteboardItem itemFromDictionary:dictionary];

    UIContextualAction *moveAction = [self moveActionForItem:item dictionary:dictionary indexPath:indexPath];
    if (moveAction) {
        [actions addObject:moveAction];
    }

    UIContextualAction *noteAction = [self noteActionForItem:item indexPath:indexPath];
    if (noteAction) {
        [actions addObject:noteAction];
    }

    UIContextualAction *saveAction = [self saveActionForItem:item];
    if (saveAction) {
        [actions addObject:saveAction];
    }

    UIContextualAction *linkAction = [self linkActionForItem:item];
    if (linkAction) {
        [actions addObject:linkAction];
    }

    return [UISwipeActionsConfiguration configurationWithActions:actions];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    KayokoPasteboardItem *item = [KayokoPasteboardItem itemFromDictionary:[self itemDictionaryAtIndexPath:indexPath]];

    UIContextualAction *deleteAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleDestructive
                            title:@""
                          handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView,
                                    void (^completionHandler)(BOOL)) {
                            [[self actionHandler]
                                deleteItem:item
                                historyKey:[self historyKey]
                                completion:^(BOOL success) {
                                  if (!success) {
                                      completionHandler(NO);
                                      return;
                                  }
                                  [self removeItemAtIndexPath:indexPath
                                                   completion:^(BOOL removed) {
                                                     if (removed) {
                                                         [[self delegate] historyListViewControllerDidChangeContentState:self];
                                                     }
                                                     completionHandler(removed);
                                                   }];
                                }];
                          }];
    [deleteAction setImage:[UIImage systemImageNamed:@"trash.fill"]];
    [deleteAction setBackgroundColor:[UIColor systemRedColor]];
    return [UISwipeActionsConfiguration configurationWithActions:@[ deleteAction ]];
}

#pragma mark - Swipe Actions

- (UIContextualAction *)moveActionForItem:(KayokoPasteboardItem *)item
                               dictionary:(NSDictionary<NSString *, id> *)dictionary
                                indexPath:(NSIndexPath *)indexPath {
    NSString *sourceHistoryKey = [self historyKey];
    BOOL sourceIsFavorites = [sourceHistoryKey isEqualToString:kKayokoHistoryKeyFavorites];
    NSString *destinationHistoryKey = sourceIsFavorites ? kKayokoHistoryKeyHistory : kKayokoHistoryKeyFavorites;
    NSString *imageName = sourceIsFavorites ? @"heart.slash.fill" : @"heart.fill";

    UIContextualAction *moveAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleDestructive
                            title:@""
                          handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView,
                                    void (^completionHandler)(BOOL)) {
                            [[self actionHandler]
                                             moveItem:item
                                     sourceHistoryKey:sourceHistoryKey
                                destinationHistoryKey:destinationHistoryKey
                                           completion:^(BOOL success) {
                                             if (!success) {
                                                 completionHandler(NO);
                                                 return;
                                             }
                                             [[self delegate] historyListViewController:self
                                                                  didMoveItemDictionary:dictionary
                                                                     fromHistoryWithKey:sourceHistoryKey
                                                                       toHistoryWithKey:destinationHistoryKey];
                                             [self
                                                 removeItemAtIndexPath:indexPath
                                                            completion:^(BOOL removed) {
                                                              if (removed) {
                                                                  [[self delegate]
                                                                      historyListViewControllerDidChangeContentState:self];
                                                              }
                                                              completionHandler(removed);
                                                            }];
                                           }];
                          }];
    [moveAction setImage:[UIImage systemImageNamed:imageName]];
    [moveAction setBackgroundColor:[UIColor systemPinkColor]];
    return moveAction;
}

- (UIContextualAction *)noteActionForItem:(KayokoPasteboardItem *)item indexPath:(NSIndexPath *)indexPath {
    UIContextualAction *noteAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleNormal
                            title:@""
                          handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView,
                                    void (^completionHandler)(BOOL)) {
                            KayokoTableViewCell *sourceCell =
                                (KayokoTableViewCell *)[[self tableView] cellForRowAtIndexPath:indexPath];
                            KayokoTableViewCell *presentationCell =
                                [self newCellForItem:item addsPreviewGesture:NO];
                            completionHandler(YES);
                            dispatch_async(dispatch_get_main_queue(), ^{
                              [[self delegate] historyListViewController:self
                                                  didRequestEditNoteForItem:item
                                                           presentationCell:presentationCell
                                                                 sourceCell:sourceCell];
                            });
                          }];
    [noteAction setImage:[UIImage systemImageNamed:@"note.text"]];
    [noteAction setBackgroundColor:[UIColor systemOrangeColor]];
    return noteAction;
}

- (UIContextualAction *)saveActionForItem:(KayokoPasteboardItem *)item {
    if (![self automaticallyPaste] && [[item imageName] length] == 0) {
        return nil;
    }

    BOOL savesImage = [[item imageName] length] > 0;
    UIContextualAction *saveAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleNormal
                            title:@""
                          handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView,
                                    void (^completionHandler)(BOOL)) {
                            if (savesImage) {
                                [[self actionHandler] saveImageForItem:item completion:completionHandler];
                            } else {
                                [[self actionHandler] copyItem:item completion:completionHandler];
                            }
                          }];
    [saveAction setImage:[UIImage systemImageNamed:savesImage ? @"square.and.arrow.down.fill" : @"doc.on.doc.fill"]];
    [saveAction setBackgroundColor:[UIColor systemBlueColor]];
    return saveAction;
}

- (UIContextualAction *)linkActionForItem:(KayokoPasteboardItem *)item {
    if (![item hasLink]) {
        return nil;
    }

    UIContextualAction *linkAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleNormal
                            title:@""
                          handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView,
                                    void (^completionHandler)(BOOL)) {
                            [[self actionHandler] openLinkForItem:item completion:completionHandler];
                          }];
    [linkAction setImage:[UIImage systemImageNamed:@"arrow.up"]];
    [linkAction setBackgroundColor:[UIColor systemGreenColor]];
    return linkAction;
}

#pragma mark - Gestures

- (void)handleLongPressGestureRecognizer:(UILongPressGestureRecognizer *)recognizer {
    if ([recognizer state] != UIGestureRecognizerStateBegan) {
        return;
    }

    NSIndexPath *indexPath = [[self tableView] indexPathForCell:(UITableViewCell *)[recognizer view]];
    KayokoPasteboardItem *item = [KayokoPasteboardItem itemFromDictionary:[self itemDictionaryAtIndexPath:indexPath]];
    if (item) {
        [[self delegate] historyListViewController:self didRequestPreviewForItem:item];
    }
}

@end
