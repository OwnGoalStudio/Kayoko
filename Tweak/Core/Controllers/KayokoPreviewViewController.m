//
//  KayokoPreviewViewController.m
//  Kayoko
//

#import "KayokoPreviewViewController.h"

#import "KayokoHeaderButtonStyle.h"
#import "KayokoPreviewView.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

static NSString *kayokoPreviewTextByTrimmingBoundaryNewlines(NSString *text) {
    return [(text ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPreviewViewController ()
@property(nonatomic, strong, readwrite) KayokoPreviewView *previewView;
@property(nonatomic, weak) UIButton *favoritesButton;
@property(nonatomic, weak) UIButton *backButton;
@property(nonatomic, weak) UIButton *clearButton;
@property(nonatomic, copy, nullable, readwrite) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readwrite) PasteboardItem *previewItem;

- (void)restoreHeaderButtonsForSourceHistoryKey:(nullable NSString *)historyKey;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoPreviewViewController

- (instancetype)initWithFavoritesButton:(UIButton *)favoritesButton
                             backButton:(UIButton *)backButton
                            clearButton:(UIButton *)clearButton {
    self = [super init];
    if (self) {
        _previewView = [[KayokoPreviewView alloc]
            initWithName:[[PasteboardManager localizationBundle] localizedStringForKey:@"Preview"
                                                                                 value:nil
                                                                                 table:@"Tweak"]];
        _favoritesButton = favoritesButton;
        _backButton = backButton;
        _clearButton = clearButton;
        [self setView:_previewView];
    }
    return self;
}

- (void)updateStyleForHeaderButton:(UIButton *)button
                     withImageName:(NSString *)imageName
                      andImageSize:(NSUInteger)imageSize
                      andTintColor:(UIColor *)color {
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:imageSize weight:UIImageSymbolWeightMedium];
    UIImage *image = [UIImage systemImageNamed:imageName] ?: [UIImage systemImageNamed:@"doc.on.doc"];
    [button setImage:[image imageWithConfiguration:configuration] forState:UIControlStateNormal];
    [button setTintColor:color];
}

- (void)showPreviewWithItem:(PasteboardItem *)item sourceHistoryKey:(NSString *)sourceHistoryKey {
    [self setPreviewItem:item];
    [self setSourceHistoryKey:sourceHistoryKey];

    if (![[item imageName] isEqualToString:@""]) {
        NSData *imageData = [[NSFileManager defaultManager]
            contentsAtPath:[NSString
                               stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]]];
        [[self previewView] reset];
        [[[self previewView] imageView] setImage:[UIImage imageWithData:imageData]];
        [[[self previewView] imageView] setHidden:NO];
    } else {
        NSString *previewText = kayokoPreviewTextByTrimmingBoundaryNewlines([item content]);
        [[self previewView] showText:previewText];
    }

    [self updateStyleForHeaderButton:[self favoritesButton]
                       withImageName:@"arrowshape.turn.up.backward"
                        andImageSize:kKayokoFavoritesButtonImageSize
                        andTintColor:[UIColor labelColor]];
    [self updateStyleForHeaderButton:[self backButton]
                       withImageName:@"doc.on.doc.fill"
                        andImageSize:kKayokoBackButtonImageSize
                        andTintColor:[UIColor labelColor]];
    [[self favoritesButton]
        setAccessibilityLabel:[[PasteboardManager localizationBundle] localizedStringForKey:@"Back"
                                                                                      value:nil
                                                                                      table:@"Tweak"]];
    [[self backButton] setAccessibilityLabel:[[PasteboardManager localizationBundle] localizedStringForKey:@"Copy"
                                                                                                     value:nil
                                                                                                     table:@"Tweak"]];
    [[self clearButton] setHidden:YES];
    [[self backButton] setHidden:YES];
}

- (void)prepareToHidePreview {
    [[self clearButton] setHidden:NO];
    [[self backButton] setHidden:YES];
    [[self backButton] setEnabled:YES];
    [[self backButton] setAlpha:1.0];
    [self restoreHeaderButtonsForSourceHistoryKey:[self sourceHistoryKey]];
    [[self favoritesButton]
        setAccessibilityLabel:[[PasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
                                                                                      value:nil
                                                                                      table:@"Tweak"]];
}

- (void)hidePreview {
    [self prepareToHidePreview];
    [self setPreviewItem:nil];

    [[self previewView] reset];
    [self setSourceHistoryKey:nil];
}

- (void)resetPreviewState {
    [[self previewView] reset];
    [[self previewView] setHidden:YES];
    [[self clearButton] setHidden:NO];
    [[self backButton] setHidden:YES];
    [[self backButton] setEnabled:YES];
    [[self backButton] setAlpha:1.0];
    [self restoreHeaderButtonsForSourceHistoryKey:[self sourceHistoryKey]];
    [[self favoritesButton]
        setAccessibilityLabel:[[PasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
                                                                                      value:nil
                                                                                      table:@"Tweak"]];
    [self setPreviewItem:nil];
    [self setSourceHistoryKey:nil];
}

- (void)scrollToTopAnimated:(BOOL)animated {
    [[self previewView] scrollToTopAnimated:animated];
}

- (void)restoreHeaderButtonsForSourceHistoryKey:(nullable NSString *)historyKey {
    BOOL showingFavorites = [historyKey isEqualToString:kKayokoHistoryKeyFavorites];
    NSString *imageName = showingFavorites ? @"heart.fill" : @"heart";
    UIColor *tintColor = showingFavorites ? [UIColor systemPinkColor] : [UIColor labelColor];
    [self updateStyleForHeaderButton:[self favoritesButton]
                       withImageName:imageName
                        andImageSize:kKayokoFavoritesButtonImageSize
                        andTintColor:tintColor];
}

@end
