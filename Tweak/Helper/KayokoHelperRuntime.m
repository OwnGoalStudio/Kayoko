//
//  KayokoHelperRuntime.m
//  Kayoko
//

#define CHUseSubstrate

#import "KayokoHelper.h"

#import "NotificationKeys.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"
#import "PreferenceKeys.h"

#import <CaptainHook/CaptainHook.h>
#import <CoreFoundation/CFNotificationCenter.h>
#import <Foundation/Foundation.h>
#import <libSandy.h>

CHDeclareClass(UIKeyboardLayoutStar);
CHDeclareClass(UIKBInputBackdropView);
CHDeclareClass(UIKeyboardImpl);

static NSUserDefaults *kayokoHelperPreferences = nil;
static BOOL kayokoHelperPrefsEnabled = NO;
static NSUInteger kayokoHelperPrefsActivationMethod = 0;
static BOOL kayokoHelperPrefsAutomaticallyPaste = NO;

static BOOL kayokoApplicationIsInForeground = YES;
static BOOL kayokoHasCapturedFocusSession = NO;
static __weak UIResponder *kayokoFirstResponderBeforeShowingKayoko = nil;
static __weak UIResponder *kayokoKeyboardInputDelegateBeforeShowingKayoko = nil;
static __weak UIWindow *kayokoKeyWindowBeforeShowingKayoko = nil;

static BOOL kayokoHasPendingPaste = NO;
static BOOL kayokoPendingPasteCanExecute = NO;
static BOOL kayokoPendingPasteRequiresKeyboardDelegate = NO;
static NSUInteger kayokoPendingPasteToken = 0;
static __weak UIResponder *kayokoPendingPasteResponder = nil;
static __weak UIWindow *kayokoPendingPasteKeyWindow = nil;

static const NSTimeInterval kKayokoPendingPasteExpirationDelay = 2.8;

@interface UIKeyboardLayoutStar : UIView
@end

@interface UIKBInputBackdropView : UIView
@end

@interface UIKeyboardImpl : UIView
+ (instancetype)activeInstance;
@property(nonatomic, strong, readonly) id inputDelegate;
@end

BOOL KayokoHelperEnabled(void) { return kayokoHelperPrefsEnabled; }

NSUInteger KayokoHelperActivationMethod(void) { return kayokoHelperPrefsActivationMethod; }

BOOL KayokoHelperAutomaticallyPasteEnabled(void) { return kayokoHelperPrefsAutomaticallyPaste; }

static CFStringRef kayokoHelperNotificationName(NSString *name) { return (__bridge CFStringRef)name; }

void KayokoHelperPostCoreShow(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         kayokoHelperNotificationName(kKayokoNotificationKeyCoreShow), nil, nil, YES);
}

static void kayokoHelperPostCoreHide(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         kayokoHelperNotificationName(kKayokoNotificationKeyCoreHide), nil, nil, YES);
}

void KayokoHelperLoadPreferences(void) {
    kayokoHelperPreferences = [[NSUserDefaults alloc]
        initWithSuiteName:[NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist",
                                                     kKayokoPreferencesIdentifier]];

#if THEOS_PACKAGE_SCHEME_ROOTHIDE
    libSandy_applyProfile("Kayoko_RootHide");
#else
    libSandy_applyProfile("Kayoko");
#endif

    [kayokoHelperPreferences registerDefaults:@{
        kKayokoPreferenceKeyEnabled : @(kKayokoPreferenceKeyEnabledDefaultValue),
        kKayokoPreferenceKeyActivationMethod : @(kKayokoPreferenceKeyActivationMethodDefaultValue),
        kKayokoPreferenceKeyAutomaticallyPaste : @(kKayokoPreferenceKeyAutomaticallyPasteDefaultValue)
    }];

    kayokoHelperPrefsEnabled = [[kayokoHelperPreferences objectForKey:kKayokoPreferenceKeyEnabled] boolValue];
    kayokoHelperPrefsActivationMethod =
        [[kayokoHelperPreferences objectForKey:kKayokoPreferenceKeyActivationMethod] unsignedIntegerValue];
    kayokoHelperPrefsAutomaticallyPaste =
        [[kayokoHelperPreferences objectForKey:kKayokoPreferenceKeyAutomaticallyPaste] boolValue];
}

