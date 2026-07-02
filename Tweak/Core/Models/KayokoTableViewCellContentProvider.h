//
//  KayokoTableViewCellContentProvider.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoTableViewCellContent;
@class PasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableViewCellContentProvider : NSObject

- (KayokoTableViewCellContent *)cellContentForItem:(PasteboardItem *)item previewLineCount:(NSUInteger)previewLineCount;
- (KayokoTableViewCellContent *)cellContentForItem:(PasteboardItem *)item
                                  previewLineCount:(NSUInteger)previewLineCount
                                        searchText:(nullable NSString *)searchText;

- (void)loadThumbnailForItem:(PasteboardItem *)item
                  targetSize:(CGSize)targetSize
                  completion:(void (^)(UIImage *_Nullable image))completion;

@end

NS_ASSUME_NONNULL_END
