//
//  KayokoHelperRuntime.m
//  Kayoko
//

#define CHUseSubstrate

#import "KayokoHelperRuntime.h"
#import "KayokoNotificationKeys.h"
#import "KayokoSceneSettingKeys.h"

#import <AudioToolbox/AudioToolbox.h>
#import <CaptainHook/CaptainHook.h>
#import <CoreFoundation/CFNotificationCenter.h>
#import <Foundation/Foundation.h>
#import <HBLog.h>
#import <objc/runtime.h>

CHDeclareClass(UIKeyboardLayoutStar);
CHDeclareClass(UIKBInputBackdropView);
CHDeclareClass(UIKeyboardImpl);
CHDeclareClass(FBSScene);
CHDeclareClass(UISearchBar);
CHDeclareClass(UITextField);

static const NSTimeInterval kKayokoPendingPasteFocusExpirationDelay = 2.8;
static const NSTimeInterval kKayokoPendingPasteboardVisibilityExpirationDelay = 0.5;
static const NSTimeInterval kKayokoPendingPasteboardVisibilityRecheckDelay = 0.1;
static const NSTimeInterval kKayokoKeyboardHideSuppressionInterval = 1.0;

@interface UIKeyboardLayoutStar : UIView
@end

@interface UIKBInputBackdropView : UIView
@end

@interface UIKeyboardImpl : UIView
+ (instancetype)activeInstance;
@property(nonatomic, strong, readonly) id inputDelegate;
@end

@class BSMutableSettings;

@interface FBSMutableSceneClientSettings : NSObject
- (BSMutableSettings *)otherSettings;
@end

@interface BSMutableSettings : NSObject
- (void)setFlag:(long long)flag forSetting:(unsigned long long)setting;
@end

typedef void (^FBSSceneClientSettingsUpdateBlock)(FBSMutableSceneClientSettings *mutableClientSettings);

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHelperFocusSession : NSObject

#pragma mark - State

@property(nonatomic, assign, getter=hasCapturedFocusSession) BOOL capturedFocusSession;
@property(nonatomic, assign, getter=hasCapturedPasteboardChangeCount) BOOL capturedPasteboardChangeCount;
@property(nonatomic, assign) NSUInteger pasteboardChangeCount;

#pragma mark - Responders

@property(nonatomic, weak, nullable) UIResponder *firstResponder;
@property(nonatomic, weak, nullable) UIResponder *keyboardInputDelegate;
@property(nonatomic, weak, nullable) UIWindow *keyWindow;

#pragma mark - Lifecycle

- (void)clear;
- (void)finishCapturing;

#pragma mark - Matching

- (BOOL)matchesKeyWindow:(UIWindow *)keyWindow;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoHelperFocusSession

- (void)clear {
    self.capturedFocusSession = NO;
    self.capturedPasteboardChangeCount = NO;
    self.pasteboardChangeCount = 0;
    self.firstResponder = nil;
    self.keyboardInputDelegate = nil;
    self.keyWindow = nil;
}

- (void)finishCapturing {
    self.capturedFocusSession = self.keyboardInputDelegate || self.firstResponder;
}

- (BOOL)matchesKeyWindow:(UIWindow *)keyWindow {
    UIWindow *capturedKeyWindow = self.keyWindow;
    return !capturedKeyWindow || capturedKeyWindow == keyWindow;
}

@end

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHelperPendingPasteSession : NSObject

#pragma mark - State

@property(nonatomic, assign, getter=hasPendingPaste) BOOL pendingPaste;
@property(nonatomic, assign) BOOL canExecute;
@property(nonatomic, assign) BOOL requiresKeyboardDelegate;
@property(nonatomic, assign) BOOL requiresPasteboardChange;
@property(nonatomic, assign, getter=isWaitingForPasteboardVisibility) BOOL waitingForPasteboardVisibility;
@property(nonatomic, assign) NSUInteger pasteboardChangeCountBeforePaste;
@property(nonatomic, assign) NSUInteger token;

#pragma mark - Expiration

@property(nonatomic, copy, nullable) dispatch_block_t focusExpirationBlock;
@property(nonatomic, copy, nullable) dispatch_block_t pasteboardVisibilityExpirationBlock;
@property(nonatomic, copy, nullable) dispatch_block_t pasteboardVisibilityRecheckBlock;

#pragma mark - Responders

@property(nonatomic, weak, nullable) UIResponder *responder;
@property(nonatomic, weak, nullable) UIWindow *keyWindow;

#pragma mark - Scheduling

- (void)scheduleFocusExpirationAfterDelay:(NSTimeInterval)delay handler:(dispatch_block_t)handler;
- (void)schedulePasteboardVisibilityExpirationAfterDelay:(NSTimeInterval)delay handler:(dispatch_block_t)handler;
- (void)schedulePasteboardVisibilityRecheckAfterDelay:(NSTimeInterval)delay handler:(dispatch_block_t)handler;

#pragma mark - Cancellation

- (void)cancelFocusExpirationBlock;
- (void)cancelPasteboardVisibilityExpirationBlock;
- (void)cancelPasteboardVisibilityRecheckBlock;
- (void)cancelPasteboardVisibilityWait;

#pragma mark - Lifecycle

- (void)clear;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoHelperPendingPasteSession

- (void)clear {
    [self cancelFocusExpirationBlock];
    [self cancelPasteboardVisibilityWait];
    self.token++;
    self.pendingPaste = NO;
    self.canExecute = NO;
    self.requiresKeyboardDelegate = NO;
    self.requiresPasteboardChange = NO;
    self.waitingForPasteboardVisibility = NO;
    self.pasteboardChangeCountBeforePaste = 0;
    self.responder = nil;
    self.keyWindow = nil;
}

- (void)scheduleFocusExpirationAfterDelay:(NSTimeInterval)delay handler:(dispatch_block_t)handler {
    [self cancelFocusExpirationBlock];
    dispatch_block_t expirationBlock = dispatch_block_create(0, handler);
    self.focusExpirationBlock = expirationBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(),
                   expirationBlock);
}

- (void)schedulePasteboardVisibilityExpirationAfterDelay:(NSTimeInterval)delay handler:(dispatch_block_t)handler {
    [self cancelPasteboardVisibilityExpirationBlock];
    dispatch_block_t expirationBlock = dispatch_block_create(0, handler);
    self.pasteboardVisibilityExpirationBlock = expirationBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(),
                   expirationBlock);
}

- (void)schedulePasteboardVisibilityRecheckAfterDelay:(NSTimeInterval)delay handler:(dispatch_block_t)handler {
    [self cancelPasteboardVisibilityRecheckBlock];
    dispatch_block_t recheckBlock = dispatch_block_create(0, handler);
    self.pasteboardVisibilityRecheckBlock = recheckBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(),
                   recheckBlock);
}

- (void)cancelFocusExpirationBlock {
    dispatch_block_t expirationBlock = self.focusExpirationBlock;
    if (expirationBlock) {
        dispatch_block_cancel(expirationBlock);
        self.focusExpirationBlock = nil;
    }
}

- (void)cancelPasteboardVisibilityExpirationBlock {
    dispatch_block_t expirationBlock = self.pasteboardVisibilityExpirationBlock;
    if (expirationBlock) {
        dispatch_block_cancel(expirationBlock);
        self.pasteboardVisibilityExpirationBlock = nil;
    }
}

