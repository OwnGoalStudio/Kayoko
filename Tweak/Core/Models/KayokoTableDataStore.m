//
//  KayokoTableDataStore.m
//  Kayoko
//

#import "KayokoTableDataStore.h"

#import "KayokoPasteboardItem.h"
#import "KayokoSearchCriteria.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableDataStore ()
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *displayedItems;
@property(nonatomic, copy) NSString *searchText;
@property(nonatomic, strong) KayokoSearchCriteria *searchCriteria;
@property(nonatomic, assign, getter=isBrowsingSearchTokens) BOOL browsingSearchTokens;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoTableDataStore

- (instancetype)init {
    self = [super init];
    if (self) {
        _items = @[];
        _displayedItems = @[];
        _searchText = @"";
        _searchCriteria = [KayokoSearchCriteria emptyCriteria];
    }
    return self;
}

- (BOOL)hasActiveSearch {
    return [[self searchCriteria] hasActiveFilters] || [self isBrowsingSearchTokens];
}

- (void)refreshDisplayedItems {
    NSArray<NSDictionary<NSString *, id> *> *items = [self items] ?: @[];
    NSString *searchText =
        [[self searchText] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([searchText length] == 0) {
        [self setDisplayedItems:items];
        return;
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *displayedItems = [[NSMutableArray alloc] init];
    for (NSDictionary<NSString *, id> *item in items) {
        NSString *imageName = item[kKayokoItemKeyImageName];
        NSString *content = item[kKayokoItemKeyContent];
        if ([imageName length] > 0 || [content rangeOfString:searchText
                                                     options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch]
                                              .location == NSNotFound) {
            continue;
        }

        [displayedItems addObject:item];
    }
    [self setDisplayedItems:displayedItems];
}

- (void)setItems:(NSArray<NSDictionary<NSString *, id> *> *)items {
    _items = [items copy] ?: @[];
    if (![self hasActiveSearch]) {
        [self refreshDisplayedItems];
    }
}

- (void)applySearchText:(NSString *)searchText {
    _searchCriteria = [[self searchCriteria] criteriaByReplacingSearchText:searchText];
    _searchText = [[self searchCriteria] searchText];
    [self setBrowsingSearchTokens:NO];
    [self refreshDisplayedItems];
}

- (void)beginApplyingSearchCriteria:(KayokoSearchCriteria *)searchCriteria {
    _searchCriteria = [searchCriteria copy] ?: [KayokoSearchCriteria emptyCriteria];
    _searchText = [[self searchCriteria] searchText];
    [self setBrowsingSearchTokens:NO];
}

- (void)applySearchCriteria:(KayokoSearchCriteria *)searchCriteria
              filteredItems:(NSArray<NSDictionary<NSString *, id> *> *)filteredItems {
    _searchCriteria = [searchCriteria copy] ?: [KayokoSearchCriteria emptyCriteria];
    _searchText = [[self searchCriteria] searchText];
    [self setBrowsingSearchTokens:NO];
    if ([[self searchCriteria] hasActiveFilters]) {
        [self setDisplayedItems:filteredItems ?: @[]];
        return;
    }
    [self refreshDisplayedItems];
}

- (void)showSearchTokensOnlyWithCriteria:(KayokoSearchCriteria *)searchCriteria {
    _searchCriteria = [searchCriteria copy] ?: [KayokoSearchCriteria emptyCriteria];
    _searchText = [[self searchCriteria] searchText];
    [self setBrowsingSearchTokens:YES];
    [self setDisplayedItems:@[]];
}

- (void)clearSearch {
    _searchCriteria = [KayokoSearchCriteria emptyCriteria];
    _searchText = @"";
    [self setBrowsingSearchTokens:NO];
    [self refreshDisplayedItems];
}

- (NSUInteger)indexOfItemMatchingDictionary:(NSDictionary<NSString *, id> *)dictionary
                                    inItems:(NSArray<NSDictionary<NSString *, id> *> *)items {
    NSString *content = dictionary[kKayokoItemKeyContent];
    if ([content length] == 0) {
        return NSNotFound;
    }

    for (NSUInteger index = 0; index < [items count]; index++) {
        NSDictionary<NSString *, id> *item = items[index];
        if ([item[kKayokoItemKeyContent] isEqualToString:content]) {
            return index;
        }
    }
    return NSNotFound;
}

@end
