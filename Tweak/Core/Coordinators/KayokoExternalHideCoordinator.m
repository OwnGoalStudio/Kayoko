//
//  KayokoExternalHideCoordinator.m
//  Kayoko
//

#import "KayokoExternalHideCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoExternalHideRequest ()

@property(nonatomic, assign, readwrite) KayokoPanelHideAnimationStyle animationStyle;
@property(nonatomic, copy, readwrite, nullable) void (^completion)(void);

@end

@implementation KayokoExternalHideRequest

- (instancetype)initWithAnimationStyle:(KayokoPanelHideAnimationStyle)animationStyle
                            completion:(nullable void (^)(void))completion {
    self = [super init];
    if (self) {
        _animationStyle = animationStyle;
        _completion = [completion copy];
    }
    return self;
}

@end

@interface KayokoExternalHideCoordinator ()

@property(nonatomic, assign, readwrite, getter=isSearchInputTransitionSuppressed) BOOL searchInputTransitionSuppressed;
@property(nonatomic, assign) NSUInteger searchInputTransitionSuppressionToken;
@property(nonatomic, copy, nullable) dispatch_block_t searchInputTransitionSuppressionExpirationBlock;
@property(nonatomic, strong, nullable) KayokoExternalHideRequest *pendingExternalHideRequestObject;

@end

@implementation KayokoExternalHideCoordinator

- (BOOL)hasPendingExternalHideRequest {
    return self.pendingExternalHideRequestObject != nil;
}

- (void)cancelSearchInputTransitionSuppressionExpiration {
    dispatch_block_t expirationBlock = self.searchInputTransitionSuppressionExpirationBlock;
    if (expirationBlock) {
        dispatch_block_cancel(expirationBlock);
        self.searchInputTransitionSuppressionExpirationBlock = nil;
    }
}

- (void)beginSearchInputTransitionSuppressionWithDuration:(NSTimeInterval)duration
                                        expirationHandler:(nullable void (^)(void))expirationHandler {
    [self cancelSearchInputTransitionSuppressionExpiration];
    self.searchInputTransitionSuppressed = YES;
    self.searchInputTransitionSuppressionToken++;
    self.pendingExternalHideRequestObject = nil;

    NSUInteger token = self.searchInputTransitionSuppressionToken;
    __weak typeof(self) weakSelf = self;
    dispatch_block_t expirationBlock = dispatch_block_create(0, ^{
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (!strongSelf || ![strongSelf isSearchInputTransitionSuppressed] ||
          [strongSelf searchInputTransitionSuppressionToken] != token) {
          return;
      }

      [strongSelf endSearchInputTransitionSuppression];
      if (expirationHandler) {
          expirationHandler();
      }
    });
    self.searchInputTransitionSuppressionExpirationBlock = expirationBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(),
                   expirationBlock);
}

- (void)endSearchInputTransitionSuppression {
    [self cancelSearchInputTransitionSuppressionExpiration];
    self.searchInputTransitionSuppressionToken++;
    self.searchInputTransitionSuppressed = NO;
}

- (BOOL)shouldSuppressExternalHide {
    return [self isSearchInputTransitionSuppressed];
}

- (BOOL)recordPendingExternalHideRequestWithAnimationStyle:(KayokoPanelHideAnimationStyle)animationStyle
                                                completion:(nullable void (^)(void))completion {
    if ([self hasPendingExternalHideRequest]) {
        return NO;
    }

    self.pendingExternalHideRequestObject = [[KayokoExternalHideRequest alloc] initWithAnimationStyle:animationStyle
                                                                                           completion:completion];
    return YES;
}

- (nullable KayokoExternalHideRequest *)takePendingExternalHideRequest {
    KayokoExternalHideRequest *request = self.pendingExternalHideRequestObject;
    self.pendingExternalHideRequestObject = nil;
    return request;
}

- (void)clear {
    [self endSearchInputTransitionSuppression];
    self.pendingExternalHideRequestObject = nil;
}

@end

NS_ASSUME_NONNULL_END