- (void)cancelPasteboardVisibilityRecheckBlock {
    dispatch_block_t recheckBlock = self.pasteboardVisibilityRecheckBlock;
    if (recheckBlock) {
        dispatch_block_cancel(recheckBlock);
        self.pasteboardVisibilityRecheckBlock = nil;
    }
}

- (void)cancelPasteboardVisibilityWait {
    [self cancelPasteboardVisibilityExpirationBlock];
    [self cancelPasteboardVisibilityRecheckBlock];
    self.waitingForPasteboardVisibility = NO;
}

@end

@class KayokoKeyboardObserver;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHelperRuntime ()

#pragma mark - Runtime State

@property(nonatomic, assign, getter=isSpringBoardRuntime) BOOL springBoardRuntime;
@property(nonatomic, assign, getter=isAutomaticallyPasteEnabled) BOOL automaticallyPasteEnabled;
@property(nonatomic, assign, getter=isHapticFeedbackEnabled) BOOL hapticFeedbackEnabled;
@property(nonatomic, assign) BOOL applicationInForeground;

#pragma mark - Sessions

@property(nonatomic, strong) KayokoHelperFocusSession *focusSession;
@property(nonatomic, strong) KayokoHelperPendingPasteSession *pendingPasteSession;

#pragma mark - Input State

@property(nonatomic, assign) BOOL lastKeyboardInputWasKayokoOwned;
@property(nonatomic, assign) NSTimeInterval lastKayokoKeyboardInputTime;
@property(nonatomic, weak, nullable) UIResponder *resolvedCurrentFirstResponder;

#pragma mark - Observers

@property(nonatomic, strong, nullable) KayokoKeyboardObserver *keyboardObserver;
@property(nonatomic, assign, getter=hasInstalledObservers) BOOL installedObservers;

#pragma mark - Runtime Hook Events

- (void)keyboardWindowDidMoveToWindow;
- (void)keyboardImplDidBecomeActive;
- (void)keyboardImplWillLeaveActive;
- (void)keyboardImplDidSetDelegate:(id)delegate;
- (void)rememberResponderWillResign:(UIResponder *)responder;

#pragma mark - Keyboard Notifications

- (void)windowDidResignKeyWithNotification:(NSNotification *)notification;
- (void)keyboardWillHideWithNotification:(NSNotification *)notification;
- (void)keyboardDidShowWithNotification:(NSNotification *)notification;
- (void)pasteboardDidChangeWithNotification:(NSNotification *)notification;

#pragma mark - Darwin Notifications

- (void)postCoreShow;
- (void)postCoreHide;
- (void)showKayoko;
- (void)showKayokoAfterCapturingCurrentFocus;
- (void)showKayokoFromResponder:(UIResponder *)responder;

#pragma mark - Application And Window State

- (UIWindow *)activeKeyWindowForApplication:(UIApplication *)application;
- (BOOL)applicationHasActiveKeyWindow:(UIApplication *)application;
- (UIWindow *)capturedFocusKeyWindowForSpringBoard;
- (BOOL)makeCapturedFocusKeyWindowKeyIfNeeded:(UIWindow *)keyWindow;
- (UIWindow *)keyWindowForRestoringCapturedFocusInApplication:(UIApplication *)application;
- (BOOL)applicationHasPasteContext:(UIApplication *)application;
- (BOOL)applicationCanPerformPaste:(UIApplication *)application;

#pragma mark - Keyboard State

- (UIKeyboardImpl *)activeKeyboardImpl;
- (UIResponder *)activeKeyboardInputDelegate;

#pragma mark - SpringBoard Input Isolation

- (BOOL)objectHasKayokoClassPrefix:(id)object;
- (BOOL)viewHierarchyIsKayokoOwned:(UIView *)view;
- (BOOL)responderIsKayokoOwned:(UIResponder *)responder;
- (BOOL)shouldHandleActivationForCurrentInput;
- (void)playActivationRejectedFeedbackIfNeeded;
- (void)rememberKayokoKeyboardInput;
- (void)clearLastKayokoKeyboardInput;
- (BOOL)hasRecentKayokoKeyboardInput;
- (UIResponder *)currentFirstResponder;
- (UIResponder *)currentKayokoInputResponder;
- (BOOL)currentInputIsKayokoOwnedUpdatingLast:(BOOL)clearsLastForExternalInput;
- (BOOL)currentInputIsKayokoOwned;
- (BOOL)keyboardHideIsFromKayokoInput;

#pragma mark - Focus Capture And Restore

- (UIResponder *)restorableKeyboardInputDelegate;
- (BOOL)restoreResponder:(UIResponder *)responder;
- (void)captureFocusSessionInKeyWindow:(UIWindow *)keyWindow;
- (void)captureFocusSessionFromResponder:(UIResponder *)responder keyWindow:(UIWindow *)keyWindow;
- (void)captureResponderForFocusRestore:(UIResponder *)responder;
- (BOOL)restoreCapturedFocusSessionInKeyWindow:(UIWindow *)keyWindow;

#pragma mark - Pending Paste

- (UIResponder *)capturedFocusResponderForPasteRequiringKeyboardDelegate:(BOOL *)requiresKeyboardDelegate;
- (void)postPasteWillStart;
- (BOOL)preparePasteboardForPaste;
- (BOOL)pasteIntoKayokoInputResponder:(UIResponder *)responder;
- (BOOL)performPaste;
- (BOOL)pendingPasteIsReady;
- (BOOL)pendingPasteboardChangeIsReady;
- (void)attemptPendingPaste;
- (void)schedulePendingPasteCheck;
- (void)beginPendingPasteboardVisibilityWaitIfNeeded;
- (void)schedulePendingPasteboardVisibilityRecheck;
- (BOOL)beginPendingPaste;

#pragma mark - Installation

- (void)installRuntimeHooks;
- (void)installSceneClientSettingsHooks;
- (void)installSpringBoardInputIsolationHooks;
- (void)installRuntimeObserversObservingWindowResign:(BOOL)observesWindowResign;

@end

NS_ASSUME_NONNULL_END

@interface KayokoKeyboardObserver : NSObject
- (instancetype)initWithRuntime:(KayokoHelperRuntime *)runtime;
@end

static void kayokoHelperPasteNotificationCallback(CFNotificationCenterRef center, void *observer,
                                                  CFNotificationName name, const void *object,
                                                  CFDictionaryRef userInfo) {
    HBLogDebug(@"Kayoko: helper paste notification received process=%@", [[NSProcessInfo processInfo] processName]);
    [[KayokoHelperRuntime sharedRuntime] paste];
}

static void kayokoHelperCaptureFocusNotificationCallback(CFNotificationCenterRef center, void *observer,
                                                         CFNotificationName name, const void *object,
                                                         CFDictionaryRef userInfo) {
    [[KayokoHelperRuntime sharedRuntime] captureCurrentFirstResponder];
}

static void kayokoHelperRestoreFocusNotificationCallback(CFNotificationCenterRef center, void *observer,
                                                         CFNotificationName name, const void *object,
                                                         CFDictionaryRef userInfo) {
    [[KayokoHelperRuntime sharedRuntime] restoreCapturedFirstResponder];
}

