//
//  KayokoEdgeFadeMaskController.m
//  Kayoko
//

#import "KayokoEdgeFadeMaskController.h"

#import <QuartzCore/QuartzCore.h>

@interface KayokoEdgeFadeMaskController ()
@property(nonatomic, weak) UIScrollView *scrollView;
@property(nonatomic, strong) CAGradientLayer *maskLayer;
@end

@implementation KayokoEdgeFadeMaskController

#pragma mark - Lifecycle

- (instancetype)initWithScrollView:(UIScrollView *)scrollView {
    self = [super init];
    if (self) {
        _scrollView = scrollView;
        _axis = KayokoEdgeFadeAxisHorizontal;
        _enabled = YES;
        _maskLayer = [self newMaskLayer];
        [[scrollView layer] setMask:_maskLayer];
    }
    return self;
}

#pragma mark - Layers

- (CAGradientLayer *)newMaskLayer {
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    [gradientLayer setStartPoint:CGPointMake(0, 0.5)];
    [gradientLayer setEndPoint:CGPointMake(1, 0.5)];

    UIColor *opaqueColor = [UIColor colorWithWhite:0 alpha:1];
    [gradientLayer setColors:@[ (__bridge id)[opaqueColor CGColor], (__bridge id)[opaqueColor CGColor] ]];
    [gradientLayer setLocations:@[ @0, @1 ]];
    return gradientLayer;
}

#pragma mark - Configuration

- (void)setFadeWidth:(CGFloat)fadeWidth {
    CGFloat normalizedFadeWidth = MAX(fadeWidth, 0.0);
    if (fabs(_fadeWidth - normalizedFadeWidth) < 0.5) {
        return;
    }

    _fadeWidth = normalizedFadeWidth;
    [self updateMask];
}

- (void)setEdgeInsets:(UIEdgeInsets)edgeInsets {
    UIEdgeInsets normalizedInsets = UIEdgeInsetsMake(MAX(edgeInsets.top, 0), MAX(edgeInsets.left, 0),
                                                     MAX(edgeInsets.bottom, 0), MAX(edgeInsets.right, 0));
    if (UIEdgeInsetsEqualToEdgeInsets(_edgeInsets, normalizedInsets)) {
        return;
    }

    _edgeInsets = normalizedInsets;
    [self updateMask];
}

- (void)setLeadingFadeScrollOffset:(CGFloat)leadingFadeScrollOffset {
    CGFloat normalizedOffset = MAX(leadingFadeScrollOffset, 0);
    if (fabs(_leadingFadeScrollOffset - normalizedOffset) < 0.5) {
        return;
    }

    _leadingFadeScrollOffset = normalizedOffset;
    [self updateMask];
}

- (void)setAxis:(KayokoEdgeFadeAxis)axis {
    if (_axis == axis) {
        return;
    }

    _axis = axis;
    [self updateMask];
}

- (void)setEnabled:(BOOL)enabled {
    if (_enabled == enabled) {
        return;
    }

    _enabled = enabled;
    [self updateMask];
}

#pragma mark - Mask Updates

