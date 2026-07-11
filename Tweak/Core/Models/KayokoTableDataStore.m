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
        NSString *imageName = item[kKayokoItemKeyImageName] ?: @"";
        NSString *content = item[kKayokoItemKeyContent] ?: @"";
        NSString *note = item[kKayokoItemKeyNote] ?: @"";
        BOOL contentMatches =
            [imageName length] == 0 && [content rangeOfString:searchText
                                                      options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch]
                                               .location != NSNotFound;
        BOOL noteMatches =
            [note rangeOfString:searchText options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location !=
            NSNotFound;
        if (!contentMatches && !noteMatches) {
            continue;
        }

        [displayedItems addObject:item];
    }
    [self setDisplayedItems:displayedItems];
}

- (void)setItems:(NSArray<NSDictionary<NSString *, id> *> *)items {
    _items = [items copy] ?: @[];
    if ([self isBrowsingSearchTokens]) {
        [self setDisplayedItems:[self items]];
    } else if (![self hasActiveSearch]) {
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

- (void)showSearchTokensWithFullListForCriteria:(KayokoSearchCriteria *)searchCriteria {
    _searchCriteria = [searchCriteria copy] ?: [KayokoSearchCriteria emptyCriteria];
    _searchText = [[self searchCriteria] searchText];
    [self setBrowsingSearchTokens:YES];
    [self setDisplayedItems:[self items] ?: @[]];
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

- (NSDictionary<NSString *, id> *)dictionaryBySettingTagUUID:(NSString *)tagUUID
                                                inDictionary:(NSDictionary<NSString *, id> *)dictionary {
    NSMutableDictionary<NSString *, id> *updatedDictionary = [dictionary mutableCopy];
    if ([tagUUID length] > 0) {
        updatedDictionary[kKayokoItemKeyTagUUID] = tagUUID;
    } else {
        [updatedDictionary removeObjectForKey:kKayokoItemKeyTagUUID];
    }
    return updatedDictionary;
}

- (NSDictionary<NSString *, id> *)dictionaryBySettingNote:(NSString *)note
                                             inDictionary:(NSDictionary<NSString *, id> *)dictionary {
    NSMutableDictionary<NSString *, id> *updatedDictionary = [dictionary mutableCopy];
    if ([note length] > 0) {
        updatedDictionary[kKayokoItemKeyNote] = note;
    } else {
        [updatedDictionary removeObjectForKey:kKayokoItemKeyNote];
    }
    return updatedDictionary;
}

- (BOOL)dictionaryMatchesSearchText:(NSDictionary<NSString *, id> *)dictionary {
    NSString *searchText = [[[self searchCriteria] searchText]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([searchText length] == 0) {
        return YES;
    }

    NSString *imageName = dictionary[kKayokoItemKeyImageName] ?: @"";
    NSString *content = dictionary[kKayokoItemKeyContent] ?: @"";
    NSString *note = dictionary[kKayokoItemKeyNote] ?: @"";
    BOOL contentMatches =
        [imageName length] == 0 &&
        [content rangeOfString:searchText options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location !=
            NSNotFound;
    BOOL noteMatches =
        [note rangeOfString:searchText options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location !=
        NSNotFound;
    return contentMatches || noteMatches;
}

- (BOOL)displayedItemWithTagUUID:(NSString *)tagUUID matchesSearchCriteria:(KayokoSearchCriteria *)searchCriteria {
    if (![searchCriteria hasTagToken]) {
        return YES;
    }
    return [(tagUUID ?: @"") isEqualToString:([searchCriteria tagUUID] ?: @"")];
}

- (KayokoTableDataStoreDisplayedItemUpdate)updateTagUUID:(NSString *)tagUUID
                               forItemMatchingDictionary:(NSDictionary<NSString *, id> *)dictionary
                                      displayedItemIndex:(NSUInteger *)displayedItemIndex {
    if (displayedItemIndex) {
        *displayedItemIndex = NSNotFound;
    }
    if (!dictionary) {
        return KayokoTableDataStoreDisplayedItemUpdateNotFound;
    }

    NSUInteger itemIndex = [self indexOfItemMatchingDictionary:dictionary inItems:[self items]];
    if (itemIndex == NSNotFound) {
        return KayokoTableDataStoreDisplayedItemUpdateNotFound;
    }

    NSDictionary<NSString *, id> *updatedDictionary = [self dictionaryBySettingTagUUID:tagUUID
                                                                          inDictionary:[self items][itemIndex]];
    NSMutableArray<NSDictionary<NSString *, id> *> *items = [[self items] mutableCopy];
    items[itemIndex] = updatedDictionary;
    [self setItems:items];

    NSUInteger displayedIndex = [self indexOfItemMatchingDictionary:dictionary inItems:[self displayedItems]];
    if (displayedIndex == NSNotFound) {
        return KayokoTableDataStoreDisplayedItemUpdateNotFound;
    }
    if (displayedItemIndex) {
        *displayedItemIndex = displayedIndex;
    }

    if (![self displayedItemWithTagUUID:tagUUID matchesSearchCriteria:[self searchCriteria]]) {
        NSMutableArray<NSDictionary<NSString *, id> *> *displayedItems = [[self displayedItems] mutableCopy];
        [displayedItems removeObjectAtIndex:displayedIndex];
        [self setDisplayedItems:displayedItems];
        return KayokoTableDataStoreDisplayedItemUpdateRemove;
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *displayedItems = [[self displayedItems] mutableCopy];
    displayedItems[displayedIndex] = updatedDictionary;
    [self setDisplayedItems:displayedItems];
    return KayokoTableDataStoreDisplayedItemUpdateReload;
}

- (KayokoTableDataStoreDisplayedItemUpdate)updateNote:(NSString *)note
                            forItemMatchingDictionary:(NSDictionary<NSString *, id> *)dictionary
                                   displayedItemIndex:(NSUInteger *)displayedItemIndex {
    if (displayedItemIndex) {
        *displayedItemIndex = NSNotFound;
    }
    if (!dictionary) {
        return KayokoTableDataStoreDisplayedItemUpdateNotFound;
    }

    NSUInteger itemIndex = [self indexOfItemMatchingDictionary:dictionary inItems:[self items]];
    if (itemIndex == NSNotFound) {
        return KayokoTableDataStoreDisplayedItemUpdateNotFound;
    }

    NSDictionary<NSString *, id> *updatedDictionary = [self dictionaryBySettingNote:note
                                                                       inDictionary:[self items][itemIndex]];
    NSMutableArray<NSDictionary<NSString *, id> *> *items = [[self items] mutableCopy];
    items[itemIndex] = updatedDictionary;
    [self setItems:items];

    NSUInteger displayedIndex = [self indexOfItemMatchingDictionary:dictionary inItems:[self displayedItems]];
    if (displayedIndex == NSNotFound) {
        return KayokoTableDataStoreDisplayedItemUpdateNotFound;
    }
    if (displayedItemIndex) {
        *displayedItemIndex = displayedIndex;
    }

    if (![self dictionaryMatchesSearchText:updatedDictionary]) {
        NSMutableArray<NSDictionary<NSString *, id> *> *displayedItems = [[self displayedItems] mutableCopy];
        [displayedItems removeObjectAtIndex:displayedIndex];
        [self setDisplayedItems:displayedItems];
        return KayokoTableDataStoreDisplayedItemUpdateRemove;
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *displayedItems = [[self displayedItems] mutableCopy];
    displayedItems[displayedIndex] = updatedDictionary;
    [self setDisplayedItems:displayedItems];
    return KayokoTableDataStoreDisplayedItemUpdateReload;
}

@end
