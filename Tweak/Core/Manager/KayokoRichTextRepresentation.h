//
//  KayokoRichTextRepresentation.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoRichTextRepresentation : NSObject

@property(nonatomic, copy, readonly) NSString *typeIdentifier;
@property(nonatomic, copy, readonly) NSData *data;
@property(nonatomic, copy, readonly) NSString *fileExtension;

+ (nullable instancetype)preferredRepresentationFromDictionary:(NSDictionary<NSString *, id> *)dictionary;
- (nullable NSString *)plainText;
- (NSString *)stableFileName;

@end

NS_ASSUME_NONNULL_END
