//
//  KayokoCore.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class KayokoView;

static CGFloat const kHeight = 420;

OBJC_EXTERN KayokoView* kayokoView;

OBJC_EXTERN NSUserDefaults* kayokoPreferences;
OBJC_EXTERN BOOL kayokoPrefsEnabled;

OBJC_EXTERN NSUInteger kayokoPrefsMaximumHistoryAmount;
OBJC_EXTERN BOOL kayokoPrefsSaveText;
OBJC_EXTERN BOOL kayokoPrefsSaveImages;
OBJC_EXTERN BOOL kayokoPrefsAutomaticallyPaste;

OBJC_EXTERN void EnableKayokoActivationGlobe(void);

@interface UIStatusBarWindow  : UIWindow
@end
