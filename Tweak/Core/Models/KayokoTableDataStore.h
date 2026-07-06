//
//  KayokoTableDataStore.h
//  Kayoko
//

#import <Foundation/Foundation.h>

@class KayokoSearchCriteria;

NS_ASSUME_NONNULL_BEGIN

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

@end

NS_ASSUME_NONNULL_END
