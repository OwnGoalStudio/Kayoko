//
//  KayokoHeaderCell.h
//  Kayoko
//

#import <Preferences/PSSpecifier.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHeaderCell : PSTableCell
@property(nonatomic, strong) UIImageView *iconImageView;
@property(nonatomic, strong) UILabel *headerTitleLabel;
@property(nonatomic, strong) UILabel *subtitleLabel;
@property(nonatomic, strong) UILabel *versionLabel;
@end

NS_ASSUME_NONNULL_END
