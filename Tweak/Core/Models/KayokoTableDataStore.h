//
//  KayokoTableDataStore.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableDataStore : NSObject

@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *items;
@property(nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *displayedItems;
@property(nonatomic, copy, readonly) NSString *searchText;
@property(nonatomic, assign, readonly) BOOL hasActiveSearch;

- (void)applySearchText:(NSString *)searchText;
- (NSUInteger)indexOfItemMatchingDictionary:(NSDictionary<NSString *, id> *)dictionary
                                    inItems:(NSArray<NSDictionary<NSString *, id> *> *)items;

@end

NS_ASSUME_NONNULL_END
