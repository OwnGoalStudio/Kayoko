//
//  KayokoTagTableViewCell.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoTag;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTagTableViewCell : UITableViewCell

- (void)configureWithTag:(KayokoTag *)tag editing:(BOOL)editing;

@end

NS_ASSUME_NONNULL_END
