//
//  KayokoHelperProcessContext.h
//  Kayoko
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, KayokoHelperProcessKind) {
    KayokoHelperProcessKindUnsupported = 0,
    KayokoHelperProcessKindApplication,
    KayokoHelperProcessKindSpringBoard,
    KayokoHelperProcessKindKeyboardExtension,
};

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHelperProcessContext : NSObject

@property(nonatomic, assign, readonly) KayokoHelperProcessKind kind;

+ (instancetype)currentContext;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
