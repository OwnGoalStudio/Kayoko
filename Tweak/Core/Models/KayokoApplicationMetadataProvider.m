//
//  KayokoApplicationMetadataProvider.m
//  Kayoko
//

#import "KayokoApplicationMetadataProvider.h"
#import "KayokoPasteboardManager.h"

#import <objc/runtime.h>

static int const kKayokoApplicationIconFormatListRow = 1;
static int const kKayokoApplicationIconFormatSearchToken = 5;

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (IconCache)
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

@interface KayokoApplicationMetadataProvider ()
@property(nonatomic, strong) NSCache<NSString *, UIImage *> *iconCache;
@end

@implementation KayokoApplicationMetadataProvider

- (instancetype)init {
    self = [super init];
    if (self) {
        _iconCache = [[NSCache alloc] init];
        [_iconCache setCountLimit:256];
    }
    return self;
}

- (NSString *)displayNameForBundleIdentifier:(NSString *)bundleIdentifier {
    if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        return [[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"SpringBoard"
                                                                             value:nil
                                                                             table:@"Tweak"];
    }

    NSString *displayName = [[[objc_getClass("SBApplicationController") sharedInstance]
        applicationWithBundleIdentifier:bundleIdentifier] displayName];
    return [displayName length] > 0 ? displayName : bundleIdentifier;
}

- (NSString *)iconCacheKeyForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale {
    NSString *cacheBundleIdentifier = [bundleIdentifier length] > 0 ? bundleIdentifier : @"com.apple.WebSheet";
    return [NSString stringWithFormat:@"%@|%d|%.2f", cacheBundleIdentifier, format, scale];
}

- (nullable UIImage *)applicationIconForBundleIdentifier:(NSString *)bundleIdentifier
                                                  format:(int)format
                                                   scale:(CGFloat)scale {
    NSString *effectiveBundleIdentifier = [bundleIdentifier length] > 0 ? bundleIdentifier : @"com.apple.WebSheet";
    NSString *cacheKey = [self iconCacheKeyForBundleIdentifier:effectiveBundleIdentifier format:format scale:scale];
    UIImage *cachedIcon = [[self iconCache] objectForKey:cacheKey];
    if (cachedIcon) {
        return cachedIcon;
    }

    UIImage *icon = [UIImage _applicationIconImageForBundleIdentifier:effectiveBundleIdentifier
                                                               format:format
                                                                scale:scale];
    if (!icon) {
        NSString *fallbackCacheKey = [self iconCacheKeyForBundleIdentifier:@"com.apple.WebSheet"
                                                                    format:format
                                                                     scale:scale];
        icon = [[self iconCache] objectForKey:fallbackCacheKey];
        if (!icon) {
            icon = [UIImage _applicationIconImageForBundleIdentifier:@"com.apple.WebSheet" format:format scale:scale];
            if (icon) {
                [[self iconCache] setObject:icon forKey:fallbackCacheKey];
            }
        }
    }

    if (icon) {
        [[self iconCache] setObject:icon forKey:cacheKey];
    }
    return icon;
}

- (nullable UIImage *)iconForBundleIdentifier:(NSString *)bundleIdentifier {
    if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        BOOL isPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
        return [UIImage imageNamed:isPad ? @"HLS_iPad_Universal" : @"HLS_iPhone_Universal"
                                 inBundle:[KayokoPasteboardManager localizationBundle]
            compatibleWithTraitCollection:nil];
    }

    return [self applicationIconForBundleIdentifier:bundleIdentifier
                                             format:kKayokoApplicationIconFormatListRow
                                              scale:[[UIScreen mainScreen] scale]];
}

- (nullable UIImage *)smallIconForBundleIdentifier:(NSString *)bundleIdentifier {
    return [self applicationIconForBundleIdentifier:bundleIdentifier
                                             format:kKayokoApplicationIconFormatSearchToken
                                              scale:[[UIScreen mainScreen] scale]];
}

@end
