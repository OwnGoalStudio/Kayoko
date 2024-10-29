//
//  KayokoCore.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoCore.h"

#import <AudioToolbox/AudioToolbox.h>
#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>

#import <HBLog.h>
#import <libroot.h>
#import <substrate.h>

#import "NotificationKeys.h"
#import "PasteboardManager.h"
#import "PreferenceKeys.h"
#import "Views/KayokoView.h"

#define kMinimumFeedbackInterval 0.6

KayokoView *kayokoView = nil;

NSUserDefaults *kayokoPreferences = nil;
BOOL kayokoPrefsEnabled = NO;
NSUInteger kayokoHelperPrefsActivationMethod = 0;

NSUInteger kayokoPrefsMaximumHistoryAmount = 0;
BOOL kayokoPrefsSaveText = NO;
BOOL kayokoPrefsSaveImages = NO;
BOOL kayokoPrefsAutomaticallyPaste = NO;
BOOL kayokoPrefsDisablePasteTips = NO;
BOOL kayokoPrefsPlaySoundEffects = NO;
BOOL kayokoPrefsPlayHapticFeedback = NO;

CGFloat kayokoPrefsHeightInPoints = 420;

static BOOL isInPasteProgress = NO;

static NSTimeInterval lastPasteFeedbackOccurred = 0;
static NSTimeInterval lastCopyFeedbackOccurred = 0;

@interface UIStatusBarStyleRequest : NSObject
@property(nonatomic, assign, readonly) long long style;
@end

@interface SBStatusBarManager : NSObject
+ (instancetype)sharedInstance;
- (UIStatusBarStyleRequest *)frontmostStatusBarStyleRequest;
@end

@interface SBWindowSceneStatusBarManager : NSObject
+ (instancetype)windowSceneStatusBarManagerForEmbeddedDisplay;
- (UIStatusBarStyleRequest *)frontmostStatusBarStyleRequest;
@end

#pragma mark - UIStatusBarWindow class hooks

/**
 * Sets up the history view.
 *
 * Using the status bar's window is hacky, yet it's present on SpringBoard and in apps.
 * It's important to note that it runs on the SpringBoard process too, which gives us file system read/write.
 *
 * @param frame
 */
static void (*orig_UIStatusBarWindow_initWithFrame)(UIStatusBarWindow *self, SEL _cmd, CGRect frame);
static void override_UIStatusBarWindow_initWithFrame(UIStatusBarWindow *self, SEL _cmd, CGRect frame) {
    orig_UIStatusBarWindow_initWithFrame(self, _cmd, frame);

    if (!kayokoView) {
        CGRect bounds = [[UIScreen mainScreen] bounds];
        kayokoView = [[KayokoView alloc] initWithFrame:CGRectMake(0, bounds.size.height - kayokoPrefsHeightInPoints,
                                                                  bounds.size.width, kayokoPrefsHeightInPoints)];
        [kayokoView setAutomaticallyPaste:kayokoPrefsAutomaticallyPaste];
        [kayokoView setHidden:YES];
        [self addSubview:kayokoView];
    }
}

#pragma mark - Notification callbacks

static void kayokoPasteWillStart() { isInPasteProgress = YES; }

/**
 * Receives the notification that the pasteboard changed from the daemon and pulls the new changes.
 */
static void _kayokoCopy() {
    [[PasteboardManager sharedInstance] pullPasteboardChanges];
    if (isInPasteProgress) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          isInPasteProgress = NO;
        });
        return;
    }
    NSTimeInterval now = CACurrentMediaTime();
    if (fabs(now - lastCopyFeedbackOccurred) < kMinimumFeedbackInterval) {
        return;
    }
    lastCopyFeedbackOccurred = now;
    if (kayokoPrefsPlaySoundEffects) {
        static dispatch_once_t onceToken;
        static SystemSoundID soundID;
        dispatch_once(&onceToken, ^{
          AudioServicesCreateSystemSoundID(
              (__bridge CFURLRef)
                  [NSURL fileURLWithPath:JBROOT_PATH_NSSTRING(
                                             @"/Library/PreferenceBundles/KayokoPreferences.bundle/Copy.aiff")],
              &soundID);
        });
        AudioServicesPlaySystemSound(soundID);
    }
    if (kayokoPrefsPlayHapticFeedback) {
        AudioServicesPlaySystemSound(1519);
    }
}

static void kayokoCopy() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      _kayokoCopy();
    });
}

/**
 * Shows the history.
 */
