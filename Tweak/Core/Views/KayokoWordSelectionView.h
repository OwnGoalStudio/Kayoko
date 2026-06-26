//
//  KayokoWordSelectionView.h
//  Kayoko
//
//  Created by Lessica
//

#import <UIKit/UIKit.h>

@interface KayokoWordSelectionView : UIView
@property(nonatomic, copy, readonly) NSString *selectedText;
@property(nonatomic, assign, readonly) BOOL hasCustomSelection;
@property(nonatomic, copy) void (^selectionChangedHandler)(void);
- (void)setText:(NSString *)text;
- (void)reset;
@end
