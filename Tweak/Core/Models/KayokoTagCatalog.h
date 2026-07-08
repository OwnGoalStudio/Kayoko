//
//  KayokoTagCatalog.h
//  Kayoko
//

#import <Foundation/Foundation.h>

@class KayokoTag;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTagCatalog : NSObject

+ (instancetype)sharedCatalog;
- (NSArray<KayokoTag *> *)reloadTags;
- (NSArray<KayokoTag *> *)tags;
- (nullable KayokoTag *)tagForUUID:(nullable NSString *)uuid;

@end

NS_ASSUME_NONNULL_END