CHOptimizedMethod0(self, void, UIKeyboardLayoutStar, didMoveToWindow) {
    CHSuper0(UIKeyboardLayoutStar, didMoveToWindow);
    [[KayokoHelperRuntime sharedRuntime] keyboardWindowDidMoveToWindow];
}

CHOptimizedMethod0(self, void, UIKBInputBackdropView, didMoveToWindow) {
    CHSuper0(UIKBInputBackdropView, didMoveToWindow);
    [[KayokoHelperRuntime sharedRuntime] keyboardWindowDidMoveToWindow];
}

CHOptimizedMethod1(self, void, UIKeyboardImpl, applicationDidBecomeActive, BOOL, didBecomeActive) {
    CHSuper1(UIKeyboardImpl, applicationDidBecomeActive, didBecomeActive);
    [[KayokoHelperRuntime sharedRuntime] keyboardImplDidBecomeActive];
}

CHOptimizedMethod1(self, void, UIKeyboardImpl, applicationWillResignActive, BOOL, willResignActive) {
    CHSuper1(UIKeyboardImpl, applicationWillResignActive, willResignActive);
    [[KayokoHelperRuntime sharedRuntime] keyboardImplWillLeaveActive];
}

CHOptimizedMethod1(self, void, UIKeyboardImpl, applicationWillSuspend, BOOL, willSuspend) {
    CHSuper1(UIKeyboardImpl, applicationWillSuspend, willSuspend);
    [[KayokoHelperRuntime sharedRuntime] keyboardImplWillLeaveActive];
}

CHOptimizedMethod3(self, void, UIKeyboardImpl, setDelegate, id, delegate, force, BOOL, force, fromBecomeFirstResponder,
                   BOOL, fromBecomeFirstResponder) {
    CHSuper3(UIKeyboardImpl, setDelegate, delegate, force, force, fromBecomeFirstResponder, fromBecomeFirstResponder);
    [[KayokoHelperRuntime sharedRuntime] keyboardImplDidSetDelegate:delegate];
}

CHOptimizedMethod2(self, void, UIKeyboardImpl, setDelegate, id, delegate, force, BOOL, force) {
    CHSuper2(UIKeyboardImpl, setDelegate, delegate, force, force);
    [[KayokoHelperRuntime sharedRuntime] keyboardImplDidSetDelegate:delegate];
}

CHOptimizedMethod1(self, void, UIKeyboardImpl, setDelegate, id, delegate) {
    CHSuper1(UIKeyboardImpl, setDelegate, delegate);
    [[KayokoHelperRuntime sharedRuntime] keyboardImplDidSetDelegate:delegate];
}

CHOptimizedMethod1(self, void, FBSScene, updateClientSettingsWithBlock, FBSSceneClientSettingsUpdateBlock, block) {
    FBSSceneClientSettingsUpdateBlock wrappedBlock = ^(FBSMutableSceneClientSettings *mutableClientSettings) {
      if (block) {
          block(mutableClientSettings);
      }

      if (![mutableClientSettings respondsToSelector:@selector(otherSettings)]) {
          return;
      }

      BSMutableSettings *otherSettings = [mutableClientSettings otherSettings];
      if (![otherSettings respondsToSelector:@selector(setFlag:forSetting:)]) {
          return;
      }

      [otherSettings setFlag:1 forSetting:kKayokoSceneClientSettingHelperInjected];
    };
    CHSuper1(FBSScene, updateClientSettingsWithBlock, wrappedBlock);
}

CHOptimizedMethod0(self, BOOL, UISearchBar, resignFirstResponder) {
    [[KayokoHelperRuntime sharedRuntime] rememberResponderWillResign:self];
    return CHSuper0(UISearchBar, resignFirstResponder);
}

CHOptimizedMethod0(self, BOOL, UITextField, resignFirstResponder) {
    [[KayokoHelperRuntime sharedRuntime] rememberResponderWillResign:self];
    return CHSuper0(UITextField, resignFirstResponder);
}

@implementation KayokoHelperRuntime

#pragma mark - Lifecycle

+ (instancetype)sharedRuntime {
    static KayokoHelperRuntime *runtime;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      runtime = [[self alloc] initPrivate];
    });
    return runtime;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _applicationInForeground = YES;
        _focusSession = [[KayokoHelperFocusSession alloc] init];
        _pendingPasteSession = [[KayokoHelperPendingPasteSession alloc] init];
    }
    return self;
}

#pragma mark - Runtime Installation Entry Points

- (void)installApplicationRuntimeWithConfiguration:(KayokoHelperConfiguration *)configuration {
    self.springBoardRuntime = NO;
    self.automaticallyPasteEnabled = configuration.automaticallyPasteEnabled;
    self.hapticFeedbackEnabled = configuration.hapticFeedbackEnabled;
    [self installSceneClientSettingsHooks];
    [self installRuntimeHooks];
    [self installRuntimeObserversObservingWindowResign:YES];
}

- (void)installSpringBoardRuntimeWithConfiguration:(KayokoHelperConfiguration *)configuration {
    self.springBoardRuntime = YES;
    self.automaticallyPasteEnabled = configuration.automaticallyPasteEnabled;
    self.hapticFeedbackEnabled = configuration.hapticFeedbackEnabled;
    [self installSpringBoardInputIsolationHooks];
    [self installRuntimeHooks];
    [self installRuntimeObserversObservingWindowResign:NO];
}

#pragma mark - Public Runtime API

- (void)showKayoko {
    [self postCoreShow];
}

- (void)showKayokoAfterCapturingCurrentFocus {
    [self captureCurrentFirstResponder];
    [self postCoreShow];
}

- (void)showKayokoFromResponder:(UIResponder *)responder {
    if ([responder isKindOfClass:[UIResponder class]] && ![self responderIsKayokoOwned:responder]) {
        [self captureFocusSessionFromResponder:responder
                                     keyWindow:[self activeKeyWindowForApplication:[UIApplication sharedApplication]]];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      [self postCoreShow];
    });
}

- (void)captureCurrentFirstResponder {
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *keyWindow = [self activeKeyWindowForApplication:application];
    if (!keyWindow) {
        return;
    }

    if ([self currentInputIsKayokoOwned]) {
        return;
    }

    [self captureFocusSessionInKeyWindow:keyWindow];
    [application sendAction:@selector(kayokoCaptureFirstResponderForFocusRestore:) to:nil from:nil forEvent:nil];
    [self.focusSession finishCapturing];
}

- (void)restoreCapturedFirstResponder {
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *keyWindow = [self keyWindowForRestoringCapturedFocusInApplication:application];
    [self restoreCapturedFocusSessionInKeyWindow:keyWindow];
}

