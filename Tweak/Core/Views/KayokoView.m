//
//  KayokoView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoView.h"
#import "KayokoClearConfirmationView.h"
#import "KayokoEmptyStateView.h"
#import "KayokoFavoritesTableView.h"
#import "KayokoHistoryTableView.h"
#import "KayokoPreviewView.h"
#import "KayokoWordSelectionView.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"
#import <rootless.h>

@implementation KayokoView

/**
 * Initializes the main view.
 *
 * @param frame
 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        _activeHistoryKey = kHistoryKeyHistory;

        [self hide];

        [[self layer] setShadowColor:[[UIColor blackColor] CGColor]];
        [[self layer] setShadowOffset:CGSizeZero];
        [[self layer] setShadowRadius:10];
        [[self layer] setShadowOpacity:0.5];

        [self setBlurEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular]];
        [self setBlurEffectView:[[UIVisualEffectView alloc] initWithEffect:[self blurEffect]]];
        [self addSubview:[self blurEffectView]];

        [[self blurEffectView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self blurEffectView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self blurEffectView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self blurEffectView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self blurEffectView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setHeaderView:[[UIView alloc] init]];
        [self addSubview:[self headerView]];

        [[self headerView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self headerView] heightAnchor] constraintEqualToConstant:60],
            [[[self headerView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self headerView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self headerView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]]
        ]];

        [self setPanGestureRecognizer:[[UIPanGestureRecognizer alloc]
                                          initWithTarget:self
                                                  action:@selector(handlePanGestureRecognizer:)]];
        [[self headerView] addGestureRecognizer:[self panGestureRecognizer]];

        [self setTapGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(hidePreview)]];
        [[self headerView] addGestureRecognizer:[self tapGestureRecognizer]];

        [self setGrabber:[[_UIGrabber alloc] init]];
        [[self headerView] addSubview:[self grabber]];

        [[self grabber] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self grabber] topAnchor] constraintEqualToAnchor:[[self headerView] topAnchor] constant:12],
            [[[self grabber] centerXAnchor] constraintEqualToAnchor:[[self headerView] centerXAnchor]]
        ]];

        [self setFavoritesButton:[[UIButton alloc] init]];
        [[self favoritesButton] addTarget:self
                                   action:@selector(handleFavoritesButtonPressed)
                         forControlEvents:UIControlEventTouchUpInside];
        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart"
                            andImageSize:kFavoritesButtonImageSize
                            andTintColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self favoritesButton]];

        [[self favoritesButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self favoritesButton] bottomAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor]
                                                                  constant:-2],
            [[[self favoritesButton] centerXAnchor] constraintEqualToAnchor:[[self headerView] leadingAnchor]
                                                                   constant:kLeadingHeaderButtonCenterXInset]
        ]];

        [self setTitleLabel:[[UILabel alloc] init]];
        [[self titleLabel] setText:[[PasteboardManager localizationBundle] localizedStringForKey:@"History"
                                                                                           value:nil
                                                                                           table:@"Tweak"]];
        [[self titleLabel] setFont:[UIFont systemFontOfSize:26 weight:UIFontWeightSemibold]];
        [[self titleLabel] setTextColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self titleLabel]];

        [[self titleLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self titleLabel] centerYAnchor] constraintEqualToAnchor:[[self favoritesButton] centerYAnchor]],
            [[[self titleLabel] leadingAnchor] constraintEqualToAnchor:[[self headerView] leadingAnchor]
                                                              constant:kTitleLabelLeadingInset]
        ]];

        [self setClearButton:[[UIButton alloc] init]];
        [[self clearButton] addTarget:self
                               action:@selector(handleClearButtonPressed)
                     forControlEvents:UIControlEventTouchUpInside];
        [self updateStyleForHeaderButton:[self clearButton]
                           withImageName:@"trash"
                            andImageSize:kClearButtonImageSize
                            andTintColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self clearButton]];
        [[self clearButton] setHidden:NO];

        [[self clearButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self clearButton] centerYAnchor] constraintEqualToAnchor:[[self favoritesButton] centerYAnchor]],
            [[[self clearButton] centerXAnchor] constraintEqualToAnchor:[[self headerView] trailingAnchor]
                                                               constant:-kTrailingHeaderButtonCenterXInset]
        ]];

        [self setBackButton:[[UIButton alloc] init]];
        [[self backButton] addTarget:self
                              action:@selector(handlePreviewActionButtonPressed)
                    forControlEvents:UIControlEventTouchUpInside];
        [self updateStyleForHeaderButton:[self backButton]
                           withImageName:@"arrowshape.turn.up.backward"
                            andImageSize:kBackButtonImageSize
                            andTintColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self backButton]];
        [[self backButton] setHidden:YES];

        [[self backButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self backButton] centerYAnchor] constraintEqualToAnchor:[[self favoritesButton] centerYAnchor]],
            [[[self backButton] centerXAnchor] constraintEqualToAnchor:[[self headerView] trailingAnchor]
                                                              constant:-kTrailingHeaderButtonCenterXInset]
        ]];

        [self setHistoryTableView:[[KayokoHistoryTableView alloc] initWithName:[[PasteboardManager localizationBundle]
                                                                                   localizedStringForKey:@"History"
                                                                                                   value:nil
                                                                                                   table:@"Tweak"]]];
        [self addSubview:[self historyTableView]];

        [[self historyTableView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self historyTableView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:8],
            [[[self historyTableView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self historyTableView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self historyTableView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self
            setFavoritesTableView:[[KayokoFavoritesTableView alloc] initWithName:[[PasteboardManager localizationBundle]
                                                                                     localizedStringForKey:@"Favorites"
                                                                                                     value:nil
                                                                                                     table:@"Tweak"]]];
        [[self favoritesTableView] setHistoryKey:kHistoryKeyFavorites];
        [[self favoritesTableView] setHidden:YES];
        [self addSubview:[self favoritesTableView]];

        [[self favoritesTableView] reloadDataWithItems:nil];

        [[self favoritesTableView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self favoritesTableView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:8],
            [[[self favoritesTableView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self favoritesTableView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self favoritesTableView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setClearConfirmationView:[[KayokoClearConfirmationView alloc] init]];
        [[self clearConfirmationView] setHidden:YES];
        [self addSubview:[self clearConfirmationView]];

        [[self clearConfirmationView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self clearConfirmationView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:8],
            [[[self clearConfirmationView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self clearConfirmationView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self clearConfirmationView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [[[self clearConfirmationView] cancelButton] addTarget:self
                                                        action:@selector(handleClearConfirmationCancelButtonPressed)
                                              forControlEvents:UIControlEventTouchUpInside];
        [[[self clearConfirmationView] confirmButton] addTarget:self
                                                         action:@selector(handleClearConfirmationConfirmButtonPressed)
                                               forControlEvents:UIControlEventTouchUpInside];

        [self setEmptyStateView:[[KayokoEmptyStateView alloc] init]];
        [[self emptyStateView] setHidden:YES];
        [self addSubview:[self emptyStateView]];

        [[self emptyStateView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self emptyStateView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:8],
            [[[self emptyStateView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self emptyStateView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self emptyStateView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setPreviewView:[[KayokoPreviewView alloc]
                                 initWithName:[[PasteboardManager localizationBundle] localizedStringForKey:@"Preview"
                                                                                                      value:nil
                                                                                                      table:@"Tweak"]]];
        __weak typeof(self) weakSelf = self;
        [[[self previewView] wordSelectionView] setSelectionChangedHandler:^{
          [weakSelf updatePreviewActionButtonState];
        }];
        [[self previewView] setHidden:YES];
        [self addSubview:[self previewView]];

        [[self previewView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self previewView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:8],
            [[[self previewView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self previewView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self previewView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];
    }

    return self;
}

/**
 * Handles the drag on the top of the main view to close it.
 *
 * @param recognizer The pan gesture recognizer.
 */
