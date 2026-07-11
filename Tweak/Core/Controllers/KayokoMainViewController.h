//
//  KayokoMainViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

#import "KayokoPanelPresentationMode.h"
#import "KayokoPreferenceKeys.h"

NS_ASSUME_NONNULL_BEGIN

@class KayokoMainViewController;

@protocol KayokoMainViewControllerDelegate <NSObject>

- (void)mainViewControllerDidRequestFocusRestore:(KayokoMainViewController *)viewController;
- (void)mainViewControllerDidHide:(KayokoMainViewController *)viewController;

@end

@interface KayokoMainViewController : UIViewController

@property(nonatomic, weak, nullable) id<KayokoMainViewControllerDelegate> delegate;
@property(nonatomic, assign) BOOL automaticallyPaste;
@property(nonatomic, assign) BOOL dismissOnOutsideTouch;
@property(nonatomic, assign) BOOL swipeToSelectWords;
@property(nonatomic, assign) KayokoInitialViewMode initialViewMode;
@property(nonatomic, assign) NSUInteger previewLineCount;
@property(nonatomic, assign) KayokoItemDetailsMode itemDetailsMode;
@property(nonatomic, assign) BOOL shouldPlayFeedback;
@property(nonatomic, assign, getter=isAuthorizationPassed) BOOL authorizationPassed;
@property(nonatomic, assign) KayokoPanelPresentationMode presentationMode;
@property(nonatomic, assign) UIInterfaceOrientationMask kayokoSupportedInterfaceOrientations;

- (instancetype)initWithFrame:(CGRect)frame;

- (BOOL)isHidden;
- (void)setOutsideDismissOverlayView:(nullable UIControl *)outsideDismissOverlayView;
- (void)applyUserInterfaceStyle:(UIUserInterfaceStyle)style;

- (void)handleHistoryChanged;
- (void)handleApplicationMetadataChanged;
- (void)preloadHistoryIfNeeded;
- (BOOL)isFullscreenSearchActive;
- (BOOL)shouldSuppressSystemMultitaskingGesture;
- (void)show;
- (void)hide;
- (void)hideRestoringFocus;
- (void)hideWithStandardDismissAnimation;
- (void)hideWithCompletion:(nullable void (^)(void))completion;
- (void)hideWithAnimationStyle:(KayokoPanelHideAnimationStyle)animationStyle
                    completion:(nullable void (^)(void))completion;
- (void)hideForExternalRequestWithAnimationStyle:(KayokoPanelHideAnimationStyle)animationStyle
                                      completion:(nullable void (^)(void))completion;
- (void)hideImmediately;
- (void)reload;

@end

NS_ASSUME_NONNULL_END
