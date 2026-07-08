//
//  KayokoPurchaseAuthorization.m
//  Kayoko
//

#import "KayokoPurchaseAuthorization.h"

#import <Security/Security.h>
#import <dlfcn.h>
#import <sys/sysctl.h>

NSString *const kKayokoPurchaseAuthorizationProductIdentifier = @"com.82flex.kayoko";

static NSString *const kKayokoPurchaseAuthorizationErrorDomain = @"com.82flex.kayoko.purchase-authorization";
static NSString *const kKayokoSileoAccessGroup = @"org.coolstar.Sileo";
static NSString *const kKayokoAppleAccessGroup = @"apple";
static NSString *const kKayokoSileoPaymentTokenService = @"SileoPaymentToken";
static NSString *const kKayokoCredentialMirrorService = @"com.82flex.kayoko.havoc-credential";
static NSString *const kKayokoCredentialMirrorAccount = @"sileo-havoc";
static NSString *const kKayokoAuthorizationFlagService = @"com.82flex.kayoko.authorization";
static NSString *const kKayokoAuthorizationFlagAccount = @"com.82flex.kayoko";
static NSString *const kKayokoHavocPaymentEndpointURLString = @"https://havoc.app/payment_endpoint";

static NSInteger const kKayokoPurchaseAuthorizationErrorKeychain = 1;
static NSInteger const kKayokoPurchaseAuthorizationErrorNoCredential = 2;
static NSInteger const kKayokoPurchaseAuthorizationErrorInvalidCredential = 3;
static NSInteger const kKayokoPurchaseAuthorizationErrorEndpoint = 4;

@class KayokoHavocCredential;

static NSError *KayokoAuthorizationError(NSInteger code, NSString *message);
static NSArray<NSDictionary *> *KayokoCopyKeychainItems(NSString *service, NSString *accessGroup, NSError **error);
static NSData *KayokoCopyKeychainData(NSString *service, NSString *account, NSString *accessGroup, NSError **error);
static BOOL KayokoDeleteKeychainItems(NSString *service, NSString *account, NSString *accessGroup, NSError **error);
static BOOL KayokoSaveKeychainData(NSData *data, NSString *service, NSString *account, NSString *accessGroup,
                                   NSError **error);
static KayokoHavocCredential *KayokoCopyMirroredCredential(NSError **error);
static NSDictionary *KayokoSelectSileoTokenItem(NSArray<NSDictionary *> *tokenItems, NSString *endpoint);
static NSString *KayokoFetchHavocPaymentEndpoint(NSError **error);
static NSString *KayokoNormalizeProviderBaseURL(NSString *URLString);
static BOOL KayokoProviderAccountLooksLikeHavoc(NSString *account);
static NSString *KayokoCopyUniqueDeviceIdentifier(void);
static NSString *KayokoCopyHardwareMachine(void);
static NSString *KayokoHTTPStatusMessage(NSInteger statusCode);

@interface KayokoHavocCredential : NSObject
@property(nonatomic, copy) NSString *token;
@property(nonatomic, copy) NSString *providerBaseURL;
@property(nonatomic, copy) NSString *udid;
@property(nonatomic, copy) NSString *device;
@property(nonatomic, strong) NSDate *syncedAt;
@end

@implementation KayokoHavocCredential
@end

@implementation KayokoPurchaseAuthorizationResult

#pragma mark - Lifecycle

- (instancetype)initWithState:(KayokoPurchaseAuthorizationState)state
                        error:(NSError *)error
                   statusCode:(NSInteger)statusCode
                statusMessage:(NSString *)statusMessage {
    self = [super init];
    if (self) {
        _state = state;
        _error = error;
        _statusCode = statusCode;
        _statusMessage = [statusMessage copy];
    }
    return self;
}

@end

@implementation KayokoPurchaseAuthorization

#pragma mark - Credential Mirroring

