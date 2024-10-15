//
//  SingleContactCell.h
//  Akarii Utils
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

@interface SingleContactCell : PSTableCell
@property(nonatomic, strong) UIImageView *avatarImageView;
@property(nonatomic, strong) UILabel *displayNameLabel;
@property(nonatomic, strong) UILabel *usernameLabel;
@property(nonatomic, strong) UIView *tapRecognizerView;
@property(nonatomic, strong) UITapGestureRecognizer *tap;
@property(nonatomic, copy) NSString *displayName;
@property(nonatomic, copy) NSString *username;
@end
