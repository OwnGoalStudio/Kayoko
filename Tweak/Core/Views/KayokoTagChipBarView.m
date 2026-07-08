//
//  KayokoTagChipBarView.m
//  Kayoko
//

#import "KayokoTagChipBarView.h"

#import "KayokoEdgeFadingScrollView.h"
#import "KayokoPasteboardManager.h"
#import "KayokoTag.h"
#import "KayokoTagColorFormatter.h"
#import "KayokoTagDotView.h"

#import <QuartzCore/QuartzCore.h>

static CGFloat const kKayokoTagChipBarHeight = 54;
static CGFloat const kKayokoTagChipHeight = 32;
static CGFloat const kKayokoTagChipMaximumWidth = 136;
static CGFloat const kKayokoTagChipHorizontalInset = 20;
static CGFloat const kKayokoTagChipSpacing = 8;
static CGFloat const kKayokoTagChipLeadingInset = 11;
static CGFloat const kKayokoTagChipTrailingInset = 13;
static CGFloat const kKayokoTagChipDotSlotSize = 20;
static CGFloat const kKayokoTagChipDotSize = 14;
static CGFloat const kKayokoTagChipDotBorderWidth = 1.25;
static CGFloat const kKayokoTagChipDotLabelSpacing = 7;
static CGFloat const kKayokoTagChipFadeHeight = 20;
static CGFloat const kKayokoTagChipFloatingLightMaterialAlpha = 1.0;
static CGFloat const kKayokoTagChipFloatingDarkMaterialAlpha = 0.38;
static CGFloat const kKayokoTagChipFloatingLightFadeAlpha = 0.58;
static CGFloat const kKayokoTagChipFloatingDarkFadeAlpha = 0.0;
static CGFloat const kKayokoTagChipFloatingProgressDistance = 42;

@interface KayokoTagChipButton : UIControl

#pragma mark - State

@property(nonatomic, copy, nullable) NSString *tagUUID;
@property(nonatomic, copy, nullable) NSString *hexColor;

#pragma mark - Views

@property(nonatomic, strong) KayokoTagDotView *dotView;
@property(nonatomic, strong) UILabel *textLabel;

#pragma mark - Configuration

- (void)configureWithTitle:(NSString *)title
                   tagUUID:(nullable NSString *)tagUUID
                  hexColor:(nullable NSString *)hexColor
                  selected:(BOOL)selected;
- (UIColor *)colorByResolvingColor:(UIColor *)color alpha:(CGFloat)alpha;
- (UIColor *)resolvedColorForCurrentTrait:(UIColor *)color;
- (CGFloat)preferredWidth;
@end

@implementation KayokoTagChipButton

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setIsAccessibilityElement:YES];
        [[self layer] setCornerRadius:kKayokoTagChipHeight / 2.0];
        [[self layer] setCornerCurve:kCACornerCurveContinuous];
        [[self layer] setBorderWidth:1.0 / [UIScreen mainScreen].scale];

        _dotView = [[KayokoTagDotView alloc] init];
        [_dotView setDotDiameter:kKayokoTagChipDotSize];
        [_dotView setBorderWidth:kKayokoTagChipDotBorderWidth];
        [self addSubview:_dotView];

        _textLabel = [[UILabel alloc] init];
        [_textLabel setFont:[UIFont systemFontOfSize:13 weight:UIFontWeightMedium]];
        [_textLabel setLineBreakMode:NSLineBreakByTruncatingTail];
        [self addSubview:_textLabel];
    }
    return self;
}

#pragma mark - Configuration

- (void)configureWithTitle:(NSString *)title
                   tagUUID:(nullable NSString *)tagUUID
                  hexColor:(nullable NSString *)hexColor
                  selected:(BOOL)selected {
    [self setTagUUID:[tagUUID copy]];
    [self setHexColor:[hexColor copy]];
    [self setSelected:selected];
    [[self textLabel] setText:title ?: @""];
    [self setAccessibilityLabel:title ?: @""];
    [self updateStyle];
    [self setNeedsLayout];
}

