//
//  KayokoExternalHideCoordinator.h
//  Kayoko
//

#import <Foundation/Foundation.h>

#import "KayokoPanelPresentationMode.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoExternalHideRequest : NSObject

@property(nonatomic, assign, readonly) KayokoPanelHideAnimationStyle animationStyle;
@property(nonatomic, copy, readonly, nullable) void (^completion)(void);

- (instancetype)initWithAnimationStyle:(KayokoPanelHideAnimationStyle)animationStyle
                            completion:(nullable void (^)(void))completion;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

@interface KayokoExternalHideCoordinator : NSObject

@property(nonatomic, assign, readonly, getter=isSearchInputTransitionSuppressed) BOOL searchInputTransitionSuppressed;
@property(nonatomic, assign, readonly, getter=hasPendingExternalHideRequest) BOOL pendingExternalHideRequest;

- (void)beginSearchInputTransitionSuppressionWithDuration:(NSTimeInterval)duration
                                        expirationHandler:(nullable void (^)(void))expirationHandler;
- (void)endSearchInputTransitionSuppression;
- (BOOL)shouldSuppressExternalHide;
- (BOOL)recordPendingExternalHideRequestWithAnimationStyle:(KayokoPanelHideAnimationStyle)animationStyle
                                                completion:(nullable void (^)(void))completion;
- (nullable KayokoExternalHideRequest *)takePendingExternalHideRequest;
- (void)clear;

@end

NS_ASSUME_NONNULL_END