BOOL KayokoHelperIsKeyboardExtensionProcess(void) {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *bundlePath = [mainBundle bundlePath];
    BOOL isPluginBundle = [[bundlePath pathExtension] isEqualToString:@"appex"] ||
                          [bundlePath rangeOfString:@"/PlugIns/"].location != NSNotFound;
    if (!isPluginBundle) {
        return NO;
    }

    NSDictionary<NSString *, id> *extensionInfo = [[mainBundle infoDictionary] objectForKey:@"NSExtension"];
    NSString *extensionPointIdentifier = [extensionInfo objectForKey:@"NSExtensionPointIdentifier"];
    return [extensionPointIdentifier isEqualToString:@"com.apple.keyboard-service"];
}

static UIWindow *kayokoHelperActiveKeyWindow(UIApplication *application) {
    if (!application || [application applicationState] != UIApplicationStateActive) {
        return nil;
    }

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [application connectedScenes]) {
            if ([scene activationState] != UISceneActivationStateForegroundActive ||
                ![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            for (UIWindow *window in [(UIWindowScene *)scene windows]) {
                if ([window isKeyWindow]) {
                    return window;
                }
            }
        }

        return nil;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIWindow *keyWindow = [application keyWindow];
#pragma clang diagnostic pop
    return [keyWindow isKeyWindow] ? keyWindow : nil;
}

static BOOL kayokoHelperApplicationHasActiveKeyWindow(UIApplication *application) {
    return kayokoHelperActiveKeyWindow(application) != nil;
}

static UIKeyboardImpl *kayokoHelperActiveKeyboardImpl(void) {
    Class keyboardImplClass = NSClassFromString(@"UIKeyboardImpl");
    SEL activeInstanceSelector = @selector(activeInstance);
    if (![keyboardImplClass respondsToSelector:activeInstanceSelector]) {
        return nil;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [keyboardImplClass performSelector:activeInstanceSelector];
#pragma clang diagnostic pop
}

static UIResponder *kayokoHelperActiveKeyboardInputDelegate(void) {
    UIKeyboardImpl *keyboardImpl = kayokoHelperActiveKeyboardImpl();
    SEL inputDelegateSelector = @selector(inputDelegate);
    if (![keyboardImpl respondsToSelector:inputDelegateSelector]) {
        return nil;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id inputDelegate = [keyboardImpl performSelector:inputDelegateSelector];
#pragma clang diagnostic pop
    if (![inputDelegate isKindOfClass:[UIResponder class]]) {
        return nil;
    }

    return inputDelegate;
}

static BOOL kayokoHelperRestoreResponder(UIResponder *responder) {
    if (!responder || [responder isFirstResponder]) {
        return responder != nil;
    }

    return [responder becomeFirstResponder];
}

static void kayokoHelperClearCapturedFocusSession(void) {
    kayokoHasCapturedFocusSession = NO;
    kayokoFirstResponderBeforeShowingKayoko = nil;
    kayokoKeyboardInputDelegateBeforeShowingKayoko = nil;
    kayokoKeyWindowBeforeShowingKayoko = nil;
}

static void kayokoHelperFinishCapturingFocusSession(void) {
    kayokoHasCapturedFocusSession =
        kayokoKeyboardInputDelegateBeforeShowingKayoko || kayokoFirstResponderBeforeShowingKayoko;
}

static void kayokoHelperCaptureFocusSessionInKeyWindow(UIWindow *keyWindow) {
    kayokoHelperClearCapturedFocusSession();
    if (!keyWindow) {
        return;
    }

    kayokoKeyWindowBeforeShowingKayoko = keyWindow;
    kayokoKeyboardInputDelegateBeforeShowingKayoko = kayokoHelperActiveKeyboardInputDelegate();
}

static void kayokoHelperCaptureFocusSessionFromResponder(UIResponder *responder, UIWindow *keyWindow) {
    kayokoHelperCaptureFocusSessionInKeyWindow(keyWindow);
    kayokoFirstResponderBeforeShowingKayoko = responder;
    kayokoHelperFinishCapturingFocusSession();
}

static BOOL kayokoHelperCapturedFocusSessionMatchesKeyWindow(UIWindow *keyWindow) {
    UIWindow *capturedKeyWindow = kayokoKeyWindowBeforeShowingKayoko;
    return !capturedKeyWindow || capturedKeyWindow == keyWindow;
}

static BOOL kayokoHelperRestoreCapturedFocusSessionInKeyWindow(UIWindow *keyWindow) {
    if (!keyWindow || !kayokoHasCapturedFocusSession || !kayokoHelperCapturedFocusSessionMatchesKeyWindow(keyWindow)) {
        return NO;
    }

    if (kayokoHelperRestoreResponder(kayokoKeyboardInputDelegateBeforeShowingKayoko)) {
        return YES;
    }

    return kayokoHelperRestoreResponder(kayokoFirstResponderBeforeShowingKayoko);
}

static UIResponder *kayokoHelperCapturedFocusResponderForPaste(BOOL *requiresKeyboardDelegate) {
    UIResponder *keyboardInputDelegate = kayokoKeyboardInputDelegateBeforeShowingKayoko;
    if (keyboardInputDelegate) {
        if (requiresKeyboardDelegate) {
            *requiresKeyboardDelegate = YES;
        }
        return keyboardInputDelegate;
    }

    if (requiresKeyboardDelegate) {
        *requiresKeyboardDelegate = NO;
    }
    return kayokoFirstResponderBeforeShowingKayoko;
}

@implementation UIResponder (KayokoFocusRestoration)

- (void)kayokoCaptureFirstResponderForFocusRestore:(id)sender {
    kayokoFirstResponderBeforeShowingKayoko = self;
}

@end

void KayokoHelperCaptureCurrentFirstResponder(void) {
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *keyWindow = kayokoHelperActiveKeyWindow(application);
    if (!keyWindow) {
        return;
    }

    kayokoHelperCaptureFocusSessionInKeyWindow(keyWindow);
    [application sendAction:@selector(kayokoCaptureFirstResponderForFocusRestore:) to:nil from:nil forEvent:nil];
    kayokoHelperFinishCapturingFocusSession();
}

void KayokoHelperRestoreCapturedFirstResponder(void) {
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *keyWindow = kayokoHelperActiveKeyWindow(application);
    kayokoHelperRestoreCapturedFocusSessionInKeyWindow(keyWindow);
}

static void kayokoHelperPerformPaste(void) {
    UIApplication *activeApplication = [UIApplication sharedApplication];
    if (!kayokoApplicationIsInForeground || !kayokoHelperApplicationHasActiveKeyWindow(activeApplication)) {
        return;
    }

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         kayokoHelperNotificationName(kKayokoNotificationKeyPasteWillStart), nil, nil,
                                         YES);
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    if (![pasteboard string] && ![pasteboard image]) {
        PasteboardItem *item = [[PasteboardManager sharedInstance] getLatestHistoryItem];
        if (!item) {
            return;
        }

        if (![[item imageName] isEqualToString:@""]) {
            [pasteboard setImage:[[PasteboardManager sharedInstance] getImageForItem:item]];
        } else {
            [pasteboard setString:[item content]];
        }
    }

    [activeApplication sendAction:@selector(paste:) to:nil from:nil forEvent:nil];
}

static void kayokoHelperClearPendingPaste(void) {
    kayokoHasPendingPaste = NO;
    kayokoPendingPasteCanExecute = NO;
    kayokoPendingPasteRequiresKeyboardDelegate = NO;
    kayokoPendingPasteResponder = nil;
    kayokoPendingPasteKeyWindow = nil;
}

static BOOL kayokoHelperPendingPasteIsReady(void) {
    UIResponder *pendingResponder = kayokoPendingPasteResponder;
    if (!pendingResponder) {
        return NO;
    }

    UIResponder *activeKeyboardInputDelegate = kayokoHelperActiveKeyboardInputDelegate();
    if (activeKeyboardInputDelegate == pendingResponder) {
        return YES;
    }

    return !kayokoPendingPasteRequiresKeyboardDelegate && [pendingResponder isFirstResponder];
}

static void kayokoHelperAttemptPendingPaste(void) {
    if (!kayokoHasPendingPaste || !kayokoPendingPasteCanExecute) {
        return;
    }

    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *activeKeyWindow = kayokoHelperActiveKeyWindow(application);
    if (!kayokoApplicationIsInForeground || !activeKeyWindow || activeKeyWindow != kayokoPendingPasteKeyWindow) {
        kayokoHelperClearPendingPaste();
        return;
    }

    if (!kayokoHelperPendingPasteIsReady()) {
        return;
    }

    kayokoHelperClearPendingPaste();
    kayokoHelperPerformPaste();
}

static void kayokoHelperSchedulePendingPasteCheck(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
      kayokoHelperAttemptPendingPaste();
    });
}

