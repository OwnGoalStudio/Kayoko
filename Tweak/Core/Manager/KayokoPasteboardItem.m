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
    KayokoPasteboardItem *item = [[KayokoPasteboardItem alloc] initWithBundleIdentifier:bundleIdentifier
                                                                             andContent:content
                                                                         withImageNamed:imageName];
    id tagUUID = dictionary[kKayokoItemKeyTagUUID];
    if ([tagUUID isKindOfClass:[NSString class]] && [tagUUID length] > 0) {
        [item setTagUUID:tagUUID];
    }
    id note = dictionary[kKayokoItemKeyNote];
    if ([note isKindOfClass:[NSString class]] && [note length] > 0) {
        [item setNote:note];
    }
    return item;
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    NSMutableDictionary<NSString *, id> *dictionary = [@{
        kKayokoItemKeyBundleIdentifier : [self bundleIdentifier] ?: @"com.apple.springboard",
        kKayokoItemKeyContent : [self content] ?: @"",
        kKayokoItemKeyImageName : [self imageName] ?: @"",
        kKayokoItemKeyHasLink : @([self hasLink])
    } mutableCopy];
    if ([[self tagUUID] length] > 0) {
        dictionary[kKayokoItemKeyTagUUID] = [self tagUUID];
    }
    if ([[self note] length] > 0) {
        dictionary[kKayokoItemKeyNote] = [self note];
    }
    return dictionary;
}

@end
