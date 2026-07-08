//
//  KayokoTagChipBarView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoTag;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTagChipBarView : UIView

@property(nonatomic, copy, nullable) NSString *selectedTagUUID;
@property(nonatomic, copy, nullable) void (^selectionHandler)(NSString *_Nullable tagUUID);
@property(nonatomic, assign, readonly, getter=isSettled) BOOL settled;
@property(nonatomic, assign) CGFloat bottomMaterialExtension;

+ (CGFloat)preferredHeight;
+ (CGFloat)floatingProgressForScrollView:(UIScrollView *)scrollView;
- (void)configureWithTags:(NSArray<KayokoTag *> *)tags selectedTagUUID:(nullable NSString *)selectedTagUUID;
- (void)setFloatingProgress:(CGFloat)floatingProgress animated:(BOOL)animated;
- (void)setSettled:(BOOL)settled animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
