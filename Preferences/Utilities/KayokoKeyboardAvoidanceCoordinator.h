//
//  KayokoKeyboardAvoidanceCoordinator.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoKeyboardAvoidanceCoordinator : NSObject

@property(nonatomic, copy, nullable) void (^keyboardBottomInsetChangeHandler)(CGFloat keyboardBottomInset);

- (instancetype)initWithView:(UIView *)view scrollView:(UIScrollView *)scrollView NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)startObserving;
- (void)stopObservingAndRestoreInsets;

@end

NS_ASSUME_NONNULL_END