- (void)handlePanGestureRecognizer:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = CGPointMake(0, 0);
    NSUInteger const kMaxTranslation = 100;

    if ([recognizer state] == UIGestureRecognizerStateChanged) {
        translation = [recognizer translationInView:self];

        if (translation.y < 0) {
            return;
        }

        CGFloat alpha = fabs(translation.y / kMaxTranslation);
        [UIView animateWithDuration:0.1
                              delay:0
             usingSpringWithDamping:0.7
              initialSpringVelocity:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                           [self setTransform:CGAffineTransformMakeTranslation(0, translation.y)];
                           [self setAlpha:1 - alpha];
                         }
                         completion:nil];

        if (translation.y >= kMaxTranslation) {
            [self hide];
            return;
        }
    } else if ([recognizer state] == UIGestureRecognizerStateEnded) {
        if (translation.y < kMaxTranslation) {
            [UIView animateWithDuration:0.4
                                  delay:0
                 usingSpringWithDamping:1
                  initialSpringVelocity:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                               [self setTransform:CGAffineTransformIdentity];
                               [self setAlpha:1];
                             }
                             completion:nil];
        }
    }
}

/**
 * Updates the style of the a header button.
 *
 * @param button The button to update.
 * @param imageName The name of the system image to use on the button.
 * @param color The color to use for the image.
 */