- (void)paste {
    if (!self.applicationInForeground) {
        HBLogDebug(@"Kayoko: helper paste ignored because application is not foreground process=%@",
                   [[NSProcessInfo processInfo] processName]);
        return;
    }

    UIApplication *application = [UIApplication sharedApplication];
    if (![self applicationHasPasteContext:application]) {
        HBLogDebug(@"Kayoko: helper paste ignored because application has no paste context process=%@ state=%ld",
                   [[NSProcessInfo processInfo] processName], (long)[application applicationState]);
        return;
    }

    BOOL hasPendingPaste = [self beginPendingPaste];
    NSUInteger pendingPasteToken = self.pendingPasteSession.token;
    HBLogDebug(@"Kayoko: helper paste started process=%@ hasPendingPaste=%@", [[NSProcessInfo processInfo] processName],
               hasPendingPaste ? @"YES" : @"NO");

    if (hasPendingPaste) {
        self.pendingPasteSession.canExecute = YES;
    }

    [self restoreCapturedFirstResponder];

    if (!hasPendingPaste && self.isSpringBoardRuntime) {
        HBLogDebug(@"Kayoko: helper paste skipped because SpringBoard has no pending paste target");
        return;
    }

    if (hasPendingPaste && self.pendingPasteSession.hasPendingPaste &&
        self.pendingPasteSession.token == pendingPasteToken) {
        HBLogDebug(@"Kayoko: helper paste scheduled pending check token=%lu", (unsigned long)pendingPasteToken);
        [self schedulePendingPasteCheck];
    } else if (hasPendingPaste) {
        HBLogDebug(@"Kayoko: helper paste completed before pending check token=%lu", (unsigned long)pendingPasteToken);
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
          HBLogDebug(@"Kayoko: helper paste scheduled immediate perform");
          [self performPaste];
        });
    }
}

- (BOOL)activateKayoko {
    if (![self shouldHandleActivationForCurrentInput]) {
        [self playActivationRejectedFeedbackIfNeeded];
        return NO;
    }

    [self showKayoko];
    return YES;
}

- (BOOL)activateKayokoAfterCapturingCurrentFocus {
    if (![self shouldHandleActivationForCurrentInput]) {
        [self playActivationRejectedFeedbackIfNeeded];
        return NO;
    }

    [self showKayokoAfterCapturingCurrentFocus];
    return YES;
}

- (BOOL)activateKayokoFromResponder:(UIResponder *)responder {
    if (![self shouldHandleActivationForCurrentInput]) {
        [self playActivationRejectedFeedbackIfNeeded];
        return NO;
    }

    [self showKayokoFromResponder:responder];
    return YES;
}

- (void)pasteFromPredictionBar {
    UIResponder *responder = [self currentKayokoInputResponder];
    if (responder) {
        [self pasteIntoKayokoInputResponder:responder];
        return;
    }

    [self paste];
}

#pragma mark - Runtime Hook Events

- (void)keyboardWindowDidMoveToWindow {
    if ([self keyboardHideIsFromKayokoInput]) {
        return;
    }
    [self postCoreHide];
}

- (void)keyboardImplDidBecomeActive {
    self.applicationInForeground = YES;
    [self schedulePendingPasteCheck];
}

- (void)keyboardImplWillLeaveActive {
    self.applicationInForeground = NO;
    [self.pendingPasteSession clear];
}

- (void)keyboardImplDidSetDelegate:(id)delegate {
    if ([delegate isKindOfClass:[UIResponder class]] && [self responderIsKayokoOwned:(UIResponder *)delegate]) {
        [self rememberKayokoKeyboardInput];
        return;
    }
    if ([delegate isKindOfClass:[UIResponder class]] && self.isSpringBoardRuntime) {
        [self clearLastKayokoKeyboardInput];
    }
    [self schedulePendingPasteCheck];
}

- (void)rememberResponderWillResign:(UIResponder *)responder {
    if ([self responderIsKayokoOwned:responder]) {
        [self rememberKayokoKeyboardInput];
    }
}

#pragma mark - Keyboard Notifications

- (void)windowDidResignKeyWithNotification:(NSNotification *)notification {
    if ([self keyboardHideIsFromKayokoInput]) {
        return;
    }
    [self postCoreHide];
}

- (void)keyboardWillHideWithNotification:(NSNotification *)notification {
    NSDictionary<NSString *, id> *userInfo = [notification userInfo];
    BOOL isLocalKeyboard = [userInfo[UIKeyboardIsLocalUserInfoKey] boolValue];
    if (!isLocalKeyboard) {
        return;
    }

    if ([self keyboardHideIsFromKayokoInput]) {
        return;
    }

    [self postCoreHide];
}

- (void)keyboardDidShowWithNotification:(NSNotification *)notification {
    if ([self currentInputIsKayokoOwned]) {
        return;
    }
    [self attemptPendingPaste];
}

- (void)pasteboardDidChangeWithNotification:(NSNotification *)notification {
    (void)notification;
    if (!self.pendingPasteSession.hasPendingPaste || !self.pendingPasteSession.canExecute) {
        return;
    }

    HBLogDebug(@"Kayoko: pasteboard changed while pending paste token=%lu changeCount=%lu",
               (unsigned long)self.pendingPasteSession.token,
               (unsigned long)[[UIPasteboard generalPasteboard] changeCount]);
    [self schedulePendingPasteCheck];
}

#pragma mark - Darwin Notifications

- (void)postCoreShow {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kKayokoNotificationKeyCoreShow, nil, nil, YES);
}

- (void)postCoreHide {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kKayokoNotificationKeyCoreHide, nil, nil, YES);
}

#pragma mark - Application And Window State