+ (BOOL)mirrorSileoHavocCredentialToAppleAccessGroupWithError:(NSError **)error {
    NSArray<NSDictionary *> *tokenItems =
        KayokoCopyKeychainItems(kKayokoSileoPaymentTokenService, kKayokoSileoAccessGroup, error);
    if ([tokenItems count] == 0) {
        if (error && !*error) {
            *error = KayokoAuthorizationError(kKayokoPurchaseAuthorizationErrorNoCredential,
                                              @"No Sileo payment token was found.");
        }
        return NO;
    }

    NSError *endpointError = nil;
    NSString *endpoint = KayokoFetchHavocPaymentEndpoint(&endpointError);
    NSDictionary *selectedItem = KayokoSelectSileoTokenItem(tokenItems, endpoint);
    if (!selectedItem) {
        if (error) {
            *error = endpointError
                         ?: KayokoAuthorizationError(kKayokoPurchaseAuthorizationErrorNoCredential,
                                                     @"No Havoc payment token was found in Sileo.");
        }
        return NO;
    }

    NSString *providerBaseURL = selectedItem[(__bridge NSString *)kSecAttrAccount];
    NSData *tokenData = selectedItem[(__bridge NSString *)kSecValueData];
    NSString *token = [[NSString alloc] initWithData:tokenData encoding:NSUTF8StringEncoding];
    NSString *udid = KayokoCopyUniqueDeviceIdentifier();
    NSString *device = KayokoCopyHardwareMachine();
    if ([providerBaseURL length] == 0 || [token length] == 0 || [udid length] == 0 || [device length] == 0) {
        if (error) {
            *error = KayokoAuthorizationError(kKayokoPurchaseAuthorizationErrorInvalidCredential,
                                              @"The Havoc credential is incomplete.");
        }
        return NO;
    }

    NSDictionary *payload = @{
        @"token" : token,
        @"providerBaseURL" : KayokoNormalizeProviderBaseURL(providerBaseURL),
        @"udid" : udid,
        @"device" : device,
        @"syncedAt" : @([[NSDate date] timeIntervalSince1970])
    };
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:error];
    if (!payloadData) {
        return NO;
    }

    return KayokoSaveKeychainData(payloadData, kKayokoCredentialMirrorService, kKayokoCredentialMirrorAccount,
                                  kKayokoAppleAccessGroup, error);
}

#pragma mark - Authorization State

+ (BOOL)hasAuthorizationPassFlagWithError:(NSError **)error {
    NSData *flagData = KayokoCopyKeychainData(kKayokoAuthorizationFlagService, kKayokoAuthorizationFlagAccount,
                                              kKayokoAppleAccessGroup, error);
    return [flagData length] > 0;
}

+ (BOOL)setAuthorizationPassFlagWithError:(NSError **)error {
    NSData *flagData = [kKayokoPurchaseAuthorizationProductIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    return KayokoSaveKeychainData(flagData, kKayokoAuthorizationFlagService, kKayokoAuthorizationFlagAccount,
                                  kKayokoAppleAccessGroup, error);
}

+ (BOOL)clearAuthorizationStateWithError:(NSError **)error {
    if (!KayokoDeleteKeychainItems(kKayokoCredentialMirrorService, nil, kKayokoAppleAccessGroup, error)) {
        return NO;
    }

    return KayokoDeleteKeychainItems(kKayokoAuthorizationFlagService, nil, kKayokoAppleAccessGroup, error);
}

#pragma mark - Purchase Check

+ (void)checkMirroredPurchaseWithCompletion:(void (^)(KayokoPurchaseAuthorizationResult *result))completion {
    NSError *credentialError = nil;
    KayokoHavocCredential *credential = KayokoCopyMirroredCredential(&credentialError);
    if (!credential) {
        KayokoPurchaseAuthorizationResult *result =
            [[KayokoPurchaseAuthorizationResult alloc] initWithState:KayokoPurchaseAuthorizationStateMissingCredential
                                                               error:credentialError
                                                          statusCode:0
                                                       statusMessage:nil];
        completion(result);
        return;
    }

    NSURL *baseURL = [NSURL URLWithString:credential.providerBaseURL];
    NSURL *requestURL = [baseURL URLByAppendingPathComponent:@"user_info"];
    if (!requestURL) {
        KayokoPurchaseAuthorizationResult *result =
            [[KayokoPurchaseAuthorizationResult alloc] initWithState:KayokoPurchaseAuthorizationStateMissingCredential
                                                               error:nil
                                                          statusCode:0
                                                       statusMessage:nil];
        completion(result);
        return;
    }

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:requestURL
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:15.0];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *body = @{@"token" : credential.token, @"udid" : credential.udid, @"device" : credential.device};
    NSError *bodyError = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&bodyError];
    if (!bodyData) {
        KayokoPurchaseAuthorizationResult *result =
            [[KayokoPurchaseAuthorizationResult alloc] initWithState:KayokoPurchaseAuthorizationStateInvalidResponse
                                                               error:bodyError
                                                          statusCode:0
                                                       statusMessage:nil];
        completion(result);
        return;
    }
    [request setHTTPBody:bodyData];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                KayokoPurchaseAuthorizationResult *result = [[KayokoPurchaseAuthorizationResult alloc]
                    initWithState:KayokoPurchaseAuthorizationStateNetworkFailed
                            error:error
                       statusCode:0
                    statusMessage:nil];
                completion(result);
                return;
            }

            NSHTTPURLResponse *HTTPResponse =
                [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
            NSInteger statusCode = [HTTPResponse statusCode];
            NSString *statusMessage = KayokoHTTPStatusMessage(statusCode);
            if (statusCode < 200 || statusCode >= 300 || !data) {
                KayokoPurchaseAuthorizationResult *result = [[KayokoPurchaseAuthorizationResult alloc]
                    initWithState:KayokoPurchaseAuthorizationStateInvalidResponse
                            error:nil
                       statusCode:statusCode
                    statusMessage:statusMessage];
                completion(result);
                return;
            }

            NSError *JSONError = nil;
            id JSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONError];
            NSDictionary *dictionary = [JSON isKindOfClass:[NSDictionary class]] ? JSON : nil;
            NSArray *items = [dictionary[@"items"] isKindOfClass:[NSArray class]] ? dictionary[@"items"] : nil;
            if (!dictionary || !items) {
                KayokoPurchaseAuthorizationResult *result = [[KayokoPurchaseAuthorizationResult alloc]
                    initWithState:KayokoPurchaseAuthorizationStateInvalidResponse
                            error:JSONError
                       statusCode:statusCode
                    statusMessage:statusMessage];
                completion(result);
                return;
            }

            BOOL purchased = NO;
            for (id item in items) {
                if ([item isKindOfClass:[NSString class]] &&
                    [item isEqualToString:kKayokoPurchaseAuthorizationProductIdentifier]) {
                    purchased = YES;
                    break;
                }
            }

            KayokoPurchaseAuthorizationResult *result = [[KayokoPurchaseAuthorizationResult alloc]
                initWithState:purchased ? KayokoPurchaseAuthorizationStatePurchased
                                        : KayokoPurchaseAuthorizationStateNotPurchased
                        error:nil
                   statusCode:statusCode
                statusMessage:statusMessage];
            completion(result);
          }];
    [task resume];
}

