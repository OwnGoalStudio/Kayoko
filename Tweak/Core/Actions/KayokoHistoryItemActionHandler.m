//
//  KayokoHistoryItemActionHandler.m
//  Kayoko
//

#import "KayokoHistoryItemActionHandler.h"

#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"

@implementation KayokoHistoryItemActionHandler

- (void)activateItem:(KayokoPasteboardItem *)item
          historyKey:(NSString *)historyKey
          completion:(void (^)(BOOL success))completion {
    if (!item || [historyKey length] == 0) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [[KayokoPasteboardManager sharedInstance] writePasteboardItem:item
                                                sourceHistoryItem:item
                                               fromHistoryWithKey:historyKey
                                             allowsAutomaticPaste:YES];
    if (completion) {
        completion(YES);
    }
}

- (void)copyItem:(KayokoPasteboardItem *)item completion:(void (^)(BOOL success))completion {
    BOOL copied = item && [[KayokoPasteboardManager sharedInstance] copyPasteboardItemToPasteboard:item];
    if (completion) {
        completion(copied);
    }
}

- (void)saveImageForItem:(KayokoPasteboardItem *)item completion:(void (^)(BOOL success))completion {
    UIImage *image = item ? [[KayokoPasteboardManager sharedInstance] getImageForItem:item] : nil;
    if (image) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    }
    if (completion) {
        completion(image != nil);
    }
}

- (void)openLinkForItem:(KayokoPasteboardItem *)item completion:(void (^)(BOOL success))completion {
    NSURL *URL = [NSURL URLWithString:[item content] ?: @""];
    if (!URL) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [[UIApplication sharedApplication] openURL:URL
                                       options:@{}
                             completionHandler:^(BOOL success) {
                               if (completion) {
                                   completion(success);
                               }
                             }];
}

- (void)deleteItem:(KayokoPasteboardItem *)item
        historyKey:(NSString *)historyKey
        completion:(void (^)(BOOL success))completion {
    if (!item || [historyKey length] == 0) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [[KayokoPasteboardManager sharedInstance] removePasteboardItem:item
                                                fromHistoryWithKey:historyKey
                                                 shouldRemoveImage:YES
                                                        completion:completion];
}

- (void)moveItem:(KayokoPasteboardItem *)item
         sourceHistoryKey:(NSString *)sourceHistoryKey
    destinationHistoryKey:(NSString *)destinationHistoryKey
               completion:(void (^)(BOOL success))completion {
    if (!item || [sourceHistoryKey length] == 0 || [destinationHistoryKey length] == 0) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [[KayokoPasteboardManager sharedInstance] movePasteboardItem:item
                                              fromHistoryWithKey:sourceHistoryKey
                                                toHistoryWithKey:destinationHistoryKey
                                                      completion:completion];
}

- (void)setTagUUID:(NSString *)tagUUID
           forItem:(KayokoPasteboardItem *)item
        historyKey:(NSString *)historyKey
        completion:(void (^)(BOOL success))completion {
    if (!item || [historyKey length] == 0) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [[KayokoPasteboardManager sharedInstance] setTagUUID:tagUUID
                                       forPasteboardItem:item
                                        inHistoryWithKey:historyKey
                                              completion:completion];
}

@end
