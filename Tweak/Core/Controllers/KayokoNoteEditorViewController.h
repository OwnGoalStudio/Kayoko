//
//  KayokoNoteEditorViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoNoteEditorView;
@class KayokoNoteEditorViewController;
@class KayokoPasteboardItem;
@class KayokoTableViewCell;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoNoteEditorViewControllerDelegate <NSObject>

- (void)noteEditorViewController:(KayokoNoteEditorViewController *)controller
              didRequestSaveNote:(nullable NSString *)note;
- (void)noteEditorViewController:(KayokoNoteEditorViewController *)controller
    didUpdateKeyboardBottomInset:(CGFloat)keyboardBottomInset
               animationDuration:(NSTimeInterval)animationDuration
                         options:(UIViewAnimationOptions)options;

@end

@interface KayokoNoteEditorViewController : UIViewController

@property(nonatomic, weak, nullable) id<KayokoNoteEditorViewControllerDelegate> delegate;
@property(nonatomic, strong, readonly) KayokoNoteEditorView *noteEditorView;
@property(nonatomic, strong, readonly, nullable) KayokoPasteboardItem *item;

- (void)prepareForItem:(KayokoPasteboardItem *)item
       presentationCell:(KayokoTableViewCell *)presentationCell
             cellHeight:(CGFloat)cellHeight
    keyboardBottomInset:(CGFloat)keyboardBottomInset;
- (void)refreshLastValidKeyboardBottomInset;
- (CGFloat)lastValidKeyboardBottomInset;
- (void)beginEditing;
- (void)resignEditing;
- (void)setSaving:(BOOL)saving;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
