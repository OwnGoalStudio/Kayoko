//
//  KayokoWordSelectionView.m
//  Kayoko
//

#import "KayokoWordSelectionView.h"
#import "KayokoMainView.h"
#import "KayokoWordSelectionTokenizer.h"
#import "KayokoWordTokenView.h"

static CGFloat const kKayokoWordSelectionHorizontalInset = 20;
static CGFloat const kKayokoWordSelectionTopInset = 8;
static CGFloat const kKayokoWordSelectionTokenSpacing = 2;
static CGFloat const kKayokoWordSelectionLineSpacing = 9;
static CGFloat const kKayokoWordSelectionTokenHeight = 34;
static CGFloat const kKayokoWordSelectionTokenHorizontalInset = 3;
static CGFloat const kKayokoWordSelectionTokenCornerRadius = 4;
static CGFloat const kKayokoWordSelectionTokenBorderWidth = 0.5;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoWordSelectionView () <UIGestureRecognizerDelegate>
@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UIView *contentView;
@property(nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *tokens;
@property(nonatomic, strong) NSMutableArray<KayokoWordTokenView *> *tokenButtons;
@property(nonatomic, strong) NSMutableIndexSet *selectedTokenIndexes;
@property(nonatomic, strong) NSMutableIndexSet *selectionGestureOriginalIndexes;
@property(nonatomic, copy, nullable) NSString *originalText;
@property(nonatomic, copy, readwrite) NSString *selectedText;
@property(nonatomic, assign, readwrite) BOOL hasCustomSelection;
@property(nonatomic, assign) NSUInteger selectionAnchorIndex;
@property(nonatomic, assign) BOOL selectionGestureSelectsTokens;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoWordSelectionView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        [self setTokens:[[NSMutableArray alloc] init]];
        [self setTokenButtons:[[NSMutableArray alloc] init]];
        [self setSelectedTokenIndexes:[[NSMutableIndexSet alloc] init]];
        [self setSelectionGestureOriginalIndexes:[[NSMutableIndexSet alloc] init]];
        [self setSelectedText:@""];
        [self setSelectionAnchorIndex:NSNotFound];

        [self setScrollView:[[UIScrollView alloc] init]];
        [[self scrollView] setAlwaysBounceVertical:NO];
        [[self scrollView] setBackgroundColor:[UIColor clearColor]];
        [self addSubview:[self scrollView]];

        [[self scrollView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self scrollView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self scrollView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self scrollView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self scrollView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setContentView:[[UIView alloc] init]];
        [[self scrollView] addSubview:[self contentView]];

        UITapGestureRecognizer *tapGesture =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
        [tapGesture setDelegate:self];
        [[self contentView] addGestureRecognizer:tapGesture];

        UIPanGestureRecognizer *selectionGesture =
            [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSelectionGesture:)];
        [selectionGesture setDelegate:self];
        [[self contentView] addGestureRecognizer:selectionGesture];
    }

    return self;
}

- (void)setText:(NSString *)text {
    [self reset];
    [self setOriginalText:[text copy]];

    NSArray<NSDictionary<NSString *, id> *> *tokens = [KayokoWordSelectionTokenizer tokensForText:text];
    [[self tokens] addObjectsFromArray:tokens];

    for (NSUInteger index = 0; index < [[self tokens] count]; index++) {
        KayokoWordTokenView *button = [[KayokoWordTokenView alloc] initWithFrame:CGRectZero];
        NSDictionary<NSString *, id> *token = [self tokens][index];
        [button setTag:index];
        [button setTitle:token[@"text"] forState:UIControlStateNormal];
        [[button titleLabel] setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightRegular]];
        [[button titleLabel] setLineBreakMode:NSLineBreakByTruncatingMiddle];
        [button setKayokoContentInsets:UIEdgeInsetsMake(0, kKayokoWordSelectionTokenHorizontalInset, 0,
                                                        kKayokoWordSelectionTokenHorizontalInset)];
        [button setUserInteractionEnabled:NO];
        [[button layer] setCornerRadius:kKayokoWordSelectionTokenCornerRadius];
        [[button layer] setBorderWidth:kKayokoWordSelectionTokenBorderWidth];
        [[self contentView] addSubview:button];
        [[self tokenButtons] addObject:button];
    }

    [self updateSelectedText];
    [self updateButtonStyles];
    [self setNeedsLayout];
}