@end

#pragma mark - Errors

static NSError *KayokoAuthorizationError(NSInteger code, NSString *message) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey : message ?: @"Kayoko authorization failed."};
    return [NSError errorWithDomain:kKayokoPurchaseAuthorizationErrorDomain code:code userInfo:userInfo];
}

#pragma mark - Keychain

static NSMutableDictionary *KayokoKeychainQuery(NSString *service, NSString *account, NSString *accessGroup) {
    NSMutableDictionary *query = [@{
        (__bridge NSString *)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge NSString *)kSecAttrService : service
    } mutableCopy];
    if ([account length] > 0) {
        query[(__bridge NSString *)kSecAttrAccount] = account;
    }
    if ([accessGroup length] > 0) {
        query[(__bridge NSString *)kSecAttrAccessGroup] = accessGroup;
    }
    return query;
}

static NSData *KayokoCopyKeychainData(NSString *service, NSString *account, NSString *accessGroup, NSError **error) {
    NSMutableDictionary *query = KayokoKeychainQuery(service, account, accessGroup);
    query[(__bridge NSString *)kSecReturnData] = @YES;
    query[(__bridge NSString *)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess) {
        if (error && status != errSecItemNotFound) {
            *error = KayokoAuthorizationError(kKayokoPurchaseAuthorizationErrorKeychain,
                                              [NSString stringWithFormat:@"Keychain read failed: %d", (int)status]);
        }
        if (result) {
            CFRelease(result);
        }
        return nil;
    }

    NSData *data = [(__bridge NSData *)result copy];
    if (result) {
        CFRelease(result);
    }
    return data;
}

