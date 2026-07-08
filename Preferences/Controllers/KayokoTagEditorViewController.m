//
//  KayokoTagEditorViewController.m
//  Kayoko
//

#import "KayokoTagEditorViewController.h"
#import "KayokoKeyboardAvoidanceCoordinator.h"
#import "KayokoTag.h"
#import "KayokoTagColorFormatter.h"

@interface KayokoTagEditorViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

#pragma mark - Data

@property(nonatomic, strong) KayokoTag *tag;
@property(nonatomic, strong) NSBundle *localizationBundle;

#pragma mark - Views

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UITextField *titleTextField;
@property(nonatomic, strong) UIColorWell *colorWell;

#pragma mark - Keyboard

@property(nonatomic, strong) KayokoKeyboardAvoidanceCoordinator *keyboardAvoidanceCoordinator;

#pragma mark - State

@property(nonatomic, assign) BOOL didFocusTitleTextFieldInitially;
@end

@implementation KayokoTagEditorViewController

#pragma mark - Lifecycle

- (instancetype)initWithTag:(KayokoTag *)tag localizationBundle:(NSBundle *)localizationBundle {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _tag = [tag copy];
        _localizationBundle = localizationBundle ?: [NSBundle mainBundle];
        [self setModalPresentationStyle:UIModalPresentationPageSheet];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [[self view] setBackgroundColor:[UIColor systemGroupedBackgroundColor]];
    [self setTitle:[self localizedStringForKey:@"Edit Tag"]];

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:[self localizedStringForKey:@"Cancel"]
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(cancelEditing)];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:[self localizedStringForKey:@"Done"]
                                                                   style:UIBarButtonItemStyleDone
                                                                  target:self
                                                                  action:@selector(finishEditing)];
    [[self navigationItem] setLeftBarButtonItem:cancelButton];
    [[self navigationItem] setRightBarButtonItem:doneButton];

    [self configureTableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[self keyboardAvoidanceCoordinator] startObserving];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([self didFocusTitleTextFieldInitially]) {
        return;
    }

    [self setDidFocusTitleTextFieldInitially:YES];
    [[self titleTextField] becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[self keyboardAvoidanceCoordinator] stopObservingAndRestoreInsets];
    if ([self isBeingDismissed] || [[self navigationController] isBeingDismissed]) {
        [self notifyDismissalTransitionIfNeeded];
    }
}

#pragma mark - View Setup

- (void)configureTableView {
    _titleTextField = [[UITextField alloc] init];
    [_titleTextField setText:[[self tag] title]];
    [_titleTextField setBorderStyle:UITextBorderStyleNone];
    [_titleTextField setClearButtonMode:UITextFieldViewModeNever];
    [_titleTextField setReturnKeyType:UIReturnKeyDone];
    [_titleTextField setDelegate:self];
    [_titleTextField setTextAlignment:NSTextAlignmentRight];
    [_titleTextField setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];

    _colorWell = [[UIColorWell alloc] init];
    [_colorWell setSupportsAlpha:YES];
    [_colorWell setSelectedColor:[KayokoTagColorFormatter colorFromHexColor:[[self tag] hexColor]]];
    [_colorWell setFrame:CGRectMake(0.0, 0.0, 44.0, 44.0)];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    [_tableView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setKeyboardDismissMode:UIScrollViewKeyboardDismissModeInteractive];
    [[self view] addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [[_tableView topAnchor] constraintEqualToAnchor:[[self view] topAnchor]],
        [[_tableView leadingAnchor] constraintEqualToAnchor:[[self view] leadingAnchor]],
        [[_tableView trailingAnchor] constraintEqualToAnchor:[[self view] trailingAnchor]],
        [[_tableView bottomAnchor] constraintEqualToAnchor:[[self view] bottomAnchor]]
    ]];

    _keyboardAvoidanceCoordinator = [[KayokoKeyboardAvoidanceCoordinator alloc] initWithView:[self view]
                                                                                  scrollView:_tableView];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const reuseIdentifier = @"KayokoTagEditorCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    }

    [[cell textLabel] setTextColor:[UIColor labelColor]];
    [[cell detailTextLabel] setText:nil];
    [cell setAccessoryView:nil];

    if ([indexPath row] == 0) {
        [[cell textLabel] setText:[self localizedStringForKey:@"Title"]];
        CGRect frame = CGRectMake(0.0, 0.0, 190.0, 36.0);
        [[self titleTextField] setFrame:frame];
        [cell setAccessoryView:[self titleTextField]];
    } else {
        [[cell textLabel] setText:[self localizedStringForKey:@"Color"]];
        [cell setAccessoryView:[self colorWell]];
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if ([indexPath row] == 0) {
        [[self titleTextField] becomeFirstResponder];
    }
}

#pragma mark - Actions

- (void)cancelEditing {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)finishEditing {
    NSString *title = [[[self titleTextField] text]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([title length] == 0) {
        title = [self localizedStringForKey:@"Untitled"];
    }

    KayokoTag *updatedTag =
        [[KayokoTag alloc] initWithUUID:[[self tag] uuid]
                                  title:title
                               hexColor:[KayokoTagColorFormatter hexColorFromColor:[[self colorWell] selectedColor]]];
    void (^completionHandler)(KayokoTag *) = [self completionHandler];
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               if (completionHandler) {
                                   completionHandler(updatedTag);
                               }
                             }];
}

#pragma mark - Helpers

- (NSString *)localizedStringForKey:(NSString *)key {
    return [[self localizationBundle] localizedStringForKey:key value:key table:@"Tags"] ?: key;
}

- (void)notifyDismissalTransitionIfNeeded {
    if (![self dismissalTransitionHandler]) {
        return;
    }

    id<UIViewControllerTransitionCoordinator> transitionCoordinator = [self transitionCoordinator];
    if (!transitionCoordinator) {
        transitionCoordinator = [[self navigationController] transitionCoordinator];
    }
    [self dismissalTransitionHandler](transitionCoordinator);
}

@end
