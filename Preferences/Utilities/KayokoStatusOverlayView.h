//
//  KayokoStatusOverlayView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoStatusOverlayView : UIView

@property(nonatomic, copy, nullable) void (^tapHandler)(void);

- (void)setLoadingTitle:(NSString *)title subtitle:(nullable NSString *)subtitle;
- (void)setFailureTitle:(NSString *)title subtitle:(NSString *)subtitle actionEnabled:(BOOL)actionEnabled;
- (void)setSuccessTitle:(NSString *)title subtitle:(NSString *)subtitle actionEnabled:(BOOL)actionEnabled;
- (void)animateAppearance;
- (void)animateDisappearanceWithCompletion:(nullable void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
