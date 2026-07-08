//
//  KayokoWordSelectionViewController.m
//  Kayoko
//

#import "KayokoWordSelectionViewController.h"

#import "KayokoHeaderButtonStyle.h"
#import "KayokoHistoryItemActionHandler.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import "KayokoTag.h"
#import "KayokoTagCatalog.h"
#import "KayokoWordSelectionView.h"

// Word selection creates one button per token; CJK text can approach one token per character.
static NSUInteger const kKayokoWordSelectionMaximumTextLength = 5000;

static NSString *kayokoWordSelectionTextByTrimmingBoundaryNewlines(NSString *text) {
    return [(text ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

NS_ASSUME_NONNULL_BEGIN

@interface KayokoWordSelectionViewController ()
#pragma mark - Views

@property(nonatomic, strong, readwrite) KayokoWordSelectionView *wordSelectionView;
@property(nonatomic, weak) UIButton *favoritesButton;
@property(nonatomic, weak) UIButton *backButton;
@property(nonatomic, weak) UIButton *clearButton;

#pragma mark - State

@property(nonatomic, copy, readwrite) NSString *name;
@property(nonatomic, copy, nullable, readwrite) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readwrite) KayokoPasteboardItem *sourceItem;
@property(nonatomic, strong) KayokoHistoryItemActionHandler *actionHandler;

#pragma mark - Header

- (void)restoreHeaderButtonsForSourceHistoryKey:(nullable NSString *)historyKey;
- (void)resetHeaderState;
- (void)updateStyleForHeaderButton:(UIButton *)button
                     withImageName:(NSString *)imageName
                      andImageSize:(NSUInteger)imageSize
                      andTintColor:(UIColor *)color;

#pragma mark - Tags

- (void)configureTagBarForSourceItem:(KayokoPasteboardItem *)item;
- (void)assignTagUUID:(nullable NSString *)tagUUID;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoWordSelectionViewController

#pragma mark - Lifecycle

- (instancetype)initWithName:(NSString *)name
             favoritesButton:(UIButton *)favoritesButton
                  backButton:(UIButton *)backButton
                 clearButton:(UIButton *)clearButton {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _name = [name copy];
        _favoritesButton = favoritesButton;
        _backButton = backButton;
        _clearButton = clearButton;
        _wordSelectionView = [[KayokoWordSelectionView alloc] init];
        [_wordSelectionView setHidden:YES];
        _actionHandler = [[KayokoHistoryItemActionHandler alloc] init];
        [self setView:_wordSelectionView];

        __weak typeof(self) weakSelf = self;
        [_wordSelectionView setSelectionChangedHandler:^{
          [weakSelf updateActionButtonState];
          if ([weakSelf selectionChangedHandler]) {
              [weakSelf selectionChangedHandler]();
          }
        }];
    }
    return self;
}

#pragma mark - Public State

- (NSString *)selectedText {
    return [[self wordSelectionView] selectedText];
}

- (BOOL)isShowingWordSelection {
    return ![[self wordSelectionView] isHidden];
}

- (BOOL)hasSelectedText {
    return [[self selectedText] length] > 0;
}

- (BOOL)canShowText:(NSString *)text {
    return [text length] <= kKayokoWordSelectionMaximumTextLength;
}

- (void)scrollToTopAnimated:(BOOL)animated {
    [[self wordSelectionView] scrollToTopAnimated:animated];
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

- (void)showWordSelectionWithItem:(KayokoPasteboardItem *)item
                 sourceHistoryKey:(NSString *)sourceHistoryKey
               automaticallyPaste:(BOOL)automaticallyPaste {
    [self setSourceItem:item];
    [self setSourceHistoryKey:sourceHistoryKey];

    NSString *text = kayokoWordSelectionTextByTrimmingBoundaryNewlines([item content]);
    [[self wordSelectionView] setText:text];
    [[self wordSelectionView] setHidden:NO];
    [self configureTagBarForSourceItem:item];

    [self updateStyleForHeaderButton:[self favoritesButton]
                       withImageName:@"arrowshape.turn.up.backward"
                        andImageSize:kKayokoFavoritesButtonImageSize
                        andTintColor:[UIColor labelColor]];
    [self updateStyleForHeaderButton:[self backButton]
                       withImageName:(automaticallyPaste ? @"doc.on.clipboard" : @"doc.on.doc.fill")andImageSize
                                    :kKayokoBackButtonImageSize
                        andTintColor:[UIColor labelColor]];
    [[self favoritesButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Back"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    [[self backButton] setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle]
                                                 localizedStringForKey:(automaticallyPaste ? @"Paste" : @"Copy")
                                                                 value:nil
                                                                 table:@"Tweak"]];
    [[self clearButton] setHidden:YES];
    [[self backButton] setHidden:NO];
    [self updateActionButtonState];
}

#pragma mark - Tags

- (void)configureTagBarForSourceItem:(KayokoPasteboardItem *)item {
    NSArray<KayokoTag *> *tags = [[KayokoTagCatalog sharedCatalog] reloadTags];
    __weak typeof(self) weakSelf = self;
    [[self wordSelectionView] configureTagBarWithTags:tags
                                      selectedTagUUID:[item tagUUID]
                                     selectionHandler:^(NSString *tagUUID) {
                                       [weakSelf assignTagUUID:tagUUID];
                                     }];
}

- (void)assignTagUUID:(NSString *)tagUUID {
    KayokoPasteboardItem *item = [self sourceItem];
    NSString *historyKey = [self sourceHistoryKey];
    NSString *normalizedTagUUID = [tagUUID length] > 0 ? tagUUID : nil;
    NSString *previousTagUUID = [item tagUUID];
    if (!item || [historyKey length] == 0 || [(previousTagUUID ?: @"") isEqualToString:(normalizedTagUUID ?: @"")]) {
        return;
    }

    [[self wordSelectionView] setSelectedTagUUID:normalizedTagUUID];
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
                                [[strongSelf wordSelectionView] setSelectedTagUUID:previousTagUUID];
                                return;
                            }
                            [[strongSelf delegate] wordSelectionViewController:strongSelf
                                                triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleLight];
                            if ([strongSelf tagAssignmentHandler]) {
                                [strongSelf tagAssignmentHandler](item, historyKey);
                            }
                          }];
}

