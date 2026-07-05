//
//  KayokoSearchCriteria.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kKayokoSearchTokenTypeCategory;
extern NSString *const kKayokoSearchTokenTypeApp;

extern NSString *const kKayokoSearchCategoryText;
extern NSString *const kKayokoSearchCategoryLink;
extern NSString *const kKayokoSearchCategoryPhone;
extern NSString *const kKayokoSearchCategoryDate;
extern NSString *const kKayokoSearchCategoryAddress;
extern NSString *const kKayokoSearchCategoryFlight;
extern NSString *const kKayokoSearchCategoryImage;

@interface KayokoSearchToken : NSObject <NSCopying>

@property(nonatomic, copy, readonly) NSString *type;
@property(nonatomic, copy, readonly) NSString *value;
@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly, nullable) NSString *imageName;

+ (instancetype)tokenWithType:(NSString *)type
                        value:(NSString *)value
                        title:(NSString *)title
                    imageName:(nullable NSString *)imageName;
- (instancetype)initWithType:(NSString *)type
                       value:(NSString *)value
                       title:(NSString *)title
                   imageName:(nullable NSString *)imageName NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

@interface KayokoSearchCriteria : NSObject <NSCopying>

@property(nonatomic, copy, readonly) NSString *searchText;
@property(nonatomic, copy, readonly, nullable) NSString *categoryValue;
@property(nonatomic, copy, readonly, nullable) NSString *appBundleIdentifier;
@property(nonatomic, assign, readonly) BOOL hasCategoryToken;
@property(nonatomic, assign, readonly) BOOL hasAppToken;
@property(nonatomic, assign, readonly) BOOL hasSearchText;
@property(nonatomic, assign, readonly) BOOL hasActiveFilters;

+ (instancetype)emptyCriteria;
+ (instancetype)criteriaWithSearchText:(nullable NSString *)searchText
                         categoryValue:(nullable NSString *)categoryValue
                   appBundleIdentifier:(nullable NSString *)appBundleIdentifier;

- (instancetype)initWithSearchText:(nullable NSString *)searchText
                     categoryValue:(nullable NSString *)categoryValue
               appBundleIdentifier:(nullable NSString *)appBundleIdentifier NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (KayokoSearchCriteria *)criteriaByReplacingSearchText:(nullable NSString *)searchText;
- (KayokoSearchCriteria *)criteriaBySelectingToken:(KayokoSearchToken *)token;
- (KayokoSearchCriteria *)criteriaByRemovingToken:(KayokoSearchToken *)token;
- (BOOL)isEqualToCriteria:(nullable KayokoSearchCriteria *)criteria;

@end

NS_ASSUME_NONNULL_END
