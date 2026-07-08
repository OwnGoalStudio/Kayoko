//
//  KayokoTag.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kKayokoTagDictionaryKeyUUID;
extern NSString *const kKayokoTagDictionaryKeyTitle;
extern NSString *const kKayokoTagDictionaryKeyHexColor;

@interface KayokoTag : NSObject <NSCopying>

@property(nonatomic, copy) NSString *uuid;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *hexColor;

- (instancetype)initWithUUID:(NSString *)uuid
                       title:(NSString *)title
                    hexColor:(NSString *)hexColor NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)tagWithTitle:(NSString *)title hexColor:(NSString *)hexColor;
+ (nullable instancetype)tagWithDictionary:(NSDictionary<NSString *, id> *)dictionary;
+ (nullable NSString *)normalizedHexColorFromString:(NSString *)hexColor;

- (NSDictionary<NSString *, id> *)dictionaryRepresentation;

@end

NS_ASSUME_NONNULL_END
