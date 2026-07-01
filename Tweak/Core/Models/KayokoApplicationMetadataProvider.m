//
//  KayokoApplicationMetadataProvider.m
//  Kayoko
//

#import "KayokoApplicationMetadataProvider.h"

#import "PasteboardManager.h"

#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (KayokoApplicationMetadataProviderPrivate)
+ (nullable instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier
                                                           format:(int)format
                                                            scale:(CGFloat)scale;
@end

@interface SBApplication : NSObject
@property(nonatomic, copy, readonly) NSString *displayName;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)bundleIdentifier;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoApplicationMetadataProvider

- (NSString *)displayNameForBundleIdentifier:(NSString *)bundleIdentifier {
    if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        return [[PasteboardManager localizationBundle] localizedStringForKey:@"SpringBoard" value:nil table:@"Tweak"];
    }

    NSString *displayName = [[[objc_getClass("SBApplicationController") sharedInstance]
        applicationWithBundleIdentifier:bundleIdentifier] displayName];
    return [displayName length] > 0 ? displayName : bundleIdentifier;
}

- (UIImage *)iconForBundleIdentifier:(NSString *)bundleIdentifier {
    UIImage *icon = nil;
    if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        BOOL isPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
        icon = [UIImage imageNamed:isPad ? @"HLS_iPad_Universal" : @"HLS_iPhone_Universal"
                                 inBundle:[PasteboardManager localizationBundle]
            compatibleWithTraitCollection:nil];
    } else {
        icon = [UIImage _applicationIconImageForBundleIdentifier:bundleIdentifier
                                                          format:2
                                                           scale:[[UIScreen mainScreen] scale]];
    }
    if (!icon) {
        icon = [UIImage _applicationIconImageForBundleIdentifier:@"com.apple.WebSheet"
                                                          format:2
                                                           scale:[[UIScreen mainScreen] scale]];
    }
    return icon;
}

@end
