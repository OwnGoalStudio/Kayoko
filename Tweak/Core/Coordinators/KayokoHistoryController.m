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
@property(nonatomic, strong) NSMutableSet<NSString *> *historyKeysNeedingScrollToTopBeforeNextDisplay;
@property(nonatomic, assign) NSUInteger pendingLocalHistoryChangeNotificationCount;
@property(nonatomic, weak) KayokoHistoryListViewController *historyListViewController;
@property(nonatomic, weak) KayokoHistoryListViewController *favoritesListViewController;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoHistoryController

#pragma mark - Lifecycle

- (instancetype)initWithHistoryListViewController:(KayokoHistoryListViewController *)historyListViewController
                      favoritesListViewController:(KayokoHistoryListViewController *)favoritesListViewController {
    self = [super init];
    if (self) {
        _activeHistoryKey = kKayokoHistoryKeyHistory;
        _loadedHistoryKeys = [[NSMutableSet alloc] init];
        _dirtyHistoryKeys = [NSMutableSet setWithObjects:kKayokoHistoryKeyHistory, kKayokoHistoryKeyFavorites, nil];
        _historyKeysNeedingScrollToTopBeforeNextDisplay = [[NSMutableSet alloc] init];
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

#pragma mark - View Lookup

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

#pragma mark - Load State

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

- (void)markHistoryKeyForScrollToTopBeforeNextDisplay:(NSString *)historyKey {
    if ([historyKey length] == 0) {
        return;
    }
    [[self historyKeysNeedingScrollToTopBeforeNextDisplay] addObject:historyKey];
}

- (void)markAllHistoryKeysForScrollToTopBeforeNextDisplay {
    [self markHistoryKeyForScrollToTopBeforeNextDisplay:kKayokoHistoryKeyHistory];
    [self markHistoryKeyForScrollToTopBeforeNextDisplay:kKayokoHistoryKeyFavorites];
}

- (BOOL)consumeScrollToTopBeforeNextDisplayForHistoryKey:(NSString *)historyKey {
    if (![[self historyKeysNeedingScrollToTopBeforeNextDisplay] containsObject:historyKey]) {
        return NO;
    }

    [[self historyKeysNeedingScrollToTopBeforeNextDisplay] removeObject:historyKey];
    return YES;
}

- (NSUInteger)limitForHistoryKey:(NSString *)historyKey {
    if ([historyKey isEqualToString:kKayokoHistoryKeyFavorites]) {
        return NSUIntegerMax;
    }
    return [[KayokoPasteboardManager sharedInstance] maximumHistoryAmount];
}

#pragma mark - Update Policy

- (BOOL)shouldAnimateUpdatesForHistoryKey:(NSString *)historyKey {
    return
        [[self activeHistoryKey] isEqualToString:historyKey] && [[self delegate] historyControllerIsPanelVisible:self];
}

- (BOOL)shouldDeferEmptyInactiveUpsertForHistoryKey:(NSString *)historyKey
                                 listViewController:(KayokoHistoryListViewController *)listViewController {
    return ![[self activeHistoryKey] isEqualToString:historyKey] && [[listViewController items] count] == 0;
}

#pragma mark - Cached Updates

- (void)updateCachedTableViewForHistoryKey:(NSString *)historyKey
                                changeType:(NSString *)changeType
                            itemDictionary:(NSDictionary<NSString *, id> *)dictionary
                                     limit:(NSUInteger)limit {
    KayokoHistoryListViewController *listViewController = [self listViewControllerForHistoryKey:historyKey];
    if ([changeType isEqualToString:kKayokoPasteboardManagerHistoryChangeTypeUpsertTop] &&
        (![[self delegate] historyControllerIsPanelVisible:self] || [[listViewController tableView] isHidden])) {
        [self markHistoryKeyForScrollToTopBeforeNextDisplay:historyKey];
    }
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

#pragma mark - Notifications

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

#pragma mark - Loading

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

#pragma mark - Moves

- (void)handlePasteboardItemDictionary:(NSDictionary<NSString *, id> *)dictionary
                   movedFromHistoryKey:(NSString *)sourceHistoryKey
                          toHistoryKey:(NSString *)destinationHistoryKey {
    if ([destinationHistoryKey length] == 0) {
        return;
    }

    KayokoHistoryListViewController *destinationListViewController =
        [self listViewControllerForHistoryKey:destinationHistoryKey];
    if (![[self delegate] historyControllerIsPanelVisible:self] ||
        [[destinationListViewController tableView] isHidden]) {
        [self markHistoryKeyForScrollToTopBeforeNextDisplay:destinationHistoryKey];
    }

    if ([self hasLoadedHistoryKey:destinationHistoryKey]) {
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
