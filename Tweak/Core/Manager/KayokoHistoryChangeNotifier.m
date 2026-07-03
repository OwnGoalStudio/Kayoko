//
//  KayokoHistoryChangeNotifier.m
//  Kayoko
//

#import "KayokoHistoryChangeNotifier.h"
#import "KayokoNotificationKeys.h"
#import "KayokoPasteboardManager.h"

@implementation KayokoHistoryChangeNotifier

- (void)postReloadNotificationWithObject:(id)object {
    [self postChangeNotificationForHistoryKey:nil
                                   changeType:kKayokoPasteboardManagerHistoryChangeTypeReload
                               itemDictionary:nil
                                        limit:0
                                       object:object];
}

- (void)postChangeNotificationForHistoryKey:(NSString *)historyKey
                                 changeType:(NSString *)changeType
                             itemDictionary:(NSDictionary<NSString *, id> *)itemDictionary
                                      limit:(NSUInteger)limit
                                     object:(id)object {
    NSDictionary<NSString *, id> *userInfo = [self userInfoWithChangeType:changeType
                                                               historyKey:historyKey
                                                           itemDictionary:itemDictionary
                                                                    limit:limit];
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter] postNotificationName:kKayokoPasteboardManagerHistoryDidChangeNotification
                                                          object:object
                                                        userInfo:userInfo];
    });
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kKayokoNotificationKeyCoreReload, nil, nil, YES);
}

- (NSDictionary<NSString *, id> *)userInfoWithChangeType:(NSString *)changeType
                                              historyKey:(NSString *)historyKey
                                          itemDictionary:(NSDictionary<NSString *, id> *)itemDictionary
                                                   limit:(NSUInteger)limit {
    NSMutableDictionary<NSString *, id> *userInfo = [[NSMutableDictionary alloc] init];
    userInfo[kKayokoPasteboardManagerHistoryChangeTypeKey] =
        changeType ?: kKayokoPasteboardManagerHistoryChangeTypeReload;
    if ([historyKey length] > 0) {
        userInfo[kKayokoPasteboardManagerHistoryChangeHistoryKeyKey] = historyKey;
        userInfo[kKayokoPasteboardManagerHistoryChangeLimitKey] = @(limit);
    }
    if (itemDictionary) {
        userInfo[kKayokoPasteboardManagerHistoryChangeItemKey] = itemDictionary;
    }
    return userInfo;
}

@end
