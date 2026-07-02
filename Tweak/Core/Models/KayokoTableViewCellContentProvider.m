//
//  KayokoTableViewCellContentProvider.m
//  Kayoko
//

#import "KayokoTableViewCellContentProvider.h"
#import "KayokoApplicationMetadataProvider.h"
#import "KayokoTableViewCellContent.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

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

- (nullable NSAttributedString *)attributedContentTextForText:(NSString *)text
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

- (KayokoTableViewCellContent *)cellContentForItem:(PasteboardItem *)item
                                  previewLineCount:(NSUInteger)previewLineCount {
    return [self cellContentForItem:item previewLineCount:previewLineCount searchText:nil];
}

- (KayokoTableViewCellContent *)cellContentForItem:(PasteboardItem *)item
                                  previewLineCount:(NSUInteger)previewLineCount
                                        searchText:(nullable NSString *)searchText {
    KayokoTableViewCellContent *content = [[KayokoTableViewCellContent alloc] init];
    NSString *bundleIdentifier = [item bundleIdentifier];
    NSString *contentText =
        [([item content] ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    [content setIcon:[[self metadataProvider] iconForBundleIdentifier:bundleIdentifier]];
    [content setDisplayName:[[self metadataProvider] displayNameForBundleIdentifier:bundleIdentifier]];
    [content setContentText:contentText];
    [content setAttributedContentText:[self attributedContentTextForText:contentText searchText:searchText]];
    [content setThumbnailImageName:[item imageName]];
    [content setPreviewLineCount:previewLineCount];
    return content;
}

- (void)loadThumbnailForItem:(PasteboardItem *)item
                  targetSize:(CGSize)targetSize
                  completion:(void (^)(UIImage *_Nullable image))completion {
    [[PasteboardManager sharedInstance] getThumbnailForItem:item targetSize:targetSize completion:completion];
}

@end
