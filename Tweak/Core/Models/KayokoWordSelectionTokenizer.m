//
//  KayokoWordSelectionTokenizer.m
//  Kayoko
//

#import "KayokoWordSelectionTokenizer.h"

@implementation KayokoWordSelectionTokenizer

#pragma mark - Public Tokenization

+ (NSArray<NSDictionary<NSString *, id> *> *)tokensForText:(NSString *)text {
    if (![text length]) {
        return @[];
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *tokens = [[NSMutableArray alloc] init];
    __block NSUInteger cursor = 0;
    __block NSUInteger previousSentenceLastTokenIndex = NSNotFound;
    __block BOOL foundSentence = NO;

    [text enumerateSubstringsInRange:NSMakeRange(0, [text length])
                             options:NSStringEnumerationBySentences
                          usingBlock:^(NSString *_Nullable substring, NSRange substringRange, NSRange enclosingRange,
                                       BOOL *_Nonnull stop) {
                            foundSentence = YES;

                            if (substringRange.location > cursor) {
                                NSRange gapRange = NSMakeRange(cursor, substringRange.location - cursor);
                                [tokens addObjectsFromArray:[self detectedTokensForText:text inRange:gapRange]];
                            }

                            NSArray<NSDictionary<NSString *, id> *> *sentenceTokens =
                                [self detectedTokensForText:text inRange:substringRange];
                            if ([sentenceTokens count] > 0) {
                                if (previousSentenceLastTokenIndex != NSNotFound) {
                                    [self markTokenForLineBreakAtIndex:previousSentenceLastTokenIndex inTokens:tokens];
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

#pragma mark - Detectors

+ (NSArray<NSDictionary<NSString *, id> *> *)detectedTokensForText:(NSString *)text inRange:(NSRange)textRange {
    NSMutableArray<NSDictionary<NSString *, id> *> *tokens = [[NSMutableArray alloc] init];
    NSMutableArray<NSTextCheckingResult *> *detectedResults = [[NSMutableArray alloc] init];
    NSDataDetector *detector = [NSDataDetector
        dataDetectorWithTypes:NSTextCheckingTypeLink | NSTextCheckingTypePhoneNumber | NSTextCheckingTypeDate |
                              NSTextCheckingTypeAddress | NSTextCheckingTypeTransitInformation
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

+ (void)markTokenForLineBreakAtIndex:(NSUInteger)index
                            inTokens:(NSMutableArray<NSDictionary<NSString *, id> *> *)tokens {
    if (index >= [tokens count]) {
        return;
    }

    NSMutableDictionary<NSString *, id> *token = [tokens[index] mutableCopy];
    token[@"lineBreakAfter"] = @YES;
    tokens[index] = token;
}

#pragma mark - Word Tokenization

+ (NSArray<NSDictionary<NSString *, id> *> *)wordTokensForText:(NSString *)text inRange:(NSRange)range {
    NSMutableArray<NSDictionary<NSString *, id> *> *tokens = [[NSMutableArray alloc] init];
    NSString *substring = [text substringWithRange:range];
    CFStringRef cfSubstring = (__bridge CFStringRef)substring;
    CFStringTokenizerRef tokenizer = CFStringTokenizerCreate(NULL, cfSubstring, CFRangeMake(0, [substring length]),
                                                             kCFStringTokenizerUnitWord, NULL);

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

+ (void)addCharacterTokensFromText:(NSString *)text
                           inRange:(NSRange)range
                          toTokens:(NSMutableArray<NSDictionary<NSString *, id> *> *)tokens {
    [text enumerateSubstringsInRange:range
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *_Nullable substring, NSRange substringRange, NSRange enclosingRange,
                                       BOOL *_Nonnull stop) {
                            if ([self isTokenTextValid:substring]) {
                                [self addTokenFromText:text inRange:substringRange toTokens:tokens];
                            }
                          }];
}

+ (void)addNonWhitespaceCharacterTokensFromText:(NSString *)text
                                        inRange:(NSRange)range
                                       toTokens:(NSMutableArray<NSDictionary<NSString *, id> *> *)tokens {
    [text enumerateSubstringsInRange:range
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *_Nullable substring, NSRange substringRange, NSRange enclosingRange,
                                       BOOL *_Nonnull stop) {
                            if ([self isTokenTextValid:substring]) {
                                [self addTokenFromText:text inRange:substringRange toTokens:tokens];
                            }
                          }];
}

#pragma mark - Token Construction

+ (void)addTokenFromText:(NSString *)text
                 inRange:(NSRange)range
                toTokens:(NSMutableArray<NSDictionary<NSString *, id> *> *)tokens {
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

#pragma mark - Character Sets

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
