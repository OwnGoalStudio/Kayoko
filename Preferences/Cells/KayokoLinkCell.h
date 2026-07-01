//
//  KayokoLinkCell.h
//  Akarii Utils
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Preferences/PSSpecifier.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoLinkCell : PSTableCell
@property(nonatomic, strong) UILabel *label;
@property(nonatomic, strong) UILabel *subtitleLabel;
@property(nonatomic, strong) UIImageView *indicatorImageView;
@property(nonatomic, strong) UIView *tapRecognizerView;
@property(nonatomic, strong) UITapGestureRecognizer *tap;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *subtitle;
@property(nonatomic, copy) NSString *url;
@end

NS_ASSUME_NONNULL_END
