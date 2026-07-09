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
@end

NS_ASSUME_NONNULL_END

@implementation KayokoTableViewCellContentProvider

- (instancetype)init {
    self = [super init];
    if (self) {
        _metadataProvider = [[KayokoApplicationMetadataProvider alloc] init];
    }
    return self;
}

- (UIColor *)searchHighlightBackgroundColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      if ([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark) {
          return [[UIColor systemYellowColor] colorWithAlphaComponent:0.42];
      }

      return [UIColor colorWithRed:1.0 green:0.82 blue:0.24 alpha:0.55];
    }];
}

- (nullable NSAttributedString *)attributedTextForText:(NSString *)text
                                            searchText:(nullable NSString *)searchText {
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
                                  previewLineCount:(NSUInteger)previewLineCount {
    return [self cellContentForItem:item previewLineCount:previewLineCount searchText:nil];
}

- (KayokoTableViewCellContent *)cellContentForItem:(KayokoPasteboardItem *)item
                                  previewLineCount:(NSUInteger)previewLineCount
                                        searchText:(nullable NSString *)searchText {
    KayokoTableViewCellContent *content = [[KayokoTableViewCellContent alloc] init];
    NSString *bundleIdentifier = [item bundleIdentifier];
    NSString *contentText =
        [([item content] ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *sourceDisplayName = [[self metadataProvider] displayNameForBundleIdentifier:bundleIdentifier];
    NSString *displayName = [[item note] length] > 0 ? [item note] : sourceDisplayName;
    [content setIcon:[[self metadataProvider] iconForBundleIdentifier:bundleIdentifier]];
    [content setDisplayName:displayName];
    [content setAttributedDisplayName:[[item note] length] > 0
                                          ? [self attributedTextForText:displayName searchText:searchText]
                                          : nil];
    KayokoTag *tag = [[KayokoTagCatalog sharedCatalog] tagForUUID:[item tagUUID]];
    [content setTagHexColor:[tag hexColor]];
    [content setContentText:contentText];
    [content setAttributedContentText:[self attributedTextForText:contentText searchText:searchText]];
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