#pragma mark - Dismissal

- (void)prepareToHideWordSelection {
    [self resetHeaderState];
}

- (void)hideWordSelection {
    [self resetWordSelectionState];
}

#pragma mark - Actions

- (void)handleActionButtonWithAutomaticallyPaste:(BOOL)automaticallyPaste {
    KayokoPasteboardItem *sourceItem = [self sourceItem];
    if (!sourceItem || ![self isShowingWordSelection] || ![self hasSelectedText]) {
        return;
    }

    NSString *text = [self selectedText];
    KayokoPasteboardItem *selectedItem =
        [[KayokoPasteboardItem alloc] initWithBundleIdentifier:[sourceItem bundleIdentifier]
                                                    andContent:text
                                                withImageNamed:@""];
    NSString *historyKey = [self sourceHistoryKey] ?: kKayokoHistoryKeyHistory;
    if (automaticallyPaste) {
        [[KayokoPasteboardManager sharedInstance] performDirectPasteWithPasteboardItem:selectedItem
                                                                           historyItem:sourceItem
                                                                    fromHistoryWithKey:historyKey
                                                                       shouldAutoPaste:YES];
    } else {
        KayokoPasteboardManager *pasteboardManager = [KayokoPasteboardManager sharedInstance];
        if ([pasteboardManager copyPasteboardItemToPasteboard:selectedItem]) {
            [pasteboardManager addPasteboardItem:selectedItem toHistoryWithKey:kKayokoHistoryKeyHistory];
        }
    }

    [[self delegate] wordSelectionViewController:self didRequestHideContainerAfterDirectPaste:automaticallyPaste];
    [[self delegate] wordSelectionViewController:self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

#pragma mark - Header Helpers

- (void)resetHeaderState {
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

- (void)resetWordSelectionState {
    [[self wordSelectionView] setHidden:YES];
    [[self wordSelectionView] reset];
    [self resetHeaderState];
    [self setSourceItem:nil];
    [self setSourceHistoryKey:nil];
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

- (void)updateActionButtonState {
    BOOL enabled = [self hasSelectedText];
    [[self backButton] setEnabled:enabled];
    [[self backButton] setAlpha:enabled ? 1.0 : 0.35];
}

@end