- (void)updateStyleForHeaderButton:(UIButton *)button
                     withImageName:(NSString *)imageName
                      andImageSize:(NSUInteger)imageSize
                      andTintColor:(UIColor *)color {
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:imageSize weight:UIImageSymbolWeightMedium];
    UIImage *image = [UIImage systemImageNamed:imageName];
    if (!image) {
        image = [UIImage systemImageNamed:@"doc.on.doc"];
    }
    [button setImage:[image imageWithConfiguration:configuration] forState:UIControlStateNormal];
    [button setTintColor:color];
}

- (NSString *)activeHistoryKey {
    if (_clearConfirmationHistoryKey) {
        return _clearConfirmationHistoryKey;
    }

    return _activeHistoryKey ?: kHistoryKeyHistory;
}

- (KayokoTableView *)tableViewForHistoryKey:(NSString *)key {
    return [key isEqualToString:kHistoryKeyFavorites] ? [self favoritesTableView] : [self historyTableView];
}

- (UIView *)contentViewForHistoryKey:(NSString *)key {
    KayokoTableView *tableView = [self tableViewForHistoryKey:key];
    if ([[tableView items] count] > 0) {
        return tableView;
    }

    [[self emptyStateView] updateWithHistoryKey:key];
    return [self emptyStateView];
}

- (UIView *)activeHistoryContentView {
    if (![[self historyTableView] isHidden]) {
        return [self historyTableView];
    }

    if (![[self favoritesTableView] isHidden]) {
        return [self favoritesTableView];
    }

    return [self emptyStateView];
}

- (void)setHistoryContentVisibleForKey:(NSString *)key {
    _activeHistoryKey = key;
    UIView *contentView = [self contentViewForHistoryKey:key];
    [[self historyTableView] setHidden:contentView != [self historyTableView]];
    [[self favoritesTableView] setHidden:contentView != [self favoritesTableView]];
    [[self emptyStateView] setHidden:contentView != [self emptyStateView]];
    [contentView setAlpha:1];
    [contentView setTransform:CGAffineTransformIdentity];
    [[self titleLabel] setText:[self titleForContentView:contentView]];
}

- (NSString *)titleForContentView:(UIView *)view {
    if (view == [self clearConfirmationView]) {
        return [[self titleLabel] text];
    }

    if ([view respondsToSelector:@selector(name)]) {
        return [view valueForKey:@"name"];
    }

    return nil;
}

- (void)updateClearConfirmationTextForHistoryKey:(NSString *)key {
    [[self clearConfirmationView] updateWithHistoryKey:key];
}

- (void)showClearConfirmationForHistoryKey:(NSString *)key {
    _activeHistoryKey = key;
    _clearConfirmationHistoryKey = key;
    [self updateClearConfirmationTextForHistoryKey:key];
    [[self clearButton] setHidden:YES];

    [self showContentView:[self clearConfirmationView] andHideContentView:[self activeHistoryContentView] reverse:NO];
}

- (void)hideClearConfirmationWithReload:(BOOL)reload {
    if ([[self clearConfirmationView] isHidden] || !_clearConfirmationHistoryKey) {
        return;
    }

    NSString *key = _clearConfirmationHistoryKey;
    KayokoTableView *tableView = [self tableViewForHistoryKey:key];
    if (reload) {
        NSArray *items = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:key];
        [tableView reloadDataWithItems:items];
    }

    _clearConfirmationHistoryKey = nil;
    [[self clearButton] setHidden:NO];
    [self updateClearButtonStateForTableView:[self tableViewForHistoryKey:key]];
    [self showContentView:[self contentViewForHistoryKey:key] andHideContentView:[self clearConfirmationView] reverse:YES];
}

- (void)resetClearConfirmationIfNeeded {
    if (!_clearConfirmationHistoryKey) {
        return;
    }

    [[self clearConfirmationView] setHidden:YES];
    [[self clearConfirmationView] setAlpha:1];
    [[self clearConfirmationView] setTransform:CGAffineTransformIdentity];
    [self setHistoryContentVisibleForKey:_clearConfirmationHistoryKey];
    [[self clearButton] setHidden:NO];
    _clearConfirmationHistoryKey = nil;
    [self updateClearButtonState];
}

