//
//  KayokoWordTokenView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoWordTokenView : UIControl

@property(nonatomic, strong, readonly) UILabel *titleLabel;
@property(nonatomic, assign) UIEdgeInsets kayokoContentInsets;

- (void)setTitle:(NSString *)title forState:(UIControlState)state;
- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state;

@end

NS_ASSUME_NONNULL_END
