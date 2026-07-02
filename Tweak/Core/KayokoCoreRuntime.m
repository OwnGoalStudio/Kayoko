//
//  KayokoCoreRuntime.m
//  Kayoko
//

#import "KayokoCoreRuntime.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#import <HBLog.h>
#import <notify.h>
#import <roothide.h>

#import "Controllers/KayokoMainViewController.h"
#import "KayokoCore.h"
#import "NotificationKeys.h"
#import "PasteboardManager.h"
#import "PreferenceKeys.h"

static NSTimeInterval const kKayokoMinimumFeedbackInterval = 0.6;

static KayokoMainViewController *kayokoMainViewController = nil;
static NSUserDefaults *kayokoPreferences = nil;

static BOOL kayokoPrefsEnabled = NO;
static NSUInteger kayokoHelperPrefsActivationMethod = 0;
static NSUInteger kayokoPrefsMaximumHistoryAmount = 0;
static BOOL kayokoPrefsSaveText = NO;
static BOOL kayokoPrefsSaveImages = NO;
static BOOL kayokoPrefsSwipeToSelectWords = NO;
static BOOL kayokoPrefsAutomaticallyPaste = NO;
static BOOL kayokoPrefsDismissOnOutsideTouch = NO;
static BOOL kayokoPrefsDisablePasteTips = NO;
static BOOL kayokoPrefsPlaySoundEffects = NO;
static BOOL kayokoPrefsPlayHapticFeedback = NO;
static NSUInteger kayokoPrefsPreviewLineCount = 1;
static CGFloat kayokoPrefsHeightInPoints = 420;

static BOOL kayokoIsInPasteProgress = NO;
static NSTimeInterval kayokoLastPasteFeedbackOccurred = 0;
static NSTimeInterval kayokoLastCopyFeedbackOccurred = 0;
static AVAudioPlayer *copySoundPlayer = nil;
static AVAudioPlayer *pasteSoundPlayer = nil;
static BOOL kayokoPendingHeightPreferenceApply = NO;
static BOOL kayokoDidRequestInitialHistoryPreload = NO;
static int kayokoLockStateToken = 0;

static void kayokoCoreApplyPreferencesToView(void);

NS_ASSUME_NONNULL_BEGIN

@interface UIStatusBarStyleRequest : NSObject
@property(nonatomic, assign, readonly) long long style;
@end

@interface UIApplication (KayokoPrivate)
- (UIInterfaceOrientation)_frontMostAppOrientation;
@end

@interface SBStatusBarManager : NSObject
+ (nullable instancetype)sharedInstance;
- (nullable UIStatusBarStyleRequest *)frontmostStatusBarStyleRequest;
@end

@interface SBWindowSceneStatusBarManager : NSObject
+ (nullable instancetype)windowSceneStatusBarManagerForEmbeddedDisplay;
- (nullable UIStatusBarStyleRequest *)frontmostStatusBarStyleRequest;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
@end

NS_ASSUME_NONNULL_END

BOOL KayokoCoreEnabled(void) { return kayokoPrefsEnabled; }

NSUInteger KayokoCoreActivationMethod(void) { return kayokoHelperPrefsActivationMethod; }

BOOL KayokoCorePasteTipsDisabled(void) { return kayokoPrefsDisablePasteTips; }

BOOL KayokoCorePanelVisible(void) { return kayokoMainViewController && ![kayokoMainViewController isHidden]; }

BOOL KayokoCoreFullscreenSearchActive(void) {
    return KayokoCorePanelVisible() && [kayokoMainViewController isFullscreenSearchActive];
}

static void kayokoCoreRequestHelperFocusRestore(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kKayokoNotificationKeyHelperRestoreFocus, nil, nil, YES);
}

void KayokoCoreInstallPanelInStatusBarWindow(UIWindow *window) {
    if (kayokoMainViewController) {
        return;
    }

    CGRect bounds = [[UIScreen mainScreen] bounds];
    UIControl *outsideDismissOverlayView = [[UIControl alloc] initWithFrame:[window bounds]];
    [outsideDismissOverlayView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [outsideDismissOverlayView setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.18]];
    [outsideDismissOverlayView setAlpha:0];
    [outsideDismissOverlayView setHidden:YES];
    [outsideDismissOverlayView setUserInteractionEnabled:NO];
    [window addSubview:outsideDismissOverlayView];

    kayokoMainViewController =
        [[KayokoMainViewController alloc] initWithFrame:CGRectMake(0, bounds.size.height - kayokoPrefsHeightInPoints,
                                                                   bounds.size.width, kayokoPrefsHeightInPoints)];
    [kayokoMainViewController setFocusRestoreRequestHandler:^{
      kayokoCoreRequestHelperFocusRestore();
    }];
    [kayokoMainViewController setOutsideDismissOverlayView:outsideDismissOverlayView];
    kayokoCoreApplyPreferencesToView();
    [window addSubview:[kayokoMainViewController view]];
    if (kayokoDidRequestInitialHistoryPreload) {
        [kayokoMainViewController preloadHistoryIfNeeded];
    }
}

