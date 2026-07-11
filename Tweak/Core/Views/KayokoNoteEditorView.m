//
//  KayokoNoteEditorView.m
//  Kayoko
//

#import "KayokoNoteEditorView.h"

#import "KayokoTableViewCell.h"

static CGFloat const kKayokoNoteEditorDefaultCellHeight = 65;
static CGFloat const kKayokoNoteEditorInputHeight = 44;
static CGFloat const kKayokoNoteEditorHorizontalInset = 24;
static CGFloat const kKayokoNoteEditorPreviewTopSpacing = 10;
static CGFloat const kKayokoNoteEditorInputTopSpacing = 12;
static CGFloat const kKayokoNoteEditorInputBottomSpacing = 16;
static CGFloat const kKayokoNoteEditorTextLeadingInset = 14;
static CGFloat const kKayokoNoteEditorTextTrailingInset = 6;
static CGFloat const kKayokoNoteEditorMinimumButtonWidth = 68;
static CGFloat const kKayokoNoteEditorSeparatorVerticalInset = 9;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoNoteEditorView ()

@property(nonatomic, strong, readwrite) UIView *inputRowView;
@property(nonatomic, strong, readwrite) UITextField *textField;
@property(nonatomic, strong, readwrite) UIButton *saveButton;
@property(nonatomic, strong, readwrite, nullable) KayokoTableViewCell *previewCell;
@property(nonatomic, strong) UIView *keyboardSpacerView;
@property(nonatomic, strong) UIView *inputSeparatorView;

@end

@implementation KayokoNoteEditorView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _previewCellHeight = kKayokoNoteEditorDefaultCellHeight;
        _automaticallyPositionsPreviewCell = YES;
        [self setBackgroundColor:[UIColor clearColor]];
        [self setClipsToBounds:YES];

        _keyboardSpacerView = [[UIView alloc] init];
        [_keyboardSpacerView setBackgroundColor:[UIColor clearColor]];
        [_keyboardSpacerView setUserInteractionEnabled:NO];
        [self addSubview:_keyboardSpacerView];

        _inputRowView = [[UIView alloc] init];
        [_inputRowView setBackgroundColor:[UIColor tertiarySystemFillColor]];
        [[_inputRowView layer] setCornerRadius:8];
        [[_inputRowView layer] setCornerCurve:kCACornerCurveContinuous];
        [_inputRowView setClipsToBounds:YES];
        [self addSubview:_inputRowView];

        _textField = [[UITextField alloc] init];
        [_textField setBorderStyle:UITextBorderStyleNone];
        [_textField setBackgroundColor:[UIColor clearColor]];
        [_textField setClearButtonMode:UITextFieldViewModeWhileEditing];
        [_textField setFont:[UIFont systemFontOfSize:16]];
        [_textField setTextColor:[UIColor labelColor]];
        [_textField setReturnKeyType:UIReturnKeyDone];
        UIView *textLeadingInsetView =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, kKayokoNoteEditorTextLeadingInset, 1)];
        [_textField setLeftView:textLeadingInsetView];
        [_textField setLeftViewMode:UITextFieldViewModeAlways];
        [_inputRowView addSubview:_textField];

        _inputSeparatorView = [[UIView alloc] init];
        [_inputSeparatorView setBackgroundColor:[UIColor separatorColor]];
        [_inputSeparatorView setUserInteractionEnabled:NO];
        [_inputRowView addSubview:_inputSeparatorView];

        _saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_saveButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        [_saveButton setBackgroundColor:[UIColor clearColor]];
        [[_saveButton titleLabel] setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold]];
        [_inputRowView addSubview:_saveButton];
    }
    return self;
}

- (void)setPreviewCell:(nullable KayokoTableViewCell *)previewCell {
    if (_previewCell == previewCell) {
        return;
    }

    [_previewCell removeFromSuperview];
    _previewCell = previewCell;
    if (_previewCell) {
        [_previewCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [_previewCell setUserInteractionEnabled:NO];
        [self insertSubview:_previewCell belowSubview:[self inputRowView]];
    }
    [self setNeedsLayout];
}

- (void)setPreviewCellHeight:(CGFloat)previewCellHeight {
    _previewCellHeight = MAX(previewCellHeight, 1);
    [self setNeedsLayout];
}

- (void)setKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    _keyboardBottomInset = MAX(keyboardBottomInset, 0);
    [self setNeedsLayout];
}

