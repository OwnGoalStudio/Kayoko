//
//  KayokoClearConfirmationView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoClearConfirmationView : UIView

@property(nonatomic, strong, readonly) UIButton *cancelButton;
@property(nonatomic, strong, readonly) UIButton *confirmButton;
@property(nonatomic, assign) CGFloat keyboardBottomInset;

- (void)updateWithHistoryKey:(NSString *)historyKey;

@end

NS_ASSUME_NONNULL_END