- (UIWindow *)activeKeyWindowForApplication:(UIApplication *)application {
    if (!application || [application applicationState] != UIApplicationStateActive) {
        return nil;
    }

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

- (BOOL)applicationHasActiveKeyWindow:(UIApplication *)application {
    return [self activeKeyWindowForApplication:application] != nil;
}

- (UIWindow *)capturedFocusKeyWindowForSpringBoard {
    if (!self.isSpringBoardRuntime || !self.focusSession.hasCapturedFocusSession) {
        return nil;
    }

    return self.focusSession.keyWindow;
}

- (BOOL)makeCapturedFocusKeyWindowKeyIfNeeded:(UIWindow *)keyWindow {
    UIWindow *capturedKeyWindow = [self capturedFocusKeyWindowForSpringBoard];
    if (!capturedKeyWindow || keyWindow != capturedKeyWindow || [keyWindow isKeyWindow]) {
        return YES;
    }

    [keyWindow makeKeyWindow];
    return [keyWindow isKeyWindow];
}

- (UIWindow *)keyWindowForRestoringCapturedFocusInApplication:(UIApplication *)application {
    UIWindow *activeKeyWindow = [self activeKeyWindowForApplication:application];
    UIWindow *capturedKeyWindow = [self capturedFocusKeyWindowForSpringBoard];
    if (!capturedKeyWindow) {
        return activeKeyWindow;
    }

    if (!activeKeyWindow || ![self.focusSession matchesKeyWindow:activeKeyWindow]) {
        return capturedKeyWindow;
    }

    return activeKeyWindow;
}

- (BOOL)applicationHasPasteContext:(UIApplication *)application {
    if (!application || [application applicationState] != UIApplicationStateActive) {
        return NO;
    }

    if (self.isSpringBoardRuntime) {
        return [self capturedFocusKeyWindowForSpringBoard] != nil;
    }

    if ([self applicationHasActiveKeyWindow:application]) {
        return YES;
    }

    return NO;
}

- (BOOL)applicationCanPerformPaste:(UIApplication *)application {
    if (self.isSpringBoardRuntime) {
        if (![self capturedFocusKeyWindowForSpringBoard]) {
            return NO;
        }

        return [self pendingPasteIsReady];
    }

    if ([self applicationHasActiveKeyWindow:application]) {
        return YES;
    }

    return NO;
}

#pragma mark - Keyboard State

- (UIKeyboardImpl *)activeKeyboardImpl {
    id keyboardImplClass = NSClassFromString(@"UIKeyboardImpl");
    if (![keyboardImplClass respondsToSelector:@selector(activeInstance)]) {
        return nil;
    }

    return [keyboardImplClass activeInstance];
}

- (UIResponder *)activeKeyboardInputDelegate {
    UIKeyboardImpl *keyboardImpl = [self activeKeyboardImpl];
    if (![keyboardImpl respondsToSelector:@selector(inputDelegate)]) {
        return nil;
    }

    id inputDelegate = [keyboardImpl inputDelegate];
    if (![inputDelegate isKindOfClass:[UIResponder class]]) {
        return nil;
    }

    return inputDelegate;
}

#pragma mark - SpringBoard Input Isolation

- (BOOL)objectHasKayokoClassPrefix:(id)object {
    if (!self.isSpringBoardRuntime || !object) {
        return NO;
    }

    Class cls = [object class];
    while (cls) {
        if ([NSStringFromClass(cls) hasPrefix:@"Kayoko"]) {
            return YES;
        }
        cls = class_getSuperclass(cls);
    }
    return NO;
}

- (BOOL)viewHierarchyIsKayokoOwned:(UIView *)view {
    if (!self.isSpringBoardRuntime) {
        return NO;
    }

    NSUInteger depth = 0;
    while (view && depth < 64) {
        if ([self objectHasKayokoClassPrefix:view]) {
            return YES;
        }
        view = [view superview];
        depth++;
    }
    return NO;
}

- (BOOL)responderIsKayokoOwned:(UIResponder *)responder {
    if (!self.isSpringBoardRuntime || !responder) {
        return NO;
    }

    UIResponder *currentResponder = responder;
    NSUInteger depth = 0;
    while (currentResponder && depth < 64) {
        if ([self objectHasKayokoClassPrefix:currentResponder]) {
            return YES;
        }
        if ([currentResponder isKindOfClass:[UIView class]] &&
            [self viewHierarchyIsKayokoOwned:[(UIView *)currentResponder superview]]) {
            return YES;
        }
        currentResponder = [currentResponder nextResponder];
        depth++;
    }
    return NO;
}

- (BOOL)shouldHandleActivationForCurrentInput {
    if (!self.isSpringBoardRuntime) {
        return YES;
    }

    return ![self currentInputIsKayokoOwned];
}

- (void)playActivationRejectedFeedbackIfNeeded {
    if (self.isHapticFeedbackEnabled) {
        AudioServicesPlaySystemSound(1521);
    }
}

- (void)rememberKayokoKeyboardInput {
    self.lastKeyboardInputWasKayokoOwned = YES;
    self.lastKayokoKeyboardInputTime = [NSDate timeIntervalSinceReferenceDate];
}

- (void)clearLastKayokoKeyboardInput {
    self.lastKeyboardInputWasKayokoOwned = NO;
    self.lastKayokoKeyboardInputTime = 0;
}

- (BOOL)hasRecentKayokoKeyboardInput {
    if (!self.lastKeyboardInputWasKayokoOwned) {
        return NO;
    }

    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - self.lastKayokoKeyboardInputTime;
    if (elapsed <= kKayokoKeyboardHideSuppressionInterval) {
        return YES;
    }

    [self clearLastKayokoKeyboardInput];
    return NO;
}

- (UIResponder *)currentFirstResponder {
    if (!self.isSpringBoardRuntime) {
        return nil;
    }

    self.resolvedCurrentFirstResponder = nil;
    [[UIApplication sharedApplication] sendAction:@selector(kayokoResolveCurrentFirstResponder:)
                                               to:nil
                                             from:nil
                                         forEvent:nil];
    return self.resolvedCurrentFirstResponder;
}

- (UIResponder *)currentKayokoInputResponder {
    UIResponder *keyboardInputDelegate = [self activeKeyboardInputDelegate];
    if ([self responderIsKayokoOwned:keyboardInputDelegate]) {
        [self rememberKayokoKeyboardInput];
        return keyboardInputDelegate;
    }

    UIResponder *firstResponder = [self currentFirstResponder];
    if ([self responderIsKayokoOwned:firstResponder]) {
        [self rememberKayokoKeyboardInput];
        return firstResponder;
    }

    return nil;
}

- (BOOL)currentInputIsKayokoOwnedUpdatingLast:(BOOL)clearsLastForExternalInput {
    if (!self.isSpringBoardRuntime) {
        return NO;
    }

    BOOL foundCurrentInput = NO;
    UIResponder *keyboardInputDelegate = [self activeKeyboardInputDelegate];
    if (keyboardInputDelegate) {
        foundCurrentInput = YES;
        if ([self responderIsKayokoOwned:keyboardInputDelegate]) {
            [self rememberKayokoKeyboardInput];
            return YES;
        }
    }

    UIResponder *firstResponder = [self currentFirstResponder];
    if (firstResponder) {
        foundCurrentInput = YES;
        if ([self responderIsKayokoOwned:firstResponder]) {
            [self rememberKayokoKeyboardInput];
            return YES;
        }
    }

    if (foundCurrentInput) {
        if (clearsLastForExternalInput) {
            [self clearLastKayokoKeyboardInput];
        }
        return NO;
    }

    return NO;
}

- (BOOL)currentInputIsKayokoOwned {
    return [self currentInputIsKayokoOwnedUpdatingLast:YES];
}

- (BOOL)keyboardHideIsFromKayokoInput {
    if (!self.isSpringBoardRuntime) {
        return NO;
    }

    if ([self currentInputIsKayokoOwnedUpdatingLast:NO]) {
        return YES;
    }

    if ([self hasRecentKayokoKeyboardInput]) {
        return YES;
    }

    return NO;
}

#pragma mark - Focus Capture And Restore

- (UIResponder *)restorableKeyboardInputDelegate {
    UIResponder *keyboardInputDelegate = [self activeKeyboardInputDelegate];
    if ([self responderIsKayokoOwned:keyboardInputDelegate]) {
        return nil;
    }
    return keyboardInputDelegate;
}

- (BOOL)restoreResponder:(UIResponder *)responder {
    if ([self responderIsKayokoOwned:responder]) {
        return NO;
    }

    if (!responder) {
        return NO;
    }

    BOOL requiresKeyboardInputDelegate =
        self.isSpringBoardRuntime && responder == self.focusSession.keyboardInputDelegate;
    if (!requiresKeyboardInputDelegate) {
        if ([responder isFirstResponder]) {
            return YES;
        }

        return [responder becomeFirstResponder];
    }

    if ([self activeKeyboardInputDelegate] == responder) {
        return YES;
    }

    if ([responder isFirstResponder]) {
        [responder resignFirstResponder];
        [self makeCapturedFocusKeyWindowKeyIfNeeded:self.focusSession.keyWindow];
    }

    if (![responder becomeFirstResponder]) {
        return NO;
    }

    return [self activeKeyboardInputDelegate] == responder;
}

- (void)captureFocusSessionInKeyWindow:(UIWindow *)keyWindow {
    [self.focusSession clear];
    if (!keyWindow) {
        return;
    }

    self.focusSession.keyWindow = keyWindow;
    self.focusSession.keyboardInputDelegate = [self restorableKeyboardInputDelegate];
    self.focusSession.pasteboardChangeCount = [[UIPasteboard generalPasteboard] changeCount];
    self.focusSession.capturedPasteboardChangeCount = YES;

    HBLogDebug(@"Kayoko: captured focus pasteboard baseline changeCount=%lu keyWindow=%@",
               (unsigned long)self.focusSession.pasteboardChangeCount,
               keyWindow ? NSStringFromClass([keyWindow class]) : @"nil");
}

- (void)captureFocusSessionFromResponder:(UIResponder *)responder keyWindow:(UIWindow *)keyWindow {
    if ([self responderIsKayokoOwned:responder]) {
        return;
    }

    [self captureFocusSessionInKeyWindow:keyWindow];
    self.focusSession.firstResponder = responder;
    [self.focusSession finishCapturing];
}

- (void)captureResponderForFocusRestore:(UIResponder *)responder {
    if ([self responderIsKayokoOwned:responder]) {
        return;
    }

    self.focusSession.firstResponder = responder;
}

- (BOOL)restoreCapturedFocusSessionInKeyWindow:(UIWindow *)keyWindow {
    if (!keyWindow || !self.focusSession.hasCapturedFocusSession || ![self.focusSession matchesKeyWindow:keyWindow]) {
        return NO;
    }

    if (![self makeCapturedFocusKeyWindowKeyIfNeeded:keyWindow]) {
        return NO;
    }

    if ([self restoreResponder:self.focusSession.keyboardInputDelegate]) {
        return YES;
    }

    return [self restoreResponder:self.focusSession.firstResponder];
}

#pragma mark - Pending Paste

- (UIResponder *)capturedFocusResponderForPasteRequiringKeyboardDelegate:(BOOL *)requiresKeyboardDelegate {
    UIResponder *keyboardInputDelegate = self.focusSession.keyboardInputDelegate;
    if (keyboardInputDelegate && ![self responderIsKayokoOwned:keyboardInputDelegate]) {
        if (requiresKeyboardDelegate) {
            *requiresKeyboardDelegate = YES;
        }
        return keyboardInputDelegate;
    }

    if (requiresKeyboardDelegate) {
        *requiresKeyboardDelegate = NO;
    }
    UIResponder *firstResponder = self.focusSession.firstResponder;
    return [self responderIsKayokoOwned:firstResponder] ? nil : firstResponder;
}

- (void)postPasteWillStart {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kKayokoNotificationKeyPasteWillStart, nil, nil, YES);
}

