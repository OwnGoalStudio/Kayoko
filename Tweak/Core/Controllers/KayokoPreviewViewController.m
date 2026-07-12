//
//  KayokoPreviewViewController.m
//  Kayoko
//

#import "KayokoPreviewViewController.h"

#import "KayokoHeaderButtonStyle.h"
#import "KayokoHeaderView.h"
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

#pragma mark - State

@property(nonatomic, copy, nullable, readwrite) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readwrite) KayokoPasteboardItem *previewItem;
@property(nonatomic, strong) KayokoHistoryItemActionHandler *actionHandler;

- (NSString *)actionImageNameForItem:(KayokoPasteboardItem *)item;
- (NSString *)actionAccessibilityLabelKeyForItem:(KayokoPasteboardItem *)item;

#pragma mark - Tags

- (void)configureTagBarForPreviewItem:(KayokoPasteboardItem *)item;
- (void)assignTagUUID:(nullable NSString *)tagUUID;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoPreviewViewController

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _previewView = [[KayokoPreviewView alloc]
            initWithName:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Preview"
                                                                                       value:nil
                                                                                       table:@"Tweak"]];
        _actionHandler = [[KayokoHistoryItemActionHandler alloc] init];
        [self setView:_previewView];
    }
    return self;
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

    KayokoHeaderView *headerView = [[self previewView] headerView];
    [headerView setHidden:NO];
    [headerView setTitleText:[[self previewView] name]];
    [headerView updateStyleForButton:[headerView leadingButton]
                       withImageName:@"arrowshape.turn.up.backward"
                           imageSize:kKayokoFavoritesButtonImageSize
                           tintColor:[UIColor labelColor]];
    [headerView updateStyleForButton:[headerView trailingButton]
                       withImageName:[self actionImageNameForItem:item]
                           imageSize:kKayokoBackButtonImageSize
                           tintColor:[UIColor labelColor]];
    [[headerView leadingButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Back"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    NSString *actionAccessibilityLabelKey = [self actionAccessibilityLabelKeyForItem:item];
    [[headerView trailingButton] setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle]
                                                           localizedStringForKey:actionAccessibilityLabelKey
                                                                           value:nil
                                                                           table:@"Tweak"]];
    [[headerView trailingButton] setEnabled:YES];
    [[headerView trailingButton] setAlpha:1.0];
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
                            if ([strongSelf hapticFeedbackHandler]) {
                                [strongSelf hapticFeedbackHandler](UIImpactFeedbackStyleLight);
                            }
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

- (void)hidePreview {
    [self setPreviewItem:nil];

    [[self previewView] reset];
    [self setSourceHistoryKey:nil];
}

- (void)resetPreviewState {
    [[self previewView] reset];
    [[self previewView] setHidden:YES];
    [self setPreviewItem:nil];
    [self setSourceHistoryKey:nil];
}

- (void)scrollToTopAnimated:(BOOL)animated {
    [[self previewView] scrollToTopAnimated:animated];
}

@end