#pragma mark - Colors

- (UIColor *)selectedFillColor {
    if ([[self hexColor] length] > 0) {
        return [[KayokoTagColorFormatter visibleColorFromHexColor:[self hexColor]] colorWithAlphaComponent:0.12];
    }
    return [UIColor tertiarySystemFillColor];
}

- (UIColor *)normalFillColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      BOOL dark = [traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark;
      return [UIColor colorWithWhite:(dark ? 1.0 : 0.0) alpha:(dark ? 0.09 : 0.035)];
    }];
}

- (UIColor *)borderColor {
    if ([self isSelected] && [[self hexColor] length] > 0) {
        return [[KayokoTagColorFormatter borderColorFromHexColor:[self hexColor]] colorWithAlphaComponent:0.78];
    }
    if ([self isSelected]) {
        return [self colorByResolvingColor:[UIColor labelColor] alpha:0.24];
    }
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      BOOL dark = [traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark;
      UIColor *separatorColor = [[UIColor separatorColor] resolvedColorWithTraitCollection:traitCollection];
      return [separatorColor colorWithAlphaComponent:(dark ? 0.32 : 0.24)];
    }];
}

- (void)updateStyle {
    UIColor *textColor = [self isSelected] ? [UIColor labelColor] : [UIColor secondaryLabelColor];
    [[self textLabel] setTextColor:textColor];
    [self setBackgroundColor:[self isSelected] ? [self selectedFillColor] : [self normalFillColor]];
    [[self layer] setBorderWidth:[self isSelected] ? 1.0 : 1.0 / [UIScreen mainScreen].scale];
    [[self layer] setBorderColor:[[self resolvedColorForCurrentTrait:[self borderColor]] CGColor]];
    [self updateDotStyle];
    [self setAlpha:[self isHighlighted] ? 0.72 : 1.0];
}

- (void)updateDotStyle {
    if ([[self hexColor] length] > 0) {
        [[self dotView] configureWithFillColor:[KayokoTagColorFormatter visibleColorFromHexColor:[self hexColor]]
                                   borderColor:[KayokoTagColorFormatter borderColorFromHexColor:[self hexColor]]];
        return;
    }

    UIColor *tintColor = [self isSelected] ? [self colorByResolvingColor:[UIColor labelColor] alpha:0.64]
                                           : [self colorByResolvingColor:[UIColor secondaryLabelColor] alpha:0.54];
    [[self dotView] configureNoTagWithTintColor:tintColor];
}

- (UIColor *)colorByResolvingColor:(UIColor *)color alpha:(CGFloat)alpha {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      UIColor *resolvedColor = [color resolvedColorWithTraitCollection:traitCollection];
      return [resolvedColor colorWithAlphaComponent:alpha];
    }];
}

- (UIColor *)resolvedColorForCurrentTrait:(UIColor *)color {
    return [color resolvedColorWithTraitCollection:[self traitCollection]];
}

#pragma mark - State

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    [self updateStyle];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self updateStyle];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self updateStyle];
}

#pragma mark - Layout

