//
//  KayokoView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class KayokoTableView;
@class KayokoHistoryTableView;
@class KayokoFavoritesTableView;
@class KayokoClearConfirmationView;
@class KayokoEmptyStateView;
@class KayokoPreviewView;
@class PasteboardItem;

static NSUInteger const kFavoritesButtonImageSize = 24;
static NSUInteger const kClearButtonImageSize = 22;
static NSUInteger const kBackButtonImageSize = 22;
static CGFloat const kLeadingHeaderButtonCenterXInset = 36;
static CGFloat const kTrailingHeaderButtonCenterXInset = 34;
static CGFloat const kTitleLabelLeadingInset = 64;

@interface _UIGrabber : UIControl
@end

@interface KayokoView : UIView {
    KayokoTableView *_previewSourceTableView;
    PasteboardItem *_previewItem;
    NSString *_activeHistoryKey;
    NSString *_clearConfirmationHistoryKey;
    BOOL _isAnimating;
}
@property(nonatomic, strong) UIBlurEffect *blurEffect;
@property(nonatomic, strong) UIVisualEffectView *blurEffectView;
@property(nonatomic, strong) UIView *headerView;
@property(nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;
@property(nonatomic, strong) _UIGrabber *grabber;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIButton *clearButton;
@property(nonatomic, strong) UIButton *backButton;
@property(nonatomic, strong) UIButton *favoritesButton;
@property(nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property(nonatomic, strong) KayokoHistoryTableView *historyTableView;
@property(nonatomic, strong) KayokoFavoritesTableView *favoritesTableView;
@property(nonatomic, strong) KayokoClearConfirmationView *clearConfirmationView;
@property(nonatomic, strong) KayokoEmptyStateView *emptyStateView;
@property(nonatomic, strong) KayokoPreviewView *previewView;
@property(nonatomic, strong) UIImpactFeedbackGenerator *feedbackGenerator;
@property(nonatomic, strong) UIControl *outsideDismissOverlayView;
@property(nonatomic, assign) BOOL automaticallyPaste;
@property(nonatomic, assign) BOOL dismissOnOutsideTouch;
@property(nonatomic, assign) BOOL swipeToSelectWords;
@property(nonatomic, assign) NSUInteger previewLineCount;
@property(nonatomic, assign) BOOL shouldPlayFeedback;
- (void)showPreviewWithItem:(PasteboardItem *)item;
- (void)show;
- (void)hide;
- (void)reload;
@end
