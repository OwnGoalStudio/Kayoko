//
//  KayokoTagManagementViewController.m
//  Kayoko
//

#import "KayokoTagManagementViewController.h"
#import "KayokoKeyboardAvoidanceCoordinator.h"
#import "KayokoTag.h"
#import "KayokoTagEditorViewController.h"
#import "KayokoTagPlaceholderView.h"
#import "KayokoTagStore.h"
#import "KayokoTagTableViewCell.h"

#import <UIKit/UIKit.h>

static NSString *const kKayokoTagCellReuseIdentifier = @"KayokoTagCell";
static CGFloat const kKayokoTagPlaceholderMinimumHeight = 96.0;

@interface KayokoTagManagementViewController () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating,
                                                 UISearchControllerDelegate>
#pragma mark - Views

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) KayokoTagPlaceholderView *placeholderView;
@property(nonatomic, strong) UISearchController *searchController;

#pragma mark - Data

@property(nonatomic, strong) NSMutableArray<KayokoTag *> *tags;
@property(nonatomic, strong) NSMutableArray<KayokoTag *> *filteredTags;
@property(nonatomic, strong) NSMutableSet<NSString *> *selectedTagUUIDs;
@property(nonatomic, strong) KayokoTagStore *tagStore;
@property(nonatomic, strong) NSBundle *localizationBundle;

#pragma mark - Keyboard

@property(nonatomic, strong) KayokoKeyboardAvoidanceCoordinator *keyboardAvoidanceCoordinator;

#pragma mark - Toolbar

@property(nonatomic, strong) UIBarButtonItem *toolbarFlexibleSpaceItem;
@property(nonatomic, strong) UIBarButtonItem *addToolbarItem;
@property(nonatomic, strong) UIBarButtonItem *selectToolbarItem;
@property(nonatomic, strong) UIBarButtonItem *deleteToolbarItem;

#pragma mark - State

@property(nonatomic, assign, getter=isSearchInterfaceActive) BOOL searchInterfaceActive;
@property(nonatomic, assign) CGFloat keyboardBottomInset;
@property(nonatomic, assign, getter=isUpdatingPlaceholderLayout) BOOL updatingPlaceholderLayout;
@end

@implementation KayokoTagManagementViewController

#pragma mark - Lifecycle

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [view setBackgroundColor:[UIColor systemGroupedBackgroundColor]];
    [self setView:view];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _localizationBundle = [NSBundle bundleForClass:[self class]];
    _selectedTagUUIDs = [[NSMutableSet alloc] init];
    _filteredTags = [[NSMutableArray alloc] init];
    _tagStore = [[KayokoTagStore alloc] initWithTagsPath:[KayokoTagStore defaultTagsPath]
                                      localizationBundle:_localizationBundle];

    [self setTitle:[self localizedStringForKey:@"Tags"]];
    [self loadTags];
    [self configureNavigationItem];
    [self configureSearchController];
    [self configureTableView];
    [self configurePlaceholderView];
    [self configureToolbarItems];
    [self updateToolbarItems];
    [self updatePlaceholderVisibility];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updatePlaceholderLayout];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[self navigationController] setToolbarHidden:NO animated:animated];
    [[self keyboardAvoidanceCoordinator] startObserving];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[self keyboardAvoidanceCoordinator] stopObservingAndRestoreInsets];
    if ([self isMovingFromParentViewController] || [[self navigationController] isBeingDismissed]) {
        [[self navigationController] setToolbarHidden:YES animated:animated];
    }
}

- (void)loadTags {
    NSError *error = nil;
    NSMutableArray<KayokoTag *> *loadedTags = [[self tagStore] loadTagsWithError:&error];
    if (!loadedTags) {
        _tags = [[NSMutableArray alloc] init];
        [self presentError:error];
        return;
    }

    _tags = loadedTags;
}

- (void)configureNavigationItem {
    [[self navigationItem] setLargeTitleDisplayMode:UINavigationItemLargeTitleDisplayModeNever];
    [[self navigationItem] setRightBarButtonItem:[self editDoneButton]];
}

- (UIBarButtonItem *)editDoneButton {
    NSString *title = [self localizedStringForKey:[self isEditing] ? @"Done" : @"Edit"];
    UIBarButtonItemStyle style = [self isEditing] ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain;
    return [[UIBarButtonItem alloc] initWithTitle:title style:style target:self action:@selector(toggleEditing)];
}

