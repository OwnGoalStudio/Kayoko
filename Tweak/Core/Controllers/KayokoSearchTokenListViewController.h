//
//  KayokoSearchTokenListViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoSearchCriteria;
@class KayokoSearchToken;
@class KayokoSearchTokenListViewController;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoSearchTokenListViewControllerDelegate <NSObject>

- (void)searchTokenListViewController:(KayokoSearchTokenListViewController *)controller
                       didSelectToken:(KayokoSearchToken *)token;

@end

@interface KayokoSearchTokenListViewController : UIViewController

@property(nonatomic, weak, nullable) id<KayokoSearchTokenListViewControllerDelegate> delegate;
@property(nonatomic, copy, nullable) void (^contentHeightDidChange)(void);

- (void)updateWithSearchCriteria:(KayokoSearchCriteria *)searchCriteria
                       tagTokens:(NSArray<KayokoSearchToken *> *)tagTokens
                       appTokens:(NSArray<KayokoSearchToken *> *)appTokens;
- (void)resetSearchSessionState;
- (CGFloat)preferredContentHeightForWidth:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
