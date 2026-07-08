//
//  KayokoEdgeFadeMaskController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, KayokoEdgeFadeAxis) {
    KayokoEdgeFadeAxisHorizontal,
    KayokoEdgeFadeAxisVertical,
};

@interface KayokoEdgeFadeMaskController : NSObject
@property(nonatomic, assign) CGFloat fadeWidth;
@property(nonatomic, assign) UIEdgeInsets edgeInsets;
@property(nonatomic, assign) CGFloat leadingFadeScrollOffset;
@property(nonatomic, assign) KayokoEdgeFadeAxis axis;
@property(nonatomic, assign, getter=isEnabled) BOOL enabled;
- (instancetype)initWithScrollView:(UIScrollView *)scrollView NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (void)updateMask;
@end

NS_ASSUME_NONNULL_END
