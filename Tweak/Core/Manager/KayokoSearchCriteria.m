//
//  KayokoSearchCriteria.m
//  Kayoko
//

#import "KayokoSearchCriteria.h"

NSString *const kKayokoSearchTokenTypeCategory = @"category";
NSString *const kKayokoSearchTokenTypeApp = @"app";
NSString *const kKayokoSearchTokenTypeTag = @"tag";

NSString *const kKayokoSearchCategoryText = @"text";
NSString *const kKayokoSearchCategoryLink = @"link";
NSString *const kKayokoSearchCategoryPhone = @"phone";
NSString *const kKayokoSearchCategoryDate = @"date";
NSString *const kKayokoSearchCategoryAddress = @"address";
NSString *const kKayokoSearchCategoryFlight = @"flight";
NSString *const kKayokoSearchCategoryImage = @"image";

@implementation KayokoSearchToken

#pragma mark - Construction

+ (instancetype)tokenWithType:(NSString *)type
                        value:(NSString *)value
                        title:(NSString *)title
                    imageName:(nullable NSString *)imageName {
    return [[self alloc] initWithType:type value:value title:title imageName:imageName displaySignature:nil];
}

+ (instancetype)tokenWithType:(NSString *)type
                        value:(NSString *)value
                        title:(NSString *)title
                    imageName:(nullable NSString *)imageName
             displaySignature:(nullable NSString *)displaySignature {
    return [[self alloc] initWithType:type
                                value:value
                                title:title
                            imageName:imageName
                     displaySignature:displaySignature];
}

- (instancetype)initWithType:(NSString *)type
                       value:(NSString *)value
                       title:(NSString *)title
                   imageName:(nullable NSString *)imageName {
    return [self initWithType:type value:value title:title imageName:imageName displaySignature:nil];
}

- (instancetype)initWithType:(NSString *)type
                       value:(NSString *)value
                       title:(NSString *)title
                   imageName:(nullable NSString *)imageName
            displaySignature:(nullable NSString *)displaySignature {
    self = [super init];
    if (self) {
        _type = [type copy] ?: @"";
        _value = [value copy] ?: @"";
        _title = [title copy] ?: @"";
        _imageName = [imageName copy];
        _displaySignature = [displaySignature copy];
    }
    return self;
}

#pragma mark - Copying

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithType:[self type]
                                                     value:[self value]
                                                     title:[self title]
                                                 imageName:[self imageName]
                                          displaySignature:[self displaySignature]];
}

