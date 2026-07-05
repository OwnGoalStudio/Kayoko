//
//  KayokoHistoryController.m
//  Kayoko
//

#import "KayokoHistoryController.h"

#import "KayokoHistoryListView.h"
#import "KayokoHistoryListViewController.h"
#import "KayokoPasteboardManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHistoryController ()
@property(nonatomic, strong) NSMutableSet<NSString *> *loadedHistoryKeys;
@property(nonatomic, strong) NSMutableSet<NSString *> *dirtyHistoryKeys;
@property(nonatomic, assign) NSUInteger pendingLocalHistoryChangeNotificationCount;
@property(nonatomic, weak) KayokoHistoryListViewController *historyListViewController;
@property(nonatomic, weak) KayokoHistoryListViewController *favoritesListViewController;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoHistoryController

- (instancetype)initWithHistoryListViewController:(KayokoHistoryListViewController *)historyListViewController
                      favoritesListViewController:(KayokoHistoryListViewController *)favoritesListViewController {
    self = [super init];
    if (self) {
        _activeHistoryKey = kKayokoHistoryKeyHistory;
        _loadedHistoryKeys = [[NSMutableSet alloc] init];
        _dirtyHistoryKeys = [NSMutableSet setWithObjects:kKayokoHistoryKeyHistory, kKayokoHistoryKeyFavorites, nil];
        _historyListViewController = historyListViewController;
        _favoritesListViewController = favoritesListViewController;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleLocalHistoryChangeNotification:)
                                                     name:kKayokoPasteboardManagerHistoryDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)effectiveActiveHistoryKeyWithClearConfirmationHistoryKey:(NSString *)clearConfirmationHistoryKey {
    return clearConfirmationHistoryKey ?: [self activeHistoryKey] ?: kKayokoHistoryKeyHistory;
}

- (KayokoHistoryListViewController *)listViewControllerForHistoryKey:(NSString *)historyKey {
    return [historyKey isEqualToString:kKayokoHistoryKeyFavorites] ? [self favoritesListViewController]
                                                                   : [self historyListViewController];
}

- (KayokoHistoryListView *)tableViewForHistoryKey:(NSString *)historyKey {
    return [[self listViewControllerForHistoryKey:historyKey] tableView];
}

- (KayokoHistoryListView *)activeTableViewWithClearConfirmationHistoryKey:(NSString *)clearConfirmationHistoryKey {
    return [self tableViewForHistoryKey:
                     [self effectiveActiveHistoryKeyWithClearConfirmationHistoryKey:clearConfirmationHistoryKey]];
}

- (BOOL)hasLoadedHistoryKey:(NSString *)historyKey {
    return [[self loadedHistoryKeys] containsObject:historyKey];
}

- (BOOL)needsReloadForHistoryKey:(NSString *)historyKey {
    return ![self hasLoadedHistoryKey:historyKey] || [[self dirtyHistoryKeys] containsObject:historyKey];
}

- (void)markHistoryKeyLoaded:(NSString *)historyKey {
    if ([historyKey length] == 0) {
        return;
    }
    [[self loadedHistoryKeys] addObject:historyKey];
    [[self dirtyHistoryKeys] removeObject:historyKey];
}

- (void)markHistoryKeyDirty:(NSString *)historyKey {
    if ([historyKey length] == 0) {
        return;
    }
    [[self dirtyHistoryKeys] addObject:historyKey];
}

- (void)markAllHistoryKeysDirty {
    [self markHistoryKeyDirty:kKayokoHistoryKeyHistory];
    [self markHistoryKeyDirty:kKayokoHistoryKeyFavorites];
}

- (NSUInteger)limitForHistoryKey:(NSString *)historyKey {
    if ([historyKey isEqualToString:kKayokoHistoryKeyFavorites]) {
        return NSUIntegerMax;
    }
    return [[KayokoPasteboardManager sharedInstance] maximumHistoryAmount];
}

- (BOOL)shouldAnimateUpdatesForHistoryKey:(NSString *)historyKey {
    return
        [[self activeHistoryKey] isEqualToString:historyKey] && [[self delegate] historyControllerIsPanelVisible:self];
}

