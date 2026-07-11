//
//  KayokoPasteboardItem.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kKayokoContinuityBundleIdentifier;

static NSString *const kKayokoItemKeyBundleIdentifier = @"bundle_identifier";
static NSString *const kKayokoItemKeyContent = @"content";
static NSString *const kKayokoItemKeyImageName = @"image_name";
static NSString *const kKayokoItemKeyHasLink = @"has_link";
static NSString *const kKayokoItemKeyTagUUID = @"tag_uuid";
static NSString *const kKayokoItemKeyNote = @"note";
static NSString *const kKayokoItemKeyCapturedAt = @"captured_at";
static NSString *const kKayokoItemKeyImagePixelWidth = @"image_width";
static NSString *const kKayokoItemKeyImagePixelHeight = @"image_height";
static NSString *const kKayokoItemKeyRichTextUTI = @"rich_text_uti";
static NSString *const kKayokoItemKeyRichTextName = @"rich_text_name";
static NSString *const kKayokoItemKeyImageByteCount = @"image_byte_count";

@interface KayokoPasteboardItem : NSObject

@property(nonatomic, copy) NSString *bundleIdentifier;
@property(nonatomic, copy) NSString *displayName;
@property(nonatomic, copy) NSString *content;
@property(nonatomic, copy) NSString *imageName;
@property(nonatomic, copy, nullable) NSString *tagUUID;
@property(nonatomic, copy, nullable) NSString *note;
@property(nonatomic, copy) NSDate *capturedAt;
@property(nonatomic, assign) NSUInteger imagePixelWidth;
@property(nonatomic, assign) NSUInteger imagePixelHeight;
@property(nonatomic, copy, nullable) NSString *richTextUTI;
@property(nonatomic, copy) NSString *richTextName;
@property(nonatomic, assign) unsigned long long imageByteCount;
@property(nonatomic, assign) BOOL hasLink;

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                              andContent:(NSString *)content
                          withImageNamed:(nullable NSString *)imageName;

+ (nullable KayokoPasteboardItem *)itemFromDictionary:(nullable NSDictionary<NSString *, id> *)dictionary;
- (NSDictionary<NSString *, id> *)dictionaryRepresentation;

@end

NS_ASSUME_NONNULL_END