- (BOOL)isShowingClearConfirmation {
    return _clearConfirmationHistoryKey && ![[self clearConfirmationView] isHidden];
}

- (void)updateClearButtonState {
    KayokoTableView *tableView = [self tableViewForHistoryKey:[self activeHistoryKey]];
    [self updateClearButtonStateForTableView:tableView];
}

- (void)updateClearButtonStateForTableView:(KayokoTableView *)tableView {
    BOOL enabled = [[tableView items] count] > 0;
    [[self clearButton] setEnabled:enabled];
    [[self clearButton] setAlpha:enabled ? 1.0 : 0.35];
}

- (void)setPreviewLineCount:(NSUInteger)previewLineCount {
    _previewLineCount = previewLineCount;
    [[self historyTableView] setPreviewLineCount:previewLineCount];
    [[self favoritesTableView] setPreviewLineCount:previewLineCount];
}

- (void)updateContentState {
    if (![self isShowingClearConfirmation] && [[self previewView] isHidden]) {
        UIView *viewToHide = [self activeHistoryContentView];
        UIView *viewToShow = [self contentViewForHistoryKey:[self activeHistoryKey]];

        if (viewToShow != viewToHide) {
            [self showContentView:viewToShow andHideContentView:viewToHide reverse:NO];
        } else {
            [[self titleLabel] setText:[self titleForContentView:viewToShow]];
        }
    }

    [self updateClearButtonState];
}

/**
 * Handles the press of the favorites button.
 *
 * It either shows the history or favorites view or hides the preview view again.
 */
- (void)handleFavoritesButtonPressed {
    if (_isAnimating) {
        return;
    }

    if ([self isShowingClearConfirmation]) {
        [self hideClearConfirmationWithReload:NO];
        [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
        return;
    }

    if (![[self previewView] isHidden]) {
        [self hidePreview];
        [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
        return;
    }

    NSString *key = [self activeHistoryKey];
    BOOL showingFavorites = [key isEqualToString:kHistoryKeyFavorites];
    NSString *targetKey = showingFavorites ? kHistoryKeyHistory : kHistoryKeyFavorites;
    KayokoTableView *targetTableView = [self tableViewForHistoryKey:targetKey];
    UIView *viewToHide = [self activeHistoryContentView];

    if (showingFavorites) {
        NSArray *items = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:kHistoryKeyHistory];
        [[self historyTableView] reloadDataWithItems:items];
        _activeHistoryKey = kHistoryKeyHistory;
        [self updateClearButtonStateForTableView:targetTableView];

        UIView *viewToShow = [self contentViewForHistoryKey:kHistoryKeyHistory];
        if (viewToShow != viewToHide) {
            [self showContentView:viewToShow andHideContentView:viewToHide reverse:YES];
        } else {
            [[self titleLabel] setText:[self titleForContentView:viewToShow]];
        }

        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart"
                            andImageSize:kFavoritesButtonImageSize
                            andTintColor:[UIColor labelColor]];
    } else {
        NSArray *items = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:kHistoryKeyFavorites];
        [[self favoritesTableView] reloadDataWithItems:items];
        _activeHistoryKey = kHistoryKeyFavorites;
        [self updateClearButtonStateForTableView:targetTableView];

        UIView *viewToShow = [self contentViewForHistoryKey:kHistoryKeyFavorites];
        if (viewToShow != viewToHide) {
            [self showContentView:viewToShow andHideContentView:viewToHide reverse:NO];
        } else {
            [[self titleLabel] setText:[self titleForContentView:viewToShow]];
        }

        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart.fill"
                            andImageSize:kFavoritesButtonImageSize
                            andTintColor:[UIColor systemPinkColor]];
    }

    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
}