void KayokoCorePreloadInitialHistory(void) {
    kayokoDidRequestInitialHistoryPreload = YES;

    PasteboardManager *pasteboardManager = [PasteboardManager sharedInstance];
    [pasteboardManager warmUpHistoryAccess];

    if (kayokoMainViewController) {
        [kayokoMainViewController preloadHistoryIfNeeded];
    }
}

static void kayokoCoreApplyHeightPreferenceToView(BOOL applyWhenHidden) {
    if (!kayokoMainViewController) {
        return;
    }

    if (!applyWhenHidden && [kayokoMainViewController isHidden]) {
        return;
    }

    UIView *panelView = [kayokoMainViewController view];
    UIView *containerView = [panelView superview];
    CGRect bounds = containerView ? [containerView bounds] : [[UIScreen mainScreen] bounds];
    CGFloat height = MIN(kayokoPrefsHeightInPoints, CGRectGetHeight(bounds));
    CGRect newFrame = CGRectMake(CGRectGetMinX(bounds), CGRectGetMaxY(bounds) - height, CGRectGetWidth(bounds), height);
    if (!CGRectEqualToRect([panelView frame], newFrame)) {
        if (!CGAffineTransformIsIdentity([panelView transform])) {
            [panelView setTransform:CGAffineTransformIdentity];
        }
        [panelView setFrame:newFrame];
        [panelView setNeedsLayout];
    }
}

static void kayokoCoreApplyPreferencesToView(void) {
    if (!kayokoMainViewController) {
        return;
    }

    if ([kayokoMainViewController automaticallyPaste] != kayokoPrefsAutomaticallyPaste) {
        [kayokoMainViewController setAutomaticallyPaste:kayokoPrefsAutomaticallyPaste];
    }
    if ([kayokoMainViewController dismissOnOutsideTouch] != kayokoPrefsDismissOnOutsideTouch) {
        [kayokoMainViewController setDismissOnOutsideTouch:kayokoPrefsDismissOnOutsideTouch];
    }
    if ([kayokoMainViewController swipeToSelectWords] != kayokoPrefsSwipeToSelectWords) {
        [kayokoMainViewController setSwipeToSelectWords:kayokoPrefsSwipeToSelectWords];
    }
    if ([kayokoMainViewController previewLineCount] != kayokoPrefsPreviewLineCount) {
        [kayokoMainViewController setPreviewLineCount:kayokoPrefsPreviewLineCount];
    }
    if ([kayokoMainViewController shouldPlayFeedback] != kayokoPrefsPlayHapticFeedback) {
        [kayokoMainViewController setShouldPlayFeedback:kayokoPrefsPlayHapticFeedback];
    }

    kayokoCoreApplyHeightPreferenceToView(YES);
}

static void kayokoCoreReadPasteTipPreferences(NSUserDefaults *preferences) {
    kayokoPrefsEnabled = [[preferences objectForKey:kKayokoPreferenceKeyEnabled] boolValue];
    kayokoPrefsDisablePasteTips = [[preferences objectForKey:kKayokoPreferenceKeyDisablePasteTips] boolValue];
}

BOOL KayokoCoreRefreshPasteTipPreferences(void) {
    NSUserDefaults *preferences = [[NSUserDefaults alloc] initWithSuiteName:kKayokoPreferencesIdentifier];
    [preferences registerDefaults:@{
        kKayokoPreferenceKeyEnabled : @(kKayokoPreferenceKeyEnabledDefaultValue),
        kKayokoPreferenceKeyDisablePasteTips : @(kKayokoPreferenceKeyDisablePasteTipsDefaultValue),
    }];

    kayokoCoreReadPasteTipPreferences(preferences);
    return kayokoPrefsEnabled;
}

