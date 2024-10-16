//
//  KayokoCore.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class KayokoView;

OBJC_EXTERN KayokoView *kayokoView;

OBJC_EXTERN NSUserDefaults *kayokoPreferences;
OBJC_EXTERN BOOL kayokoPrefsEnabled;
OBJC_EXTERN NSUInteger kayokoHelperPrefsActivationMethod;

OBJC_EXTERN NSUInteger kayokoPrefsMaximumHistoryAmount;
OBJC_EXTERN BOOL kayokoPrefsSaveText;
OBJC_EXTERN BOOL kayokoPrefsSaveImages;
OBJC_EXTERN BOOL kayokoPrefsAutomaticallyPaste;
OBJC_EXTERN BOOL kayokoPrefsDisablePasteTips;
OBJC_EXTERN BOOL kayokoPrefsPlaySoundEffects;
OBJC_EXTERN BOOL kayokoPrefsPlayHapticFeedback;
OBJC_EXTERN CGFloat kayokoPrefsHeightInPoints;

OBJC_EXTERN void EnableKayokoDisablePasteTips(void);

@interface UIStatusBarWindow : UIWindow
@end
