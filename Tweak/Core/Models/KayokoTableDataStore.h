//
//  KayokoTableDataStore.h
//  Kayoko
//

#import <Foundation/Foundation.h>

@class KayokoSearchCriteria;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, KayokoTableDataStoreDisplayedItemUpdate) {
    KayokoTableDataStoreDisplayedItemUpdateNotFound = 0,
    KayokoTableDataStoreDisplayedItemUpdateReload,
    KayokoTableDataStoreDisplayedItemUpdateRemove,
};

@interface KayokoTableDataStore : NSObject

@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *items;
@property(nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *displayedItems;
@property(nonatomic, copy, readonly) NSString *searchText;
@property(nonatomic, strong, readonly) KayokoSearchCriteria *searchCriteria;
@property(nonatomic, assign, readonly, getter=isBrowsingSearchTokens) BOOL browsingSearchTokens;
@property(nonatomic, assign, readonly) BOOL hasActiveSearch;

- (void)applySearchText:(NSString *)searchText;
- (void)beginApplyingSearchCriteria:(KayokoSearchCriteria *)searchCriteria;
- (void)applySearchCriteria:(KayokoSearchCriteria *)searchCriteria
              filteredItems:(NSArray<NSDictionary<NSString *, id> *> *)filteredItems;
- (void)showSearchTokensWithFullListForCriteria:(KayokoSearchCriteria *)searchCriteria;
- (void)clearSearch;
- (NSUInteger)indexOfItemMatchingDictionary:(NSDictionary<NSString *, id> *)dictionary
                                    inItems:(NSArray<NSDictionary<NSString *, id> *> *)items;
- (KayokoTableDataStoreDisplayedItemUpdate)updateTagUUID:(nullable NSString *)tagUUID
                               forItemMatchingDictionary:(NSDictionary<NSString *, id> *)dictionary
                                      displayedItemIndex:(NSUInteger *)displayedItemIndex;
- (KayokoTableDataStoreDisplayedItemUpdate)updateNote:(nullable NSString *)note
                            forItemMatchingDictionary:(NSDictionary<NSString *, id> *)dictionary
                                   displayedItemIndex:(NSUInteger *)displayedItemIndex;

@end

NS_ASSUME_NONNULL_END
