//
//  KayokoNoteEditorViewController.m
//  Kayoko
//

#import "KayokoNoteEditorViewController.h"

#import "KayokoApplicationMetadataProvider.h"
#import "KayokoNoteEditorView.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import "KayokoTableViewCell.h"

@interface UIPeripheralHost : NSObject
+ (instancetype)sharedInstance;
+ (NSArray<NSValue *> *)allVisiblePeripheralFrames;
- (BOOL)isOnScreen;
@end

static CGFloat const kKayokoKeyboardFrameEdgeTolerance = 1.0;

static CGFloat kayokoBottomInsetForDockedKeyboardFrame(CGRect keyboardFrame, UIWindow *window) {
    if (CGRectIsNull(keyboardFrame) || CGRectIsEmpty(keyboardFrame) || !window) {
        return 0;
    }

    CGRect windowBounds = [window bounds];
    CGFloat windowBottom = CGRectGetMaxY(windowBounds);
    if (CGRectGetMinY(keyboardFrame) >= windowBottom - kKayokoKeyboardFrameEdgeTolerance ||
        fabs(CGRectGetMaxY(keyboardFrame) - windowBottom) > kKayokoKeyboardFrameEdgeTolerance) {
        return 0;
    }
    return windowBottom - CGRectGetMinY(keyboardFrame);
}

NS_ASSUME_NONNULL_BEGIN

@interface KayokoNoteEditorViewController () <UITextFieldDelegate>

@property(nonatomic, strong, readwrite) KayokoNoteEditorView *noteEditorView;
@property(nonatomic, strong, readwrite, nullable) KayokoPasteboardItem *item;
@property(nonatomic, strong) KayokoApplicationMetadataProvider *metadataProvider;
@property(nonatomic, copy) NSString *sourceDisplayName;
@property(nonatomic, assign, getter=isSaving) BOOL saving;
@property(nonatomic, assign) CGFloat lastValidKeyboardBottomInset;
@property(nonatomic, assign) BOOL preservingKeyboardInsetDuringActivation;

@end

@implementation KayokoNoteEditorViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _metadataProvider = [[KayokoApplicationMetadataProvider alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardWillChangeFrameNotification:)
                                                     name:UIKeyboardWillChangeFrameNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardWillHideNotification:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    KayokoNoteEditorView *noteEditorView = [[KayokoNoteEditorView alloc] initWithFrame:CGRectZero];
    [self setNoteEditorView:noteEditorView];
    [self setView:noteEditorView];

    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    [[noteEditorView textField] setPlaceholder:[bundle localizedStringForKey:@"Note" value:nil table:@"Tweak"]];
    [[noteEditorView textField] setDelegate:self];
    [[noteEditorView textField] addTarget:self
                                   action:@selector(handleTextFieldEditingChanged:)
                         forControlEvents:UIControlEventEditingChanged];
    [[noteEditorView saveButton] setTitle:[bundle localizedStringForKey:@"Save" value:nil table:@"Tweak"]
                                 forState:UIControlStateNormal];
    [[noteEditorView saveButton] addTarget:self
                                    action:@selector(handleSaveButtonPressed)
                          forControlEvents:UIControlEventTouchUpInside];
}

