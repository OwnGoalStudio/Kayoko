//
//  KayokoPasteboardItem.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoPasteboardItem.h"

@implementation KayokoPasteboardItem

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                              andContent:(NSString *)content
                          withImageNamed:(NSString *)imageName {
    self = [super init];

    if (self) {
        [self setBundleIdentifier:bundleIdentifier];
        [self setContent:content];
        [self setImageName:imageName];
        [self setHasLink:[content hasPrefix:@"http://"] || [content hasPrefix:@"https://"]];
    }

    return self;
}

+ (KayokoPasteboardItem *)itemFromDictionary:(NSDictionary<NSString *, id> *)dictionary {
    if (!dictionary) {
        return nil;
    }

    NSString *bundleIdentifier = dictionary[kKayokoItemKeyBundleIdentifier];
    NSString *content = dictionary[kKayokoItemKeyContent];
    NSString *imageName = dictionary[kKayokoItemKeyImageName];
    return [[KayokoPasteboardItem alloc] initWithBundleIdentifier:bundleIdentifier
                                                       andContent:content
                                                   withImageNamed:imageName];
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    return @{
        kKayokoItemKeyBundleIdentifier : [self bundleIdentifier] ?: @"com.apple.springboard",
        kKayokoItemKeyContent : [self content] ?: @"",
        kKayokoItemKeyImageName : [self imageName] ?: @"",
        kKayokoItemKeyHasLink : @([self hasLink])
    };
}

@end
