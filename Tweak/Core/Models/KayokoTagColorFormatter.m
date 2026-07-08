//
//  KayokoTagColorFormatter.m
//  Kayoko
//

#import "KayokoTagColorFormatter.h"

#import "KayokoTag.h"

@interface KayokoTagColorFormatter ()
+ (UIColor *)borderColorForVisibleColor:(UIColor *)color;
@end

@implementation KayokoTagColorFormatter

+ (UIColor *)colorFromHexColor:(NSString *)hexColor {
    NSString *candidate = [KayokoTag normalizedHexColorFromString:hexColor] ?: @"#00000000";
    NSString *valueString = [candidate substringFromIndex:1];
    unsigned long long value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:valueString];
    [scanner scanHexLongLong:&value];

    CGFloat red = (CGFloat)((value >> 24) & 0xFF) / 255.0;
    CGFloat green = (CGFloat)((value >> 16) & 0xFF) / 255.0;
    CGFloat blue = (CGFloat)((value >> 8) & 0xFF) / 255.0;
    CGFloat alpha = (CGFloat)(value & 0xFF) / 255.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

+ (UIColor *)visibleColorFromHexColor:(NSString *)hexColor {
    UIColor *color = [self colorFromHexColor:hexColor];
    CGFloat red = 0.0;
    CGFloat green = 0.0;
    CGFloat blue = 0.0;
    CGFloat alpha = 0.0;
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha] || alpha < 0.08) {
        return [UIColor tertiaryLabelColor];
    }
    return [UIColor colorWithRed:red green:green blue:blue alpha:MAX(alpha, 0.78)];
}

+ (UIColor *)borderColorFromHexColor:(NSString *)hexColor {
    return [self borderColorForVisibleColor:[self visibleColorFromHexColor:hexColor]];
}

+ (UIImage *)dotImageWithHexColor:(NSString *)hexColor diameter:(CGFloat)diameter {
    return [self dotImageWithHexColor:hexColor diameter:diameter canvasDiameter:diameter];
}

+ (UIImage *)dotImageWithHexColor:(NSString *)hexColor
                         diameter:(CGFloat)diameter
                   canvasDiameter:(CGFloat)canvasDiameter {
    return [self dotImageWithHexColor:hexColor diameter:diameter canvasDiameter:canvasDiameter borderWidth:0];
}

+ (UIImage *)dotImageWithHexColor:(NSString *)hexColor
                         diameter:(CGFloat)diameter
                   canvasDiameter:(CGFloat)canvasDiameter
                      borderWidth:(CGFloat)borderWidth {
    CGFloat normalizedCanvasDiameter = MAX(canvasDiameter, diameter);
    CGSize size = CGSizeMake(normalizedCanvasDiameter, normalizedCanvasDiameter);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGFloat origin = (normalizedCanvasDiameter - diameter) / 2.0;
    CGRect rect = CGRectMake(origin, origin, diameter, diameter);
    UIColor *color = [self visibleColorFromHexColor:hexColor];
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillEllipseInRect(context, rect);
    if (borderWidth > 0) {
        CGRect strokeRect = CGRectInset(rect, borderWidth / 2.0, borderWidth / 2.0);
        CGContextSetLineWidth(context, borderWidth);
        CGContextSetStrokeColorWithColor(context, [[self borderColorForVisibleColor:color] CGColor]);
        CGContextStrokeEllipseInRect(context, strokeRect);
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

+ (UIColor *)borderColorForVisibleColor:(UIColor *)color {
    CGFloat hue = 0.0;
    CGFloat saturation = 0.0;
    CGFloat brightness = 0.0;
    CGFloat alpha = 0.0;
    if (![color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
        return [[UIColor labelColor] colorWithAlphaComponent:0.18];
    }

    CGFloat borderBrightness = saturation < 0.05 ? brightness * 0.87 : brightness * 0.94;
    return [UIColor colorWithHue:hue
                      saturation:MIN(saturation + 0.10, 1.0)
                      brightness:MAX(MIN(borderBrightness, 1.0), 0.0)
                           alpha:MAX(alpha, 0.86)];
}

@end
