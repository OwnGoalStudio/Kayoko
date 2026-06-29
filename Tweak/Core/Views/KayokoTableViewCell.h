//
//  KayokoTableViewCell.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class PasteboardItem;

@interface KayokoTableViewCell : UITableViewCell

@property(nonatomic) UIImageView *iconImageView;
@property(nonatomic) UILabel *headerLabel;
@property(nonatomic) UILabel *contentLabel;
@property(nonatomic) UIImageView *contentImageView;

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                      andItem:(PasteboardItem *)item
          andPreviewLineCount:(NSUInteger)previewLineCount
              reuseIdentifier:(NSString *)reuseIdentifier;

@end