- (BOOL)shouldDeferEmptyInactiveUpsertForHistoryKey:(NSString *)historyKey
                                 listViewController:(KayokoHistoryListViewController *)listViewController {
    return ![[self activeHistoryKey] isEqualToString:historyKey] && [[listViewController items] count] == 0;
}

- (void)updateCachedTableViewForHistoryKey:(NSString *)historyKey
                                changeType:(NSString *)changeType
                            itemDictionary:(NSDictionary<NSString *, id> *)dictionary
                                     limit:(NSUInteger)limit {
    KayokoHistoryListViewController *listViewController = [self listViewControllerForHistoryKey:historyKey];
    if ([[self delegate] historyControllerShouldSuppressVisibleUpdates:self]) {
        [self markHistoryKeyDirty:historyKey];
        return;
    }

    if (![self hasLoadedHistoryKey:historyKey]) {
        [self markHistoryKeyDirty:historyKey];
        if ([[self delegate] historyControllerIsPanelVisible:self] &&
            [[self activeHistoryKey] isEqualToString:historyKey]) {
            [[self delegate] historyControllerNeedsVisibleReload:self];
        }
        return;
    }

    if ([changeType isEqualToString:kKayokoPasteboardManagerHistoryChangeTypeClear]) {
        [listViewController clearItems];
    } else if ([changeType isEqualToString:kKayokoPasteboardManagerHistoryChangeTypeUpsertTop]) {
        if ([self shouldDeferEmptyInactiveUpsertForHistoryKey:historyKey listViewController:listViewController]) {
            [self markHistoryKeyDirty:historyKey];
            return;
        }
        [listViewController upsertItemDictionaryAtTop:dictionary
                                                limit:(limit ?: [self limitForHistoryKey:historyKey])animating
                                                     :[self shouldAnimateUpdatesForHistoryKey:historyKey]];
    } else if ([changeType isEqualToString:kKayokoPasteboardManagerHistoryChangeTypeRemove]) {
        [listViewController removeItemDictionary:dictionary];
    } else {
        [self markHistoryKeyDirty:historyKey];
        return;
    }

    [self markHistoryKeyLoaded:historyKey];
    if ([[self activeHistoryKey] isEqualToString:historyKey]) {
        [[self delegate] historyController:self didUpdateActiveTableView:[listViewController tableView]];
    }
}

- (void)handleLocalHistoryChangeNotification:(NSNotification *)notification {
    [self setPendingLocalHistoryChangeNotificationCount:[self pendingLocalHistoryChangeNotificationCount] + 1];
    NSDictionary<NSString *, id> *userInfo = [notification userInfo];
    NSString *historyKey = userInfo[kKayokoPasteboardManagerHistoryChangeHistoryKeyKey];
    NSString *changeType =
        userInfo[kKayokoPasteboardManagerHistoryChangeTypeKey] ?: kKayokoPasteboardManagerHistoryChangeTypeReload;
    NSDictionary<NSString *, id> *dictionary = userInfo[kKayokoPasteboardManagerHistoryChangeItemKey];
    NSUInteger limit = [userInfo[kKayokoPasteboardManagerHistoryChangeLimitKey] unsignedIntegerValue];

    if ([historyKey length] == 0 || [changeType isEqualToString:kKayokoPasteboardManagerHistoryChangeTypeReload]) {
        [self markAllHistoryKeysDirty];
        if ([[self delegate] historyControllerIsPanelVisible:self]) {
            [[self delegate] historyControllerNeedsVisibleReload:self];
        }
        return;
    }

    [self updateCachedTableViewForHistoryKey:historyKey changeType:changeType itemDictionary:dictionary limit:limit];
}

- (void)handleHistoryChanged {
    if ([self pendingLocalHistoryChangeNotificationCount] > 0) {
        [self setPendingLocalHistoryChangeNotificationCount:[self pendingLocalHistoryChangeNotificationCount] - 1];
        return;
    }

    [self markAllHistoryKeysDirty];
    if ([[self delegate] historyControllerIsPanelVisible:self]) {
        [[self delegate] historyControllerNeedsVisibleReload:self];
    }
}

