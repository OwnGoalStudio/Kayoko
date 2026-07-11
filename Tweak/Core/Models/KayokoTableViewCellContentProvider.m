//
//  KayokoTableViewCellContentProvider.m
//  Kayoko
//

#import "KayokoTableViewCellContentProvider.h"
#import "KayokoApplicationMetadataProvider.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import "KayokoTableViewCellContent.h"
#import "KayokoTag.h"
#import "KayokoTagCatalog.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableViewCellContentProvider ()
@property(nonatomic, strong) KayokoApplicationMetadataProvider *metadataProvider;
@property(nonatomic, strong) NSRelativeDateTimeFormatter *relativeDateTimeFormatter;
@property(nonatomic, strong) NSByteCountFormatter *byteCountFormatter;
@property(nonatomic, strong) NSCache<NSString *, NSNumber *> *characterCountCache;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoTableViewCellContentProvider

- (instancetype)init {
    self = [super init];
    if (self) {
        _metadataProvider = [[KayokoApplicationMetadataProvider alloc] init];
        _relativeDateTimeFormatter = [[NSRelativeDateTimeFormatter alloc] init];
        [_relativeDateTimeFormatter setDateTimeStyle:NSRelativeDateTimeFormatterStyleNumeric];
        [_relativeDateTimeFormatter setUnitsStyle:NSRelativeDateTimeFormatterUnitsStyleFull];
        NSString *localizationIdentifier =
            [[[KayokoPasteboardManager localizationBundle] preferredLocalizations] firstObject];
        if ([localizationIdentifier length] > 0) {
            [_relativeDateTimeFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:localizationIdentifier]];
        }
        _byteCountFormatter = [[NSByteCountFormatter alloc] init];
        [_byteCountFormatter setCountStyle:NSByteCountFormatterCountStyleFile];
        _characterCountCache = [[NSCache alloc] init];
        [_characterCountCache setCountLimit:256];
    }
    return self;
}

- (NSString *)relativeTimeTextForDate:(NSDate *)date {
    NSDate *now = [NSDate date];
    NSTimeInterval age = [now timeIntervalSinceDate:date];
    if (age < 60.0) {
        return [[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Just Now"
                                                                             value:nil
                                                                             table:@"Tweak"];
    }
    return [[self relativeDateTimeFormatter] localizedStringForDate:date relativeToDate:now];
}

- (NSUInteger)visibleCharacterCountForText:(NSString *)text {
    NSNumber *cachedCount = [[self characterCountCache] objectForKey:text];
    if (cachedCount) {
        return [cachedCount unsignedIntegerValue];
    }

    __block NSUInteger characterCount = 0;
    [text enumerateSubstringsInRange:NSMakeRange(0, [text length])
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(__unused NSString *substring, __unused NSRange substringRange,
                                       __unused NSRange enclosingRange, __unused BOOL *stop) {
                            characterCount++;
                          }];
    [[self characterCountCache] setObject:@(characterCount) forKey:text];
    return characterCount;
}

- (UIColor *)searchHighlightBackgroundColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      if ([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark) {
          return [[UIColor systemYellowColor] colorWithAlphaComponent:0.42];
      }

      return [UIColor colorWithRed:1.0 green:0.82 blue:0.24 alpha:0.55];
    }];
}

- (nullable NSAttributedString *)attributedTextForText:(NSString *)text searchText:(nullable NSString *)searchText {
    NSString *trimmedSearchText =
        [searchText ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([text length] == 0 || [trimmedSearchText length] == 0) {
        return nil;
    }

    NSRange matchRange = [text rangeOfString:trimmedSearchText
                                     options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch];
    if (matchRange.location == NSNotFound || matchRange.length == 0) {
        return nil;
    }

    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:text];
    [attributedText addAttribute:NSBackgroundColorAttributeName
                           value:[self searchHighlightBackgroundColor]
                           range:matchRange];
    return attributedText;
}

- (KayokoTableViewCellContent *)cellContentForItem:(KayokoPasteboardItem *)item
                                  previewLineCount:(NSUInteger)previewLineCount
                                   itemDetailsMode:(KayokoItemDetailsMode)itemDetailsMode {
    return [self cellContentForItem:item
                   previewLineCount:previewLineCount
                    itemDetailsMode:itemDetailsMode
                         searchText:nil];
}

