//
//  KayokoHelper.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

OBJC_EXTERN BOOL KayokoHelperEnabled(void);
OBJC_EXTERN NSUInteger KayokoHelperActivationMethod(void);
OBJC_EXTERN BOOL KayokoHelperAutomaticallyPasteEnabled(void);
OBJC_EXTERN BOOL KayokoHelperIsKeyboardExtensionProcess(void);
OBJC_EXTERN void KayokoHelperLoadPreferences(void);
OBJC_EXTERN void KayokoHelperInstallRuntimeHooks(void);
OBJC_EXTERN void KayokoHelperInstallRuntimeObservers(void);
OBJC_EXTERN void KayokoHelperPostCoreShow(void);
OBJC_EXTERN void KayokoHelperCaptureCurrentFirstResponder(void);
OBJC_EXTERN void KayokoHelperRestoreCapturedFirstResponder(void);
OBJC_EXTERN void KayokoHelperPaste(void);
OBJC_EXTERN void KayokoHelperOpenKayokoFromResponder(id self, SEL _cmd);

OBJC_EXTERN void EnableKayokoPredictionBar(void);
OBJC_EXTERN void EnableKayokoCalloutBar(void);
OBJC_EXTERN void EnableKayokoActivationGlobe(void);
OBJC_EXTERN void EnableKayokoActivationDictation(void);
OBJC_EXTERN void EnableKayokoActivationSwipeUp(void);
OBJC_EXTERN void EnableKayokoActivationSwipeUpForKeyboardExtension(void);

NS_ASSUME_NONNULL_END
