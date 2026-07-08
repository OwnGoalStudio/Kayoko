//
//  KayokoSearchTokenCollectionView.m
//  Kayoko
//

#import "KayokoSearchTokenCollectionView.h"

@interface KayokoSearchTokenFlowLayout : UICollectionViewFlowLayout
@end

@implementation KayokoSearchTokenFlowLayout

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSArray<UICollectionViewLayoutAttributes *> *attributes = [super layoutAttributesForElementsInRect:rect];
    if ([self scrollDirection] != UICollectionViewScrollDirectionVertical) {
        return attributes;
    }

    NSMutableArray<UICollectionViewLayoutAttributes *> *adjustedAttributes =
        [[NSMutableArray alloc] initWithCapacity:[attributes count]];
    CGFloat currentRowMinY = CGFLOAT_MAX;
    CGFloat currentX = [self sectionInset].left;
    for (UICollectionViewLayoutAttributes *attribute in attributes) {
        UICollectionViewLayoutAttributes *adjustedAttribute = [attribute copy];
        if ([adjustedAttribute representedElementCategory] != UICollectionElementCategoryCell) {
            [adjustedAttributes addObject:adjustedAttribute];
            continue;
        }

        CGRect frame = [adjustedAttribute frame];
        if (fabs(CGRectGetMinY(frame) - currentRowMinY) > 0.5) {
            currentRowMinY = CGRectGetMinY(frame);
            currentX = [self sectionInset].left;
        }

        frame.origin.x = currentX;
        [adjustedAttribute setFrame:frame];
        currentX += CGRectGetWidth(frame) + [self minimumInteritemSpacing];
        [adjustedAttributes addObject:adjustedAttribute];
    }

    return adjustedAttributes;
}

@end

@implementation KayokoSearchTokenCollectionView

- (instancetype)initWithItemSize:(CGSize)itemSize
                     itemSpacing:(CGFloat)itemSpacing
          horizontalContentInset:(CGFloat)horizontalContentInset {
    UICollectionViewFlowLayout *layout = [[KayokoSearchTokenFlowLayout alloc] init];
    [layout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
    [layout setItemSize:itemSize];
    [layout setMinimumInteritemSpacing:itemSpacing];
    [layout setMinimumLineSpacing:itemSpacing];

    self = [super initWithFrame:CGRectZero collectionViewLayout:layout];
    if (self) {
        _horizontalScrollingLayout = YES;

        [self setBackgroundColor:[UIColor clearColor]];
        [self setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentNever];
        [self setContentInset:UIEdgeInsetsMake(0, horizontalContentInset, 0, horizontalContentInset)];
        [self setEdgeFadeAxis:KayokoEdgeFadeAxisHorizontal];
        [self setEdgeFadeWidth:horizontalContentInset];
        [self setEdgeFadeEnabled:YES];
        [self setScrollEnabled:YES];
        [self setShowsHorizontalScrollIndicator:NO];
        [self setShowsVerticalScrollIndicator:NO];
    }
    return self;
}

- (void)setHorizontalScrollingLayout:(BOOL)horizontalScrollingLayout {
    if (_horizontalScrollingLayout == horizontalScrollingLayout) {
        return;
    }

    _horizontalScrollingLayout = horizontalScrollingLayout;
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)[self collectionViewLayout];
    [layout setScrollDirection:horizontalScrollingLayout ? UICollectionViewScrollDirectionHorizontal
                                                         : UICollectionViewScrollDirectionVertical];
    [layout invalidateLayout];
    [self setScrollEnabled:horizontalScrollingLayout];
    [self setEdgeFadeAxis:KayokoEdgeFadeAxisHorizontal];
    [self setEdgeFadeEnabled:horizontalScrollingLayout];
    [self resetContentOffsetToLeadingEdge];
    [self updateEdgeFadeMask];
}

- (void)resetContentOffsetToLeadingEdge {
    [self layoutIfNeeded];
    UIEdgeInsets adjustedInset = [self adjustedContentInset];
    CGPoint contentOffset = [self contentOffset];
    contentOffset.x = -adjustedInset.left;
    contentOffset.y = -adjustedInset.top;
    [self setContentOffset:contentOffset animated:NO];
    [self updateEdgeFadeMask];
}

@end
