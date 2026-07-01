//
//  KayokoPreviewViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoPreviewView;
@class PasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPreviewViewController : UIViewController

@property(nonatomic, strong, readonly) KayokoPreviewView *previewView;
@property(nonatomic, copy, nullable, readonly) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readonly) PasteboardItem *previewItem;

- (instancetype)initWithFavoritesButton:(UIButton *)favoritesButton
                             backButton:(UIButton *)backButton
                            clearButton:(UIButton *)clearButton;

- (void)showPreviewWithItem:(PasteboardItem *)item sourceHistoryKey:(NSString *)sourceHistoryKey;
- (void)prepareToHidePreview;
- (void)hidePreview;
- (void)resetPreviewState;
- (void)scrollToTopAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
