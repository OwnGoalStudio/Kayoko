//
//  KayokoTagPlaceholderView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTagPlaceholderView : UIView

@property(nonatomic, assign) CGFloat keyboardBottomInset;

- (instancetype)initWithMessage:(NSString *)message NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (void)setMessage:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
