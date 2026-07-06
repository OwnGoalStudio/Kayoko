//
//  KayokoSearchTokenCollectionView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchTokenCollectionView : UICollectionView
@property(nonatomic, assign, getter=isHorizontalScrollingLayout) BOOL horizontalScrollingLayout;
- (instancetype)initWithItemSize:(CGSize)itemSize
                     itemSpacing:(CGFloat)itemSpacing
          horizontalContentInset:(CGFloat)horizontalContentInset NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (void)resetContentOffsetToLeadingEdge;
- (void)updateEdgeFadeMask;
@end

NS_ASSUME_NONNULL_END
