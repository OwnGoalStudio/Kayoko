//
//  KayokoWordSelectionView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoWordSelectionView : UIView

@property(nonatomic, copy, readonly) NSString *selectedText;
@property(nonatomic, assign, readonly) BOOL hasCustomSelection;
@property(nonatomic, copy, nullable) void (^selectionChangedHandler)(void);

- (void)setText:(NSString *)text;
- (void)reset;
- (void)scrollToTopAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
