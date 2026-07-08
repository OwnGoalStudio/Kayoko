//
//  KayokoStepSliderCell.m
//  Kayoko
//

#import "KayokoStepSliderCell.h"

#import <Preferences/PSSpecifier.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoStepSlider : UISlider
@property(nonatomic, copy) NSArray<NSNumber *> *stepValues;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoStepSlider {
    CGRect _cachedTrackRect;
    CGRect _cachedThumbRect;
}

#pragma mark - Track Geometry

- (CGRect)trackRectForBounds:(CGRect)bounds {
    _cachedTrackRect = [super trackRectForBounds:bounds];
    return _cachedTrackRect;
}

- (CGRect)thumbRectForBounds:(CGRect)bounds trackRect:(CGRect)rect value:(float)value {
    _cachedThumbRect = [super thumbRectForBounds:bounds trackRect:rect value:value];
    return _cachedThumbRect;
}

#pragma mark - Step Rendering

- (void)setStepValues:(NSArray<NSNumber *> *)stepValues {
    _stepValues = [stepValues copy];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    if ([[self stepValues] count] < 2) {
        return;
    }

    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }

    CGRect trackRect = CGRectInset(_cachedTrackRect, CGRectGetWidth(_cachedThumbRect) / 2.0, 0);
    if (CGRectIsEmpty(trackRect)) {
        trackRect = CGRectInset([self trackRectForBounds:[self bounds]], 14, 0);
    }

    UIColor *tickColor = [[self tintColor] colorWithAlphaComponent:0.45];
    CGContextSetFillColorWithColor(context, [tickColor CGColor]);

    CGFloat tickWidth = 3.0;
    CGFloat tickHeight = MAX(CGRectGetHeight(trackRect) * 3.0, 6.0);
    NSUInteger lastIndex = [[self stepValues] count] - 1;
    for (NSUInteger index = 0; index <= lastIndex; index++) {
        CGFloat progress = (CGFloat)index / (CGFloat)lastIndex;
        CGFloat x = CGRectGetMinX(trackRect) + progress * CGRectGetWidth(trackRect) - tickWidth / 2.0;
        CGFloat y = CGRectGetMidY(trackRect) - tickHeight / 2.0;
        UIBezierPath *tickPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(x, y, tickWidth, tickHeight)
                                                            cornerRadius:tickWidth / 2.0];
        CGContextAddPath(context, [tickPath CGPath]);
    }

    CGContextFillPath(context);
}

@end

@implementation KayokoStepSliderCell {
    KayokoStepSlider *_slider;
    UILabel *_valueLabel;
    NSArray<NSNumber *> *_stepValues;
    CGFloat _valueLabelWidth;
}

#pragma mark - Lifecycle

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (!self) {
        return nil;
    }

    _valueLabelWidth = [[specifier propertyForKey:@"valueLabelWidth"] doubleValue] ?: 50.0;

    _slider = [[KayokoStepSlider alloc] init];
    [_slider setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [[self contentView] addSubview:_slider];

    _valueLabel = [[UILabel alloc] init];
    [_valueLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_valueLabel setTextAlignment:NSTextAlignmentRight];
    [_valueLabel setFont:[UIFont monospacedDigitSystemFontOfSize:[UIFont systemFontSize] weight:UIFontWeightRegular]];
    [_valueLabel setTextColor:[UIColor secondaryLabelColor]];
    [_valueLabel setAdjustsFontSizeToFitWidth:YES];
    [_valueLabel setMinimumScaleFactor:0.75];
    [[self contentView] addSubview:_valueLabel];

    [self setupConstraints];
    [self syncWithSpecifier:specifier];

    return self;
}

#pragma mark - Layout

- (void)setupConstraints {
    UILayoutGuide *margins = [self layoutMarginsGuide];
    [NSLayoutConstraint activateConstraints:@[
        [_slider.leadingAnchor constraintEqualToAnchor:[margins leadingAnchor]],
        [_slider.trailingAnchor constraintEqualToAnchor:[_valueLabel leadingAnchor] constant:-12],
        [_slider.centerYAnchor constraintEqualToAnchor:[[self contentView] centerYAnchor]],

        [_valueLabel.trailingAnchor constraintEqualToAnchor:[margins trailingAnchor]],
        [_valueLabel.centerYAnchor constraintEqualToAnchor:[[self contentView] centerYAnchor]],
        [_valueLabel.widthAnchor constraintEqualToConstant:_valueLabelWidth],

        [[[self contentView] heightAnchor] constraintGreaterThanOrEqualToConstant:44],
    ]];
}

#pragma mark - Specifier Sync

- (void)setSpecifier:(PSSpecifier *)specifier {
    [super setSpecifier:specifier];
    [self syncWithSpecifier:specifier];
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    [self syncWithSpecifier:specifier];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self syncWithSpecifier:[self specifier]];
}

- (void)syncWithSpecifier:(PSSpecifier *)specifier {
    _stepValues = [self normalizedStepValuesFromSpecifier:specifier];
    [_slider setStepValues:_stepValues];
    [_slider setMinimumValue:0];
    [_slider setMaximumValue:MAX((NSInteger)[_stepValues count] - 1, 0)];

    NSNumber *isContinuous = [specifier propertyForKey:@"isContinuous"];
    [_slider setContinuous:isContinuous ? [isContinuous boolValue] : YES];

    NSNumber *storedValue = [specifier performGetter];
    if (![storedValue isKindOfClass:[NSNumber class]]) {
        storedValue = [specifier propertyForKey:@"default"];
    }

    NSUInteger index = [self upperBoundIndexForValue:[storedValue unsignedIntegerValue]];
    [_slider setValue:(float)index animated:NO];
    [self updateValueLabelForIndex:index];
}

#pragma mark - Value Mapping

- (NSArray<NSNumber *> *)normalizedStepValuesFromSpecifier:(PSSpecifier *)specifier {
    NSArray<NSNumber *> *values = [specifier propertyForKey:@"stepValues"];
    NSMutableArray<NSNumber *> *normalizedValues = [[NSMutableArray alloc] init];
    for (id value in values) {
        if ([value isKindOfClass:[NSNumber class]]) {
            [normalizedValues addObject:value];
        }
    }

    if ([normalizedValues count] == 0) {
        return @[ @50, @100, @200, @300, @500, @1000, @2000, @3000, @4000, @5000 ];
    }

    return normalizedValues;
}

- (NSUInteger)upperBoundIndexForValue:(NSUInteger)value {
    if ([_stepValues count] == 0) {
        return 0;
    }

    for (NSUInteger index = 0; index < [_stepValues count]; index++) {
        NSUInteger candidate = [_stepValues[index] unsignedIntegerValue];
        if (value <= candidate) {
            return index;
        }
    }
    return [_stepValues count] - 1;
}

- (NSNumber *)valueForIndex:(NSUInteger)index {
    if ([_stepValues count] == 0) {
        return @0;
    }
    NSUInteger boundedIndex = MIN(index, [_stepValues count] - 1);
    return _stepValues[boundedIndex];
}

- (void)updateValueLabelForIndex:(NSUInteger)index {
    [_valueLabel setText:[[self valueForIndex:index] stringValue]];
}

#pragma mark - Actions

- (void)sliderValueChanged:(UISlider *)slider {
    NSUInteger index = (NSUInteger)llroundf([slider value]);
    [slider setValue:(float)index animated:NO];
    [self updateValueLabelForIndex:index];

    NSNumber *value = [self valueForIndex:index];
    [[self specifier] performSetterWithValue:value];
}

@end