- (CGFloat)preferredWidth {
    CGFloat maximumLabelWidth = kKayokoTagChipMaximumWidth - kKayokoTagChipLeadingInset - kKayokoTagChipDotSlotSize -
                                kKayokoTagChipDotLabelSpacing - kKayokoTagChipTrailingInset;
    CGSize labelSize = [[self textLabel] sizeThatFits:CGSizeMake(maximumLabelWidth, kKayokoTagChipHeight)];
    CGFloat width = kKayokoTagChipLeadingInset + kKayokoTagChipDotSlotSize + kKayokoTagChipDotLabelSpacing +
                    ceil(labelSize.width) + kKayokoTagChipTrailingInset;
    return MIN(MAX(width, kKayokoTagChipHeight), kKayokoTagChipMaximumWidth);
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect bounds = [self bounds];
    CGFloat dotY = floor((CGRectGetHeight(bounds) - kKayokoTagChipDotSlotSize) / 2.0);
    [[self dotView]
        setFrame:CGRectMake(kKayokoTagChipLeadingInset, dotY, kKayokoTagChipDotSlotSize, kKayokoTagChipDotSlotSize)];

    CGFloat x = CGRectGetMaxX([[self dotView] frame]) + kKayokoTagChipDotLabelSpacing;
    CGFloat labelWidth = MAX(CGRectGetWidth(bounds) - x - kKayokoTagChipTrailingInset, 0);
    [[self textLabel] setFrame:CGRectMake(x, 0, labelWidth, CGRectGetHeight(bounds))];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateStyle];
}

@end

@interface KayokoTagChipBarFadeView : UIView
@end

@implementation KayokoTagChipBarFadeView

#pragma mark - Layer

+ (Class)layerClass {
    return [CAGradientLayer class];
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self updateGradientColors];
    }
    return self;
}

#pragma mark - Appearance

- (void)updateGradientColors {
    BOOL dark = [[self traitCollection] userInterfaceStyle] == UIUserInterfaceStyleDark;
    UIColor *backgroundColor = dark ? [UIColor clearColor] : [UIColor systemBackgroundColor];
    CGFloat endAlpha = dark ? 0.0 : 0.08;
    CAGradientLayer *gradientLayer = (CAGradientLayer *)[self layer];
    [gradientLayer setStartPoint:CGPointMake(0.5, 0.0)];
    [gradientLayer setEndPoint:CGPointMake(0.5, 1.0)];
    [gradientLayer setColors:@[
        (__bridge id)[[backgroundColor colorWithAlphaComponent:0.0] CGColor],
        (__bridge id)[[backgroundColor colorWithAlphaComponent:endAlpha] CGColor]
    ]];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateGradientColors];
}

@end

@interface KayokoTagChipBarView ()

#pragma mark - Views

@property(nonatomic, strong) UIVisualEffectView *materialView;
@property(nonatomic, strong) CAGradientLayer *materialMaskLayer;
@property(nonatomic, strong) KayokoTagChipBarFadeView *fadeView;
@property(nonatomic, strong) KayokoEdgeFadingScrollView *scrollView;

#pragma mark - Data

@property(nonatomic, strong) NSMutableArray<KayokoTagChipButton *> *chipButtons;

#pragma mark - State

@property(nonatomic, assign, readwrite, getter=isSettled) BOOL settled;
@property(nonatomic, assign) CGFloat floatingProgress;
@property(nonatomic, assign) BOOL shouldRevealSelectedTagAfterLayout;
@end

@implementation KayokoTagChipBarView

#pragma mark - Metrics

+ (CGFloat)preferredHeight {
    return kKayokoTagChipBarHeight;
}

+ (CGFloat)floatingProgressForScrollView:(UIScrollView *)scrollView {
    UIEdgeInsets adjustedInset = [scrollView adjustedContentInset];
    CGFloat viewportHeight = CGRectGetHeight([scrollView bounds]) - adjustedInset.top - adjustedInset.bottom;
    CGFloat contentHeight = [scrollView contentSize].height;
    if (viewportHeight <= 0 || contentHeight <= viewportHeight + 0.5) {
        return 0.0;
    }

    CGFloat visibleBottomY = [scrollView contentOffset].y + CGRectGetHeight([scrollView bounds]) - adjustedInset.bottom;
    CGFloat distanceToBottom = contentHeight - visibleBottomY;
    return MIN(MAX(distanceToBottom / kKayokoTagChipFloatingProgressDistance, 0.0), 1.0);
}

#pragma mark - Appearance

- (BOOL)isDarkMode {
    return [[self traitCollection] userInterfaceStyle] == UIUserInterfaceStyleDark;
}

