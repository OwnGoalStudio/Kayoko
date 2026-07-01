//
//  KayokoApplicationMetadataProvider.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoApplicationMetadataProvider : NSObject

- (NSString *)displayNameForBundleIdentifier:(NSString *)bundleIdentifier;
- (nullable UIImage *)iconForBundleIdentifier:(NSString *)bundleIdentifier;

@end

NS_ASSUME_NONNULL_END