- (void)reset {
    for (KayokoWordTokenView *button in [self tokenButtons]) {
        [button removeFromSuperview];
    }

    [[self tokenButtons] removeAllObjects];
    [[self tokens] removeAllObjects];
    [[self selectedTokenIndexes] removeAllIndexes];
    [[self selectionGestureOriginalIndexes] removeAllIndexes];
    [self setOriginalText:nil];
    [self setSelectedText:@""];
    [self setHasCustomSelection:NO];
    [self setSelectionAnchorIndex:NSNotFound];
    [[self scrollView] setContentOffset:CGPointZero];
    [[self scrollView] setContentSize:CGSizeZero];
}

- (void)scrollToTopAnimated:(BOOL)animated {
    CGPoint contentOffset = [[self scrollView] contentOffset];
    contentOffset.y = -[[self scrollView] adjustedContentInset].top;
    [[self scrollView] setContentOffset:contentOffset animated:animated];
}

- (nullable KayokoMainView *)mainView {
    UIView *view = [self superview];
    while (view) {
        if ([view isKindOfClass:[KayokoMainView class]]) {
            return (KayokoMainView *)view;
        }
        view = [view superview];
    }

    return nil;
}

- (void)updateScrollInsets {
    CGFloat bottomInset = 0;
    KayokoMainView *mainView = [self mainView];
    if (mainView) {
        bottomInset = [mainView safeAreaBottomInsetForContentView:[self scrollView]];
    } else {
        bottomInset = MAX([[self scrollView] safeAreaInsets].bottom, 0);
    }

    UIEdgeInsets contentInset = [[self scrollView] contentInset];
    contentInset.bottom = bottomInset;
    [[self scrollView] setContentInset:contentInset];

    UIEdgeInsets indicatorInsets = UIEdgeInsetsMake(0, 0, bottomInset, 0);
    [[self scrollView] setVerticalScrollIndicatorInsets:indicatorInsets];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat availableWidth = CGRectGetWidth([self bounds]) - kKayokoWordSelectionHorizontalInset * 2;
    CGFloat x = kKayokoWordSelectionHorizontalInset;
    CGFloat y = kKayokoWordSelectionTopInset;

    for (NSUInteger index = 0; index < [[self tokenButtons] count]; index++) {
        KayokoWordTokenView *button = [self tokenButtons][index];
        CGSize size = [button sizeThatFits:CGSizeMake(availableWidth, kKayokoWordSelectionTokenHeight)];
        CGFloat buttonWidth = MIN(MAX(ceil(size.width), kKayokoWordSelectionTokenHeight), availableWidth);

        if (x > kKayokoWordSelectionHorizontalInset &&
            x + buttonWidth > kKayokoWordSelectionHorizontalInset + availableWidth) {
            x = kKayokoWordSelectionHorizontalInset;
            y += kKayokoWordSelectionTokenHeight + kKayokoWordSelectionLineSpacing;
        }

        [button setFrame:CGRectMake(x, y, buttonWidth, kKayokoWordSelectionTokenHeight)];
        x += buttonWidth + kKayokoWordSelectionTokenSpacing;

        if ([self tokens][index][@"lineBreakAfter"] && index + 1 < [[self tokenButtons] count]) {
            x = kKayokoWordSelectionHorizontalInset;
            y += kKayokoWordSelectionTokenHeight + kKayokoWordSelectionLineSpacing;
        }
    }

    CGFloat contentHeight = [[self tokenButtons] count] > 0
                                ? y + kKayokoWordSelectionTokenHeight + kKayokoWordSelectionLineSpacing
                                : kKayokoWordSelectionTopInset;
    [[self contentView] setFrame:CGRectMake(0, 0, CGRectGetWidth([self bounds]), contentHeight)];
    [[self scrollView] setContentSize:CGSizeMake(CGRectGetWidth([self bounds]), contentHeight)];

    BOOL scrollable = contentHeight > CGRectGetHeight([self bounds]) + 0.5;
    [[self scrollView] setBounces:scrollable];
    [[self scrollView] setAlwaysBounceVertical:scrollable];
    [self updateScrollInsets];
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    [self updateScrollInsets];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateButtonStyles];
}