- (CGFloat)floatingMaterialAlpha {
    return [self isDarkMode] ? kKayokoTagChipFloatingDarkMaterialAlpha : kKayokoTagChipFloatingLightMaterialAlpha;
}

- (CGFloat)floatingFadeAlpha {
    return [self isDarkMode] ? kKayokoTagChipFloatingDarkFadeAlpha : kKayokoTagChipFloatingLightFadeAlpha;
}

- (UIBlurEffect *)materialEffect {
    UIBlurEffectStyle style =
        [self isDarkMode] ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterial;
    return [UIBlurEffect effectWithStyle:style];
}

- (void)updateMaterialEffect {
    [UIView performWithoutAnimation:^{
      [[self materialView] setEffect:[self materialEffect]];
    }];
}

- (void)updateFloatingLayerAlphas {
    [[self materialView] setAlpha:[self floatingMaterialAlpha] * [self floatingProgress]];
    [[self fadeView] setAlpha:[self floatingFadeAlpha] * [self floatingProgress]];
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setClipsToBounds:NO];
        [self setHidden:YES];

        _materialView = [[UIVisualEffectView alloc] initWithEffect:[self materialEffect]];
        [_materialView setUserInteractionEnabled:NO];
        [_materialView setHidden:YES];
        [_materialView setAlpha:0.0];
        _materialMaskLayer = [CAGradientLayer layer];
        [_materialMaskLayer setStartPoint:CGPointMake(0.5, 0.0)];
        [_materialMaskLayer setEndPoint:CGPointMake(0.5, 1.0)];
        [_materialMaskLayer setColors:@[
            (__bridge id)[[UIColor clearColor] CGColor], (__bridge id)[[UIColor blackColor] CGColor],
            (__bridge id)[[UIColor blackColor] CGColor]
        ]];
        [[_materialView layer] setMask:_materialMaskLayer];
        [self addSubview:_materialView];

        _fadeView = [[KayokoTagChipBarFadeView alloc] init];
        [_fadeView setUserInteractionEnabled:NO];
        [_fadeView setAlpha:0.0];
        [self addSubview:_fadeView];

        _scrollView = [[KayokoEdgeFadingScrollView alloc] init];
        [_scrollView setShowsHorizontalScrollIndicator:NO];
        [_scrollView setAlwaysBounceHorizontal:YES];
        [_scrollView setBackgroundColor:[UIColor clearColor]];
        [_scrollView setEdgeFadeAxis:KayokoEdgeFadeAxisHorizontal];
        [_scrollView setEdgeFadeWidth:kKayokoTagChipHorizontalInset];
        [_scrollView setEdgeFadeEnabled:YES];
        [self addSubview:_scrollView];

        _chipButtons = [[NSMutableArray alloc] init];
        _settled = YES;
    }
    return self;
}

#pragma mark - Configuration

- (void)configureWithTags:(NSArray<KayokoTag *> *)tags selectedTagUUID:(NSString *)selectedTagUUID {
    for (KayokoTagChipButton *button in [self chipButtons]) {
        [button removeFromSuperview];
    }
    [[self chipButtons] removeAllObjects];

    [self setSelectedTagUUID:[selectedTagUUID copy]];
    [self setShouldRevealSelectedTagAfterLayout:([selectedTagUUID length] > 0)];
    [self setHidden:[tags count] == 0];
    if ([tags count] == 0) {
        [self setShouldRevealSelectedTagAfterLayout:NO];
        [[self scrollView] setContentSize:CGSizeZero];
        return;
    }

    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    NSString *noTagTitle = [bundle localizedStringForKey:@"No Tag" value:nil table:@"Tweak"];
    [self addChipWithTitle:noTagTitle tagUUID:nil hexColor:nil];
    for (KayokoTag *tag in tags) {
        [self addChipWithTitle:[tag title] tagUUID:[tag uuid] hexColor:[tag hexColor]];
    }

    [[self scrollView] setContentOffset:CGPointZero animated:NO];
    [[self scrollView] updateEdgeFadeMask];
    [self setNeedsLayout];
}