- (nullable NSString *)normalizedNote {
    NSString *note = [[[self noteEditorView] textField].text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [note length] > 0 ? note : nil;
}

- (void)updatePreview {
    NSString *displayName = [self normalizedNote] ?: [self sourceDisplayName] ?: @"";
    UILabel *headerLabel = [[[self noteEditorView] previewCell] headerLabel];
    [headerLabel setAttributedText:nil];
    [headerLabel setText:displayName];
}

- (void)prepareForItem:(KayokoPasteboardItem *)item
       presentationCell:(KayokoTableViewCell *)presentationCell
             cellHeight:(CGFloat)cellHeight
    keyboardBottomInset:(CGFloat)keyboardBottomInset {
    [self loadViewIfNeeded];
    [self setItem:item];
    [self setSourceDisplayName:[[self metadataProvider] displayNameForBundleIdentifier:[item bundleIdentifier]]];
    [[[self noteEditorView] textField] setText:[item note] ?: @""];
    [[self noteEditorView] setPreviewCellHeight:cellHeight];
    [[self noteEditorView] setPreviewCell:presentationCell];
    [[self noteEditorView] setAnchorsEditingContentToTop:keyboardBottomInset <= 0];
    [[self noteEditorView] setKeyboardBottomInset:keyboardBottomInset];
    [self setSaving:NO];
    [self updatePreview];
}

- (void)refreshLastValidKeyboardBottomInset {
    KayokoNoteEditorView *noteEditorView = [self noteEditorView];
    UIWindow *window = [noteEditorView window] ?: [[noteEditorView superview] window];
    if (!window) {
        return;
    }

    Class hostClass = NSClassFromString(@"UIPeripheralHost");
    if ([hostClass respondsToSelector:@selector(sharedInstance)] &&
        [hostClass respondsToSelector:@selector(allVisiblePeripheralFrames)]) {
        UIPeripheralHost *host = [(id)hostClass sharedInstance];
        if ([host respondsToSelector:@selector(isOnScreen)] && [host isOnScreen]) {
            CGRect keyboardFrame = CGRectNull;
            NSArray<NSValue *> *visibleFrames = [(id)hostClass allVisiblePeripheralFrames];
            for (NSValue *frameValue in visibleFrames) {
                if (![frameValue respondsToSelector:@selector(CGRectValue)]) {
                    continue;
                }
                CGRect frame = [frameValue CGRectValue];
                if (CGRectIsNull(frame) || CGRectIsEmpty(frame)) {
                    continue;
                }
                keyboardFrame = CGRectIsNull(keyboardFrame) ? frame : CGRectUnion(keyboardFrame, frame);
            }
            if (!CGRectIsNull(keyboardFrame) && !CGRectIsEmpty(keyboardFrame)) {
                CGRect keyboardFrameInWindow = [window convertRect:keyboardFrame fromWindow:nil];
                CGFloat keyboardBottomInset = kayokoBottomInsetForDockedKeyboardFrame(keyboardFrameInWindow, window);
                if (keyboardBottomInset > 0) {
                    [self setLastValidKeyboardBottomInset:keyboardBottomInset];
                }
            }
        }
    }
}

- (void)beginEditing {
    KayokoNoteEditorView *noteEditorView = [self noteEditorView];
    [noteEditorView layoutIfNeeded];

    if ([self lastValidKeyboardBottomInset] > 0 && [noteEditorView keyboardBottomInset] > 0) {
        [self setPreservingKeyboardInsetDuringActivation:YES];
    }

    UIWindow *window = [noteEditorView window];
    if (window && ![window isKeyWindow]) {
        [window makeKeyWindow];
    }

    CGFloat keyboardBottomInset = [self lastValidKeyboardBottomInset];
    if (keyboardBottomInset > 0 && fabs([noteEditorView keyboardBottomInset] - keyboardBottomInset) > 0.5) {
        [[self delegate] noteEditorViewController:self
                     didUpdateKeyboardBottomInset:keyboardBottomInset
                                animationDuration:0.25
                                          options:UIViewAnimationOptionCurveEaseInOut |
                                                  UIViewAnimationOptionBeginFromCurrentState |
                                                  UIViewAnimationOptionAllowUserInteraction];
    }

    UITextField *textField = [noteEditorView textField];
    if ([textField becomeFirstResponder]) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (![self item] || [noteEditorView isHidden] || ![noteEditorView window] || [textField isFirstResponder]) {
          return;
      }
      [[noteEditorView window] makeKeyWindow];
      [textField becomeFirstResponder];
    });
}

- (void)resignEditing {
    [self setPreservingKeyboardInsetDuringActivation:NO];
    [[[self noteEditorView] textField] resignFirstResponder];
}

- (void)setSaving:(BOOL)saving {
    _saving = saving;
    [[[self noteEditorView] textField] setEnabled:!saving];
    [[[self noteEditorView] saveButton] setEnabled:!saving];
    [[[self noteEditorView] saveButton] setAlpha:saving ? 0.55 : 1.0];
}

