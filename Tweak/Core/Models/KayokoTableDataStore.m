//
//  KayokoTableDataStore.m
//  Kayoko
//

#import "KayokoTableDataStore.h"

#import "KayokoPasteboardItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableDataStore ()
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *displayedItems;
@property(nonatomic, copy) NSString *searchText;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoTableDataStore

- (instancetype)init {
    self = [super init];
    if (self) {
        _items = @[];
        _displayedItems = @[];
        _searchText = @"";
    }
    return self;
}

- (BOOL)hasActiveSearch {
    return [[self searchText] length] > 0;
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
    [self refreshDisplayedItems];
}

- (void)applySearchText:(NSString *)searchText {
    _searchText = [searchText copy] ?: @"";
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