static BOOL kayokoHelperBeginPendingPaste(void) {
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *activeKeyWindow = kayokoHelperActiveKeyWindow(application);
    BOOL requiresKeyboardDelegate = NO;
    UIResponder *pendingResponder = kayokoHelperCapturedFocusResponderForPaste(&requiresKeyboardDelegate);
    if (!activeKeyWindow || !pendingResponder) {
        return NO;
    }

    kayokoHasPendingPaste = YES;
    kayokoPendingPasteCanExecute = NO;
    kayokoPendingPasteRequiresKeyboardDelegate = requiresKeyboardDelegate;
    kayokoPendingPasteResponder = pendingResponder;
    kayokoPendingPasteKeyWindow = activeKeyWindow;
    kayokoPendingPasteToken++;

    NSUInteger pendingPasteToken = kayokoPendingPasteToken;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kKayokoPendingPasteExpirationDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     if (kayokoHasPendingPaste && kayokoPendingPasteToken == pendingPasteToken) {
                         kayokoHelperClearPendingPaste();
                     }
                   });

    return YES;
}

void KayokoHelperOpenKayokoFromResponder(id self, SEL _cmd) {
    if ([self isKindOfClass:[UIResponder class]]) {
        kayokoHelperCaptureFocusSessionFromResponder(self,
                                                     kayokoHelperActiveKeyWindow([UIApplication sharedApplication]));
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      KayokoHelperPostCoreShow();
    });
}