- (void)setAnchorsEditingContentToTop:(BOOL)anchorsEditingContentToTop {
    if (_anchorsEditingContentToTop == anchorsEditingContentToTop) {
        return;
    }

    _anchorsEditingContentToTop = anchorsEditingContentToTop;
    [self setNeedsLayout];
}

- (CGFloat)editingContentHeight {
    return kKayokoNoteEditorPreviewTopSpacing + [self previewCellHeight] + kKayokoNoteEditorInputTopSpacing +
           kKayokoNoteEditorInputHeight + kKayokoNoteEditorInputBottomSpacing;
}

- (CGRect)targetPreviewCellFrame {
    CGRect bounds = [self bounds];
    UIEdgeInsets safeAreaInsets = [self safeAreaInsets];
    CGFloat minimumContentOriginY = MAX(safeAreaInsets.top, 0);
    CGFloat contentOriginY =
        [self anchorsEditingContentToTop]
            ? minimumContentOriginY
            : MAX(CGRectGetHeight(bounds) - [self keyboardBottomInset] - [self editingContentHeight],
                  minimumContentOriginY);
    CGFloat y = contentOriginY + kKayokoNoteEditorPreviewTopSpacing;
    CGFloat width = MAX(CGRectGetWidth(bounds) - safeAreaInsets.left - safeAreaInsets.right, 0);
    return CGRectMake(safeAreaInsets.left, y, width, [self previewCellHeight]);
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect bounds = [self bounds];
    CGRect previewFrame = [self targetPreviewCellFrame];
    if ([self automaticallyPositionsPreviewCell]) {
        [[self previewCell] setFrame:previewFrame];
    }

    UIEdgeInsets safeAreaInsets = [self safeAreaInsets];
    CGFloat leadingInset = safeAreaInsets.left + kKayokoNoteEditorHorizontalInset;
    CGFloat trailingInset = safeAreaInsets.right + kKayokoNoteEditorHorizontalInset;
    CGFloat availableWidth = MAX(CGRectGetWidth(bounds) - leadingInset - trailingInset, 0);
    CGSize buttonSize = [[self saveButton] sizeThatFits:CGSizeMake(CGFLOAT_MAX, kKayokoNoteEditorInputHeight)];
    CGFloat buttonWidth = MAX(ceil(buttonSize.width) + 28, kKayokoNoteEditorMinimumButtonWidth);
    buttonWidth = MIN(buttonWidth, availableWidth);
    CGFloat textFieldWidth = MAX(availableWidth - buttonWidth, 0);

    CGFloat inputY = CGRectGetMaxY(previewFrame) + kKayokoNoteEditorInputTopSpacing;
    [[self inputRowView] setFrame:CGRectMake(leadingInset, inputY, availableWidth, kKayokoNoteEditorInputHeight)];
    [[self textField] setFrame:CGRectMake(0, 0, MAX(textFieldWidth - kKayokoNoteEditorTextTrailingInset, 0),
                                          kKayokoNoteEditorInputHeight)];
    CGFloat separatorWidth = 1.0 / [UIScreen mainScreen].scale;
    [[self inputSeparatorView]
        setFrame:CGRectMake(textFieldWidth, kKayokoNoteEditorSeparatorVerticalInset, separatorWidth,
                            kKayokoNoteEditorInputHeight - kKayokoNoteEditorSeparatorVerticalInset * 2)];
    [[self saveButton] setFrame:CGRectMake(textFieldWidth + separatorWidth, 0, MAX(buttonWidth - separatorWidth, 0),
                                           kKayokoNoteEditorInputHeight)];

    CGFloat spacerHeight = MIN([self keyboardBottomInset], CGRectGetHeight(bounds));
    [[self keyboardSpacerView]
        setFrame:CGRectMake(0, CGRectGetHeight(bounds) - spacerHeight, CGRectGetWidth(bounds), spacerHeight)];
}

@end

NS_ASSUME_NONNULL_END
