//
//  KayokoWordSelectionView.m
//  Kayoko
//
//  Created by 82Flex
//

#import "KayokoWordSelectionView.h"

static CGFloat const kKayokoWordSelectionHorizontalInset = 16;
static CGFloat const kKayokoWordSelectionTopInset = 12;
static CGFloat const kKayokoWordSelectionTokenSpacing = 9;
static CGFloat const kKayokoWordSelectionLineSpacing = 9;
static CGFloat const kKayokoWordSelectionTokenHeight = 34;

@interface KayokoWordSelectionView () <UIGestureRecognizerDelegate>
@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UIView *contentView;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *tokens;
@property(nonatomic, strong) NSMutableArray<UIButton *> *tokenButtons;
@property(nonatomic, strong) NSMutableIndexSet *selectedTokenIndexes;
@property(nonatomic, strong) NSMutableIndexSet *selectionGestureOriginalIndexes;
@property(nonatomic, copy) NSString *originalText;
@property(nonatomic, copy, readwrite) NSString *selectedText;
@property(nonatomic, assign, readwrite) BOOL hasCustomSelection;
@property(nonatomic, assign) NSUInteger selectionAnchorIndex;
@property(nonatomic, assign) BOOL selectionGestureSelectsTokens;
@end

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

    NSArray<NSDictionary *> *tokens = [KayokoWordSelectionView tokensForText:text];
    [[self tokens] addObjectsFromArray:tokens];

    for (NSUInteger index = 0; index < [[self tokens] count]; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        NSDictionary *token = [self tokens][index];
        [button setTag:index];
        [button setTitle:token[@"text"] forState:UIControlStateNormal];
        [[button titleLabel] setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightRegular]];
        [[button titleLabel] setLineBreakMode:NSLineBreakByTruncatingMiddle];
        [button setContentEdgeInsets:UIEdgeInsetsMake(0, 11, 0, 11)];
        [button setUserInteractionEnabled:NO];
        [[button layer] setCornerRadius:7];
        [[button layer] setBorderWidth:0.5];
        [[self contentView] addSubview:button];
        [[self tokenButtons] addObject:button];
    }

    [self updateSelectedText];
    [self updateButtonStyles];
    [self setNeedsLayout];
}