static void show() {
    if ([kayokoView isHidden]) {

        [kayokoView setOverrideUserInterfaceStyle:UIUserInterfaceStyleUnspecified];

        /* iOS 15 */
        SBStatusBarManager *statusBarManager = [objc_getClass("SBStatusBarManager") sharedInstance];
        if (statusBarManager) {
            UIStatusBarStyleRequest *styleRequest = [statusBarManager frontmostStatusBarStyleRequest];
            if (styleRequest) {
                long long style = [styleRequest style];
                BOOL isKindOfDark = style == 1;
                if (isKindOfDark) {
                    [kayokoView setOverrideUserInterfaceStyle:UIUserInterfaceStyleDark];
                } else {
                    [kayokoView setOverrideUserInterfaceStyle:UIUserInterfaceStyleLight];
                }
            }
        }

        /* iOS 16 */
        SBWindowSceneStatusBarManager *windowSceneStatusBarManager =
            [objc_getClass("SBWindowSceneStatusBarManager") windowSceneStatusBarManagerForEmbeddedDisplay];
        if (windowSceneStatusBarManager) {
            UIStatusBarStyleRequest *styleRequest = [windowSceneStatusBarManager frontmostStatusBarStyleRequest];
            if (styleRequest) {
                long long style = [styleRequest style];
                BOOL isKindOfDark = style == 1;
                if (isKindOfDark) {
                    [kayokoView setOverrideUserInterfaceStyle:UIUserInterfaceStyleDark];
                } else {
                    [kayokoView setOverrideUserInterfaceStyle:UIUserInterfaceStyleLight];
                }
            }
        }

        [kayokoView show];
        if (kayokoPrefsPlayHapticFeedback && kayokoHelperPrefsActivationMethod == kActivationMethodDictationKey) {
            AudioServicesPlaySystemSound(1519);
        }
    }
}

/**
 * Hides the history.
 */
static void hide() {
    if (![kayokoView isHidden]) {
        [kayokoView hide];
    }
}

/**
 * Reloads the history.
 */
static void reload() {
    if (![kayokoView isHidden]) {
        [kayokoView reload];
    }
}

#pragma mark - Preferences

/**
 * Loads the user's preferences.
 */
static void load_preferences() {
    kayokoPreferences = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];

    [kayokoPreferences registerDefaults:@{
        kPreferenceKeyEnabled : @(kPreferenceKeyEnabledDefaultValue),
        kPreferenceKeyActivationMethod : @(kPreferenceKeyActivationMethodDefaultValue),
        kPreferenceKeyMaximumHistoryAmount : @(kPreferenceKeyMaximumHistoryAmountDefaultValue),
        kPreferenceKeySaveText : @(kPreferenceKeySaveTextDefaultValue),
        kPreferenceKeySaveImages : @(kPreferenceKeySaveImagesDefaultValue),
        kPreferenceKeyAutomaticallyPaste : @(kPreferenceKeyAutomaticallyPasteDefaultValue),
        kPreferenceKeyDisablePasteTips : @(kPreferenceKeyDisablePasteTipsDefaultValue),
        kPreferenceKeyPlaySoundEffects : @(kPreferenceKeyPlaySoundEffectsDefaultValue),
        kPreferenceKeyPlayHapticFeedback : @(kPreferenceKeyPlayHapticFeedbackDefaultValue),
        kPreferenceKeyHeightInPoints : @(kPreferenceKeyHeightInPointsDefaultValue),
    }];

    kayokoPrefsEnabled = [[kayokoPreferences objectForKey:kPreferenceKeyEnabled] boolValue];
    kayokoHelperPrefsActivationMethod =
        [[kayokoPreferences objectForKey:kPreferenceKeyActivationMethod] unsignedIntegerValue];
    kayokoPrefsMaximumHistoryAmount =
        [[kayokoPreferences objectForKey:kPreferenceKeyMaximumHistoryAmount] unsignedIntegerValue];
    kayokoPrefsSaveText = [[kayokoPreferences objectForKey:kPreferenceKeySaveText] boolValue];
    kayokoPrefsSaveImages = [[kayokoPreferences objectForKey:kPreferenceKeySaveImages] boolValue];
    kayokoPrefsAutomaticallyPaste = [[kayokoPreferences objectForKey:kPreferenceKeyAutomaticallyPaste] boolValue];
    kayokoPrefsDisablePasteTips = [[kayokoPreferences objectForKey:kPreferenceKeyDisablePasteTips] boolValue];
    kayokoPrefsPlaySoundEffects = [[kayokoPreferences objectForKey:kPreferenceKeyPlaySoundEffects] boolValue];
    kayokoPrefsPlayHapticFeedback = [[kayokoPreferences objectForKey:kPreferenceKeyPlayHapticFeedback] boolValue];
    kayokoPrefsHeightInPoints = [[kayokoPreferences objectForKey:kPreferenceKeyHeightInPoints] doubleValue];

    [[PasteboardManager sharedInstance] preparePasteboardQueue];
    [[PasteboardManager sharedInstance] setMaximumHistoryAmount:kayokoPrefsMaximumHistoryAmount];
    [[PasteboardManager sharedInstance] setSaveText:kayokoPrefsSaveText];
    [[PasteboardManager sharedInstance] setSaveImages:kayokoPrefsSaveImages];
    [[PasteboardManager sharedInstance] setAutomaticallyPaste:kayokoPrefsAutomaticallyPaste];

    if (kayokoView) {
        [kayokoView setAutomaticallyPaste:kayokoPrefsAutomaticallyPaste];
        [kayokoView setShouldPlayFeedback:kayokoPrefsPlayHapticFeedback];
        CGRect bounds = [[UIScreen mainScreen] bounds];
        CGRect newFrame =
            CGRectMake(0, bounds.size.height - kayokoPrefsHeightInPoints, bounds.size.width, kayokoPrefsHeightInPoints);
        [kayokoView setFrame:newFrame];
    }
}

