//
//  KayokoTableViewCellContentProvider.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoTableViewCellContent;
@class KayokoPasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableViewCellContentProvider : NSObject

- (KayokoTableViewCellContent *)cellContentForItem:(KayokoPasteboardItem *)item
                                  previewLineCount:(NSUInteger)previewLineCount;
- (KayokoTableViewCellContent *)cellContentForItem:(KayokoPasteboardItem *)item
                                  previewLineCount:(NSUInteger)previewLineCount
                                        searchText:(nullable NSString *)searchText;

- (void)loadThumbnailForItem:(KayokoPasteboardItem *)item
                  targetSize:(CGSize)targetSize
                  completion:(void (^)(UIImage *_Nullable image))completion;

@end

NS_ASSUME_NONNULL_END
