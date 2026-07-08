//
//  KayokoTag.m
//  Kayoko
//

#import "KayokoTag.h"

NSString *const kKayokoTagDictionaryKeyUUID = @"uuid";
NSString *const kKayokoTagDictionaryKeyTitle = @"title";
NSString *const kKayokoTagDictionaryKeyHexColor = @"hexColor";

@implementation KayokoTag

- (instancetype)initWithUUID:(NSString *)uuid title:(NSString *)title hexColor:(NSString *)hexColor {
    self = [super init];
    if (self) {
        _uuid = [([uuid length] > 0 ? uuid : [[NSUUID UUID] UUIDString]) copy];
        _title = [(title ?: @"") copy];
        _hexColor = [([KayokoTag normalizedHexColorFromString:hexColor] ?: @"#00000000") copy];
    }
    return self;
}

+ (instancetype)tagWithTitle:(NSString *)title hexColor:(NSString *)hexColor {
    return [[self alloc] initWithUUID:[[NSUUID UUID] UUIDString] title:title hexColor:hexColor];
}

+ (instancetype)tagWithDictionary:(NSDictionary<NSString *, id> *)dictionary {
    id uuid = dictionary[kKayokoTagDictionaryKeyUUID];
    id title = dictionary[kKayokoTagDictionaryKeyTitle];
    id hexColor = dictionary[kKayokoTagDictionaryKeyHexColor];
    if (![uuid isKindOfClass:[NSString class]] || ![title isKindOfClass:[NSString class]] ||
        ![hexColor isKindOfClass:[NSString class]]) {
        return nil;
    }
    if ([uuid length] == 0) {
        return nil;
    }

    NSString *normalizedHexColor = [self normalizedHexColorFromString:hexColor];
    if (!normalizedHexColor) {
        return nil;
    }

    return [[self alloc] initWithUUID:uuid title:title hexColor:normalizedHexColor];
}

+ (NSString *)normalizedHexColorFromString:(NSString *)hexColor {
    if (![hexColor isKindOfClass:[NSString class]]) {
        return nil;
    }

    NSString *candidate = [hexColor stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([candidate hasPrefix:@"#"]) {
        candidate = [candidate substringFromIndex:1];
    }
    if ([candidate length] == 6) {
        candidate = [candidate stringByAppendingString:@"FF"];
    }
    if ([candidate length] != 8) {
        return nil;
    }

    NSCharacterSet *nonHexCharacters =
        [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet];
    if ([candidate rangeOfCharacterFromSet:nonHexCharacters].location != NSNotFound) {
        return nil;
    }

    return [@"#" stringByAppendingString:[candidate uppercaseString]];
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    return @{
        kKayokoTagDictionaryKeyUUID : [self uuid] ?: @"",
        kKayokoTagDictionaryKeyTitle : [self title] ?: @"",
        kKayokoTagDictionaryKeyHexColor : [self hexColor] ?: @"#00000000"
    };
}

- (id)copyWithZone:(NSZone *)zone {
    KayokoTag *tag = [[[self class] allocWithZone:zone] initWithUUID:[self uuid]
                                                               title:[self title]
                                                            hexColor:[self hexColor]];
    return tag;
}

@end
