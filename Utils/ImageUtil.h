//
//  ImageUtil.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageUtil : NSObject
+ (BOOL)imageHasAlpha:(UIImage *)image;
+ (UIImage *)getRotatedImageFromImage:(UIImage *)image;
+ (UIImage *)getImageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize;
@end

NS_ASSUME_NONNULL_END
