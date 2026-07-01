//
//  KayokoMainViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoMainViewController : UIViewController

@property(nonatomic, assign) BOOL automaticallyPaste;
@property(nonatomic, assign) BOOL dismissOnOutsideTouch;
@property(nonatomic, assign) BOOL swipeToSelectWords;
@property(nonatomic, assign) NSUInteger previewLineCount;
@property(nonatomic, assign) BOOL shouldPlayFeedback;
@property(nonatomic, copy, nullable) void (^focusRestoreRequestHandler)(void);

- (instancetype)initWithFrame:(CGRect)frame;

- (BOOL)isHidden;
- (void)setOutsideDismissOverlayView:(nullable UIControl *)outsideDismissOverlayView;
- (void)applyUserInterfaceStyle:(UIUserInterfaceStyle)style;

- (void)handleHistoryChanged;
- (void)preloadHistoryIfNeeded;
- (BOOL)isFullscreenSearchActive;
- (void)show;
- (void)hide;
- (void)hideRestoringFocus;
- (void)hideWithCompletion:(nullable void (^)(void))completion;
- (void)hideImmediately;
- (void)reload;

@end

NS_ASSUME_NONNULL_END
