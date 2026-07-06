//
//  KayokoSearchTokenSectionView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class KayokoSearchTokenCollectionView;

@interface KayokoSearchTokenSectionView : UIView
@property(nonatomic, strong, readonly) KayokoSearchTokenCollectionView *collectionView;
@property(nonatomic, assign) NSUInteger numberOfRows;
@property(nonatomic, assign, getter=isHorizontalScrollingLayout) BOOL horizontalScrollingLayout;
- (instancetype)initWithTitle:(NSString *)title NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
+ (CGFloat)preferredHeight;
+ (CGFloat)preferredHeightForNumberOfRows:(NSUInteger)numberOfRows;
+ (CGFloat)preferredHeightForItemCount:(NSUInteger)itemCount
                                 width:(CGFloat)width
             horizontalScrollingLayout:(BOOL)horizontalScrollingLayout;
+ (NSUInteger)numberOfRowsForItemCount:(NSUInteger)itemCount
                                 width:(CGFloat)width
             horizontalScrollingLayout:(BOOL)horizontalScrollingLayout;
- (CGFloat)preferredHeight;
@end

NS_ASSUME_NONNULL_END