- (void)updateMask {
    UIScrollView *scrollView = [self scrollView];
    CAGradientLayer *maskLayer = [self maskLayer];
    if (!scrollView || !maskLayer) {
        return;
    }

    CGFloat width = CGRectGetWidth([scrollView bounds]);
    CGFloat height = CGRectGetHeight([scrollView bounds]);
    if (width <= 0 || height <= 0) {
        return;
    }

    CGPoint contentOffset = [scrollView contentOffset];
    UIColor *opaqueColor = [UIColor colorWithWhite:0 alpha:1];
    UIColor *transparentColor = [UIColor colorWithWhite:0 alpha:0];
    NSArray *colors = @[ (__bridge id)[opaqueColor CGColor], (__bridge id)[opaqueColor CGColor] ];
    NSArray<NSNumber *> *locations = @[ @0, @1 ];

    if ([self isEnabled] && [self fadeWidth] > 0.5) {
        UIEdgeInsets adjustedInset = [scrollView adjustedContentInset];
        BOOL verticalAxis = [self axis] == KayokoEdgeFadeAxisVertical;
        CGFloat visibleLength = verticalAxis ? height : width;
        CGFloat contentLength = verticalAxis ? [scrollView contentSize].height : [scrollView contentSize].width;
        CGFloat leadingInset = verticalAxis ? adjustedInset.top : adjustedInset.left;
        CGFloat trailingInset = verticalAxis ? adjustedInset.bottom : adjustedInset.right;
        CGFloat contentOffsetValue = verticalAxis ? contentOffset.y : contentOffset.x;
        UIEdgeInsets edgeInsets = [self edgeInsets];
        CGFloat leadingEdgeInset = verticalAxis ? edgeInsets.top : edgeInsets.left;
        CGFloat trailingEdgeInset = verticalAxis ? edgeInsets.bottom : edgeInsets.right;
        leadingEdgeInset = MIN(MAX(leadingEdgeInset, 0), visibleLength);
        trailingEdgeInset = MIN(MAX(trailingEdgeInset, 0), MAX(visibleLength - leadingEdgeInset, 0));
        CGFloat fadeStart = leadingEdgeInset;
        CGFloat fadeEnd = visibleLength - trailingEdgeInset;
        CGFloat fadeLength = MAX(fadeEnd - fadeStart, 0);

        CGFloat leadingScrolledWidth = contentOffsetValue + leadingInset - [self leadingFadeScrollOffset];
        CGFloat leadingFadeWidth = MIN(MIN([self fadeWidth], fadeLength), MAX(leadingScrolledWidth, 0));

        CGFloat visibleMaxX = contentOffsetValue + visibleLength;
        CGFloat remainingWidth = contentLength + trailingInset - visibleMaxX;
        CGFloat trailingFadeWidth = MIN(MIN([self fadeWidth], fadeLength), MAX(remainingWidth, 0));

        BOOL showsLeadingFade = leadingFadeWidth > 0.5;
        BOOL showsTrailingFade = trailingFadeWidth > 0.5;
        if (fadeLength <= 0.5) {
            colors = @[ (__bridge id)[transparentColor CGColor], (__bridge id)[transparentColor CGColor] ];
            locations = @[ @0, @1 ];
        } else if (showsLeadingFade && showsTrailingFade) {
            CGFloat leadingEnd = fadeStart + leadingFadeWidth;
            CGFloat trailingStart = fadeEnd - trailingFadeWidth;
            if (leadingEnd > trailingStart) {
                CGFloat midpoint = (leadingEnd + trailingStart) / 2.0;
                leadingEnd = midpoint;
                trailingStart = midpoint;
            }
            colors = @[
                (__bridge id)[transparentColor CGColor], (__bridge id)[opaqueColor CGColor],
                (__bridge id)[opaqueColor CGColor], (__bridge id)[transparentColor CGColor],
                (__bridge id)[transparentColor CGColor]
            ];
            locations = @[
                @(fadeStart / visibleLength), @(leadingEnd / visibleLength), @(trailingStart / visibleLength),
                @(fadeEnd / visibleLength), @1
            ];
        } else if (showsLeadingFade) {
            CGFloat leadingEnd = fadeStart + leadingFadeWidth;
            if (trailingEdgeInset > 0.5) {
                colors = @[
                    (__bridge id)[transparentColor CGColor], (__bridge id)[opaqueColor CGColor],
                    (__bridge id)[opaqueColor CGColor], (__bridge id)[transparentColor CGColor]
                ];
                locations =
                    @[ @(fadeStart / visibleLength), @(leadingEnd / visibleLength), @(fadeEnd / visibleLength), @1 ];
            } else {
                colors = @[
                    (__bridge id)[transparentColor CGColor], (__bridge id)[opaqueColor CGColor],
                    (__bridge id)[opaqueColor CGColor]
                ];
                locations = @[ @(fadeStart / visibleLength), @(leadingEnd / visibleLength), @1 ];
            }
        } else if (showsTrailingFade) {
            CGFloat trailingStart = fadeEnd - trailingFadeWidth;
            colors = @[
                (__bridge id)[opaqueColor CGColor], (__bridge id)[opaqueColor CGColor],
                (__bridge id)[transparentColor CGColor], (__bridge id)[transparentColor CGColor]
            ];
            locations = @[ @0, @(trailingStart / visibleLength), @(fadeEnd / visibleLength), @1 ];
        } else if (leadingEdgeInset > 0.5 || trailingEdgeInset > 0.5) {
            if (leadingEdgeInset > 0.5 && trailingEdgeInset > 0.5) {
                colors = @[
                    (__bridge id)[transparentColor CGColor], (__bridge id)[opaqueColor CGColor],
                    (__bridge id)[opaqueColor CGColor], (__bridge id)[transparentColor CGColor]
                ];
                locations = @[ @0, @(fadeStart / visibleLength), @(fadeEnd / visibleLength), @1 ];
            } else if (leadingEdgeInset > 0.5) {
                colors = @[
                    (__bridge id)[transparentColor CGColor], (__bridge id)[opaqueColor CGColor],
                    (__bridge id)[opaqueColor CGColor]
                ];
                locations = @[ @0, @(fadeStart / visibleLength), @1 ];
            } else {
                colors = @[
                    (__bridge id)[opaqueColor CGColor], (__bridge id)[opaqueColor CGColor],
                    (__bridge id)[transparentColor CGColor]
                ];
                locations = @[ @0, @(fadeEnd / visibleLength), @1 ];
            }
        }
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if ([self axis] == KayokoEdgeFadeAxisVertical) {
        [maskLayer setStartPoint:CGPointMake(0.5, 0)];
        [maskLayer setEndPoint:CGPointMake(0.5, 1)];
    } else {
        [maskLayer setStartPoint:CGPointMake(0, 0.5)];
        [maskLayer setEndPoint:CGPointMake(1, 0.5)];
    }
    [maskLayer setFrame:CGRectMake(contentOffset.x, contentOffset.y, width, height)];
    [maskLayer setColors:colors];
    [maskLayer setLocations:locations];
    [CATransaction commit];
}

@end
