//
//  KayokoMenu.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSString *KayokoAppleMenuIdentifier(void);
FOUNDATION_EXTERN NSString *KayokoMenuName(void);
FOUNDATION_EXTERN NSString *KayokoMenuActionSelectorName(void);
FOUNDATION_EXTERN SEL KayokoMenuActionSelector(void);
FOUNDATION_EXTERN const char *KayokoMenuActionTypeEncoding(void);
FOUNDATION_EXTERN UIMenuItem *KayokoMenuItem(void);
FOUNDATION_EXTERN UICommand *KayokoMenuItemUICommand(void);
FOUNDATION_EXTERN BOOL KayokoMenuItemIsWritingTool(id input);

NS_ASSUME_NONNULL_END
