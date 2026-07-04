#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoKeyboardShortcutSender : NSObject

+ (instancetype)sharedSender;
- (void)sendCommandV;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