- (void)configureSearchController {
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    [_searchController setSearchResultsUpdater:self];
    [_searchController setDelegate:self];
    [_searchController setObscuresBackgroundDuringPresentation:NO];
    [_searchController setHidesNavigationBarDuringPresentation:NO];
    [[_searchController searchBar] setPlaceholder:[self localizedStringForKey:@"Search Tags…"]];

    [self setDefinesPresentationContext:YES];
    [[self navigationItem] setSearchController:_searchController];
    [[self navigationItem] setHidesSearchBarWhenScrolling:YES];
}

- (void)configureTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    [_tableView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setRowHeight:58.0];
    [_tableView setAllowsSelection:YES];
    [_tableView setAllowsMultipleSelectionDuringEditing:YES];
    [_tableView registerClass:[KayokoTagTableViewCell class] forCellReuseIdentifier:kKayokoTagCellReuseIdentifier];
    [[self view] addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [[_tableView topAnchor] constraintEqualToAnchor:[[self view] topAnchor]],
        [[_tableView leadingAnchor] constraintEqualToAnchor:[[self view] leadingAnchor]],
        [[_tableView trailingAnchor] constraintEqualToAnchor:[[self view] trailingAnchor]],
        [[_tableView bottomAnchor] constraintEqualToAnchor:[[self view] bottomAnchor]]
    ]];

    _keyboardAvoidanceCoordinator = [[KayokoKeyboardAvoidanceCoordinator alloc] initWithView:[self view]
                                                                                  scrollView:_tableView];
    __weak typeof(self) weakSelf = self;
    [_keyboardAvoidanceCoordinator setKeyboardBottomInsetChangeHandler:^(CGFloat keyboardBottomInset) {
      [weakSelf setKeyboardBottomInset:keyboardBottomInset];
      [weakSelf updatePlaceholderLayout];
      [[weakSelf placeholderView] layoutIfNeeded];
    }];
}

- (void)configurePlaceholderView {
    _placeholderView = [[KayokoTagPlaceholderView alloc] initWithMessage:[self localizedStringForKey:@"No Tags"]];
}

- (void)configureToolbarItems {
    _toolbarFlexibleSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                              target:nil
                                                                              action:nil];
    _addToolbarItem = [[UIBarButtonItem alloc] initWithTitle:[self localizedStringForKey:@"Add"]
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(addTag)];
    _selectToolbarItem = [[UIBarButtonItem alloc] initWithTitle:[self localizedStringForKey:@"Select All"]
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:@selector(toggleSelectAll)];
    _deleteToolbarItem = [[UIBarButtonItem alloc] initWithTitle:[self localizedStringForKey:@"Delete"]
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:@selector(deleteSelectedTags)];
    [_deleteToolbarItem setTintColor:[UIColor systemRedColor]];
}

- (void)toggleEditing {
    [self setEditing:![self isEditing] animated:YES];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    BOOL wasEditing = [self isEditing];
    UITableView *tableView = [self tableView];
    if (editing && !wasEditing) {
        [tableView setEditing:NO animated:NO];
    }

    [super setEditing:editing animated:animated];
    [tableView setEditing:editing animated:animated];
    [[self navigationItem] setRightBarButtonItem:[self editDoneButton] animated:animated];

    if (!editing) {
        [[self selectedTagUUIDs] removeAllObjects];
    }

    [self updateToolbarItems];
}

#pragma mark - Toolbar

- (void)updateToolbarItems {
    NSArray<UIBarButtonItem *> *toolbarItems = nil;
    if (![self isEditing]) {
        toolbarItems = [self isSearching] ? @[] : @[ [self toolbarFlexibleSpaceItem], [self addToolbarItem] ];
    } else {
        BOOL hasDisplayedTags = [[self displayedTags] count] > 0;
        NSString *selectTitle = [self allDisplayedTagsSelected] ? [self localizedStringForKey:@"Deselect All"]
                                                                : [self localizedStringForKey:@"Select All"];
        [[self selectToolbarItem] setTitle:selectTitle];
        [[self selectToolbarItem] setEnabled:hasDisplayedTags];
        [[self deleteToolbarItem] setEnabled:[[self selectedDisplayedTagUUIDs] count] > 0];
        toolbarItems = @[ [self selectToolbarItem], [self toolbarFlexibleSpaceItem], [self deleteToolbarItem] ];
    }

    if (![[self toolbarItems] isEqualToArray:toolbarItems]) {
        [self setToolbarItems:toolbarItems animated:YES];
    }
}

#pragma mark - Actions

