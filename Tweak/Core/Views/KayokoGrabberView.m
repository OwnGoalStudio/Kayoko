//
//  KayokoGrabberView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoGrabberView.h"

#import <QuartzCore/QuartzCore.h>

@interface KayokoGrabberView ()
@property(nonatomic, strong) CAShapeLayer *lineLayer;
@end

@implementation KayokoGrabberView

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _lineLayer = [CAShapeLayer layer];
        [[self lineLayer] setFillColor:nil];
        [[self lineLayer] setLineCap:kCALineCapRound];
        [[self lineLayer] setLineJoin:kCALineJoinRound];
        [[self lineLayer] setLineWidth:5];
        [[self layer] addSublayer:[self lineLayer]];
        [self setFoldProgress:0];
    }
    return self;
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(36, 12);
}

- (void)tintColorDidChange {
    [super tintColorDidChange];
    [self updateLineColor];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateLineColor];
}

- (void)setFoldProgress:(CGFloat)foldProgress {
    _foldProgress = MIN(MAX(foldProgress, 0), 1);
    [self setNeedsLayout];
}

- (void)updateLineColor {
    UIColor *lineColor = [[UIColor labelColor] colorWithAlphaComponent:0.28];
    [[self lineLayer] setStrokeColor:[lineColor CGColor]];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateLineColor];

    CGRect bounds = [self bounds];
    CGFloat minX = 2.5;
    CGFloat maxX = CGRectGetWidth(bounds) - 2.5;
    CGFloat midX = CGRectGetMidX(bounds);
    CGFloat midY = CGRectGetMidY(bounds);
    CGFloat foldedMidY = midY + 4 * [self foldProgress];

    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(minX, midY)];
    [path addLineToPoint:CGPointMake(midX, foldedMidY)];
    [path addLineToPoint:CGPointMake(maxX, midY)];
    [[self lineLayer] setFrame:bounds];
    [[self lineLayer] setPath:[path CGPath]];
}

@end
