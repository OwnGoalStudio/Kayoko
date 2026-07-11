//
//  KayokoPasteboardItem.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoPasteboardItem.h"

#import <math.h>

NSString *const kKayokoContinuityBundleIdentifier = @"com.apple.continuity";

@implementation KayokoPasteboardItem

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                              andContent:(NSString *)content
                          withImageNamed:(NSString *)imageName {
    self = [super init];

    if (self) {
        [self setBundleIdentifier:bundleIdentifier];
        [self setContent:content];
        [self setImageName:imageName];
        [self setRichTextName:@""];
        [self setCapturedAt:[NSDate date]];
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
    id capturedAt = dictionary[kKayokoItemKeyCapturedAt];
    if ([capturedAt isKindOfClass:[NSNumber class]]) {
        NSTimeInterval capturedAtTimestamp = [capturedAt doubleValue];
        if (isfinite(capturedAtTimestamp) && capturedAtTimestamp > 0.0) {
            [item setCapturedAt:[NSDate dateWithTimeIntervalSince1970:capturedAtTimestamp]];
        }
    }
    id imagePixelWidth = dictionary[kKayokoItemKeyImagePixelWidth];
    id imagePixelHeight = dictionary[kKayokoItemKeyImagePixelHeight];
    if ([imagePixelWidth isKindOfClass:[NSNumber class]] && [imagePixelHeight isKindOfClass:[NSNumber class]]) {
        NSInteger width = [imagePixelWidth integerValue];
        NSInteger height = [imagePixelHeight integerValue];
        if (width > 0 && height > 0) {
            [item setImagePixelWidth:(NSUInteger)width];
            [item setImagePixelHeight:(NSUInteger)height];
        }
    }
    id richTextUTI = dictionary[kKayokoItemKeyRichTextUTI];
    id richTextName = dictionary[kKayokoItemKeyRichTextName];
    if ([richTextUTI isKindOfClass:[NSString class]] && [richTextUTI length] > 0 &&
        [richTextName isKindOfClass:[NSString class]] && [richTextName length] > 0) {
        [item setRichTextUTI:richTextUTI];
        [item setRichTextName:richTextName];
    }
    id imageByteCount = dictionary[kKayokoItemKeyImageByteCount];
    if ([imageByteCount isKindOfClass:[NSNumber class]] && [imageByteCount longLongValue] > 0) {
        [item setImageByteCount:[imageByteCount unsignedLongLongValue]];
    }
    return item;
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    NSTimeInterval capturedAtTimestamp = [[self capturedAt] timeIntervalSince1970];
    if (!isfinite(capturedAtTimestamp) || capturedAtTimestamp <= 0.0) {
        capturedAtTimestamp = [[NSDate date] timeIntervalSince1970];
    }
    NSMutableDictionary<NSString *, id> *dictionary = [@{
        kKayokoItemKeyBundleIdentifier : [self bundleIdentifier] ?: @"com.apple.springboard",
        kKayokoItemKeyContent : [self content] ?: @"",
        kKayokoItemKeyImageName : [self imageName] ?: @"",
        kKayokoItemKeyHasLink : @([self hasLink]),
        kKayokoItemKeyCapturedAt : @(capturedAtTimestamp),
        kKayokoItemKeyImagePixelWidth : @([self imagePixelWidth]),
        kKayokoItemKeyImagePixelHeight : @([self imagePixelHeight]),
        kKayokoItemKeyImageByteCount : @([self imageByteCount])
    } mutableCopy];
    if ([[self tagUUID] length] > 0) {
        dictionary[kKayokoItemKeyTagUUID] = [self tagUUID];
    }
    if ([[self note] length] > 0) {
        dictionary[kKayokoItemKeyNote] = [self note];
    }
    if ([[self richTextUTI] length] > 0 && [[self richTextName] length] > 0) {
        dictionary[kKayokoItemKeyRichTextUTI] = [self richTextUTI];
        dictionary[kKayokoItemKeyRichTextName] = [self richTextName];
    }
    return dictionary;
}

@end
