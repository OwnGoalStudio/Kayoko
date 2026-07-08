//
//  KayokoPreviewViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoPreviewView;
@class KayokoPasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPreviewViewController : UIViewController

@property(nonatomic, strong, readonly) KayokoPreviewView *previewView;
@property(nonatomic, copy, nullable, readonly) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readonly) KayokoPasteboardItem *previewItem;
@property(nonatomic, copy, nullable) void (^tagAssignmentHandler)(KayokoPasteboardItem *item, NSString *historyKey);

- (instancetype)initWithFavoritesButton:(UIButton *)favoritesButton
                             backButton:(UIButton *)backButton
                            clearButton:(UIButton *)clearButton;

- (void)showPreviewWithItem:(KayokoPasteboardItem *)item sourceHistoryKey:(NSString *)sourceHistoryKey;
- (void)handleActionButtonWithCompletion:(nullable void (^)(BOOL success))completion;
- (void)prepareToHidePreview;
- (void)hidePreview;
- (void)resetPreviewState;
- (void)scrollToTopAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
