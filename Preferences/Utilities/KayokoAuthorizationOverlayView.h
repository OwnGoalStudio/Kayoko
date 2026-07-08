//
//  KayokoAuthorizationOverlayView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoAuthorizationOverlayView : UIView

@property(nonatomic, copy, nullable) void (^retryHandler)(void);

- (void)setCheckingTitle:(NSString *)title subtitle:(nullable NSString *)subtitle;
- (void)setFailureTitle:(NSString *)title subtitle:(NSString *)subtitle retryEnabled:(BOOL)retryEnabled;

@end

NS_ASSUME_NONNULL_END