- (KayokoTableViewCellContent *)cellContentForItem:(KayokoPasteboardItem *)item
                                  previewLineCount:(NSUInteger)previewLineCount
                                   itemDetailsMode:(KayokoItemDetailsMode)itemDetailsMode
                                        searchText:(nullable NSString *)searchText {
    KayokoTableViewCellContent *content = [[KayokoTableViewCellContent alloc] init];
    NSString *bundleIdentifier = [item bundleIdentifier];
    BOOL isImage = [[item imageName] length] > 0;
    NSString *contentText =
        isImage ? @"" : [([item content] ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *sourceDisplayName = [[self metadataProvider] displayNameForBundleIdentifier:bundleIdentifier];
    NSString *displayName = [[item note] length] > 0 ? [item note] : sourceDisplayName;
    [content setIcon:[[self metadataProvider] iconForBundleIdentifier:bundleIdentifier]];
    [content setDisplayName:displayName];
    [content setAttributedDisplayName:[[item note] length] > 0 ? [self attributedTextForText:displayName
                                                                                  searchText:searchText]
                                                               : nil];
    KayokoTag *tag = [[KayokoTagCatalog sharedCatalog] tagForUUID:[item tagUUID]];
    [content setTagHexColor:[tag hexColor]];
    [content setContentText:contentText];
    [content setAttributedContentText:[self attributedTextForText:contentText searchText:searchText]];
    BOOL showsDetail =
        isImage ? itemDetailsMode != kKayokoItemDetailsModeOff : itemDetailsMode == kKayokoItemDetailsModeAll;
    [content setShowsDetail:showsDetail];
    if (showsDetail) {
        NSMutableArray<NSString *> *detailComponents = [[NSMutableArray alloc] initWithCapacity:3];
        if ([item capturedAt]) {
            [detailComponents addObject:[self relativeTimeTextForDate:[item capturedAt]]];
        }
        if (isImage) {
            if ([item imagePixelWidth] > 0 && [item imagePixelHeight] > 0) {
                [detailComponents
                    addObject:[NSString stringWithFormat:@"%lu×%lu", (unsigned long)[item imagePixelWidth],
                                                         (unsigned long)[item imagePixelHeight]]];
            }
            if ([item imageByteCount] > 0) {
                [detailComponents
                    addObject:[self.byteCountFormatter stringFromByteCount:(long long)[item imageByteCount]]];
            }
        } else {
            NSUInteger characterCount = [self visibleCharacterCountForText:[item content] ?: @""];
            NSString *formatKey = characterCount == 1 ? @"%lu character" : @"%lu characters";
            NSString *format = [[KayokoPasteboardManager localizationBundle] localizedStringForKey:formatKey
                                                                                             value:nil
                                                                                             table:@"Tweak"];
            [detailComponents addObject:[NSString stringWithFormat:format, (unsigned long)characterCount]];
        }
        NSMutableAttributedString *attributedDetailText = [[NSMutableAttributedString alloc] init];
        for (NSUInteger index = 0; index < [detailComponents count]; index++) {
            if (index > 0) {
                [attributedDetailText
                    appendAttributedString:[[NSAttributedString alloc]
                                               initWithString:@" / "
                                                   attributes:@{
                                                       NSForegroundColorAttributeName : [UIColor tertiaryLabelColor]
                                                   }]];
            }
            [attributedDetailText
                appendAttributedString:[[NSAttributedString alloc]
                                           initWithString:detailComponents[index]
                                               attributes:@{
                                                   NSForegroundColorAttributeName : [UIColor secondaryLabelColor]
                                               }]];
        }
        [content setAttributedDetailText:attributedDetailText];
    }
    [content setThumbnailImageName:[item imageName]];
    [content setPreviewLineCount:previewLineCount];
    return content;
}

- (void)loadThumbnailForItem:(KayokoPasteboardItem *)item
                  targetSize:(CGSize)targetSize
                  completion:(void (^)(UIImage *_Nullable image))completion {
    [[KayokoPasteboardManager sharedInstance] getThumbnailForItem:item targetSize:targetSize completion:completion];
}

@end
