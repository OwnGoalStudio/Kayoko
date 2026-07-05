//
//  KayokoHelperConfiguration.h
//  Kayoko
//

#import "KayokoPreferenceKeys.h"

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHelperConfiguration : NSObject

@property(nonatomic, assign, readonly, getter=isEnabled) BOOL enabled;
@property(nonatomic, assign, readonly) NSUInteger activationMethod;
@property(nonatomic, assign, readonly) KayokoGestureRecognizerMode gestureRecognizerMode;
@property(nonatomic, assign, readonly, getter=isAutomaticallyPasteEnabled) BOOL automaticallyPasteEnabled;
@property(nonatomic, assign, readonly, getter=isHapticFeedbackEnabled) BOOL hapticFeedbackEnabled;

+ (instancetype)currentConfiguration;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