void KayokoCoreLoadPreferences(void) {
    kayokoPreferences = [[NSUserDefaults alloc] initWithSuiteName:kKayokoPreferencesIdentifier];
    [kayokoPreferences registerDefaults:@{
        kKayokoPreferenceKeyEnabled : @(kKayokoPreferenceKeyEnabledDefaultValue),
        kKayokoPreferenceKeyActivationMethod : @(kKayokoPreferenceKeyActivationMethodDefaultValue),
        kKayokoPreferenceKeyMaximumHistoryAmount : @(kKayokoPreferenceKeyMaximumHistoryAmountDefaultValue),
        kKayokoPreferenceKeySaveText : @(kKayokoPreferenceKeySaveTextDefaultValue),
        kKayokoPreferenceKeySaveImages : @(kKayokoPreferenceKeySaveImagesDefaultValue),
        kKayokoPreferenceKeySwipeToSelectWords : @(kKayokoPreferenceKeySwipeToSelectWordsDefaultValue),
        kKayokoPreferenceKeyAutomaticallyPaste : @(kKayokoPreferenceKeyAutomaticallyPasteDefaultValue),
        kKayokoPreferenceKeyDismissOnOutsideTouch : @(kKayokoPreferenceKeyDismissOnOutsideTouchDefaultValue),
        kKayokoPreferenceKeyDisablePasteTips : @(kKayokoPreferenceKeyDisablePasteTipsDefaultValue),
        kKayokoPreferenceKeyIgnoreRemoteReplication : @(kKayokoPreferenceKeyIgnoreRemoteReplicationDefaultValue),
        kKayokoPreferenceKeyPlaySoundEffects : @(kKayokoPreferenceKeyPlaySoundEffectsDefaultValue),
        kKayokoPreferenceKeyPlayHapticFeedback : @(kKayokoPreferenceKeyPlayHapticFeedbackDefaultValue),
        kKayokoPreferenceKeyPreviewLineCount : @(kKayokoPreferenceKeyPreviewLineCountDefaultValue),
        kKayokoPreferenceKeyHeightInPoints : @(kKayokoPreferenceKeyHeightInPointsDefaultValue),
    }];

    kayokoCoreReadPasteTipPreferences(kayokoPreferences);
    kayokoHelperPrefsActivationMethod =
        [[kayokoPreferences objectForKey:kKayokoPreferenceKeyActivationMethod] unsignedIntegerValue];
    kayokoPrefsMaximumHistoryAmount = [PasteboardManager
        normalizedMaximumHistoryAmountForValue:[[kayokoPreferences
                                                   objectForKey:kKayokoPreferenceKeyMaximumHistoryAmount]
                                                   unsignedIntegerValue]];
    kayokoPrefsSaveText = [[kayokoPreferences objectForKey:kKayokoPreferenceKeySaveText] boolValue];
    kayokoPrefsSaveImages = [[kayokoPreferences objectForKey:kKayokoPreferenceKeySaveImages] boolValue];
    kayokoPrefsSwipeToSelectWords = [[kayokoPreferences objectForKey:kKayokoPreferenceKeySwipeToSelectWords] boolValue];
    kayokoPrefsAutomaticallyPaste = [[kayokoPreferences objectForKey:kKayokoPreferenceKeyAutomaticallyPaste] boolValue];
    kayokoPrefsDismissOnOutsideTouch =
        [[kayokoPreferences objectForKey:kKayokoPreferenceKeyDismissOnOutsideTouch] boolValue];
    BOOL ignoreRemoteReplication =
        [[kayokoPreferences objectForKey:kKayokoPreferenceKeyIgnoreRemoteReplication] boolValue];
    kayokoPrefsPlaySoundEffects = [[kayokoPreferences objectForKey:kKayokoPreferenceKeyPlaySoundEffects] boolValue];
    kayokoPrefsPlayHapticFeedback = [[kayokoPreferences objectForKey:kKayokoPreferenceKeyPlayHapticFeedback] boolValue];
    kayokoPrefsPreviewLineCount =
        [[kayokoPreferences objectForKey:kKayokoPreferenceKeyPreviewLineCount] unsignedIntegerValue];
    kayokoPrefsHeightInPoints = [[kayokoPreferences objectForKey:kKayokoPreferenceKeyHeightInPoints] doubleValue];

    PasteboardManager *pasteboardManager = [PasteboardManager sharedInstance];
    if ([pasteboardManager maximumHistoryAmount] != kayokoPrefsMaximumHistoryAmount) {
        [pasteboardManager setMaximumHistoryAmount:kayokoPrefsMaximumHistoryAmount];
    }
    if ([pasteboardManager saveText] != kayokoPrefsSaveText) {
        [pasteboardManager setSaveText:kayokoPrefsSaveText];
    }
    if ([pasteboardManager saveImages] != kayokoPrefsSaveImages) {
        [pasteboardManager setSaveImages:kayokoPrefsSaveImages];
    }
    if ([pasteboardManager automaticallyPaste] != kayokoPrefsAutomaticallyPaste) {
        [pasteboardManager setAutomaticallyPaste:kayokoPrefsAutomaticallyPaste];
    }
    if ([pasteboardManager ignoreRemoteReplication] != ignoreRemoteReplication) {
        [pasteboardManager setIgnoreRemoteReplication:ignoreRemoteReplication];
    }

    kayokoCoreApplyPreferencesToView();
}

