//
//  KayokoPreviewViewController.m
//  Kayoko
//

#import "KayokoPreviewViewController.h"

#import "KayokoHeaderButtonStyle.h"
#import "KayokoHistoryItemActionHandler.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import "KayokoPreviewView.h"
#import "KayokoTag.h"
#import "KayokoTagCatalog.h"

static NSString *kayokoPreviewTextByTrimmingBoundaryNewlines(NSString *text) {
    return [(text ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPreviewViewController ()
#pragma mark - Views

@property(nonatomic, strong, readwrite) KayokoPreviewView *previewView;
@property(nonatomic, weak) UIButton *favoritesButton;
@property(nonatomic, weak) UIButton *backButton;
@property(nonatomic, weak) UIButton *clearButton;

#pragma mark - State

@property(nonatomic, copy, nullable, readwrite) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readwrite) KayokoPasteboardItem *previewItem;
@property(nonatomic, strong) KayokoHistoryItemActionHandler *actionHandler;

#pragma mark - Header

- (void)restoreHeaderButtonsForSourceHistoryKey:(nullable NSString *)historyKey;
- (NSString *)actionImageNameForItem:(KayokoPasteboardItem *)item;
- (NSString *)actionAccessibilityLabelKeyForItem:(KayokoPasteboardItem *)item;

#pragma mark - Tags

- (void)configureTagBarForPreviewItem:(KayokoPasteboardItem *)item;
- (void)assignTagUUID:(nullable NSString *)tagUUID;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoPreviewViewController

#pragma mark - Lifecycle

- (instancetype)initWithFavoritesButton:(UIButton *)favoritesButton
                             backButton:(UIButton *)backButton
                            clearButton:(UIButton *)clearButton {
    self = [super init];
    if (self) {
        _previewView = [[KayokoPreviewView alloc]
            initWithName:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Preview"
                                                                                       value:nil
                                                                                       table:@"Tweak"]];
        _favoritesButton = favoritesButton;
        _backButton = backButton;
        _clearButton = clearButton;
        _actionHandler = [[KayokoHistoryItemActionHandler alloc] init];
        [self setView:_previewView];
    }
    return self;
}

#pragma mark - Header

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

#pragma mark - Presentation

- (void)showPreviewWithItem:(KayokoPasteboardItem *)item sourceHistoryKey:(NSString *)sourceHistoryKey {
    [self setPreviewItem:item];
    [self setSourceHistoryKey:sourceHistoryKey];

    if (![[item imageName] isEqualToString:@""]) {
        NSData *imageData = [[NSFileManager defaultManager]
            contentsAtPath:[NSString stringWithFormat:@"%@/%@", [KayokoPasteboardManager historyImagesPath],
                                                      [item imageName]]];
        [[self previewView] reset];
        [[self previewView] showImage:[UIImage imageWithData:imageData]];
    } else {
        NSString *previewText = kayokoPreviewTextByTrimmingBoundaryNewlines([item content]);
        [[self previewView] showText:previewText];
    }
    [self configureTagBarForPreviewItem:item];

    [self updateStyleForHeaderButton:[self favoritesButton]
                       withImageName:@"arrowshape.turn.up.backward"
                        andImageSize:kKayokoFavoritesButtonImageSize
                        andTintColor:[UIColor labelColor]];
    [self updateStyleForHeaderButton:[self backButton]
                       withImageName:[self actionImageNameForItem:item]
                        andImageSize:kKayokoBackButtonImageSize
                        andTintColor:[UIColor labelColor]];
    [[self favoritesButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Back"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    [[self backButton] setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle]
                                                 localizedStringForKey:[self actionAccessibilityLabelKeyForItem:item]
                                                                 value:nil
                                                                 table:@"Tweak"]];
    [[self clearButton] setHidden:YES];
    [[self backButton] setHidden:NO];
    [[self backButton] setEnabled:YES];
    [[self backButton] setAlpha:1.0];
}

#pragma mark - Tags

- (void)configureTagBarForPreviewItem:(KayokoPasteboardItem *)item {
    NSArray<KayokoTag *> *tags = [[KayokoTagCatalog sharedCatalog] reloadTags];
    __weak typeof(self) weakSelf = self;
    [[self previewView] configureTagBarWithTags:tags
                                selectedTagUUID:[item tagUUID]
                               selectionHandler:^(NSString *tagUUID) {
                                 [weakSelf assignTagUUID:tagUUID];
                               }];
}

#pragma mark - Feedback

- (void)triggerLightFeedback {
    UIImpactFeedbackGenerator *feedbackGenerator =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedbackGenerator impactOccurred];
}

#pragma mark - Actions

- (void)assignTagUUID:(NSString *)tagUUID {
    KayokoPasteboardItem *item = [self previewItem];
    NSString *historyKey = [self sourceHistoryKey];
    NSString *normalizedTagUUID = [tagUUID length] > 0 ? tagUUID : nil;
    NSString *previousTagUUID = [item tagUUID];
    if (!item || [historyKey length] == 0 || [(previousTagUUID ?: @"") isEqualToString:(normalizedTagUUID ?: @"")]) {
        return;
    }

    [[self previewView] setSelectedTagUUID:normalizedTagUUID];
    [item setTagUUID:normalizedTagUUID];

    __weak typeof(self) weakSelf = self;
    [[self actionHandler] setTagUUID:normalizedTagUUID
                             forItem:item
                          historyKey:historyKey
                          completion:^(BOOL success) {
                            __strong typeof(weakSelf) strongSelf = weakSelf;
                            if (!strongSelf) {
                                return;
                            }
                            if (!success) {
                                [item setTagUUID:previousTagUUID];
                                [[strongSelf previewView] setSelectedTagUUID:previousTagUUID];
                                return;
                            }
                            [strongSelf triggerLightFeedback];
                            if ([strongSelf tagAssignmentHandler]) {
                                [strongSelf tagAssignmentHandler](item, historyKey);
                            }
                          }];
}

- (NSString *)actionImageNameForItem:(KayokoPasteboardItem *)item {
    if ([[item imageName] length] > 0) {
        return @"square.and.arrow.down.fill";
    }
    if ([item hasLink]) {
        return @"arrow.up";
    }
    return @"doc.on.doc.fill";
}

- (NSString *)actionAccessibilityLabelKeyForItem:(KayokoPasteboardItem *)item {
    if ([[item imageName] length] > 0) {
        return @"Save to Photos";
    }
    if ([item hasLink]) {
        return @"Open";
    }
    return @"Copy";
}

- (void)handleActionButtonWithCompletion:(void (^)(BOOL success))completion {
    KayokoPasteboardItem *item = [self previewItem];
    if (!item || [[self previewView] isHidden]) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    if ([[item imageName] length] > 0) {
        [[self actionHandler] saveImageForItem:item completion:completion];
        return;
    }
    if ([item hasLink]) {
        [[self actionHandler] openLinkForItem:item completion:completion];
        return;
    }

    [[self actionHandler] copyItem:item completion:completion];
}

#pragma mark - Dismissal

- (void)prepareToHidePreview {
    [[self clearButton] setHidden:NO];
    [[self backButton] setHidden:YES];
    [[self backButton] setEnabled:YES];
    [[self backButton] setAlpha:1.0];
    [self restoreHeaderButtonsForSourceHistoryKey:[self sourceHistoryKey]];
    [[self favoritesButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
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
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    [self setPreviewItem:nil];
    [self setSourceHistoryKey:nil];
}

- (void)scrollToTopAnimated:(BOOL)animated {
    [[self previewView] scrollToTopAnimated:animated];
}

#pragma mark - Header Helpers

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
