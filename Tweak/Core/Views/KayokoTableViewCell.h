//
//  KayokoTableViewCell.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class KayokoTableViewCellContent;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableViewCell : UITableViewCell

@property(nonatomic, strong) UIImageView *iconImageView;
@property(nonatomic, strong) UILabel *headerLabel;
@property(nonatomic, strong, nullable) UIView *tagDotView;
@property(nonatomic, strong, nullable) UILabel *contentLabel;
@property(nonatomic, strong, nullable) UILabel *detailLabel;
@property(nonatomic, strong, nullable) UIImageView *contentImageView;

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                      content:(KayokoTableViewCellContent *)content
              reuseIdentifier:(NSString *)reuseIdentifier;
+ (NSString *)reuseIdentifierForContent:(KayokoTableViewCellContent *)content;
+ (CGSize)contentImageViewSizeForPreviewLineCount:(NSUInteger)previewLineCount;
+ (CGSize)contentImageThumbnailSize;
- (void)applyDetailContent:(KayokoTableViewCellContent *)content;
- (void)applyContent:(KayokoTableViewCellContent *)content;
- (void)setContentImage:(nullable UIImage *)image forImageName:(NSString *)imageName;

@end

NS_ASSUME_NONNULL_END