- (void)addTag {
    if ([self isFiltering]) {
        [[[self searchController] searchBar] setText:@""];
        [[self searchController] setActive:NO];
        [[self tableView] reloadData];
    }

    KayokoTag *tag = [KayokoTag tagWithTitle:[self localizedStringForKey:@"Untitled"] hexColor:@"#00000000"];
    NSMutableArray<KayokoTag *> *updatedTags = [[self tags] mutableCopy];
    [updatedTags addObject:tag];
    if (![self saveTags:updatedTags]) {
        return;
    }

    NSUInteger insertedIndex = [updatedTags count] - 1;
    [self setTags:updatedTags];
    [self updatePlaceholderVisibility];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:insertedIndex inSection:0];
    [[self tableView] insertRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
    [[self tableView] scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)toggleSelectAll {
    NSArray<KayokoTag *> *displayedTags = [self displayedTags];
    if ([displayedTags count] == 0) {
        return;
    }

    BOOL shouldDeselect = [self allDisplayedTagsSelected];
    for (NSUInteger index = 0; index < [displayedTags count]; index++) {
        KayokoTag *tag = displayedTags[index];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        if (shouldDeselect) {
            [[self selectedTagUUIDs] removeObject:[tag uuid]];
            [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
        } else {
            [[self selectedTagUUIDs] addObject:[tag uuid]];
            [[self tableView] selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        }
    }
    [self updateToolbarItems];
}

- (void)deleteSelectedTags {
    NSSet<NSString *> *selectedUUIDs = [self selectedDisplayedTagUUIDs];
    if ([selectedUUIDs count] == 0) {
        return;
    }

    NSArray<KayokoTag *> *displayedTagsBeforeDeletion = [[self displayedTags] copy];
    NSMutableArray<NSIndexPath *> *deletedIndexPaths = [[NSMutableArray alloc] init];
    for (NSUInteger index = 0; index < [displayedTagsBeforeDeletion count]; index++) {
        KayokoTag *tag = displayedTagsBeforeDeletion[index];
        if ([selectedUUIDs containsObject:[tag uuid]]) {
            [deletedIndexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
        }
    }

    NSMutableArray<KayokoTag *> *updatedTags = [[NSMutableArray alloc] init];
    for (KayokoTag *tag in [self tags]) {
        if (![selectedUUIDs containsObject:[tag uuid]]) {
            [updatedTags addObject:tag];
        }
    }
    if (![self saveTags:updatedTags]) {
        return;
    }

    [self setTags:updatedTags];
    [[self selectedTagUUIDs] minusSet:selectedUUIDs];
    [self refreshFilteredTags];
    [self updatePlaceholderVisibility];
    if ([deletedIndexPaths count] > 0) {
        [[self tableView] deleteRowsAtIndexPaths:deletedIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    [self updateToolbarItems];
}

- (BOOL)deleteTagAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<KayokoTag *> *displayedTags = [self displayedTags];
    if ((NSUInteger)[indexPath row] >= [displayedTags count]) {
        return NO;
    }

    KayokoTag *deletedTag = displayedTags[(NSUInteger)[indexPath row]];
    NSMutableArray<KayokoTag *> *updatedTags = [[NSMutableArray alloc] init];
    for (KayokoTag *tag in [self tags]) {
        if (![[tag uuid] isEqualToString:[deletedTag uuid]]) {
            [updatedTags addObject:tag];
        }
    }
    if (![self saveTags:updatedTags]) {
        return NO;
    }

    [self setTags:updatedTags];
    [[self selectedTagUUIDs] removeObject:[deletedTag uuid]];
    [self refreshFilteredTags];
    [self updatePlaceholderVisibility];
    [[self tableView] deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self updateToolbarItems];
    return YES;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return (NSInteger)[[self displayedTags] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    KayokoTagTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kKayokoTagCellReuseIdentifier
                                                                   forIndexPath:indexPath];
    [cell configureWithTag:[self displayedTags][(NSUInteger)[indexPath row]] editing:[self isEditing]];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    (void)indexPath;
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    (void)indexPath;
    return [self isEditing] ? UITableViewCellEditingStyleNone : UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (editingStyle == UITableViewCellEditingStyleDelete && ![self isEditing]) {
        [self deleteTagAtIndexPath:indexPath];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if ([self isEditing]) {
        return nil;
    }

    UIContextualAction *deleteAction =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                title:[self localizedStringForKey:@"Delete"]
                                              handler:^(__kindof UIContextualAction *action,
                                                        __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
                                                (void)action;
                                                (void)sourceView;
                                                completionHandler([self deleteTagAtIndexPath:indexPath]);
                                              }];
    [deleteAction setImage:[UIImage systemImageNamed:@"trash.fill"]];
    return [UISwipeActionsConfiguration configurationWithActions:@[ deleteAction ]];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    (void)indexPath;
    return [self isEditing] && ![self isSearching];
}

- (void)tableView:(UITableView *)tableView
    moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
           toIndexPath:(NSIndexPath *)destinationIndexPath {
    (void)tableView;
    if ([self isSearching] || [sourceIndexPath row] == [destinationIndexPath row]) {
        return;
    }

    NSMutableArray<KayokoTag *> *updatedTags = [[self tags] mutableCopy];
    KayokoTag *tag = updatedTags[(NSUInteger)[sourceIndexPath row]];
    [updatedTags removeObjectAtIndex:(NSUInteger)[sourceIndexPath row]];
    [updatedTags insertObject:tag atIndex:(NSUInteger)[destinationIndexPath row]];
    if (![self saveTags:updatedTags]) {
        [tableView moveRowAtIndexPath:destinationIndexPath toIndexPath:sourceIndexPath];
        return;
    }
    [self setTags:updatedTags];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    KayokoTag *tag = [self displayedTags][(NSUInteger)[indexPath row]];
    if ([self isEditing]) {
        [[self selectedTagUUIDs] addObject:[tag uuid]];
        [self updateToolbarItems];
        return;
    }

    [self presentEditorForTag:tag];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![self isEditing]) {
        return;
    }

    KayokoTag *tag = [self displayedTags][(NSUInteger)[indexPath row]];
    [[self selectedTagUUIDs] removeObject:[tag uuid]];
    [self updateToolbarItems];
}

- (BOOL)tableView:(UITableView *)tableView shouldBeginMultipleSelectionInteractionAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    return (NSUInteger)[indexPath row] < [[self displayedTags] count];
}

- (void)tableView:(UITableView *)tableView didBeginMultipleSelectionInteractionAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    (void)indexPath;
    if (![self isEditing]) {
        [self setEditing:YES animated:YES];
    }
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    (void)searchController;
    [self refreshFilteredTags];
    [[self tableView] reloadData];
    [self updatePlaceholderVisibility];
    [self syncDisplayedSelectionState];
    [self updateToolbarItems];
}

#pragma mark - UISearchControllerDelegate

- (void)willPresentSearchController:(UISearchController *)searchController {
    (void)searchController;
    BOOL wasSearching = [self isSearching];
    [self setSearchInterfaceActive:YES];
    [self reloadTableForSearchStateChangeFromSearching:wasSearching];
    [self updatePlaceholderVisibility];
    [self updateToolbarItems];
}

- (void)didDismissSearchController:(UISearchController *)searchController {
    (void)searchController;
    BOOL wasSearching = [self isSearching];
    [self setSearchInterfaceActive:NO];
    [self reloadTableForSearchStateChangeFromSearching:wasSearching];
    [self updatePlaceholderVisibility];
    [self updateToolbarItems];
}

#pragma mark - Editing

- (void)presentEditorForTag:(KayokoTag *)tag {
    KayokoTagEditorViewController *editor =
        [[KayokoTagEditorViewController alloc] initWithTag:tag localizationBundle:[self localizationBundle]];
    __weak typeof(self) weakSelf = self;
    [editor setCompletionHandler:^(KayokoTag *updatedTag) {
      [weakSelf updateTag:updatedTag];
    }];
    [editor setDismissalTransitionHandler:^(id<UIViewControllerTransitionCoordinator> transitionCoordinator) {
      [weakSelf deselectTagWithUUID:[tag uuid] transitionCoordinator:transitionCoordinator];
    }];

    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:editor];
    [navigationController setModalPresentationStyle:UIModalPresentationPageSheet];
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)deselectTagWithUUID:(NSString *)tagUUID
      transitionCoordinator:(id<UIViewControllerTransitionCoordinator>)transitionCoordinator {
    if ([tagUUID length] == 0) {
        return;
    }

    NSUInteger row = [self indexOfTagWithUUID:tagUUID inTags:[self displayedTags]];
    if (row == NSNotFound || (NSInteger)row >= [[self tableView] numberOfRowsInSection:0]) {
        return;
    }

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    void (^deselectRow)(void) = ^{
      [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    };
    if (!transitionCoordinator) {
        deselectRow();
        return;
    }

    BOOL scheduled = [transitionCoordinator
        animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
          (void)context;
          deselectRow();
        }
        completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
          if (![context isCancelled]) {
              return;
          }

          [self selectTagWithUUID:tagUUID];
        }];
    if (!scheduled) {
        deselectRow();
    }
}

