//
//  KayokoNoteEditorView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoTableViewCell;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoNoteEditorView : UIView

@property(nonatomic, strong, readonly) UIView *inputRowView;
@property(nonatomic, strong, readonly) UITextField *textField;
@property(nonatomic, strong, readonly) UIButton *saveButton;
@property(nonatomic, strong, readonly, nullable) KayokoTableViewCell *previewCell;
@property(nonatomic, assign) CGFloat previewCellHeight;
@property(nonatomic, assign) CGFloat keyboardBottomInset;
@property(nonatomic, assign) BOOL automaticallyPositionsPreviewCell;
@property(nonatomic, assign) BOOL anchorsEditingContentToTop;
@property(nonatomic, assign, readonly) CGFloat editingContentHeight;

- (void)setPreviewCell:(nullable KayokoTableViewCell *)previewCell;
- (CGRect)targetPreviewCellFrame;

@end

NS_ASSUME_NONNULL_END