static NSArray<NSDictionary *> *KayokoCopyKeychainItems(NSString *service, NSString *accessGroup, NSError **error) {
    NSMutableDictionary *query = KayokoKeychainQuery(service, nil, accessGroup);
    query[(__bridge NSString *)kSecReturnAttributes] = @YES;
    query[(__bridge NSString *)kSecReturnData] = @YES;
    query[(__bridge NSString *)kSecMatchLimit] = (__bridge id)kSecMatchLimitAll;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess) {
        if (error && status != errSecItemNotFound) {
            *error =
                KayokoAuthorizationError(kKayokoPurchaseAuthorizationErrorKeychain,
                                         [NSString stringWithFormat:@"Keychain enumeration failed: %d", (int)status]);
        }
        if (result) {
            CFRelease(result);
        }
        return @[];
    }

    NSArray *items = [(__bridge NSArray *)result copy];
    if (result) {
        CFRelease(result);
    }
    return [items isKindOfClass:[NSArray class]] ? items : @[];
}

static BOOL KayokoDeleteKeychainItems(NSString *service, NSString *account, NSString *accessGroup, NSError **error) {
    NSMutableDictionary *deleteQuery = KayokoKeychainQuery(service, account, accessGroup);
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    if (status != errSecSuccess && status != errSecItemNotFound) {
        if (error) {
            *error = KayokoAuthorizationError(kKayokoPurchaseAuthorizationErrorKeychain,
                                              [NSString stringWithFormat:@"Keychain delete failed: %d", (int)status]);
        }
        return NO;
    }
    return YES;
}

static BOOL KayokoSaveKeychainData(NSData *data, NSString *service, NSString *account, NSString *accessGroup,
                                   NSError **error) {
    NSMutableDictionary *deleteQuery = KayokoKeychainQuery(service, account, accessGroup);
    SecItemDelete((__bridge CFDictionaryRef)deleteQuery);

    NSMutableDictionary *addQuery = KayokoKeychainQuery(service, account, accessGroup);
    addQuery[(__bridge NSString *)kSecValueData] = data;
    addQuery[(__bridge NSString *)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    addQuery[(__bridge NSString *)kSecAttrSynchronizable] = @NO;

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)addQuery, nil);
    if (status != errSecSuccess) {
        if (error) {
            *error = KayokoAuthorizationError(kKayokoPurchaseAuthorizationErrorKeychain,
                                              [NSString stringWithFormat:@"Keychain write failed: %d", (int)status]);
        }
        return NO;
    }
    return YES;
}

#pragma mark - Credentials

static KayokoHavocCredential *KayokoCopyMirroredCredential(NSError **error) {
    NSData *data = KayokoCopyKeychainData(kKayokoCredentialMirrorService, kKayokoCredentialMirrorAccount,
                                          kKayokoAppleAccessGroup, error);
    if (!data) {
        if (error && !*error) {
            *error = KayokoAuthorizationError(kKayokoPurchaseAuthorizationErrorNoCredential,
                                              @"No mirrored Havoc credential was found.");
        }
        return nil;
    }

    NSError *JSONError = nil;
    id JSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONError];
    NSDictionary *dictionary = [JSON isKindOfClass:[NSDictionary class]] ? JSON : nil;
    NSString *token = [dictionary[@"token"] isKindOfClass:[NSString class]] ? dictionary[@"token"] : nil;
    NSString *providerBaseURL =
        [dictionary[@"providerBaseURL"] isKindOfClass:[NSString class]] ? dictionary[@"providerBaseURL"] : nil;
    NSString *udid = [dictionary[@"udid"] isKindOfClass:[NSString class]] ? dictionary[@"udid"] : nil;
    NSString *device = [dictionary[@"device"] isKindOfClass:[NSString class]] ? dictionary[@"device"] : nil;
    NSNumber *syncedAt = [dictionary[@"syncedAt"] isKindOfClass:[NSNumber class]] ? dictionary[@"syncedAt"] : nil;

    if ([token length] == 0 || [providerBaseURL length] == 0 || [udid length] == 0 || [device length] == 0) {
        if (error) {
            *error = JSONError
                         ?: KayokoAuthorizationError(kKayokoPurchaseAuthorizationErrorInvalidCredential,
                                                     @"The mirrored Havoc credential is incomplete.");
        }
        return nil;
    }

    KayokoHavocCredential *credential = [[KayokoHavocCredential alloc] init];
    credential.token = token;
    credential.providerBaseURL = KayokoNormalizeProviderBaseURL(providerBaseURL);
    credential.udid = udid;
    credential.device = device;
    credential.syncedAt = [NSDate dateWithTimeIntervalSince1970:[syncedAt doubleValue]];
    return credential;
}

