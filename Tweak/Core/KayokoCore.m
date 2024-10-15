//
//  KayokoCore.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoCore.h"

#import <AudioToolbox/AudioToolbox.h>
#import <CoreFoundation/CoreFoundation.h>
#import <HBLog.h>
#import <rootless.h>
#import <substrate.h>

#import "NotificationKeys.h"
#import "PasteboardManager.h"
#import "PreferenceKeys.h"
#import "Views/KayokoView.h"

KayokoView *kayokoView = nil;

NSUserDefaults *kayokoPreferences = nil;
BOOL kayokoPrefsEnabled = NO;

NSUInteger kayokoPrefsMaximumHistoryAmount = 0;
BOOL kayokoPrefsSaveText = NO;
BOOL kayokoPrefsSaveImages = NO;
BOOL kayokoPrefsAutomaticallyPaste = NO;
BOOL kayokoPrefsDisablePasteTips = NO;
BOOL kayokoPrefsPlaySoundEffects = NO;
BOOL kayokoPrefsPlayHapticFeedback = NO;

CGFloat kayokoPrefsHeightInPoints = 420;

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

/**
 * Receives the notification that the pasteboard changed from the daemon and pulls the new changes.
 */
static void kayokoCopy() {
    [[PasteboardManager sharedInstance] pullPasteboardChanges];
    if (kayokoPrefsPlaySoundEffects) {
        static dispatch_once_t onceToken;
        static SystemSoundID soundID;
        dispatch_once(&onceToken, ^{
          AudioServicesCreateSystemSoundID(
              (__bridge CFURLRef)[NSURL
                  fileURLWithPath:ROOT_PATH_NS(@"/Library/PreferenceBundles/KayokoPreferences.bundle/Copy.aiff")],
              &soundID);
        });
        AudioServicesPlaySystemSound(soundID);
    }
    if (kayokoPrefsPlayHapticFeedback) {
        AudioServicesPlaySystemSound(1519);
    }
}

/**
 * Shows the history.
 */
static void show() {
    if ([kayokoView isHidden]) {
        [kayokoView show];
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
        CGRect bounds = [[UIScreen mainScreen] bounds];
        CGRect newFrame =
            CGRectMake(0, bounds.size.height - kayokoPrefsHeightInPoints, bounds.size.width, kayokoPrefsHeightInPoints);
        [kayokoView setFrame:newFrame];
    }
}

#pragma mark - Sound effects

static void kayokoPaste() {
    if (kayokoPrefsPlaySoundEffects) {
        static dispatch_once_t onceToken;
        static SystemSoundID soundID;
        dispatch_once(&onceToken, ^{
          AudioServicesCreateSystemSoundID(
              (__bridge CFURLRef)[NSURL
                  fileURLWithPath:ROOT_PATH_NS(@"/Library/PreferenceBundles/KayokoPreferences.bundle/Paste.aiff")],
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

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                        (CFNotificationCallback)kayokoCopy,
                                        (CFStringRef)kNotificationKeyObserverPasteboardChanged, NULL,
                                        (CFNotificationSuspensionBehavior)kNilOptions);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)show,
                                        (CFStringRef)kNotificationKeyCoreShow, NULL,
                                        (CFNotificationSuspensionBehavior)kNilOptions);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)hide,
                                        (CFStringRef)kNotificationKeyCoreHide, NULL,
                                        (CFNotificationSuspensionBehavior)kNilOptions);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                        (CFNotificationCallback)reload, (CFStringRef)kNotificationKeyCoreReload, NULL,
                                        (CFNotificationSuspensionBehavior)kNilOptions);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)load_preferences,
            (CFStringRef)kNotificationKeyPreferencesReload, NULL, (CFNotificationSuspensionBehavior)kNilOptions);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                        (CFNotificationCallback)kayokoPaste, (CFStringRef)kNotificationKeyHelperPaste,
                                        NULL, (CFNotificationSuspensionBehavior)kNilOptions);

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
            (CFStringRef)kNotificationKeyPreferencesReload, NULL, (CFNotificationSuspensionBehavior)kNilOptions);

        return;
    }
}
