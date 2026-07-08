//
//  KayokoTagColorFormatter.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTagColorFormatter : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (UIColor *)colorFromHexColor:(nullable NSString *)hexColor;
+ (UIColor *)visibleColorFromHexColor:(nullable NSString *)hexColor;
+ (UIColor *)borderColorFromHexColor:(nullable NSString *)hexColor;
+ (UIImage *)dotImageWithHexColor:(nullable NSString *)hexColor diameter:(CGFloat)diameter;
+ (UIImage *)dotImageWithHexColor:(nullable NSString *)hexColor
                         diameter:(CGFloat)diameter
                   canvasDiameter:(CGFloat)canvasDiameter;
+ (UIImage *)dotImageWithHexColor:(nullable NSString *)hexColor
                         diameter:(CGFloat)diameter
                   canvasDiameter:(CGFloat)canvasDiameter
                      borderWidth:(CGFloat)borderWidth;

@end

NS_ASSUME_NONNULL_END
