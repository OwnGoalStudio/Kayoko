//
//  KayokoClearConfirmationView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@interface KayokoClearConfirmationView : UIView
@property(nonatomic, strong, readonly) UIButton *cancelButton;
@property(nonatomic, strong, readonly) UIButton *confirmButton;
- (void)updateWithHistoryKey:(NSString *)historyKey;
@end
