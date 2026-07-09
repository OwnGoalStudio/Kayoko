//
//  KayokoWordSelectionView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class KayokoTag;
@class KayokoHeaderView;

@interface KayokoWordSelectionView : UIView

@property(nonatomic, strong, readonly) KayokoHeaderView *headerView;
@property(nonatomic, strong, readonly) UIView *transitionContentView;
@property(nonatomic, copy, readonly) NSString *selectedText;
@property(nonatomic, assign, readonly) BOOL hasCustomSelection;
@property(nonatomic, assign) CGFloat keyboardBottomInset;
@property(nonatomic, copy, nullable) void (^selectionChangedHandler)(void);

- (void)setText:(NSString *)text;
- (void)configureTagBarWithTags:(NSArray<KayokoTag *> *)tags
                selectedTagUUID:(nullable NSString *)selectedTagUUID
               selectionHandler:(nullable void (^)(NSString *_Nullable tagUUID))selectionHandler;
- (void)setSelectedTagUUID:(nullable NSString *)selectedTagUUID;
- (void)reset;
- (void)scrollToTopAnimated:(BOOL)animated;
- (BOOL)hasVisibleTagBar;
- (void)requireSelectionGestureRecognizerToFailGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;

@end

NS_ASSUME_NONNULL_END