- (void)handleTapGesture:(UITapGestureRecognizer *)gesture {
    NSUInteger tokenIndex = [self tokenIndexAtPoint:[gesture locationInView:[self contentView]]];
    if (tokenIndex != NSNotFound) {
        [self toggleTokenAtIndex:tokenIndex];
    }
}

- (void)handleSelectionGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:[self contentView]];
    NSUInteger tokenIndex = [self tokenIndexForSelectionLocation:location];

    if ([gesture state] == UIGestureRecognizerStateBegan) {
        if (tokenIndex == NSNotFound) {
            return;
        }

        [self setSelectionAnchorIndex:tokenIndex];
        [self setSelectionGestureSelectsTokens:![[self selectedTokenIndexes] containsIndex:tokenIndex]];
        [self setSelectionGestureOriginalIndexes:[[self selectedTokenIndexes] mutableCopy]];
        [self setHasCustomSelection:YES];
        [[self scrollView] setScrollEnabled:NO];
        return;
    }

    if ([gesture state] == UIGestureRecognizerStateChanged && tokenIndex != NSNotFound) {
        [self applySelectionGestureThroughIndex:tokenIndex];
    }

    if ([gesture state] == UIGestureRecognizerStateEnded || [gesture state] == UIGestureRecognizerStateCancelled ||
        [gesture state] == UIGestureRecognizerStateFailed) {
        [[self selectionGestureOriginalIndexes] removeAllIndexes];
        [self setSelectionAnchorIndex:NSNotFound];
        [[self scrollView] setScrollEnabled:YES];
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint location = [gestureRecognizer locationInView:[self contentView]];

    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        return [self tokenIndexAtPoint:location] != NSNotFound;
    }

    if (![gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }

    if ([self tokenIndexForSelectionLocation:location] == NSNotFound) {
        return NO;
    }

    CGPoint velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self];
    if (fabs(velocity.y) > fabs(velocity.x) * 1.5) {
        return NO;
    }

    return YES;
}

- (NSUInteger)tokenIndexAtPoint:(CGPoint)point {
    for (KayokoWordTokenView *button in [self tokenButtons]) {
        if (CGRectContainsPoint([button frame], point)) {
            return [button tag];
        }
    }

    return NSNotFound;
}

- (NSUInteger)tokenIndexForSelectionLocation:(CGPoint)point {
    for (KayokoWordTokenView *button in [self tokenButtons]) {
        CGRect frame =
            CGRectInset([button frame], -kKayokoWordSelectionTokenSpacing / 2, -kKayokoWordSelectionLineSpacing / 2);
        if (CGRectContainsPoint(frame, point)) {
            return [button tag];
        }
    }

    return NSNotFound;
}

- (void)toggleTokenAtIndex:(NSUInteger)index {
    [self setHasCustomSelection:YES];

    if ([[self selectedTokenIndexes] containsIndex:index]) {
        [[self selectedTokenIndexes] removeIndex:index];
    } else {
        [[self selectedTokenIndexes] addIndex:index];
    }

    [self updateSelectedText];
    [self updateButtonStyles];
}

