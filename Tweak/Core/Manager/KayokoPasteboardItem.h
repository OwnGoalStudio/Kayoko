//
//  KayokoPasteboardItem.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const kKayokoItemKeyBundleIdentifier = @"bundle_identifier";
static NSString *const kKayokoItemKeyContent = @"content";
static NSString *const kKayokoItemKeyImageName = @"image_name";
static NSString *const kKayokoItemKeyHasLink = @"has_link";

@interface KayokoPasteboardItem : NSObject

@property(nonatomic, copy) NSString *bundleIdentifier;
@property(nonatomic, copy) NSString *displayName;
@property(nonatomic, copy) NSString *content;
@property(nonatomic, copy) NSString *imageName;
@property(nonatomic, assign) BOOL hasLink;

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                              andContent:(NSString *)content
                          withImageNamed:(nullable NSString *)imageName;

+ (nullable KayokoPasteboardItem *)itemFromDictionary:(nullable NSDictionary<NSString *, id> *)dictionary;
- (NSDictionary<NSString *, id> *)dictionaryRepresentation;

@end

NS_ASSUME_NONNULL_END