- (void)handlePreviewActionButtonPressed {
    if (!_previewItem || [[self previewView] isHidden] || ![[self previewView] showingWordSelection] ||
        ![[self previewView] hasSelectedText]) {
        return;
    }

    NSString *text = [[self previewView] selectedText];

    if ([self automaticallyPaste]) {
        PasteboardItem *selectedItem = [[PasteboardItem alloc] initWithBundleIdentifier:[_previewItem bundleIdentifier]
                                                                             andContent:text
                                                                         withImageNamed:@""];
        NSString *historyKey =
            _previewSourceTableView == [self favoritesTableView] ? kHistoryKeyFavorites : kHistoryKeyHistory;
        [[PasteboardManager sharedInstance] performDirectPasteWithPasteboardItem:selectedItem
                                                                      historyItem:_previewItem
                                                               fromHistoryWithKey:historyKey
                                                                  shouldAutoPaste:YES];
    } else {
        [[UIPasteboard generalPasteboard] setString:text];
    }

    [[self previewView] reset];
    [[self previewView] setHidden:YES];
    [_previewSourceTableView setHidden:NO];
    [_previewSourceTableView setAlpha:1];
    [_previewSourceTableView setTransform:CGAffineTransformIdentity];
    [[self clearButton] setHidden:NO];
    [[self backButton] setHidden:YES];
    [[self backButton] setEnabled:YES];
    [[self backButton] setAlpha:1.0];
    if (_previewSourceTableView == [self favoritesTableView]) {
        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart.fill"
                            andImageSize:kFavoritesButtonImageSize
                            andTintColor:[UIColor systemPinkColor]];
    } else {
        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart"
                            andImageSize:kFavoritesButtonImageSize
                            andTintColor:[UIColor labelColor]];
    }
    _previewItem = nil;
    [self hide];
    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)updatePreviewActionButtonState {
    BOOL enabled = [[self previewView] showingWordSelection] && [[self previewView] hasSelectedText];
    [[self backButton] setEnabled:enabled];
    [[self backButton] setAlpha:enabled ? 1.0 : 0.35];
}

- (void)handleClearButtonPressed {
    if (_isAnimating || ![[self previewView] isHidden] || [self isShowingClearConfirmation]) {
        return;
    }

    [self showClearConfirmationForHistoryKey:[self activeHistoryKey]];
    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)handleClearConfirmationCancelButtonPressed {
    if (_isAnimating) {
        return;
    }

    [self hideClearConfirmationWithReload:NO];
    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
}

- (void)handleClearConfirmationConfirmButtonPressed {
    if (_isAnimating || !_clearConfirmationHistoryKey) {
        return;
    }

    NSString *key = _clearConfirmationHistoryKey;
    NSArray *items = [[[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:key] copy];
    for (NSDictionary *dictionary in items) {
        PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];
        [[PasteboardManager sharedInstance] removePasteboardItem:item
                                              fromHistoryWithKey:key
                                               shouldRemoveImage:YES];
    }

    [self hideClearConfirmationWithReload:YES];
    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleHeavy];
}

/**
 * Shows the preview view with a given item's contents.
 *
 * @param item The item to preview.
 */
- (void)showPreviewWithItem:(PasteboardItem *)item {
    _previewItem = item;

    if (![[item imageName] isEqualToString:@""]) {
        NSData *imageData = [[NSFileManager defaultManager]
            contentsAtPath:[NSString
                               stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]]];
        [[[self previewView] imageView] setImage:[UIImage imageWithData:imageData]];
        [[[self previewView] imageView] setHidden:NO];
    } else {
        [[self previewView] showText:[item content] enablesWordSelection:[self swipeToSelectWords]];
    }

    _previewSourceTableView = [self tableViewForHistoryKey:[self activeHistoryKey]];
    [self showContentView:[self previewView] andHideContentView:_previewSourceTableView reverse:NO];

    [self updateStyleForHeaderButton:[self favoritesButton]
                       withImageName:@"arrowshape.turn.up.backward"
                        andImageSize:kFavoritesButtonImageSize
                        andTintColor:[UIColor labelColor]];
    [self updateStyleForHeaderButton:[self backButton]
                       withImageName:([self automaticallyPaste] ? @"doc.on.clipboard" : @"doc.on.doc.fill")
                        andImageSize:kBackButtonImageSize
                        andTintColor:[UIColor labelColor]];
    [[self favoritesButton]
        setAccessibilityLabel:[[PasteboardManager localizationBundle] localizedStringForKey:@"Back"
                                                                                      value:nil
                                                                                      table:@"Tweak"]];
    [[self backButton]
        setAccessibilityLabel:[[PasteboardManager localizationBundle]
                                  localizedStringForKey:([self automaticallyPaste] ? @"Paste" : @"Copy")
                                                  value:nil
                                                  table:@"Tweak"]];
    [[self clearButton] setHidden:YES];
    [[self backButton] setHidden:![[self previewView] showingWordSelection]];
    [self updatePreviewActionButtonState];

    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

/**
 * Hides the preview view.
 */
