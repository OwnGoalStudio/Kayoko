#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

OBJC_EXTERN BOOL KayokoCoreEnabled(void);
OBJC_EXTERN NSUInteger KayokoCoreActivationMethod(void);
OBJC_EXTERN BOOL KayokoCorePanelVisible(void);
OBJC_EXTERN BOOL KayokoCoreFullscreenSearchActive(void);

OBJC_EXTERN void KayokoCoreLoadPreferences(void);
OBJC_EXTERN void KayokoCoreLoadHeightPreference(void);
OBJC_EXTERN void KayokoCoreInstallPanelInStatusBarWindow(UIWindow *window);
OBJC_EXTERN void KayokoCorePreloadInitialHistory(void);
OBJC_EXTERN void KayokoCoreStartLockStateObserver(void);

OBJC_EXTERN void KayokoCoreShow(void);
OBJC_EXTERN void KayokoCoreHide(void);
OBJC_EXTERN void KayokoCoreHideImmediately(void);
OBJC_EXTERN void KayokoCoreReload(void);
OBJC_EXTERN void KayokoCoreCopy(void);
OBJC_EXTERN void KayokoCorePaste(void);
OBJC_EXTERN void KayokoCorePasteWillStart(void);

NS_ASSUME_NONNULL_END