#pragma mark - Selection

- (KayokoTagChipButton *)chipButtonForSelectedTag {
    if ([[self selectedTagUUID] length] == 0) {
        return nil;
    }

    for (KayokoTagChipButton *button in [self chipButtons]) {
        if ([[button tagUUID] isEqualToString:[self selectedTagUUID]]) {
            return button;
        }
    }

    return nil;
}

- (BOOL)revealSelectedTagIfPossible {
    if ([[self selectedTagUUID] length] == 0) {
        return YES;
    }

    KayokoEdgeFadingScrollView *scrollView = [self scrollView];
    CGFloat visibleWidth = CGRectGetWidth([scrollView bounds]);
    CGFloat contentWidth = [scrollView contentSize].width;
    if (visibleWidth <= 0 || contentWidth <= 0) {
        return NO;
    }

    KayokoTagChipButton *button = [self chipButtonForSelectedTag];
    if (!button) {
        return YES;
    }

    CGFloat currentOffsetX = [scrollView contentOffset].x;
    CGRect visibleRect = CGRectMake(currentOffsetX, 0, visibleWidth, CGRectGetHeight([scrollView bounds]));
    CGRect comfortableRect = CGRectInset(visibleRect, kKayokoTagChipHorizontalInset, 0);
    CGRect checkRect =
        CGRectGetWidth(comfortableRect) >= CGRectGetWidth([button frame]) ? comfortableRect : visibleRect;
    if (CGRectContainsRect(checkRect, [button frame])) {
        return YES;
    }

    CGFloat targetOffsetX = currentOffsetX;
    if (CGRectGetMinX([button frame]) < CGRectGetMinX(checkRect)) {
        targetOffsetX = CGRectGetMinX([button frame]) - kKayokoTagChipHorizontalInset;
    } else if (CGRectGetMaxX([button frame]) > CGRectGetMaxX(checkRect)) {
        targetOffsetX = CGRectGetMaxX([button frame]) - visibleWidth + kKayokoTagChipHorizontalInset;
    }

    CGFloat maximumOffsetX = MAX(contentWidth - visibleWidth, 0);
    targetOffsetX = MIN(MAX(floor(targetOffsetX), 0), maximumOffsetX);
    [scrollView setContentOffset:CGPointMake(targetOffsetX, [scrollView contentOffset].y) animated:NO];
    [scrollView updateEdgeFadeMask];
    return YES;
}

