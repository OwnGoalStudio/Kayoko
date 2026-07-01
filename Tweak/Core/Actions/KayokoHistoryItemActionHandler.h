//
//  KayokoHistoryItemActionHandler.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class PasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHistoryItemActionHandler : NSObject

- (void)performDirectPasteWithItem:(PasteboardItem *)item
                        historyKey:(NSString *)historyKey
                        completion:(nullable void (^)(BOOL success))completion;
- (void)copyItem:(PasteboardItem *)item completion:(nullable void (^)(BOOL success))completion;
- (void)saveImageForItem:(PasteboardItem *)item completion:(nullable void (^)(BOOL success))completion;
- (void)openLinkForItem:(PasteboardItem *)item completion:(nullable void (^)(BOOL success))completion;
- (void)deleteItem:(PasteboardItem *)item
        historyKey:(NSString *)historyKey
        completion:(nullable void (^)(BOOL success))completion;
- (void)moveItem:(PasteboardItem *)item
         sourceHistoryKey:(NSString *)sourceHistoryKey
    destinationHistoryKey:(NSString *)destinationHistoryKey
               completion:(nullable void (^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
