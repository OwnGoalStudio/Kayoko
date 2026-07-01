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

@end

NS_ASSUME_NONNULL_END