- (void)applySelectionGestureThroughIndex:(NSUInteger)index {
    if ([self selectionAnchorIndex] == NSNotFound) {
        return;
    }

    [[self selectedTokenIndexes] removeAllIndexes];
    [[self selectedTokenIndexes] addIndexes:[self selectionGestureOriginalIndexes]];

    NSUInteger lowerBound = MIN([self selectionAnchorIndex], index);
    NSUInteger upperBound = MAX([self selectionAnchorIndex], index);
    NSRange range = NSMakeRange(lowerBound, upperBound - lowerBound + 1);

    if ([self selectionGestureSelectsTokens]) {
        [[self selectedTokenIndexes] addIndexesInRange:range];
    } else {
        [[self selectedTokenIndexes] removeIndexesInRange:range];
    }

    [self updateSelectedText];
    [self updateButtonStyles];
}

- (void)updateButtonStyles {
    UIColor *selectedTextColor = [KayokoWordSelectionView dynamicColorWithLightWhite:0
                                                                               alpha:0.88
                                                                           darkWhite:1
                                                                               alpha:0.92];
    UIColor *normalTextColor = [KayokoWordSelectionView dynamicColorWithLightWhite:0 alpha:0.58 darkWhite:1 alpha:0.62];
    UIColor *selectedBackgroundColor = [KayokoWordSelectionView dynamicColorWithLightWhite:0
                                                                                     alpha:0.08
                                                                                 darkWhite:1
                                                                                     alpha:0.12];
    UIColor *normalBackgroundColor = [KayokoWordSelectionView dynamicColorWithLightWhite:1
                                                                                   alpha:0.08
                                                                               darkWhite:1
                                                                                   alpha:0.035];
    UIColor *selectedBorderColor = [KayokoWordSelectionView dynamicColorWithLightWhite:0
                                                                                 alpha:0.20
                                                                             darkWhite:1
                                                                                 alpha:0.24];
    UIColor *normalBorderColor = [KayokoWordSelectionView dynamicColorWithLightWhite:0
                                                                               alpha:0.08
                                                                           darkWhite:1
                                                                               alpha:0.10];

    for (NSUInteger index = 0; index < [[self tokenButtons] count]; index++) {
        KayokoWordTokenView *button = [self tokenButtons][index];
        BOOL selected = [[self selectedTokenIndexes] containsIndex:index];
        [[button layer] setBorderWidth:kKayokoWordSelectionTokenBorderWidth];
        UIColor *textColor = selected ? selectedTextColor : normalTextColor;
        UIColor *backgroundColor = selected ? selectedBackgroundColor : normalBackgroundColor;
        [button setTitleColor:textColor forState:UIControlStateNormal];
        [button setBackgroundColor:backgroundColor];
        [[button layer] setBorderColor:(selected ? selectedBorderColor : normalBorderColor).CGColor];
    }
}

+ (UIColor *)dynamicColorWithLightWhite:(CGFloat)lightWhite
                                  alpha:(CGFloat)lightAlpha
                              darkWhite:(CGFloat)darkWhite
                                  alpha:(CGFloat)darkAlpha {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      BOOL dark = [traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark;
      return [UIColor colorWithWhite:(dark ? darkWhite : lightWhite) alpha:(dark ? darkAlpha : lightAlpha)];
    }];
}

- (void)updateSelectedText {
    NSMutableString *selectedText = [[NSMutableString alloc] init];
    __block NSUInteger previousTokenIndex = NSNotFound;
    __block NSRange previousRange = NSMakeRange(NSNotFound, 0);

    [[self selectedTokenIndexes] enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
      NSDictionary<NSString *, id> *token = [self tokens][index];
      NSRange range = [token[@"range"] rangeValue];

      if ([selectedText length] > 0) {
          if (previousTokenIndex != NSNotFound && index == previousTokenIndex + 1 &&
              NSMaxRange(previousRange) <= range.location) {
              NSRange separatorRange =
                  NSMakeRange(NSMaxRange(previousRange), range.location - NSMaxRange(previousRange));
              [selectedText appendString:[[self originalText] substringWithRange:separatorRange]];
          } else {
              [selectedText appendString:@" "];
          }
      }

      [selectedText appendString:token[@"text"]];
      previousTokenIndex = index;
      previousRange = range;
    }];

    [self setSelectedText:selectedText];
    if ([self selectionChangedHandler]) {
        [self selectionChangedHandler]();
    }
}

@end
