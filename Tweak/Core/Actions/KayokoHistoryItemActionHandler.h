//
//  KayokoHistoryItemActionHandler.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoPasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHistoryItemActionHandler : NSObject

- (void)performDirectPasteWithItem:(KayokoPasteboardItem *)item
                        historyKey:(NSString *)historyKey
                        completion:(nullable void (^)(BOOL success))completion;
- (void)copyItem:(KayokoPasteboardItem *)item completion:(nullable void (^)(BOOL success))completion;
- (void)saveImageForItem:(KayokoPasteboardItem *)item completion:(nullable void (^)(BOOL success))completion;
- (void)openLinkForItem:(KayokoPasteboardItem *)item completion:(nullable void (^)(BOOL success))completion;
- (void)deleteItem:(KayokoPasteboardItem *)item
        historyKey:(NSString *)historyKey
        completion:(nullable void (^)(BOOL success))completion;
- (void)moveItem:(KayokoPasteboardItem *)item
         sourceHistoryKey:(NSString *)sourceHistoryKey
    destinationHistoryKey:(NSString *)destinationHistoryKey
               completion:(nullable void (^)(BOOL success))completion;
- (void)setTagUUID:(nullable NSString *)tagUUID
           forItem:(KayokoPasteboardItem *)item
        historyKey:(NSString *)historyKey
        completion:(nullable void (^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