static NSDictionary *KayokoSelectSileoTokenItem(NSArray<NSDictionary *> *tokenItems, NSString *endpoint) {
    NSString *normalizedEndpoint = KayokoNormalizeProviderBaseURL(endpoint);
    for (NSDictionary *item in tokenItems) {
        NSString *account = item[(__bridge NSString *)kSecAttrAccount];
        if ([KayokoNormalizeProviderBaseURL(account) isEqualToString:normalizedEndpoint]) {
            return item;
        }
    }

    NSMutableArray<NSDictionary *> *havocCandidates = [[NSMutableArray alloc] init];
    for (NSDictionary *item in tokenItems) {
        NSString *account = item[(__bridge NSString *)kSecAttrAccount];
        if (KayokoProviderAccountLooksLikeHavoc(account)) {
            [havocCandidates addObject:item];
        }
    }
    return [havocCandidates count] == 1 ? [havocCandidates firstObject] : nil;
}

#pragma mark - Havoc Endpoint

static NSString *KayokoFetchHavocPaymentEndpoint(NSError **error) {
    NSURL *URL = [NSURL URLWithString:kKayokoHavocPaymentEndpointURLString];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:URL
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:8.0];
    __block NSData *responseData = nil;
    __block NSError *requestError = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *HTTPResponse =
                [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
            if (error) {
                requestError = error;
            } else if ([HTTPResponse statusCode] < 200 || [HTTPResponse statusCode] >= 300) {
                requestError = KayokoAuthorizationError(kKayokoPurchaseAuthorizationErrorEndpoint,
                                                        KayokoHTTPStatusMessage([HTTPResponse statusCode]));
            } else {
                responseData = data;
            }
            dispatch_semaphore_signal(semaphore);
          }];
    [task resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)));

    if (!responseData) {
        if (error) {
            *error = requestError
                         ?: KayokoAuthorizationError(kKayokoPurchaseAuthorizationErrorEndpoint,
                                                     @"Unable to fetch Havoc payment endpoint.");
        }
        return nil;
    }

    NSString *endpoint = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    endpoint = [endpoint stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([endpoint length] == 0) {
        if (error) {
            *error = KayokoAuthorizationError(kKayokoPurchaseAuthorizationErrorEndpoint,
                                              @"Havoc payment endpoint response was empty.");
        }
        return nil;
    }
    return endpoint;
}

static NSString *KayokoNormalizeProviderBaseURL(NSString *URLString) {
    NSString *normalized =
        [URLString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([normalized length] > 0 && ![normalized hasSuffix:@"/"]) {
        normalized = [normalized stringByAppendingString:@"/"];
    }
    return normalized ?: @"";
}

static BOOL KayokoProviderAccountLooksLikeHavoc(NSString *account) {
    NSURL *URL = [NSURL URLWithString:account];
    NSString *host = [[URL host] lowercaseString];
    return [host containsString:@"havoc"] || [[account lowercaseString] containsString:@"havoc"];
}

#pragma mark - Device Identity

static NSString *KayokoCopyUniqueDeviceIdentifier(void) {
    void *gestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_GLOBAL | RTLD_LAZY);
    if (!gestalt) {
        return nil;
    }
    typedef CFTypeRef (*MGCopyAnswerFunc)(CFStringRef);
    MGCopyAnswerFunc MGCopyAnswer = (MGCopyAnswerFunc)dlsym(gestalt, "MGCopyAnswer");
    if (!MGCopyAnswer) {
        return nil;
    }
    CFTypeRef value = MGCopyAnswer(CFSTR("UniqueDeviceID"));
    NSString *identifier =
        [(__bridge id)value isKindOfClass:[NSString class]] ? [(__bridge NSString *)value copy] : nil;
    if (value) {
        CFRelease(value);
    }
    return identifier;
}

static NSString *KayokoCopyHardwareMachine(void) {
    size_t size = 0;
    if (sysctlbyname("hw.machine", NULL, &size, NULL, 0) != 0 || size == 0) {
        return nil;
    }

    NSMutableData *data = [NSMutableData dataWithLength:size];
    if (sysctlbyname("hw.machine", [data mutableBytes], &size, NULL, 0) != 0) {
        return nil;
    }
    return [NSString stringWithUTF8String:[data bytes]];
}

#pragma mark - HTTP

static NSString *KayokoHTTPStatusMessage(NSInteger statusCode) {
    if (statusCode <= 0) {
        return nil;
    }

    NSString *localized = [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
    NSString *message = [localized length] > 0 ? [localized capitalizedString] : @"HTTP Error";
    return [NSString stringWithFormat:@"%ld %@", (long)statusCode, message];
}
