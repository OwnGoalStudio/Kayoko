//
//  KayokoSearchTokenCollectionView.m
//  Kayoko
//

#import "KayokoSearchTokenCollectionView.h"

#import <QuartzCore/QuartzCore.h>

@interface KayokoSearchTokenCollectionView ()
@property(nonatomic, strong) CAGradientLayer *edgeFadeMaskLayer;
@property(nonatomic, assign) CGFloat edgeFadeWidth;
@end

@implementation KayokoSearchTokenCollectionView

- (instancetype)initWithItemSize:(CGSize)itemSize
                     itemSpacing:(CGFloat)itemSpacing
          horizontalContentInset:(CGFloat)horizontalContentInset {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    [layout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
    [layout setItemSize:itemSize];
    [layout setMinimumInteritemSpacing:itemSpacing];
    [layout setMinimumLineSpacing:itemSpacing];

    self = [super initWithFrame:CGRectZero collectionViewLayout:layout];
    if (self) {
        _edgeFadeWidth = horizontalContentInset;
        _edgeFadeMaskLayer = [self newEdgeFadeMaskLayer];

        [self setBackgroundColor:[UIColor clearColor]];
        [self setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentNever];
        [self setContentInset:UIEdgeInsetsMake(0, horizontalContentInset, 0, horizontalContentInset)];
        [self setScrollEnabled:YES];
        [self setShowsHorizontalScrollIndicator:NO];
        [self setShowsVerticalScrollIndicator:NO];
        [[self layer] setMask:_edgeFadeMaskLayer];
    }
    return self;
}

- (CAGradientLayer *)newEdgeFadeMaskLayer {
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    [gradientLayer setStartPoint:CGPointMake(0, 0.5)];
    [gradientLayer setEndPoint:CGPointMake(1, 0.5)];
    UIColor *opaqueColor = [UIColor colorWithWhite:0 alpha:1];
    [gradientLayer setColors:@[ (id)[opaqueColor CGColor], (id)[opaqueColor CGColor] ]];
    return gradientLayer;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateEdgeFadeMask];
}

- (void)setContentOffset:(CGPoint)contentOffset {
    [super setContentOffset:contentOffset];
    [self updateEdgeFadeMask];
}

- (void)setContentSize:(CGSize)contentSize {
    [super setContentSize:contentSize];
    [self updateEdgeFadeMask];
}

- (void)resetContentOffsetToLeadingEdge {
    [self layoutIfNeeded];
    UIEdgeInsets adjustedInset = [self adjustedContentInset];
    CGPoint contentOffset = [self contentOffset];
    contentOffset.x = -adjustedInset.left;
    contentOffset.y = -adjustedInset.top;
    [self setContentOffset:contentOffset animated:NO];
}

- (void)updateEdgeFadeMask {
    CAGradientLayer *maskLayer = [self edgeFadeMaskLayer];
    if (!maskLayer) {
        return;
    }

    CGFloat width = CGRectGetWidth([self bounds]);
    CGFloat height = CGRectGetHeight([self bounds]);
    if (width <= 0 || height <= 0) {
        return;
    }

    CGPoint contentOffset = [self contentOffset];
    UIEdgeInsets adjustedInset = [self adjustedContentInset];
    CGFloat leadingScrolledWidth = contentOffset.x + adjustedInset.left;
    CGFloat leadingFadeWidth = MIN([self edgeFadeWidth], MAX(leadingScrolledWidth, 0));

    CGFloat visibleMaxX = contentOffset.x + width;
    CGFloat remainingWidth = [self contentSize].width + adjustedInset.right - visibleMaxX;
    CGFloat trailingFadeWidth = MIN([self edgeFadeWidth], MAX(remainingWidth, 0));

    UIColor *opaqueColor = [UIColor colorWithWhite:0 alpha:1];
    UIColor *transparentColor = [UIColor colorWithWhite:0 alpha:0];
    NSArray *colors = @[ (id)[opaqueColor CGColor], (id)[opaqueColor CGColor] ];
    NSArray<NSNumber *> *locations = @[ @0, @1 ];
    BOOL showsLeadingFade = leadingFadeWidth > 0.5;
    BOOL showsTrailingFade = trailingFadeWidth > 0.5;
    if (showsLeadingFade && showsTrailingFade) {
        CGFloat leadingEndLocation = MIN(leadingFadeWidth / width, 1);
        CGFloat trailingStartLocation = MAX((width - trailingFadeWidth) / width, 0);
        if (leadingEndLocation > trailingStartLocation) {
            CGFloat midpoint = (leadingEndLocation + trailingStartLocation) / 2.0;
            leadingEndLocation = midpoint;
            trailingStartLocation = midpoint;
        }
        colors = @[
            (id)[transparentColor CGColor], (id)[opaqueColor CGColor], (id)[opaqueColor CGColor],
            (id)[transparentColor CGColor]
        ];
        locations = @[ @0, @(leadingEndLocation), @(trailingStartLocation), @1 ];
    } else if (showsLeadingFade) {
        CGFloat leadingEndLocation = MIN(leadingFadeWidth / width, 1);
        colors = @[ (id)[transparentColor CGColor], (id)[opaqueColor CGColor], (id)[opaqueColor CGColor] ];
        locations = @[ @0, @(leadingEndLocation), @1 ];
    } else if (showsTrailingFade) {
        CGFloat trailingStartLocation = MAX((width - trailingFadeWidth) / width, 0);
        colors = @[ (id)[opaqueColor CGColor], (id)[opaqueColor CGColor], (id)[transparentColor CGColor] ];
        locations = @[ @0, @(trailingStartLocation), @1 ];
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [maskLayer setFrame:CGRectMake(contentOffset.x, contentOffset.y, width, height)];
    [maskLayer setColors:colors];
    [maskLayer setLocations:locations];
    [CATransaction commit];
}

@end