- (void)reloadTableViewForHistoryKey:(NSString *)historyKey
              animatingTopInsertions:(BOOL)animatingTopInsertions
                          completion:(void (^)(KayokoHistoryListView *tableView))completion {
    [self loadTableViewForHistoryKey:historyKey
              animatingTopInsertions:animatingTopInsertions
                    notifiesDelegate:YES
                          completion:completion];
}

- (void)loadTableViewForHistoryKey:(NSString *)historyKey
            animatingTopInsertions:(BOOL)animatingTopInsertions
                  notifiesDelegate:(BOOL)notifiesDelegate
                        completion:(void (^)(KayokoHistoryListView *tableView))completion {
    KayokoHistoryListViewController *listViewController = [self listViewControllerForHistoryKey:historyKey];
    KayokoHistoryListView *tableView = [listViewController tableView];
    if (![self needsReloadForHistoryKey:historyKey]) {
        if (completion) {
            completion(tableView);
        }
        return;
    }

    [[KayokoPasteboardManager sharedInstance]
        getItemsFromHistoryWithKey:historyKey
                        completion:^(NSMutableArray<NSDictionary<NSString *, id> *> *items, NSError *error) {
                          if (error) {
                              [[self delegate] historyController:self didFailLoadingHistoryWithError:error];
                              if (completion) {
                                  completion(tableView);
                              }
                              return;
                          }
                          [listViewController updateDataWithItems:items animatingTopInsertions:animatingTopInsertions];
                          [self markHistoryKeyLoaded:historyKey];
                          if (notifiesDelegate && [[self activeHistoryKey] isEqualToString:historyKey]) {
                              [[self delegate] historyController:self didUpdateActiveTableView:tableView];
                          }
                          if (completion) {
                              completion(tableView);
                          }
                        }];
}

- (void)reloadTableViewForHistoryKey:(NSString *)historyKey
                          completion:(void (^)(KayokoHistoryListView *tableView))completion {
    [self reloadTableViewForHistoryKey:historyKey animatingTopInsertions:NO completion:completion];
}

- (void)preloadHistoryWithCompletion:(void (^)(void))completion {
    [self loadTableViewForHistoryKey:kKayokoHistoryKeyHistory
              animatingTopInsertions:NO
                    notifiesDelegate:NO
                          completion:^(__unused KayokoHistoryListView *historyTableView) {
                            [self loadTableViewForHistoryKey:kKayokoHistoryKeyFavorites
                                      animatingTopInsertions:NO
                                            notifiesDelegate:NO
                                                  completion:^(__unused KayokoHistoryListView *favoritesTableView) {
                                                    if (completion) {
                                                        completion();
                                                    }
                                                  }];
                          }];
}

- (void)handlePasteboardItemDictionary:(NSDictionary<NSString *, id> *)dictionary
                   movedFromHistoryKey:(NSString *)sourceHistoryKey
                          toHistoryKey:(NSString *)destinationHistoryKey {
    if ([destinationHistoryKey length] == 0) {
        return;
    }

    if ([self hasLoadedHistoryKey:destinationHistoryKey]) {
        KayokoHistoryListViewController *destinationListViewController =
            [self listViewControllerForHistoryKey:destinationHistoryKey];
        if ([self shouldDeferEmptyInactiveUpsertForHistoryKey:destinationHistoryKey
                                           listViewController:destinationListViewController]) {
            [self markHistoryKeyDirty:destinationHistoryKey];
            return;
        }

        [destinationListViewController
            upsertItemDictionaryAtTop:dictionary
                                limit:[self limitForHistoryKey:destinationHistoryKey]
                            animating:[self shouldAnimateUpdatesForHistoryKey:destinationHistoryKey]];
        [self markHistoryKeyLoaded:destinationHistoryKey];
        if ([[self activeHistoryKey] isEqualToString:destinationHistoryKey]) {
            [[self delegate] historyController:self didUpdateActiveTableView:[destinationListViewController tableView]];
        }
    } else {
        [self markHistoryKeyDirty:destinationHistoryKey];
    }
}

@end