- (void)selectTagWithUUID:(NSString *)tagUUID {
    if ([tagUUID length] == 0) {
        return;
    }

    NSUInteger row = [self indexOfTagWithUUID:tagUUID inTags:[self displayedTags]];
    if (row == NSNotFound || (NSInteger)row >= [[self tableView] numberOfRowsInSection:0]) {
        return;
    }

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    [[self tableView] selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (void)updateTag:(KayokoTag *)updatedTag {
    NSUInteger index = [self indexOfTagWithUUID:[updatedTag uuid] inTags:[self tags]];
    if (index == NSNotFound) {
        return;
    }

    NSArray<KayokoTag *> *displayedTagsBeforeUpdate = [[self displayedTags] copy];
    NSUInteger visibleIndexBeforeUpdate = [self indexOfTagWithUUID:[updatedTag uuid] inTags:displayedTagsBeforeUpdate];

    NSMutableArray<KayokoTag *> *updatedTags = [[self tags] mutableCopy];
    updatedTags[index] = updatedTag;
    if (![self saveTags:updatedTags]) {
        return;
    }

    [self setTags:updatedTags];
    [self refreshFilteredTags];
    [self updatePlaceholderVisibility];

    if (visibleIndexBeforeUpdate == NSNotFound) {
        return;
    }

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:visibleIndexBeforeUpdate inSection:0];
    NSUInteger visibleIndexAfterUpdate = [self indexOfTagWithUUID:[updatedTag uuid] inTags:[self displayedTags]];
    if (visibleIndexAfterUpdate == NSNotFound) {
        [[self tableView] deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        NSIndexPath *updatedIndexPath = [NSIndexPath indexPathForRow:visibleIndexAfterUpdate inSection:0];
        KayokoTagTableViewCell *cell =
            (KayokoTagTableViewCell *)[[self tableView] cellForRowAtIndexPath:updatedIndexPath];
        if ([cell isKindOfClass:[KayokoTagTableViewCell class]]) {
            [cell configureWithTag:updatedTag editing:[self isEditing]];
        }
    }
}

#pragma mark - Helpers

- (NSArray<KayokoTag *> *)displayedTags {
    return [self isFiltering] ? [self filteredTags] : [self tags];
}

- (BOOL)isFiltering {
    return [[self normalizedSearchText] length] > 0;
}

- (BOOL)isSearching {
    return [self isSearchInterfaceActive] || [self isFiltering];
}

- (void)refreshFilteredTags {
    [[self filteredTags] removeAllObjects];
    NSString *searchText = [self normalizedSearchText];
    if ([searchText length] == 0) {
        return;
    }

    for (KayokoTag *tag in [self tags]) {
        if ([[tag title] rangeOfString:searchText options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch]
                .location != NSNotFound) {
            [[self filteredTags] addObject:tag];
        }
    }
}

- (BOOL)allDisplayedTagsSelected {
    NSArray<KayokoTag *> *displayedTags = [self displayedTags];
    if ([displayedTags count] == 0) {
        return NO;
    }

    for (KayokoTag *tag in displayedTags) {
        if (![[self selectedTagUUIDs] containsObject:[tag uuid]]) {
            return NO;
        }
    }
    return YES;
}

- (NSSet<NSString *> *)selectedDisplayedTagUUIDs {
    NSMutableSet<NSString *> *selectedUUIDs = [[NSMutableSet alloc] init];
    for (KayokoTag *tag in [self displayedTags]) {
        if ([[self selectedTagUUIDs] containsObject:[tag uuid]]) {
            [selectedUUIDs addObject:[tag uuid]];
        }
    }
    return [selectedUUIDs copy];
}

- (NSString *)normalizedSearchText {
    NSString *searchText = [[[[self searchController] searchBar] text]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return searchText ?: @"";
}

- (void)reloadTableForSearchStateChangeFromSearching:(BOOL)wasSearching {
    if (![self isEditing] || wasSearching == [self isSearching]) {
        return;
    }

    [[self tableView] reloadData];
    [self syncDisplayedSelectionState];
}

- (void)syncDisplayedSelectionState {
    if (![self isEditing]) {
        return;
    }

    NSArray<KayokoTag *> *displayedTags = [self displayedTags];
    NSSet<NSIndexPath *> *selectedIndexPaths = [NSSet setWithArray:[[self tableView] indexPathsForSelectedRows] ?: @[]];
    for (NSUInteger index = 0; index < [displayedTags count]; index++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(NSInteger)index inSection:0];
        BOOL shouldSelect = [[self selectedTagUUIDs] containsObject:[displayedTags[index] uuid]];
        BOOL isSelected = [selectedIndexPaths containsObject:indexPath];
        if (shouldSelect == isSelected) {
            continue;
        }

        if (shouldSelect) {
            [[self tableView] selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        } else {
            [[self tableView] deselectRowAtIndexPath:indexPath animated:NO];
        }
    }
}

- (void)updatePlaceholderVisibility {
    BOOL showsNoSearchResultsPlaceholder =
        [self isFiltering] && [[self tags] count] > 0 && [[self filteredTags] count] == 0;
    BOOL shouldShowPlaceholder = [[self tags] count] == 0 || showsNoSearchResultsPlaceholder;
    UIView *footerView = [[self tableView] tableFooterView];
    BOOL isShowingPlaceholder = footerView == [self placeholderView];
    if (!shouldShowPlaceholder) {
        if (isShowingPlaceholder) {
            [[self tableView] setTableFooterView:nil];
        }
        return;
    }

    if (!isShowingPlaceholder) {
        [[self tableView] setTableFooterView:[self placeholderView]];
    }
    NSString *messageKey = showsNoSearchResultsPlaceholder ? @"No Search Results" : @"No Tags";
    [[self placeholderView] setMessage:[self localizedStringForKey:messageKey]];
    [self updatePlaceholderLayout];
}

- (void)updatePlaceholderLayout {
    if ([self isUpdatingPlaceholderLayout] || [[self tableView] tableFooterView] != [self placeholderView]) {
        return;
    }

    CGRect targetFrame = CGRectMake(0.0, 0.0, CGRectGetWidth([[self tableView] bounds]), [self placeholderHeight]);
    if (CGRectEqualToRect([[self placeholderView] frame], targetFrame)) {
        return;
    }

    [self setUpdatingPlaceholderLayout:YES];
    [[self placeholderView] setFrame:targetFrame];
    [[self tableView] setTableFooterView:[self placeholderView]];
    [self setUpdatingPlaceholderLayout:NO];
}

- (CGFloat)placeholderHeight {
    CGFloat availableHeight = CGRectGetHeight([[self tableView] bounds]) - [self automaticTopInset] -
                              [self automaticBottomInset] - [self keyboardBottomInset] - [self placeholderTopOffset];
    return floor(MAX(availableHeight, kKayokoTagPlaceholderMinimumHeight));
}

- (CGFloat)placeholderTopOffset {
    UIView *footerView = [[self tableView] tableFooterView];
    if (footerView != [self placeholderView]) {
        return 0.0;
    }

    return MAX([[self tableView] contentSize].height - CGRectGetHeight([footerView frame]), 0.0);
}

- (CGFloat)automaticTopInset {
    return MAX([[self tableView] adjustedContentInset].top - [[self tableView] contentInset].top, 0.0);
}

- (CGFloat)automaticBottomInset {
    return MAX([[self tableView] adjustedContentInset].bottom - [[self tableView] contentInset].bottom, 0.0);
}

- (NSUInteger)indexOfTagWithUUID:(NSString *)uuid inTags:(NSArray<KayokoTag *> *)tags {
    if ([uuid length] == 0) {
        return NSNotFound;
    }

    for (NSUInteger index = 0; index < [tags count]; index++) {
        if ([[tags[index] uuid] isEqualToString:uuid]) {
            return index;
        }
    }
    return NSNotFound;
}

- (BOOL)saveTags:(NSArray<KayokoTag *> *)tags {
    NSError *error = nil;
    BOOL saved = [[self tagStore] saveTags:tags error:&error];
    if (!saved) {
        [self presentError:error];
    }
    return saved;
}

- (void)presentError:(NSError *)error {
    NSString *message = [error localizedDescription] ?: [self localizedStringForKey:@"Unable to Save Tags"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self localizedStringForKey:@"Tags"]
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:[self localizedStringForKey:@"OK"]
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil];
    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)localizedStringForKey:(NSString *)key {
    return [[self localizationBundle] localizedStringForKey:key value:key table:@"Tags"] ?: key;
}

@end