- (BOOL)preparePasteboardForPaste {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    NSString *string = [pasteboard string];
    UIImage *image = [pasteboard image];
    BOOL canPaste = string || image;

    HBLogDebug(@"Kayoko: helper pasteboard check canPaste=%@ changeCount=%lu stringLength=%lu hasImage=%@",
               canPaste ? @"YES" : @"NO", (unsigned long)[pasteboard changeCount], (unsigned long)[string length],
               image != nil ? @"YES" : @"NO");

    return canPaste;
}

- (BOOL)pasteIntoKayokoInputResponder:(UIResponder *)responder {
    if (!responder) {
        HBLogDebug(@"Kayoko: paste into Kayoko responder skipped because responder is nil");
        return NO;
    }

    UIApplication *activeApplication = [UIApplication sharedApplication];
    if (!activeApplication || [activeApplication applicationState] != UIApplicationStateActive) {
        HBLogDebug(@"Kayoko: paste into Kayoko responder skipped because application is inactive state=%ld",
                   (long)[activeApplication applicationState]);
        return NO;
    }

    [self postPasteWillStart];
    if (![self preparePasteboardForPaste]) {
        HBLogDebug(@"Kayoko: paste into Kayoko responder skipped because pasteboard is empty responder=%@",
                   responder ? NSStringFromClass([responder class]) : @"nil");
        return NO;
    }

#if DEBUG
    BOOL didSendAction = [activeApplication sendAction:@selector(paste:) to:responder from:nil forEvent:nil];
    HBLogDebug(@"Kayoko: paste into Kayoko responder sent=%@ responder=%@", didSendAction ? @"YES" : @"NO",
               responder ? NSStringFromClass([responder class]) : @"nil");
#endif

    return YES;
}

- (BOOL)performPaste {
    UIApplication *activeApplication = [UIApplication sharedApplication];
    BOOL canPerformPaste = [self applicationCanPerformPaste:activeApplication];
    if (!self.applicationInForeground || !canPerformPaste) {
        HBLogDebug(@"Kayoko: perform paste skipped foreground=%@ canPerformPaste=%@ process=%@ state=%ld",
                   self.applicationInForeground ? @"YES" : @"NO", canPerformPaste ? @"YES" : @"NO",
                   [[NSProcessInfo processInfo] processName], (long)[activeApplication applicationState]);
        return NO;
    }

    if ([self currentInputIsKayokoOwned]) {
        HBLogDebug(@"Kayoko: perform paste skipped because current input is Kayoko-owned");
        return NO;
    }

    if (![self preparePasteboardForPaste]) {
        HBLogDebug(@"Kayoko: perform paste skipped because pasteboard is empty process=%@",
                   [[NSProcessInfo processInfo] processName]);
        return NO;
    }

    [self postPasteWillStart];

    BOOL didSendAction = [activeApplication sendAction:@selector(paste:) to:nil from:nil forEvent:nil];
    HBLogDebug(@"Kayoko: perform paste sent=%@ process=%@", didSendAction ? @"YES" : @"NO",
               [[NSProcessInfo processInfo] processName]);

    return didSendAction;
}

- (BOOL)pendingPasteIsReady {
    UIResponder *pendingResponder = self.pendingPasteSession.responder;
    if (!pendingResponder) {
        return NO;
    }

    UIResponder *activeKeyboardInputDelegate = [self activeKeyboardInputDelegate];
    if (activeKeyboardInputDelegate == pendingResponder) {
        return YES;
    }

    return !self.pendingPasteSession.requiresKeyboardDelegate && [pendingResponder isFirstResponder];
}

- (BOOL)pendingPasteboardChangeIsReady {
    if (!self.pendingPasteSession.requiresPasteboardChange) {
        return YES;
    }

    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    NSUInteger currentChangeCount = [pasteboard changeCount];
    NSUInteger baselineChangeCount = self.pendingPasteSession.pasteboardChangeCountBeforePaste;
    if (currentChangeCount == baselineChangeCount) {
        HBLogDebug(@"Kayoko: pending paste waiting for pasteboard change token=%lu baselineChangeCount=%lu "
                   @"currentChangeCount=%lu",
                   (unsigned long)self.pendingPasteSession.token, (unsigned long)baselineChangeCount,
                   (unsigned long)currentChangeCount);
        return NO;
    }

    return YES;
}

