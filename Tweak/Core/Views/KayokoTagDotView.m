//
//  KayokoTagDotView.m
//  Kayoko
//

#import "KayokoTagDotView.h"

#import <QuartzCore/QuartzCore.h>

static CGFloat const kKayokoTagDotDefaultDiameter = 14.0;
static CGFloat const kKayokoTagDotDefaultBorderWidth = 1.25;

@interface KayokoTagDotView ()
@property(nonatomic, strong) CAShapeLayer *dotLayer;
@property(nonatomic, strong) CAShapeLayer *noTagRingLayer;
@property(nonatomic, strong) CAShapeLayer *noTagSlashLayer;
@property(nonatomic, strong, nullable) UIColor *fillColor;
@property(nonatomic, strong, nullable) UIColor *borderColor;
@property(nonatomic, strong, nullable) UIColor *noTagTintColor;
@property(nonatomic, assign) BOOL showsNoTagGlyph;
- (nullable UIColor *)resolvedColorForCurrentTrait:(nullable UIColor *)color;
- (void)updateLayerColors;
@end

@implementation KayokoTagDotView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setUserInteractionEnabled:NO];
        [self setClipsToBounds:NO];
        _dotDiameter = kKayokoTagDotDefaultDiameter;
        _borderWidth = kKayokoTagDotDefaultBorderWidth;

        _dotLayer = [CAShapeLayer layer];
        [_dotLayer setContentsScale:[UIScreen mainScreen].scale];
        [[self layer] addSublayer:_dotLayer];

        _noTagRingLayer = [CAShapeLayer layer];
        [_noTagRingLayer setContentsScale:[UIScreen mainScreen].scale];
        [_noTagRingLayer setFillColor:[[UIColor clearColor] CGColor]];
        [[self layer] addSublayer:_noTagRingLayer];

        _noTagSlashLayer = [CAShapeLayer layer];
        [_noTagSlashLayer setContentsScale:[UIScreen mainScreen].scale];
        [_noTagSlashLayer setFillColor:[[UIColor clearColor] CGColor]];
        [_noTagSlashLayer setLineCap:kCALineCapRound];
        [[self layer] addSublayer:_noTagSlashLayer];

        [self configureWithFillColor:nil borderColor:nil];
    }
    return self;
}

- (void)configureWithFillColor:(nullable UIColor *)fillColor borderColor:(nullable UIColor *)borderColor {
    [self setFillColor:fillColor];
    [self setBorderColor:borderColor];
    [self setNoTagTintColor:nil];
    [self setShowsNoTagGlyph:NO];
    [self updateLayerColors];
    [self setNeedsLayout];
}

- (void)configureNoTagWithTintColor:(UIColor *)tintColor {
    [self setFillColor:nil];
    [self setBorderColor:nil];
    [self setNoTagTintColor:tintColor];
    [self setShowsNoTagGlyph:YES];
    [self updateLayerColors];
    [self setNeedsLayout];
}

- (nullable UIColor *)resolvedColorForCurrentTrait:(nullable UIColor *)color {
    return [color resolvedColorWithTraitCollection:[self traitCollection]];
}

- (void)updateLayerColors {
    UIColor *resolvedFillColor = [self resolvedColorForCurrentTrait:[self fillColor]];
    UIColor *resolvedBorderColor = [self resolvedColorForCurrentTrait:[self borderColor]];
    UIColor *resolvedNoTagTintColor = [self resolvedColorForCurrentTrait:[self noTagTintColor]];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [[self dotLayer] setHidden:[self showsNoTagGlyph] || [self fillColor] == nil];
    [[self dotLayer] setFillColor:[resolvedFillColor CGColor]];
    [[self dotLayer] setStrokeColor:[resolvedBorderColor CGColor]];
    [[self noTagRingLayer] setHidden:![self showsNoTagGlyph]];
    [[self noTagRingLayer] setStrokeColor:[resolvedNoTagTintColor CGColor]];
    [[self noTagSlashLayer] setHidden:![self showsNoTagGlyph]];
    [[self noTagSlashLayer] setStrokeColor:[resolvedNoTagTintColor CGColor]];
    [CATransaction commit];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self updateLayerColors];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([[self traitCollection] hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self updateLayerColors];
    }
}

- (void)setDotDiameter:(CGFloat)dotDiameter {
    _dotDiameter = MAX(dotDiameter, 1.0);
    [self setNeedsLayout];
}

- (void)setBorderWidth:(CGFloat)borderWidth {
    _borderWidth = MAX(borderWidth, 0.0);
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateLayerPaths];
}

- (void)updateLayerPaths {
    CGRect bounds = [self bounds];
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    CGFloat dotX = floor((CGRectGetWidth(bounds) - [self dotDiameter]) / 2.0);
    CGFloat dotY = floor((CGRectGetHeight(bounds) - [self dotDiameter]) / 2.0);
    CGRect dotRect = CGRectMake(dotX, dotY, [self dotDiameter], [self dotDiameter]);
    CGFloat strokeWidth = [self borderWidth];
    CGRect pathRect = CGRectInset(dotRect, strokeWidth / 2.0, strokeWidth / 2.0);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [[self dotLayer] setFrame:bounds];
    [[self dotLayer] setLineWidth:strokeWidth];
    [[self dotLayer] setPath:[[UIBezierPath bezierPathWithOvalInRect:pathRect] CGPath]];

    [[self noTagRingLayer] setFrame:bounds];
    [[self noTagRingLayer] setLineWidth:strokeWidth];
    [[self noTagRingLayer] setPath:[[UIBezierPath bezierPathWithOvalInRect:pathRect] CGPath]];

    CGFloat slashInset = round([self dotDiameter] * 0.29);
    UIBezierPath *slashPath = [UIBezierPath bezierPath];
    [slashPath moveToPoint:CGPointMake(CGRectGetMinX(dotRect) + slashInset, CGRectGetMaxY(dotRect) - slashInset)];
    [slashPath addLineToPoint:CGPointMake(CGRectGetMaxX(dotRect) - slashInset, CGRectGetMinY(dotRect) + slashInset)];
    [[self noTagSlashLayer] setFrame:bounds];
    [[self noTagSlashLayer] setLineWidth:strokeWidth];
    [[self noTagSlashLayer] setPath:[slashPath CGPath]];
    [CATransaction commit];
}

@end