void KayokoCoreLoadHeightPreference(void) {
    NSUserDefaults *heightPreferences = [[NSUserDefaults alloc] initWithSuiteName:kKayokoPreferencesIdentifier];
    [heightPreferences registerDefaults:@{
        kKayokoPreferenceKeyHeightInPoints : @(kKayokoPreferenceKeyHeightInPointsDefaultValue),
    }];
    kayokoPrefsHeightInPoints = [[heightPreferences objectForKey:kKayokoPreferenceKeyHeightInPoints] doubleValue];
    if (kayokoPendingHeightPreferenceApply) {
        return;
    }

    kayokoPendingHeightPreferenceApply = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
      kayokoPendingHeightPreferenceApply = NO;
      kayokoCoreApplyHeightPreferenceToView(NO);
    });
}

static BOOL kayokoCoreReadUILocked(BOOL *locked) {
    Class managerClass = NSClassFromString(@"SBLockScreenManager");
    if (![managerClass respondsToSelector:@selector(sharedInstance)]) {
        return NO;
    }

    SBLockScreenManager *manager = [(id)managerClass sharedInstance];
    if (![manager respondsToSelector:@selector(isUILocked)]) {
        return NO;
    }

    if (locked) {
        *locked = [manager isUILocked];
    }
    return YES;
}

static BOOL kayokoCoreFrontmostAppIsLandscape(void) {
    UIApplication *application = [UIApplication sharedApplication];
    if (![application respondsToSelector:@selector(_frontMostAppOrientation)]) {
        return NO;
    }

    UIInterfaceOrientation orientation = [application _frontMostAppOrientation];
    return UIInterfaceOrientationIsLandscape(orientation);
}

static AVAudioPlayer *kayokoCoreAudioPlayerForSound(NSString *soundName) {
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient
                                     withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                           error:&error];
    if (error) {
        HBLogDebug(@"Kayoko: Failed to configure audio session: %@", error);
    }

    NSString *relativeSoundPath =
        [NSString stringWithFormat:@"/Library/PreferenceBundles/KayokoPreferences.bundle/%@.aiff", soundName];
    NSString *soundPath = jbroot(relativeSoundPath);
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:soundPath]
                                                                   error:&error];
    if (error) {
        HBLogDebug(@"Kayoko: Failed to load %@ sound: %@", soundName, error);
        return nil;
    }

    [player prepareToPlay];
    return player;
}

static AVAudioPlayer *kayokoCorePlayFeedbackSound(AVAudioPlayer *player, NSString *soundName) {
    if (!player) {
        player = kayokoCoreAudioPlayerForSound(soundName);
    }

    [player setCurrentTime:0];
    [player play];
    return player;
}

static void kayokoCorePlaySuccessHapticFeedbackIfNeeded(void) {
    if (kayokoPrefsPlayHapticFeedback) {
        AudioServicesPlaySystemSound(1519);
    }
}

static void kayokoCorePlayFailureHapticFeedbackIfNeeded(void) {
    if (kayokoPrefsPlayHapticFeedback) {
        AudioServicesPlaySystemSound(1521);
    }
}

void KayokoCorePasteWillStart(void) { kayokoIsInPasteProgress = YES; }

