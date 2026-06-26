//
//  KayokoHeaderCell.h
//  Kayoko
//

#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

@interface KayokoHeaderCell : PSTableCell
@property(nonatomic, strong) UIImageView *iconImageView;
@property(nonatomic, strong) UILabel *headerTitleLabel;
@property(nonatomic, strong) UILabel *subtitleLabel;
@property(nonatomic, strong) UILabel *versionLabel;
@end
