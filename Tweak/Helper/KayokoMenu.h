//
//  KayokoMenu.h
//  Kayoko
//
//  Created by Lessica
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSString *KayokoAppleMenuIdentifier(void);

FOUNDATION_EXTERN UIMenuItem *KayokoMenuItem(void);
FOUNDATION_EXTERN UICommand *KayokoMenuItemUICommand(void);

FOUNDATION_EXTERN BOOL KayokoMenuItemIsWritingTool(id input);

NS_ASSUME_NONNULL_END