static void kayokoCoreCopyNow(void) {
    [[PasteboardManager sharedInstance] pullPasteboardChangesWithCompletion:^(BOOL didSaveAnyItem) {
      if (kayokoIsInPasteProgress) {
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            kayokoIsInPasteProgress = NO;
          });
          return;
      }
      if (!didSaveAnyItem) {
          return;
      }

      NSTimeInterval now = CACurrentMediaTime();
      if (fabs(now - kayokoLastCopyFeedbackOccurred) < kKayokoMinimumFeedbackInterval) {
          return;
      }
      kayokoLastCopyFeedbackOccurred = now;
      if (kayokoPrefsPlaySoundEffects) {
          copySoundPlayer = kayokoCorePlayFeedbackSound(copySoundPlayer, @"Copy");
      }
      kayokoCorePlaySuccessHapticFeedbackIfNeeded();
    }];
}

void KayokoCoreCopy(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      kayokoCoreCopyNow();
    });
}

void KayokoCoreShow(void) {
    if (!kayokoMainViewController || ![kayokoMainViewController isHidden]) {
        return;
    }

    BOOL locked = NO;
    if (kayokoCoreReadUILocked(&locked) && locked) {
        kayokoCorePlayFailureHapticFeedbackIfNeeded();
        return;
    }

    if (kayokoCoreFrontmostAppIsLandscape()) {
        kayokoCorePlayFailureHapticFeedbackIfNeeded();
        return;
    }

    kayokoCoreApplyHeightPreferenceToView(YES);
    [kayokoMainViewController applyUserInterfaceStyle:UIUserInterfaceStyleUnspecified];

    SBStatusBarManager *statusBarManager = [objc_getClass("SBStatusBarManager") sharedInstance];
    if (statusBarManager) {
        UIStatusBarStyleRequest *styleRequest = [statusBarManager frontmostStatusBarStyleRequest];
        if (styleRequest) {
            long long style = [styleRequest style];
            BOOL isKindOfDark = style == 1;
            [kayokoMainViewController
                applyUserInterfaceStyle:isKindOfDark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight];
        }
    }

    SBWindowSceneStatusBarManager *windowSceneStatusBarManager =
        [objc_getClass("SBWindowSceneStatusBarManager") windowSceneStatusBarManagerForEmbeddedDisplay];
    if (windowSceneStatusBarManager) {
        UIStatusBarStyleRequest *styleRequest = [windowSceneStatusBarManager frontmostStatusBarStyleRequest];
        if (styleRequest) {
            long long style = [styleRequest style];
            BOOL isKindOfDark = style == 1;
            [kayokoMainViewController
                applyUserInterfaceStyle:isKindOfDark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight];
        }
    }

    [kayokoMainViewController show];

    if (kayokoHelperPrefsActivationMethod & kActivationMethodDictationKey) {
        kayokoCorePlaySuccessHapticFeedbackIfNeeded();
    }
}

void KayokoCoreHide(void) {
    if (kayokoMainViewController && ![kayokoMainViewController isHidden]) {
        [kayokoMainViewController hide];
    }
}

void KayokoCoreHideImmediately(void) {
    if (kayokoMainViewController && ![kayokoMainViewController isHidden]) {
        [kayokoMainViewController hideImmediately];
    }
}

void KayokoCoreReload(void) {
    if (kayokoMainViewController) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [kayokoMainViewController handleHistoryChanged];
        });
    }
}

void KayokoCorePaste(void) {
    NSTimeInterval now = CACurrentMediaTime();
    if (fabs(now - kayokoLastPasteFeedbackOccurred) < kKayokoMinimumFeedbackInterval) {
        return;
    }
    kayokoLastPasteFeedbackOccurred = now;
    if (kayokoPrefsPlaySoundEffects) {
        pasteSoundPlayer = kayokoCorePlayFeedbackSound(pasteSoundPlayer, @"Paste");
    }
    kayokoCorePlaySuccessHapticFeedbackIfNeeded();
}

static void kayokoCoreHandleLockStateNotification(void) {
    BOOL locked = NO;
    if (!kayokoCoreReadUILocked(&locked) || !locked) {
        return;
    }

    KayokoCoreHideImmediately();
}

void KayokoCoreStartLockStateObserver(void) {
    if (kayokoLockStateToken != 0) {
        return;
    }

    int status = notify_register_dispatch("com.apple.springboard.lockstate", &kayokoLockStateToken,
                                          dispatch_get_main_queue(), ^(int token) {
                                            (void)token;
                                            kayokoCoreHandleLockStateNotification();
                                          });
    if (status != NOTIFY_STATUS_OK) {
        HBLogDebug(@"Kayoko: Unable to observe SpringBoard lock state: %d", status);
        kayokoLockStateToken = 0;
    }
}
