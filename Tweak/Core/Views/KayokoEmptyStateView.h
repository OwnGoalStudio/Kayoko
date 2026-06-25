//
//  KayokoEmptyStateView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@interface KayokoEmptyStateView : UIView
@property(nonatomic, copy) NSString *name;
- (void)updateWithHistoryKey:(NSString *)historyKey;
@end