void KayokoHelperPaste(void) {
    if (!kayokoApplicationIsInForeground) {
        return;
    }

    UIApplication *application = [UIApplication sharedApplication];
    if (!kayokoHelperApplicationHasActiveKeyWindow(application)) {
        return;
    }

    BOOL hasPendingPaste = kayokoHelperBeginPendingPaste();
    KayokoHelperRestoreCapturedFirstResponder();

    if (hasPendingPaste) {
        kayokoPendingPasteCanExecute = YES;
        kayokoHelperSchedulePendingPasteCheck();
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
          kayokoHelperPerformPaste();
        });
    }
}

CHOptimizedMethod0(self, void, UIKeyboardLayoutStar, didMoveToWindow) {
    CHSuper0(UIKeyboardLayoutStar, didMoveToWindow);
    kayokoHelperPostCoreHide();
}

CHOptimizedMethod0(self, void, UIKBInputBackdropView, didMoveToWindow) {
    CHSuper0(UIKBInputBackdropView, didMoveToWindow);
    kayokoHelperPostCoreHide();
}

CHOptimizedMethod1(self, void, UIKeyboardImpl, applicationDidBecomeActive, BOOL, didBecomeActive) {
    CHSuper1(UIKeyboardImpl, applicationDidBecomeActive, didBecomeActive);
    kayokoApplicationIsInForeground = YES;
    kayokoHelperSchedulePendingPasteCheck();
}