- (BOOL)isDisplayEqualToToken:(nullable KayokoSearchToken *)token {
    if (self == token) {
        return YES;
    }
    if (![token isKindOfClass:[KayokoSearchToken class]]) {
        return NO;
    }

    return [[self type] isEqualToString:[token type]] && [[self value] isEqualToString:[token value]] &&
           [[self title] isEqualToString:[token title]] &&
           [([self imageName] ?: @"") isEqualToString:([token imageName] ?: @"")] &&
           [([self displaySignature] ?: @"") isEqualToString:([token displaySignature] ?: @"")];
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

#pragma mark - Construction

+ (instancetype)emptyCriteria {
    return [[self alloc] initWithSearchText:nil categoryValue:nil appBundleIdentifier:nil tagUUID:nil];
}

+ (instancetype)criteriaWithSearchText:(nullable NSString *)searchText
                         categoryValue:(nullable NSString *)categoryValue
                   appBundleIdentifier:(nullable NSString *)appBundleIdentifier
                               tagUUID:(nullable NSString *)tagUUID {
    return [[self alloc] initWithSearchText:searchText
                              categoryValue:categoryValue
                        appBundleIdentifier:appBundleIdentifier
                                    tagUUID:tagUUID];
}

- (instancetype)initWithSearchText:(nullable NSString *)searchText
                     categoryValue:(nullable NSString *)categoryValue
               appBundleIdentifier:(nullable NSString *)appBundleIdentifier
                           tagUUID:(nullable NSString *)tagUUID {
    self = [super init];
    if (self) {
        NSString *trimmedText =
            [(searchText ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        _searchText = [trimmedText copy];
        _categoryValue = [categoryValue length] > 0 ? [categoryValue copy] : nil;
        _appBundleIdentifier = [appBundleIdentifier length] > 0 ? [appBundleIdentifier copy] : nil;
        _tagUUID = [tagUUID length] > 0 ? [tagUUID copy] : nil;
    }
    return self;
}

#pragma mark - Copying

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithSearchText:[self searchText]
                                                   categoryValue:[self categoryValue]
                                             appBundleIdentifier:[self appBundleIdentifier]
                                                         tagUUID:[self tagUUID]];
}

- (BOOL)hasCategoryToken {
    return [[self categoryValue] length] > 0;
}

- (BOOL)hasAppToken {
    return [[self appBundleIdentifier] length] > 0;
}

- (BOOL)hasTagToken {
    return [[self tagUUID] length] > 0;
}

- (BOOL)hasSearchText {
    return [[self searchText] length] > 0;
}

- (BOOL)hasActiveFilters {
    return [self hasSearchText] || [self hasCategoryToken] || [self hasAppToken] || [self hasTagToken];
}

#pragma mark - Mutations

- (KayokoSearchCriteria *)criteriaByReplacingSearchText:(nullable NSString *)searchText {
    return [[KayokoSearchCriteria alloc] initWithSearchText:searchText
                                              categoryValue:[self categoryValue]
                                        appBundleIdentifier:[self appBundleIdentifier]
                                                    tagUUID:[self tagUUID]];
}

- (KayokoSearchCriteria *)criteriaBySelectingToken:(KayokoSearchToken *)token {
    if ([[token type] isEqualToString:kKayokoSearchTokenTypeCategory]) {
        return [[KayokoSearchCriteria alloc] initWithSearchText:[self searchText]
                                                  categoryValue:[token value]
                                            appBundleIdentifier:[self appBundleIdentifier]
                                                        tagUUID:[self tagUUID]];
    }
    if ([[token type] isEqualToString:kKayokoSearchTokenTypeApp]) {
        return [[KayokoSearchCriteria alloc] initWithSearchText:[self searchText]
                                                  categoryValue:[self categoryValue]
                                            appBundleIdentifier:[token value]
                                                        tagUUID:[self tagUUID]];
    }
    if ([[token type] isEqualToString:kKayokoSearchTokenTypeTag]) {
        return [[KayokoSearchCriteria alloc] initWithSearchText:[self searchText]
                                                  categoryValue:[self categoryValue]
                                            appBundleIdentifier:[self appBundleIdentifier]
                                                        tagUUID:[token value]];
    }
    return [self copy];
}

- (KayokoSearchCriteria *)criteriaByRemovingToken:(KayokoSearchToken *)token {
    NSString *categoryValue = [self categoryValue];
    NSString *appBundleIdentifier = [self appBundleIdentifier];
    NSString *tagUUID = [self tagUUID];
    if ([[token type] isEqualToString:kKayokoSearchTokenTypeCategory] &&
        [[token value] isEqualToString:categoryValue ?: @""]) {
        categoryValue = nil;
    } else if ([[token type] isEqualToString:kKayokoSearchTokenTypeApp] &&
               [[token value] isEqualToString:appBundleIdentifier ?: @""]) {
        appBundleIdentifier = nil;
    } else if ([[token type] isEqualToString:kKayokoSearchTokenTypeTag] &&
               [[token value] isEqualToString:tagUUID ?: @""]) {
        tagUUID = nil;
    }

    return [[KayokoSearchCriteria alloc] initWithSearchText:[self searchText]
                                              categoryValue:categoryValue
                                        appBundleIdentifier:appBundleIdentifier
                                                    tagUUID:tagUUID];
}

#pragma mark - Equality

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
           [([self appBundleIdentifier] ?: @"") isEqualToString:([criteria appBundleIdentifier] ?: @"")] &&
           [([self tagUUID] ?: @"") isEqualToString:([criteria tagUUID] ?: @"")];
}

- (NSUInteger)hash {
    return [[self searchText] hash] ^ [[self categoryValue] hash] ^ [[self appBundleIdentifier] hash] ^
           [[self tagUUID] hash];
}

@end