#pragma mark - Sound effects

static void kayokoPaste() {
    NSTimeInterval now = CACurrentMediaTime();
    if (fabs(now - lastPasteFeedbackOccurred) < kMinimumFeedbackInterval) {
        return;
    }
    lastPasteFeedbackOccurred = now;
    if (kayokoPrefsPlaySoundEffects) {
        static dispatch_once_t onceToken;
        static SystemSoundID soundID;
        dispatch_once(&onceToken, ^{
          AudioServicesCreateSystemSoundID(
              (__bridge CFURLRef)
                  [NSURL fileURLWithPath:JBROOT_PATH_NSSTRING(
                                             @"/Library/PreferenceBundles/KayokoPreferences.bundle/Paste.aiff")],
              &soundID);
        });
        AudioServicesPlaySystemSound(soundID);
    }
    if (kayokoPrefsPlayHapticFeedback) {
        AudioServicesPlaySystemSound(1519);
    }
}

#pragma mark - Constructor

/**
 * Initializes the core.
 *
 * First it loads the preferences and continues if Kayoko is enabled.
 * Secondly it sets up the hooks.
 * Finally it registers the notification callbacks.
 */
__attribute((constructor)) static void initialize() {
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    BOOL isSpringBoard = [bundleIdentifier isEqualToString:@"com.apple.springboard"];
    if (isSpringBoard) {
        load_preferences();

        if (!kayokoPrefsEnabled) {
            return;
        }

        EnableKayokoDisablePasteTips();

        MSHookMessageEx(objc_getClass("UIStatusBarWindow"), @selector(initWithFrame:),
                        (IMP)&override_UIStatusBarWindow_initWithFrame, (IMP *)&orig_UIStatusBarWindow_initWithFrame);

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)kayokoCopy,
            CFSTR("com.apple.pasteboard.notify.changed"), NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)show,
            (CFStringRef)kNotificationKeyCoreShow, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)hide,
            (CFStringRef)kNotificationKeyCoreHide, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reload,
            (CFStringRef)kNotificationKeyCoreReload, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)load_preferences,
            (CFStringRef)kNotificationKeyPreferencesReload, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)kayokoPaste,
            (CFStringRef)kNotificationKeyHelperPaste, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)kayokoPasteWillStart,
            (CFStringRef)kNotificationKeyPasteWillStart, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);

        return;
    }

    NSArray *args = [[NSProcessInfo processInfo] arguments];
    NSString *processName = [[NSProcessInfo processInfo] processName];
    NSString *executablePath = [args firstObject];
    BOOL isDruidOrPasted =
        ([executablePath hasPrefix:@"/System/Library/"] || [executablePath hasPrefix:@"/usr/libexec/"]) &&
        ([processName isEqualToString:@"druid"] || [processName isEqualToString:@"pasted"]);
    if (isDruidOrPasted) {
        load_preferences();

        if (!kayokoPrefsEnabled) {
            return;
        }

        EnableKayokoDisablePasteTips();
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)load_preferences,
            (CFStringRef)kNotificationKeyPreferencesReload, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);

        return;
    }
}
