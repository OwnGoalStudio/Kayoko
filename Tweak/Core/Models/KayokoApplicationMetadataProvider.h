//
//  KayokoApplicationMetadataProvider.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoApplicationMetadataProvider : NSObject

- (NSString *)displayNameForBundleIdentifier:(NSString *)bundleIdentifier;
- (BOOL)hasApplicationForBundleIdentifier:(NSString *)bundleIdentifier;
- (nullable UIImage *)iconForBundleIdentifier:(NSString *)bundleIdentifier;
- (nullable UIImage *)smallIconForBundleIdentifier:(NSString *)bundleIdentifier;

@end

NS_ASSUME_NONNULL_END
