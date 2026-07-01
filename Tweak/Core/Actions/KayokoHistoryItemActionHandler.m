//
//  KayokoHistoryItemActionHandler.m
//  Kayoko
//

#import "KayokoHistoryItemActionHandler.h"

#import "PasteboardItem.h"
#import "PasteboardManager.h"

@implementation KayokoHistoryItemActionHandler

- (void)performDirectPasteWithItem:(PasteboardItem *)item
                        historyKey:(NSString *)historyKey
                        completion:(void (^)(BOOL success))completion {
    if (!item || [historyKey length] == 0) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [[PasteboardManager sharedInstance] performDirectPasteWithPasteboardItem:item
                                                                 historyItem:item
                                                          fromHistoryWithKey:historyKey
                                                             shouldAutoPaste:YES];
    if (completion) {
        completion(YES);
    }
}

- (void)copyItem:(PasteboardItem *)item completion:(void (^)(BOOL success))completion {
    BOOL copied = item && [[PasteboardManager sharedInstance] copyPasteboardItemToPasteboard:item];
    if (completion) {
        completion(copied);
    }
}

- (void)saveImageForItem:(PasteboardItem *)item completion:(void (^)(BOOL success))completion {
    UIImage *image = item ? [[PasteboardManager sharedInstance] getImageForItem:item] : nil;
    if (image) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    }
    if (completion) {
        completion(image != nil);
    }
}

- (void)openLinkForItem:(PasteboardItem *)item completion:(void (^)(BOOL success))completion {
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

- (void)deleteItem:(PasteboardItem *)item
        historyKey:(NSString *)historyKey
        completion:(void (^)(BOOL success))completion {
    if (!item || [historyKey length] == 0) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [[PasteboardManager sharedInstance] removePasteboardItem:item
                                          fromHistoryWithKey:historyKey
                                           shouldRemoveImage:YES
                                                  completion:completion];
}

- (void)moveItem:(PasteboardItem *)item
         sourceHistoryKey:(NSString *)sourceHistoryKey
    destinationHistoryKey:(NSString *)destinationHistoryKey
               completion:(void (^)(BOOL success))completion {
    if (!item || [sourceHistoryKey length] == 0 || [destinationHistoryKey length] == 0) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [[PasteboardManager sharedInstance] movePasteboardItem:item
                                        fromHistoryWithKey:sourceHistoryKey
                                          toHistoryWithKey:destinationHistoryKey
                                                completion:completion];
}

@end
