//
//  KayokoEmptyStateView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoEmptyStateView : UIView

@property(nonatomic, copy) NSString *name;
@property(nonatomic, assign) CGFloat keyboardBottomInset;

- (void)updateWithHistoryKey:(NSString *)historyKey;
- (void)updateWithStorageError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