- (void)addChipWithTitle:(NSString *)title tagUUID:(NSString *)tagUUID hexColor:(NSString *)hexColor {
    KayokoTagChipButton *button = [[KayokoTagChipButton alloc] initWithFrame:CGRectZero];
    BOOL selected = ([tagUUID length] == 0 && [[self selectedTagUUID] length] == 0) ||
                    [[self selectedTagUUID] isEqualToString:tagUUID ?: @""];
    [[self scrollView] addSubview:button];
    [[self chipButtons] addObject:button];
    [button configureWithTitle:title tagUUID:tagUUID hexColor:hexColor selected:selected];
    [button addTarget:self action:@selector(handleChipPressed:) forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - State

- (void)setSelectedTagUUID:(NSString *)selectedTagUUID {
    _selectedTagUUID = [selectedTagUUID length] > 0 ? [selectedTagUUID copy] : nil;
    for (KayokoTagChipButton *button in [self chipButtons]) {
        BOOL selected = ([[button tagUUID] length] == 0 && [_selectedTagUUID length] == 0) ||
                        [[button tagUUID] isEqualToString:_selectedTagUUID ?: @""];
        [button setSelected:selected];
    }
    [self setNeedsLayout];
}

#pragma mark - Actions

- (void)handleChipPressed:(KayokoTagChipButton *)button {
    if ([self selectionHandler]) {
        [self selectionHandler]([button tagUUID]);
    }
}

#pragma mark - Floating Material

- (void)setBottomMaterialExtension:(CGFloat)bottomMaterialExtension {
    CGFloat normalizedExtension = MAX(bottomMaterialExtension, 0.0);
    if (fabs(_bottomMaterialExtension - normalizedExtension) < 0.5) {
        return;
    }

    _bottomMaterialExtension = normalizedExtension;
    [self setNeedsLayout];
}

- (void)setFloatingProgress:(CGFloat)floatingProgress animated:(BOOL)animated {
    CGFloat normalizedProgress = MIN(MAX(floatingProgress, 0.0), 1.0);
    BOOL settled = normalizedProgress <= 0.001;
    if (fabs(_floatingProgress - normalizedProgress) < 0.001 && _settled == settled) {
        return;
    }

    _floatingProgress = normalizedProgress;
    _settled = settled;

    if (!settled) {
        [[self materialView] setHidden:NO];
    }

    void (^updates)(void) = ^{
      [self updateFloatingLayerAlphas];
    };

    if (!animated) {
        [UIView performWithoutAnimation:updates];
        [[self materialView] setHidden:settled];
        return;
    }

    [UIView animateWithDuration:0.18
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:updates
                     completion:^(BOOL finished) {
                       if (finished) {
                           [[self materialView] setHidden:[self isSettled]];
                       }
                     }];
}

- (void)setSettled:(BOOL)settled animated:(BOOL)animated {
    [self setFloatingProgress:(settled ? 0.0 : 1.0) animated:animated];
}

#pragma mark - Layout

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([[self traitCollection] hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self updateMaterialEffect];
        [UIView performWithoutAnimation:^{
          [self updateFloatingLayerAlphas];
        }];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect bounds = [self bounds];
    CGFloat bottomExtension = MAX([self bottomMaterialExtension], 0.0);
    CGRect materialFrame = CGRectMake(0, -kKayokoTagChipFadeHeight, CGRectGetWidth(bounds),
                                      CGRectGetHeight(bounds) + kKayokoTagChipFadeHeight + bottomExtension);
    CGFloat fadeLocation =
        CGRectGetHeight(materialFrame) > 0 ? MIN(kKayokoTagChipFadeHeight / CGRectGetHeight(materialFrame), 1.0) : 0.0;

    [UIView performWithoutAnimation:^{
      [[self materialView] setFrame:materialFrame];
      [[self fadeView]
          setFrame:CGRectMake(0, -kKayokoTagChipFadeHeight, CGRectGetWidth(bounds), kKayokoTagChipFadeHeight)];

      CGFloat scrollY = floor((CGRectGetHeight(bounds) - kKayokoTagChipHeight) / 2.0);
      [[self scrollView] setFrame:CGRectMake(0, scrollY, CGRectGetWidth(bounds), kKayokoTagChipHeight)];

      CGFloat x = kKayokoTagChipHorizontalInset;
      for (KayokoTagChipButton *button in [self chipButtons]) {
          CGFloat width = [button preferredWidth];
          [button setFrame:CGRectMake(x, 0, width, kKayokoTagChipHeight)];
          x += width + kKayokoTagChipSpacing;
      }
      x += kKayokoTagChipHorizontalInset - kKayokoTagChipSpacing;
      [[self scrollView]
          setContentSize:CGSizeMake(MAX(x, CGRectGetWidth([[self scrollView] bounds]) + 1), kKayokoTagChipHeight)];
      if ([self shouldRevealSelectedTagAfterLayout] && [self revealSelectedTagIfPossible]) {
          [self setShouldRevealSelectedTagAfterLayout:NO];
      }
      [[self scrollView] updateEdgeFadeMask];
    }];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [[self materialMaskLayer] setFrame:[[self materialView] bounds]];
    [[self materialMaskLayer] setLocations:@[ @0.0, @(fadeLocation), @1.0 ]];
    [CATransaction commit];
}

@end