- (void)attemptPendingPaste {
    if (!self.pendingPasteSession.hasPendingPaste || !self.pendingPasteSession.canExecute) {
        return;
    }

    if ([self currentInputIsKayokoOwned]) {
        HBLogDebug(@"Kayoko: pending paste waiting because current input is Kayoko-owned token=%lu",
                   (unsigned long)self.pendingPasteSession.token);
        return;
    }

    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *activeKeyWindow = [self activeKeyWindowForApplication:application];
    BOOL pendingPasteIsReady = [self pendingPasteIsReady];

    if (!self.applicationInForeground) {
        HBLogDebug(@"Kayoko: pending paste cleared because application left foreground token=%lu",
                   (unsigned long)self.pendingPasteSession.token);
        [self.pendingPasteSession clear];
        return;
    }

    if (!self.isSpringBoardRuntime && (!activeKeyWindow || activeKeyWindow != self.pendingPasteSession.keyWindow)) {
        HBLogDebug(
            @"Kayoko: pending paste cleared because key window changed token=%lu activeWindow=%@ pendingWindow=%@",
            (unsigned long)self.pendingPasteSession.token,
            activeKeyWindow ? NSStringFromClass([activeKeyWindow class]) : @"nil",
            self.pendingPasteSession.keyWindow ? NSStringFromClass([self.pendingPasteSession.keyWindow class])
                                               : @"nil");
        [self.pendingPasteSession clear];
        return;
    }

    if (self.isSpringBoardRuntime && activeKeyWindow && activeKeyWindow != self.pendingPasteSession.keyWindow &&
        !pendingPasteIsReady) {
        HBLogDebug(@"Kayoko: pending paste waiting for SpringBoard focus token=%lu activeWindow=%@ pendingWindow=%@",
                   (unsigned long)self.pendingPasteSession.token,
                   activeKeyWindow ? NSStringFromClass([activeKeyWindow class]) : @"nil",
                   self.pendingPasteSession.keyWindow ? NSStringFromClass([self.pendingPasteSession.keyWindow class])
                                                      : @"nil");
        return;
    }

    if (!pendingPasteIsReady) {
        HBLogDebug(@"Kayoko: pending paste not ready token=%lu responder=%@ requiresKeyboardDelegate=%@",
                   (unsigned long)self.pendingPasteSession.token,
                   self.pendingPasteSession.responder ? NSStringFromClass([self.pendingPasteSession.responder class])
                                                      : @"nil",
                   self.pendingPasteSession.requiresKeyboardDelegate ? @"YES" : @"NO");
        return;
    }

    HBLogDebug(@"Kayoko: pending responder ready token=%lu responder=%@", (unsigned long)self.pendingPasteSession.token,
               self.pendingPasteSession.responder ? NSStringFromClass([self.pendingPasteSession.responder class])
                                                  : @"nil");
    [self.pendingPasteSession cancelFocusExpirationBlock];

    if (!self.isSpringBoardRuntime && ![self pendingPasteboardChangeIsReady]) {
        [self beginPendingPasteboardVisibilityWaitIfNeeded];
        [self schedulePendingPasteboardVisibilityRecheck];
        return;
    }

    [self.pendingPasteSession cancelPasteboardVisibilityWait];
    [self performPaste];
    [self.pendingPasteSession clear];
}

- (void)schedulePendingPasteCheck {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self attemptPendingPaste];
    });
}

- (void)beginPendingPasteboardVisibilityWaitIfNeeded {
    if (self.pendingPasteSession.isWaitingForPasteboardVisibility) {
        return;
    }

    self.pendingPasteSession.waitingForPasteboardVisibility = YES;
    NSUInteger pendingPasteToken = self.pendingPasteSession.token;

#if DEBUG
    NSUInteger baselineChangeCount = self.pendingPasteSession.pasteboardChangeCountBeforePaste;
    HBLogDebug(@"Kayoko: pending pasteboard visibility wait began token=%lu baselineChangeCount=%lu",
               (unsigned long)pendingPasteToken, (unsigned long)baselineChangeCount);
#endif

    __weak typeof(self) weakSelf = self;
    [self.pendingPasteSession
        schedulePasteboardVisibilityExpirationAfterDelay:kKayokoPendingPasteboardVisibilityExpirationDelay
                                                 handler:^{
                                                   __strong typeof(weakSelf) strongSelf = weakSelf;
                                                   if (!strongSelf) {
                                                       return;
                                                   }
                                                   if (!strongSelf.pendingPasteSession.hasPendingPaste ||
                                                       strongSelf.pendingPasteSession.token != pendingPasteToken ||
                                                       !strongSelf.pendingPasteSession
                                                            .isWaitingForPasteboardVisibility) {
                                                       return;
                                                   }

#if DEBUG
                                                   NSUInteger currentChangeCount =
                                                       [[UIPasteboard generalPasteboard] changeCount];
                                                   HBLogDebug(
                                                       @"Kayoko: pending pasteboard visibility wait expired token=%lu "
                                                       @"baselineChangeCount=%lu currentChangeCount=%lu",
                                                       (unsigned long)pendingPasteToken,
                                                       (unsigned long)baselineChangeCount,
                                                       (unsigned long)currentChangeCount);
#endif

                                                   [strongSelf.pendingPasteSession clear];
                                                 }];
}

- (void)schedulePendingPasteboardVisibilityRecheck {
    NSUInteger pendingPasteToken = self.pendingPasteSession.token;
    HBLogDebug(@"Kayoko: scheduled pending pasteboard visibility recheck token=%lu", (unsigned long)pendingPasteToken);

    __weak typeof(self) weakSelf = self;
    [self.pendingPasteSession
        schedulePasteboardVisibilityRecheckAfterDelay:kKayokoPendingPasteboardVisibilityRecheckDelay
                                              handler:^{
                                                __strong typeof(weakSelf) strongSelf = weakSelf;
                                                if (!strongSelf) {
                                                    return;
                                                }
                                                if (!strongSelf.pendingPasteSession.hasPendingPaste ||
                                                    strongSelf.pendingPasteSession.token != pendingPasteToken ||
                                                    !strongSelf.pendingPasteSession.isWaitingForPasteboardVisibility) {
                                                    return;
                                                }
                                                [strongSelf attemptPendingPaste];
                                              }];
}