- (void)reset {
    for (UIButton *button in [self tokenButtons]) {
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

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat availableWidth = CGRectGetWidth([self bounds]) - kKayokoWordSelectionHorizontalInset * 2;
    CGFloat x = kKayokoWordSelectionHorizontalInset;
    CGFloat y = kKayokoWordSelectionTopInset;

    for (NSUInteger index = 0; index < [[self tokenButtons] count]; index++) {
        UIButton *button = [self tokenButtons][index];
        CGSize size = [button sizeThatFits:CGSizeMake(availableWidth, kKayokoWordSelectionTokenHeight)];
        CGFloat buttonWidth = MIN(MAX(ceil(size.width), kKayokoWordSelectionTokenHeight), availableWidth);

        if (x > kKayokoWordSelectionHorizontalInset &&
            x + buttonWidth > kKayokoWordSelectionHorizontalInset + availableWidth) {
            x = kKayokoWordSelectionHorizontalInset;
            y += kKayokoWordSelectionTokenHeight + kKayokoWordSelectionLineSpacing;
        }

        [button setFrame:CGRectMake(x, y, buttonWidth, kKayokoWordSelectionTokenHeight)];
        x += buttonWidth + kKayokoWordSelectionTokenSpacing;

        if ([self tokens][index][@"line_break_after"] && index + 1 < [[self tokenButtons] count]) {
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
    for (UIButton *button in [self tokenButtons]) {
        if (CGRectContainsPoint([button frame], point)) {
            return [button tag];
        }
    }

    return NSNotFound;
}

- (NSUInteger)tokenIndexForSelectionLocation:(CGPoint)point {
    for (UIButton *button in [self tokenButtons]) {
        CGRect frame = CGRectInset([button frame], -kKayokoWordSelectionTokenSpacing / 2, -kKayokoWordSelectionLineSpacing / 2);
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
    UIColor *selectedTextColor = [KayokoWordSelectionView dynamicColorWithLightWhite:0 alpha:0.88 darkWhite:1 alpha:0.92];
    UIColor *normalTextColor = [KayokoWordSelectionView dynamicColorWithLightWhite:0 alpha:0.58 darkWhite:1 alpha:0.62];
    UIColor *selectedBackgroundColor = [KayokoWordSelectionView dynamicColorWithLightWhite:0 alpha:0.08 darkWhite:1 alpha:0.12];
    UIColor *normalBackgroundColor = [KayokoWordSelectionView dynamicColorWithLightWhite:1 alpha:0.08 darkWhite:1 alpha:0.035];
    UIColor *selectedBorderColor = [KayokoWordSelectionView dynamicColorWithLightWhite:0 alpha:0.20 darkWhite:1 alpha:0.24];
    UIColor *normalBorderColor = [KayokoWordSelectionView dynamicColorWithLightWhite:0 alpha:0.08 darkWhite:1 alpha:0.10];

    for (NSUInteger index = 0; index < [[self tokenButtons] count]; index++) {
        UIButton *button = [self tokenButtons][index];
        BOOL selected = [[self selectedTokenIndexes] containsIndex:index];
        [[button layer] setBorderWidth:selected ? 0.75 : 0.5];
        [button setTitleColor:selected ? selectedTextColor : normalTextColor forState:UIControlStateNormal];
        [button setBackgroundColor:selected ? selectedBackgroundColor : normalBackgroundColor];
        [[button layer] setBorderColor:(selected ? selectedBorderColor : normalBorderColor).CGColor];
    }
}

+ (UIColor *)dynamicColorWithLightWhite:(CGFloat)lightWhite
                                  alpha:(CGFloat)lightAlpha
                              darkWhite:(CGFloat)darkWhite
                                  alpha:(CGFloat)darkAlpha {
    if (@available(iOS 13, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
          BOOL dark = [traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark;
          return [UIColor colorWithWhite:(dark ? darkWhite : lightWhite) alpha:(dark ? darkAlpha : lightAlpha)];
        }];
    }

    return [UIColor colorWithWhite:lightWhite alpha:lightAlpha];
}

- (void)updateSelectedText {
    NSMutableString *selectedText = [[NSMutableString alloc] init];
    __block NSUInteger previousTokenIndex = NSNotFound;
    __block NSRange previousRange = NSMakeRange(NSNotFound, 0);

    [[self selectedTokenIndexes] enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
      NSDictionary *token = [self tokens][index];
      NSRange range = [token[@"range"] rangeValue];

      if ([selectedText length] > 0) {
          if (previousTokenIndex != NSNotFound && index == previousTokenIndex + 1 &&
              NSMaxRange(previousRange) <= range.location) {
              NSRange separatorRange = NSMakeRange(NSMaxRange(previousRange), range.location - NSMaxRange(previousRange));
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

+ (NSArray<NSDictionary *> *)tokensForText:(NSString *)text {
    if (![text length]) {
        return @[];
    }

    NSMutableArray<NSDictionary *> *tokens = [[NSMutableArray alloc] init];
    __block NSUInteger cursor = 0;
    __block NSUInteger previousSentenceLastTokenIndex = NSNotFound;
    __block BOOL foundSentence = NO;

    [text enumerateSubstringsInRange:NSMakeRange(0, [text length])
                             options:NSStringEnumerationBySentences
                          usingBlock:^(NSString *_Nullable substring, NSRange substringRange,
                                        NSRange enclosingRange, BOOL *_Nonnull stop) {
                            foundSentence = YES;

                            if (substringRange.location > cursor) {
                                NSRange gapRange = NSMakeRange(cursor, substringRange.location - cursor);
                                [tokens addObjectsFromArray:[self detectedTokensForText:text inRange:gapRange]];
                            }

                            NSArray<NSDictionary *> *sentenceTokens =
                                [self detectedTokensForText:text inRange:substringRange];
                            if ([sentenceTokens count] > 0) {
                                if (previousSentenceLastTokenIndex != NSNotFound) {
                                    [self markTokenForLineBreakAtIndex:previousSentenceLastTokenIndex
                                                              inTokens:tokens];
                                }

                                [tokens addObjectsFromArray:sentenceTokens];
                                previousSentenceLastTokenIndex = [tokens count] - 1;
                            }

                            cursor = NSMaxRange(substringRange);
                          }];

    if (!foundSentence) {
        return [self detectedTokensForText:text inRange:NSMakeRange(0, [text length])];
    }

    if (cursor < [text length]) {
        NSRange remainingRange = NSMakeRange(cursor, [text length] - cursor);
        [tokens addObjectsFromArray:[self detectedTokensForText:text inRange:remainingRange]];
    }

    return tokens;
}

+ (NSArray<NSDictionary *> *)detectedTokensForText:(NSString *)text inRange:(NSRange)textRange {
    NSMutableArray<NSDictionary *> *tokens = [[NSMutableArray alloc] init];
    NSMutableArray<NSTextCheckingResult *> *detectedResults = [[NSMutableArray alloc] init];
    NSDataDetector *detector =
        [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink | NSTextCheckingTypePhoneNumber |
                                              NSTextCheckingTypeDate | NSTextCheckingTypeAddress
                                        error:nil];
    [detector enumerateMatchesInString:text
                               options:0
                                 range:textRange
                            usingBlock:^(NSTextCheckingResult *_Nullable result, NSMatchingFlags flags, BOOL *stop) {
                              if ([result range].length > 0) {
                                  [detectedResults addObject:result];
                              }
                            }];

    [detectedResults sortUsingComparator:^NSComparisonResult(NSTextCheckingResult *left, NSTextCheckingResult *right) {
      if ([left range].location < [right range].location) {
          return NSOrderedAscending;
      }
      if ([left range].location > [right range].location) {
          return NSOrderedDescending;
      }
      return NSOrderedSame;
    }];

    NSUInteger cursor = textRange.location;
    for (NSTextCheckingResult *result in detectedResults) {
        NSRange range = [result range];
        if (range.location < cursor || NSMaxRange(range) > NSMaxRange(textRange)) {
            continue;
        }

        if (range.location > cursor) {
            NSRange gapRange = NSMakeRange(cursor, range.location - cursor);
            [tokens addObjectsFromArray:[self wordTokensForText:text inRange:gapRange]];
        }

        [self addTokenFromText:text inRange:range toTokens:tokens];
        cursor = NSMaxRange(range);
    }

    if (cursor < NSMaxRange(textRange)) {
        NSRange remainingRange = NSMakeRange(cursor, NSMaxRange(textRange) - cursor);
        [tokens addObjectsFromArray:[self wordTokensForText:text inRange:remainingRange]];
    }

    return tokens;
}

+ (void)markTokenForLineBreakAtIndex:(NSUInteger)index inTokens:(NSMutableArray<NSDictionary *> *)tokens {
    if (index >= [tokens count]) {
        return;
    }

    NSMutableDictionary *token = [tokens[index] mutableCopy];
    token[@"line_break_after"] = @YES;
    tokens[index] = token;
}

+ (NSArray<NSDictionary *> *)wordTokensForText:(NSString *)text inRange:(NSRange)range {
    NSMutableArray<NSDictionary *> *tokens = [[NSMutableArray alloc] init];
    NSString *substring = [text substringWithRange:range];
    CFStringRef cfSubstring = (__bridge CFStringRef)substring;
    CFStringTokenizerRef tokenizer =
        CFStringTokenizerCreate(NULL, cfSubstring, CFRangeMake(0, [substring length]), kCFStringTokenizerUnitWord, NULL);

    if (!tokenizer) {
        [self addNonWhitespaceCharacterTokensFromText:text inRange:range toTokens:tokens];
        return tokens;
    }

    NSUInteger cursor = range.location;
    CFStringTokenizerTokenType tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer);
    while (tokenType != kCFStringTokenizerTokenNone) {
        CFRange cfRange = CFStringTokenizerGetCurrentTokenRange(tokenizer);
        NSRange tokenRange = NSMakeRange(range.location + cfRange.location, cfRange.length);

        if (tokenRange.location > cursor) {
            NSRange gapRange = NSMakeRange(cursor, tokenRange.location - cursor);
            [self addNonWhitespaceCharacterTokensFromText:text inRange:gapRange toTokens:tokens];
        }

        NSString *tokenText = [text substringWithRange:tokenRange];
        if ([self tokenContainsCJKCharacter:tokenText]) {
            [self addCharacterTokensFromText:text inRange:tokenRange toTokens:tokens];
        } else {
            [self addTokenFromText:text inRange:tokenRange toTokens:tokens];
        }
        cursor = NSMaxRange(tokenRange);
        tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer);
    }

    CFRelease(tokenizer);

    if (cursor < NSMaxRange(range)) {
        NSRange remainingRange = NSMakeRange(cursor, NSMaxRange(range) - cursor);
        [self addNonWhitespaceCharacterTokensFromText:text inRange:remainingRange toTokens:tokens];
    }

    return tokens;
}

+ (void)addCharacterTokensFromText:(NSString *)text inRange:(NSRange)range toTokens:(NSMutableArray<NSDictionary *> *)tokens {
    [text enumerateSubstringsInRange:range
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *_Nullable substring, NSRange substringRange,
                                        NSRange enclosingRange, BOOL *_Nonnull stop) {
                            if ([self isTokenTextValid:substring]) {
                                [self addTokenFromText:text inRange:substringRange toTokens:tokens];
                            }
                          }];
}

+ (void)addNonWhitespaceCharacterTokensFromText:(NSString *)text
                                        inRange:(NSRange)range
                                       toTokens:(NSMutableArray<NSDictionary *> *)tokens {
    [text enumerateSubstringsInRange:range
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *_Nullable substring, NSRange substringRange,
                                        NSRange enclosingRange, BOOL *_Nonnull stop) {
                            if ([self isTokenTextValid:substring]) {
                                [self addTokenFromText:text inRange:substringRange toTokens:tokens];
                            }
                          }];
}

+ (void)addTokenFromText:(NSString *)text inRange:(NSRange)range toTokens:(NSMutableArray<NSDictionary *> *)tokens {
    NSString *tokenText = [text substringWithRange:range];
    if (![self isTokenTextValid:tokenText]) {
        return;
    }

    [tokens addObject:@{
        @"text" : tokenText,
        @"range" : [NSValue valueWithRange:range],
    }];
}

+ (BOOL)isTokenTextValid:(NSString *)text {
    return [[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0;
}

+ (BOOL)tokenContainsCJKCharacter:(NSString *)text {
    return [text rangeOfCharacterFromSet:[self cjkCharacterSet]].location != NSNotFound;
}

+ (NSCharacterSet *)cjkCharacterSet {
    static NSCharacterSet *characterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      NSMutableCharacterSet *set = [[NSMutableCharacterSet alloc] init];
      [set addCharactersInRange:NSMakeRange(0x4E00, 0x9FFF - 0x4E00 + 1)];
      [set addCharactersInRange:NSMakeRange(0xF900, 0xFAFF - 0xF900 + 1)];
      [set addCharactersInRange:NSMakeRange(0x3000, 0x303F - 0x3000 + 1)];
      [set addCharactersInRange:NSMakeRange(0x3040, 0x309F - 0x3040 + 1)];
      [set addCharactersInRange:NSMakeRange(0x30A0, 0x30FF - 0x30A0 + 1)];
      [set addCharactersInRange:NSMakeRange(0x31F0, 0x31FF - 0x31F0 + 1)];
      [set addCharactersInRange:NSMakeRange(0xAC00, 0xD7AF - 0xAC00 + 1)];
      [set addCharactersInRange:NSMakeRange(0x1100, 0x11FF - 0x1100 + 1)];
      [set addCharactersInRange:NSMakeRange(0x3130, 0x318F - 0x3130 + 1)];
      characterSet = [set copy];
    });
    return characterSet;
}

@end
