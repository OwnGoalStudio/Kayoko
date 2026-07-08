//
//  KayokoPurchaseAuthorization.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kKayokoPurchaseAuthorizationProductIdentifier;

typedef NS_ENUM(NSInteger, KayokoPurchaseAuthorizationState) {
    KayokoPurchaseAuthorizationStateMissingCredential = 0,
    KayokoPurchaseAuthorizationStateNetworkFailed,
    KayokoPurchaseAuthorizationStateInvalidResponse,
    KayokoPurchaseAuthorizationStateNotPurchased,
    KayokoPurchaseAuthorizationStatePurchased,
};

@interface KayokoPurchaseAuthorizationResult : NSObject

@property(nonatomic, assign, readonly) KayokoPurchaseAuthorizationState state;
@property(nonatomic, strong, nullable, readonly) NSError *error;
@property(nonatomic, assign, readonly) NSInteger statusCode;
@property(nonatomic, copy, nullable, readonly) NSString *statusMessage;

- (instancetype)initWithState:(KayokoPurchaseAuthorizationState)state
                        error:(nullable NSError *)error
                   statusCode:(NSInteger)statusCode
                statusMessage:(nullable NSString *)statusMessage NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@interface KayokoPurchaseAuthorization : NSObject

+ (BOOL)mirrorHavocCredentialToAppleAccessGroupWithError:(NSError **)error;
+ (BOOL)mirrorHavocCredentialToAppleAccessGroupWithSource:(NSString *_Nullable *_Nullable)source
                                                    error:(NSError **)error;
+ (BOOL)mirrorSileoHavocCredentialToAppleAccessGroupWithError:(NSError **)error;
+ (BOOL)hasAuthorizationPassFlagWithError:(NSError **)error;
+ (BOOL)setAuthorizationPassFlagWithError:(NSError **)error;
+ (BOOL)clearAuthorizationStateWithError:(NSError **)error;
+ (void)checkMirroredPurchaseWithCompletion:(void (^)(KayokoPurchaseAuthorizationResult *result))completion;

@end

NS_ASSUME_NONNULL_END