- (BOOL)beginPendingPaste {
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *activeKeyWindow = [self keyWindowForRestoringCapturedFocusInApplication:application];
    BOOL requiresKeyboardDelegate = NO;
    UIResponder *pendingResponder =
        [self capturedFocusResponderForPasteRequiringKeyboardDelegate:&requiresKeyboardDelegate];

    if (!activeKeyWindow || !pendingResponder) {
        HBLogDebug(@"Kayoko: pending paste not created activeKeyWindow=%@ pendingResponder=%@",
                   activeKeyWindow ? NSStringFromClass([activeKeyWindow class]) : @"nil",
                   pendingResponder ? NSStringFromClass([pendingResponder class]) : @"nil");
        return NO;
    }

    [self.pendingPasteSession cancelFocusExpirationBlock];
    [self.pendingPasteSession cancelPasteboardVisibilityWait];
    self.pendingPasteSession.pendingPaste = YES;
    self.pendingPasteSession.canExecute = NO;
    self.pendingPasteSession.requiresKeyboardDelegate = requiresKeyboardDelegate;
    self.pendingPasteSession.requiresPasteboardChange =
        !self.isSpringBoardRuntime && self.focusSession.hasCapturedPasteboardChangeCount;
    self.pendingPasteSession.waitingForPasteboardVisibility = NO;
    self.pendingPasteSession.pasteboardChangeCountBeforePaste = self.focusSession.pasteboardChangeCount;
    self.pendingPasteSession.responder = pendingResponder;
    self.pendingPasteSession.keyWindow = activeKeyWindow;
    self.pendingPasteSession.token++;

    NSUInteger pendingPasteToken = self.pendingPasteSession.token;
    HBLogDebug(
        @"Kayoko: pending paste created token=%lu responder=%@ keyWindow=%@ requiresKeyboardDelegate=%@ "
        @"requiresPasteboardChange=%@ pasteboardBaseline=%lu",
        (unsigned long)pendingPasteToken, pendingResponder ? NSStringFromClass([pendingResponder class]) : @"nil",
        activeKeyWindow ? NSStringFromClass([activeKeyWindow class]) : @"nil",
        requiresKeyboardDelegate ? @"YES" : @"NO", self.pendingPasteSession.requiresPasteboardChange ? @"YES" : @"NO",
        (unsigned long)self.pendingPasteSession.pasteboardChangeCountBeforePaste);

    __weak typeof(self) weakSelf = self;
    [self.pendingPasteSession
        scheduleFocusExpirationAfterDelay:kKayokoPendingPasteFocusExpirationDelay
                                  handler:^{
                                    __strong typeof(weakSelf) strongSelf = weakSelf;
                                    if (!strongSelf) {
                                        return;
                                    }
                                    if (strongSelf.pendingPasteSession.hasPendingPaste &&
                                        strongSelf.pendingPasteSession.token == pendingPasteToken) {
                                        HBLogDebug(@"Kayoko: pending paste focus wait expired token=%lu",
                                                   (unsigned long)pendingPasteToken);
                                        [strongSelf.pendingPasteSession clear];
                                    }
                                  }];

    return YES;
}

#pragma mark - Installation

- (void)installRuntimeHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      CHLoadClass_(&UIKeyboardLayoutStar$, NSClassFromString(@"UIKeyboardLayoutStar"));
      CHHook0(UIKeyboardLayoutStar, didMoveToWindow);
      CHLoadClass_(&UIKBInputBackdropView$, NSClassFromString(@"UIKBInputBackdropView"));
      CHHook0(UIKBInputBackdropView, didMoveToWindow);
      CHLoadClass_(&UIKeyboardImpl$, NSClassFromString(@"UIKeyboardImpl"));
      CHHook1(UIKeyboardImpl, applicationDidBecomeActive);
      CHHook1(UIKeyboardImpl, applicationWillResignActive);
      CHHook1(UIKeyboardImpl, applicationWillSuspend);
      Class keyboardImplClass = NSClassFromString(@"UIKeyboardImpl");
      if (class_getInstanceMethod(keyboardImplClass, @selector(setDelegate:force:fromBecomeFirstResponder:))) {
          CHHook3(UIKeyboardImpl, setDelegate, force, fromBecomeFirstResponder);
          HBLogDebug(@"Kayoko: installed UIKeyboardImpl setDelegate:force:fromBecomeFirstResponder: hook");
      } else if (class_getInstanceMethod(keyboardImplClass, @selector(setDelegate:force:))) {
          CHHook2(UIKeyboardImpl, setDelegate, force);
          HBLogDebug(@"Kayoko: installed UIKeyboardImpl setDelegate:force: hook");
      } else if (class_getInstanceMethod(keyboardImplClass, @selector(setDelegate:))) {
          CHHook1(UIKeyboardImpl, setDelegate);
          HBLogDebug(@"Kayoko: installed UIKeyboardImpl setDelegate: hook");
      } else {
          HBLogDebug(@"Kayoko: unable to install UIKeyboardImpl setDelegate hook");
      }
    });
}

- (void)installSceneClientSettingsHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      CHLoadClass_(&FBSScene$, NSClassFromString(@"FBSScene"));
      CHHook1(FBSScene, updateClientSettingsWithBlock);
    });
}

- (void)installSpringBoardInputIsolationHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      CHLoadClass(UISearchBar);
      CHHook0(UISearchBar, resignFirstResponder);
      CHLoadClass(UITextField);
      CHHook0(UITextField, resignFirstResponder);
    });
}

- (void)installRuntimeObserversObservingWindowResign:(BOOL)observesWindowResign {
    if (self.hasInstalledObservers) {
        return;
    }
    self.installedObservers = YES;

    if (self.isAutomaticallyPasteEnabled) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                        kayokoHelperPasteNotificationCallback,
                                        (__bridge CFStringRef)kKayokoNotificationKeyHelperPaste, NULL,
                                        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDrop);

        if (!self.isSpringBoardRuntime) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(pasteboardDidChangeWithNotification:)
                                                         name:UIPasteboardChangedNotification
                                                       object:[UIPasteboard generalPasteboard]];
        }
    }

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), NULL, kayokoHelperCaptureFocusNotificationCallback,
        (__bridge CFStringRef)kKayokoNotificationKeyCoreShow, NULL,
        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), NULL, kayokoHelperCaptureFocusNotificationCallback,
        (__bridge CFStringRef)kKayokoLegacyNotificationKeyCoreShow, NULL,
        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), NULL, kayokoHelperRestoreFocusNotificationCallback,
        (__bridge CFStringRef)kKayokoNotificationKeyHelperRestoreFocus, NULL,
        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);

    self.keyboardObserver = [[KayokoKeyboardObserver alloc] initWithRuntime:self];

    if (observesWindowResign) {
        [[NSNotificationCenter defaultCenter] addObserver:self.keyboardObserver
                                                 selector:@selector(windowDidResignKey:)
                                                     name:UIWindowDidResignKeyNotification
                                                   object:nil];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self.keyboardObserver
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self.keyboardObserver
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
}

@end

#pragma mark - Responder Focus Restoration Bridge

@implementation UIResponder (KayokoFocusRestoration)

- (void)kayokoCaptureFirstResponderForFocusRestore:(id)sender {
    [[KayokoHelperRuntime sharedRuntime] captureResponderForFocusRestore:self];
}

- (void)kayokoResolveCurrentFirstResponder:(id)sender {
    [KayokoHelperRuntime sharedRuntime].resolvedCurrentFirstResponder = self;
}

@end

#pragma mark - Keyboard Observer

@interface KayokoKeyboardObserver ()
@property(nonatomic, weak, readonly) KayokoHelperRuntime *runtime;
@end

@implementation KayokoKeyboardObserver

- (instancetype)initWithRuntime:(KayokoHelperRuntime *)runtime {
    self = [super init];
    if (self) {
        _runtime = runtime;
    }
    return self;
}

- (void)windowDidResignKey:(NSNotification *)notification {
    [self.runtime windowDidResignKeyWithNotification:notification];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self.runtime keyboardWillHideWithNotification:notification];
}

- (void)keyboardDidShow:(NSNotification *)notification {
    [self.runtime keyboardDidShowWithNotification:notification];
}

@end
