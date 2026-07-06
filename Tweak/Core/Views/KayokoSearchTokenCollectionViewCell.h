//
//  KayokoSearchTokenCollectionViewCell.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchTokenCollectionViewCell : UICollectionViewCell
+ (NSString *)reuseIdentifier;
- (void)configureWithTitle:(NSString *)title icon:(nullable UIImage *)icon;
@end

NS_ASSUME_NONNULL_END
