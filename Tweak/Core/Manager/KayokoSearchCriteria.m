//
//  KayokoSearchCriteria.m
//  Kayoko
//

#import "KayokoSearchCriteria.h"

NSString *const kKayokoSearchTokenTypeCategory = @"category";
NSString *const kKayokoSearchTokenTypeApp = @"app";

NSString *const kKayokoSearchCategoryText = @"text";
NSString *const kKayokoSearchCategoryLink = @"link";
NSString *const kKayokoSearchCategoryPhone = @"phone";
NSString *const kKayokoSearchCategoryDate = @"date";
NSString *const kKayokoSearchCategoryAddress = @"address";
NSString *const kKayokoSearchCategoryFlight = @"flight";
NSString *const kKayokoSearchCategoryImage = @"image";

@implementation KayokoSearchToken

+ (instancetype)tokenWithType:(NSString *)type
                        value:(NSString *)value
                        title:(NSString *)title
                    imageName:(nullable NSString *)imageName {
    return [[self alloc] initWithType:type value:value title:title imageName:imageName];
}

- (instancetype)initWithType:(NSString *)type
                       value:(NSString *)value
                       title:(NSString *)title
                   imageName:(nullable NSString *)imageName {
    self = [super init];
    if (self) {
        _type = [type copy] ?: @"";
        _value = [value copy] ?: @"";
        _title = [title copy] ?: @"";
        _imageName = [imageName copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithType:[self type]
                                                     value:[self value]
                                                     title:[self title]
                                                 imageName:[self imageName]];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[KayokoSearchToken class]]) {
        return NO;
    }

    KayokoSearchToken *token = object;
    return [[self type] isEqualToString:[token type]] && [[self value] isEqualToString:[token value]];
}

- (NSUInteger)hash {
    return [[self type] hash] ^ [[self value] hash];
}

@end

@implementation KayokoSearchCriteria

+ (instancetype)emptyCriteria {
    return [[self alloc] initWithSearchText:nil categoryValue:nil appBundleIdentifier:nil];
}

+ (instancetype)criteriaWithSearchText:(nullable NSString *)searchText
                         categoryValue:(nullable NSString *)categoryValue
                   appBundleIdentifier:(nullable NSString *)appBundleIdentifier {
    return [[self alloc] initWithSearchText:searchText
                              categoryValue:categoryValue
                        appBundleIdentifier:appBundleIdentifier];
}

- (instancetype)initWithSearchText:(nullable NSString *)searchText
                     categoryValue:(nullable NSString *)categoryValue
               appBundleIdentifier:(nullable NSString *)appBundleIdentifier {
    self = [super init];
    if (self) {
        NSString *trimmedText =
            [(searchText ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        _searchText = [trimmedText copy];
        _categoryValue = [categoryValue length] > 0 ? [categoryValue copy] : nil;
        _appBundleIdentifier = [appBundleIdentifier length] > 0 ? [appBundleIdentifier copy] : nil;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithSearchText:[self searchText]
                                                   categoryValue:[self categoryValue]
                                             appBundleIdentifier:[self appBundleIdentifier]];
}

- (BOOL)hasCategoryToken {
    return [[self categoryValue] length] > 0;
}

- (BOOL)hasAppToken {
    return [[self appBundleIdentifier] length] > 0;
}

- (BOOL)hasSearchText {
    return [[self searchText] length] > 0;
}

- (BOOL)hasActiveFilters {
    return [self hasSearchText] || [self hasCategoryToken] || [self hasAppToken];
}

- (KayokoSearchCriteria *)criteriaByReplacingSearchText:(nullable NSString *)searchText {
    return [[KayokoSearchCriteria alloc] initWithSearchText:searchText
                                              categoryValue:[self categoryValue]
                                        appBundleIdentifier:[self appBundleIdentifier]];
}

- (KayokoSearchCriteria *)criteriaBySelectingToken:(KayokoSearchToken *)token {
    if ([[token type] isEqualToString:kKayokoSearchTokenTypeCategory]) {
        return [[KayokoSearchCriteria alloc] initWithSearchText:[self searchText]
                                                  categoryValue:[token value]
                                            appBundleIdentifier:[self appBundleIdentifier]];
    }
    if ([[token type] isEqualToString:kKayokoSearchTokenTypeApp]) {
        return [[KayokoSearchCriteria alloc] initWithSearchText:[self searchText]
                                                  categoryValue:[self categoryValue]
                                            appBundleIdentifier:[token value]];
    }
    return [self copy];
}

- (KayokoSearchCriteria *)criteriaByRemovingToken:(KayokoSearchToken *)token {
    NSString *categoryValue = [self categoryValue];
    NSString *appBundleIdentifier = [self appBundleIdentifier];
    if ([[token type] isEqualToString:kKayokoSearchTokenTypeCategory] &&
        [[token value] isEqualToString:categoryValue ?: @""]) {
        categoryValue = nil;
    } else if ([[token type] isEqualToString:kKayokoSearchTokenTypeApp] &&
               [[token value] isEqualToString:appBundleIdentifier ?: @""]) {
        appBundleIdentifier = nil;
    }

    return [[KayokoSearchCriteria alloc] initWithSearchText:[self searchText]
                                              categoryValue:categoryValue
                                        appBundleIdentifier:appBundleIdentifier];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[KayokoSearchCriteria class]]) {
        return NO;
    }
    return [self isEqualToCriteria:object];
}

- (BOOL)isEqualToCriteria:(KayokoSearchCriteria *)criteria {
    if (!criteria) {
        return NO;
    }

    return [[self searchText] isEqualToString:[criteria searchText]] &&
           [([self categoryValue] ?: @"") isEqualToString:([criteria categoryValue] ?: @"")] &&
           [([self appBundleIdentifier] ?: @"") isEqualToString:([criteria appBundleIdentifier] ?: @"")];
}

- (NSUInteger)hash {
    return [[self searchText] hash] ^ [[self categoryValue] hash] ^ [[self appBundleIdentifier] hash];
}

@end