- (void)reset {
    [self resignEditing];
    [self setSaving:NO];
    [self setItem:nil];
    [self setSourceDisplayName:@""];
    [[[self noteEditorView] textField] setText:@""];
    [[self noteEditorView] setKeyboardBottomInset:0];
    [[self noteEditorView] setAnchorsEditingContentToTop:NO];
    [[self noteEditorView] setPreviewCell:nil];
}

- (void)handleTextFieldEditingChanged:(UITextField *)textField {
    (void)textField;
    [self updatePreview];
}

- (void)requestSave {
    if ([self isSaving] || ![self item]) {
        return;
    }
    [self setSaving:YES];
    [[self delegate] noteEditorViewController:self didRequestSaveNote:[self normalizedNote]];
}

- (void)handleSaveButtonPressed {
    [self requestSave];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    (void)textField;
    [self requestSave];
    return NO;
}

- (BOOL)shouldHandleKeyboardNotification:(NSNotification *)notification {
    if (![self item] || [[[self noteEditorView] window] isHidden] || [[self noteEditorView] isHidden]) {
        return NO;
    }
    return [notification.userInfo[UIKeyboardIsLocalUserInfoKey] boolValue];
}

- (void)updateKeyboardBottomInset:(CGFloat)keyboardBottomInset
    withAnimationParametersFromNotification:(NSNotification *)notification {
    KayokoNoteEditorView *view = [self noteEditorView];
    keyboardBottomInset = MAX(keyboardBottomInset, 0);
    if (keyboardBottomInset > 0) {
        [self setPreservingKeyboardInsetDuringActivation:NO];
    }
    if (fabs([view keyboardBottomInset] - keyboardBottomInset) <= 0.5) {
        return;
    }

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve =
        (UIViewAnimationCurve)[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    UIViewAnimationOptions options = (UIViewAnimationOptions)(curve << 16) |
                                     UIViewAnimationOptionBeginFromCurrentState |
                                     UIViewAnimationOptionAllowUserInteraction;
    [[self delegate] noteEditorViewController:self
                 didUpdateKeyboardBottomInset:keyboardBottomInset
                            animationDuration:duration
                                      options:options];
}

- (BOOL)shouldIgnoreKeyboardZeroInsetDuringActivation {
    if (![self preservingKeyboardInsetDuringActivation] || [self lastValidKeyboardBottomInset] <= 0) {
        return NO;
    }

    KayokoNoteEditorView *noteEditorView = [self noteEditorView];
    if ([noteEditorView isHidden] || [noteEditorView keyboardBottomInset] <= 0) {
        return NO;
    }

    UITextField *textField = [noteEditorView textField];
    return [textField isFirstResponder] || [[noteEditorView window] isKeyWindow];
}

- (void)handleKeyboardWillChangeFrameNotification:(NSNotification *)notification {
    if (![notification.userInfo[UIKeyboardIsLocalUserInfoKey] boolValue]) {
        return;
    }

    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIWindow *window = [[self noteEditorView] window] ?: [[[self noteEditorView] superview] window];
    if (!window) {
        return;
    }
    CGRect keyboardFrameInWindow = [window convertRect:keyboardEndFrame fromWindow:nil];
    CGFloat keyboardBottomInset = kayokoBottomInsetForDockedKeyboardFrame(keyboardFrameInWindow, window);
    if (keyboardBottomInset > 0) {
        [self setLastValidKeyboardBottomInset:keyboardBottomInset];
    }
    if (![self shouldHandleKeyboardNotification:notification]) {
        return;
    }
    if (keyboardBottomInset <= 0 && [self shouldIgnoreKeyboardZeroInsetDuringActivation]) {
        return;
    }
    [self updateKeyboardBottomInset:keyboardBottomInset withAnimationParametersFromNotification:notification];
}

- (void)handleKeyboardWillHideNotification:(NSNotification *)notification {
    if (![self item]) {
        return;
    }
    if ([self shouldIgnoreKeyboardZeroInsetDuringActivation]) {
        return;
    }
    [self updateKeyboardBottomInset:0 withAnimationParametersFromNotification:notification];
}

@end

NS_ASSUME_NONNULL_END