- (void)hidePreview {
    if ([[self previewView] isHidden] || _isAnimating) {
        return;
    }

    [self showContentView:_previewSourceTableView andHideContentView:[self previewView] reverse:YES];

    [[self clearButton] setHidden:NO];
    [[self backButton] setHidden:YES];
    [[self backButton] setEnabled:YES];
    [[self backButton] setAlpha:1.0];
    _previewItem = nil;

    if (_previewSourceTableView == [self favoritesTableView]) {
        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart.fill"
                            andImageSize:kFavoritesButtonImageSize
                            andTintColor:[UIColor systemPinkColor]];
    } else {
        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart"
                            andImageSize:kFavoritesButtonImageSize
                            andTintColor:[UIColor labelColor]];
    }
    [[self favoritesButton]
        setAccessibilityLabel:[[PasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
                                                                                      value:nil
                                                                                      table:@"Tweak"]];

    [[self previewView] reset];
}

/**
 * Animates a view in and out.
 *
 * For example when switching between the history and favorites view.
 *
 * @param viewToShow The view that's to be shown.
 * @param viewToHide The view that's to be hidden.
 * @param reverse Whether the animation should play reversed for a mirrored effect.
 */
- (void)showContentView:(UIView *)viewToShow andHideContentView:(UIView *)viewToHide reverse:(BOOL)reverse {
    [UIView transitionWithView:[self titleLabel]
                      duration:0.1
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                      NSString *title = [self titleForContentView:viewToShow];
                      if (title) {
                          [[self titleLabel] setText:title];
                      }
                    }
                    completion:nil];

    CGFloat viewToShowTransform = reverse ? 10 : -10;
    [viewToShow setTransform:CGAffineTransformTranslate(viewToShow.transform, 0, viewToShowTransform)];
    [viewToShow setAlpha:0];
    [viewToShow setHidden:NO];

    _isAnimating = YES;
    [UIView animateWithDuration:0.3
        delay:0
        usingSpringWithDamping:1
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          [viewToShow setTransform:CGAffineTransformIdentity];
          [viewToShow setAlpha:1];

          CGFloat viewToHideTransform = reverse ? -10 : 10;
          [viewToHide setTransform:CGAffineTransformTranslate(viewToShow.transform, 0, viewToHideTransform)];
          [viewToHide setAlpha:0];
        }
        completion:^(BOOL finished) {
          [viewToHide setHidden:YES];
          _isAnimating = NO;
        }];
}

/**
 * Triggers haptic feedback.
 *
 * @param style The feedback type/strength to use.
 */
- (void)triggerHapticFeedbackWithStyle:(UIImpactFeedbackStyle)style {
    if (!self.shouldPlayFeedback) {
        return;
    }
    [self setFeedbackGenerator:[[UIImpactFeedbackGenerator alloc] initWithStyle:style]];
    [[self feedbackGenerator] prepare];
    [[self feedbackGenerator] impactOccurred];
    [self setFeedbackGenerator:nil];
}

/**
 * Reloads the active history view.
 */
- (void)reload {
    NSString *key = [self activeHistoryKey];
    NSArray *items = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:key];
    [[self tableViewForHistoryKey:key] reloadDataWithItems:items];
    if ([self isShowingClearConfirmation] || ![[self previewView] isHidden]) {
        return;
    }
    [self setHistoryContentVisibleForKey:key];
    [self updateClearButtonState];
}

/**
 * Shows the main view.
 */
- (void)show {
    if (_isAnimating) {
        return;
    }

    [self resetClearConfirmationIfNeeded];

    [[self historyTableView] setAutomaticallyPaste:[self automaticallyPaste]];
    [[self favoritesTableView] setAutomaticallyPaste:[self automaticallyPaste]];

    [self reload];

    [self setTransform:CGAffineTransformMakeTranslation(0, [self bounds].size.height / 3)];
    [self setAlpha:0];
    [self setHidden:NO];

    _isAnimating = YES;
    [UIView animateWithDuration:0.33
        delay:0
        usingSpringWithDamping:1
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          [self setTransform:CGAffineTransformIdentity];
          [self setAlpha:1];
        }
        completion:^(BOOL finished) {
          _isAnimating = NO;
        }];
}

/**
 * Hides the main view.
 */
- (void)hide {
    if (_isAnimating) {
        return;
    }

    _isAnimating = YES;
    [UIView animateWithDuration:0.33
        delay:0
        usingSpringWithDamping:1
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          [self setAlpha:0];
        }
        completion:^(BOOL finished) {
          [self setHidden:YES];
          _isAnimating = NO;
        }];
}

@end