CHOptimizedMethod1(self, void, UIKeyboardImpl, applicationWillResignActive, BOOL, willResignActive) {
    CHSuper1(UIKeyboardImpl, applicationWillResignActive, willResignActive);
    kayokoApplicationIsInForeground = NO;
    kayokoHelperClearPendingPaste();
}

CHOptimizedMethod1(self, void, UIKeyboardImpl, applicationWillSuspend, BOOL, willSuspend) {
    CHSuper1(UIKeyboardImpl, applicationWillSuspend, willSuspend);
    kayokoApplicationIsInForeground = NO;
    kayokoHelperClearPendingPaste();
}

CHOptimizedMethod3(self, void, UIKeyboardImpl, setDelegate, id, delegate, force, BOOL, force, fromBecomeFirstResponder,
                   BOOL, fromBecomeFirstResponder) {
    CHSuper3(UIKeyboardImpl, setDelegate, delegate, force, force, fromBecomeFirstResponder, fromBecomeFirstResponder);
    kayokoHelperAttemptPendingPaste();
}

void KayokoHelperInstallRuntimeHooks(void) {
    CHLoadClass_(&UIKeyboardLayoutStar$, NSClassFromString(@"UIKeyboardLayoutStar"));
    CHHook0(UIKeyboardLayoutStar, didMoveToWindow);
    CHLoadClass_(&UIKBInputBackdropView$, NSClassFromString(@"UIKBInputBackdropView"));
    CHHook0(UIKBInputBackdropView, didMoveToWindow);
    CHLoadClass_(&UIKeyboardImpl$, NSClassFromString(@"UIKeyboardImpl"));
    CHHook1(UIKeyboardImpl, applicationDidBecomeActive);
    CHHook1(UIKeyboardImpl, applicationWillResignActive);
    CHHook1(UIKeyboardImpl, applicationWillSuspend);
    CHHook3(UIKeyboardImpl, setDelegate, force, fromBecomeFirstResponder);
}

NS_ASSUME_NONNULL_BEGIN

@interface KayokoKeyboardObserver : NSObject
@end

NS_ASSUME_NONNULL_END

@implementation KayokoKeyboardObserver

- (void)windowDidResignKey:(NSNotification *)notification {
    kayokoHelperPostCoreHide();
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary<NSString *, id> *userInfo = [notification userInfo];
    BOOL isLocalKeyboard = [userInfo[UIKeyboardIsLocalUserInfoKey] boolValue];
    if (!isLocalKeyboard) {
        return;
    }

    kayokoHelperPostCoreHide();
}

- (void)keyboardDidShow:(NSNotification *)notification {
    kayokoHelperAttemptPendingPaste();
}

@end

void KayokoHelperInstallRuntimeObservers(void) {
    if (KayokoHelperAutomaticallyPasteEnabled()) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                        (CFNotificationCallback)KayokoHelperPaste,
                                        kayokoHelperNotificationName(kKayokoNotificationKeyHelperPaste), NULL,
                                        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDrop);
    }

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        (CFNotificationCallback)KayokoHelperCaptureCurrentFirstResponder,
        kayokoHelperNotificationName(kKayokoNotificationKeyCoreShow), NULL,
        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        (CFNotificationCallback)KayokoHelperCaptureCurrentFirstResponder,
        kayokoHelperNotificationName(kKayokoLegacyNotificationKeyCoreShow), NULL,
        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        (CFNotificationCallback)KayokoHelperRestoreCapturedFirstResponder,
        kayokoHelperNotificationName(kKayokoNotificationKeyHelperRestoreFocus), NULL,
        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);

    static KayokoKeyboardObserver *observer;
    observer = [[KayokoKeyboardObserver alloc] init];

    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:@selector(windowDidResignKey:)
                                                 name:UIWindowDidResignKeyNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
}
