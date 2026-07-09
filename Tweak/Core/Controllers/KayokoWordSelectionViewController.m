//
//  KayokoWordSelectionViewController.m
//  Kayoko
//

#import "KayokoWordSelectionViewController.h"

#import "KayokoHeaderButtonStyle.h"
#import "KayokoHistoryItemActionHandler.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import "KayokoHeaderView.h"
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

#pragma mark - State

@property(nonatomic, copy, readwrite) NSString *name;
@property(nonatomic, copy, nullable, readwrite) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readwrite) KayokoPasteboardItem *sourceItem;
@property(nonatomic, strong) KayokoHistoryItemActionHandler *actionHandler;

#pragma mark - Tags

- (void)configureTagBarForSourceItem:(KayokoPasteboardItem *)item;
- (void)assignTagUUID:(nullable NSString *)tagUUID;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoWordSelectionViewController

#pragma mark - Lifecycle

- (instancetype)initWithName:(NSString *)name {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _name = [name copy];
        _wordSelectionView = [[KayokoWordSelectionView alloc] init];
        [[_wordSelectionView headerView] setTitleText:name];
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

    KayokoHeaderView *headerView = [[self wordSelectionView] headerView];
    [headerView setHidden:NO];
    [headerView setTitleText:[self name]];
    [headerView updateStyleForButton:[headerView leadingButton]
                        withImageName:@"arrowshape.turn.up.backward"
                             imageSize:kKayokoFavoritesButtonImageSize
                             tintColor:[UIColor labelColor]];
    [headerView updateStyleForButton:[headerView trailingButton]
                        withImageName:(automaticallyPaste ? @"doc.on.clipboard" : @"doc.on.doc.fill")
                             imageSize:kKayokoBackButtonImageSize
                             tintColor:[UIColor labelColor]];
    [[headerView leadingButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Back"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    [[headerView trailingButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle]
                                  localizedStringForKey:(automaticallyPaste ? @"Paste" : @"Copy")
                                                  value:nil
                                                  table:@"Tweak"]];
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
        [[KayokoPasteboardManager sharedInstance] writePasteboardItem:selectedItem
                                                    sourceHistoryItem:sourceItem
                                                   fromHistoryWithKey:historyKey
                                                 allowsAutomaticPaste:YES];
    } else {
        KayokoPasteboardManager *pasteboardManager = [KayokoPasteboardManager sharedInstance];
        if ([pasteboardManager copyPasteboardItemToPasteboard:selectedItem]) {
            [pasteboardManager addPasteboardItem:selectedItem toHistoryWithKey:kKayokoHistoryKeyHistory];
        }
    }

    [[self delegate] wordSelectionViewController:self didRequestHideContainerAfterDirectPaste:automaticallyPaste];
    [[self delegate] wordSelectionViewController:self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

#pragma mark - State

- (void)resetWordSelectionState {
    [[self wordSelectionView] setHidden:YES];
    [[self wordSelectionView] reset];
    [self setSourceItem:nil];
    [self setSourceHistoryKey:nil];
}

#pragma mark - Header

- (void)updateActionButtonState {
    BOOL enabled = [self hasSelectedText];
    UIButton *actionButton = [[[self wordSelectionView] headerView] trailingButton];
    [actionButton setEnabled:enabled];
    [actionButton setAlpha:enabled ? 1.0 : 0.35];
}

@end
