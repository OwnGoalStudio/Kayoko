//
//  KayokoTableViewCellContentProvider.h
//  Kayoko
//

#import <UIKit/UIKit.h>

#import "KayokoPreferenceKeys.h"

@class KayokoTableViewCellContent;
@class KayokoPasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableViewCellContentProvider : NSObject

- (KayokoTableViewCellContent *)cellContentForItem:(KayokoPasteboardItem *)item
                                  previewLineCount:(NSUInteger)previewLineCount
                                   itemDetailsMode:(KayokoItemDetailsMode)itemDetailsMode;
- (KayokoTableViewCellContent *)cellContentForItem:(KayokoPasteboardItem *)item
                                  previewLineCount:(NSUInteger)previewLineCount
                                   itemDetailsMode:(KayokoItemDetailsMode)itemDetailsMode
                                        searchText:(nullable NSString *)searchText;

- (void)loadThumbnailForItem:(KayokoPasteboardItem *)item
                  targetSize:(CGSize)targetSize
                  completion:(void (^)(UIImage *_Nullable image))completion;

@end

NS_ASSUME_NONNULL_END
