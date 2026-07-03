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
#import "KayokoNotificationKeys.h"
#import "KayokoPasteboardManager.h"
#import "KayokoPreferenceKeys.h"

static NSTimeInterval const kKayokoMinimumFeedbackInterval = 0.6;

@interface UIStatusBarStyleRequest : NSObject
@property(nonatomic, assign, readonly) long long style;
@end

@interface UIApplication (KayokoPrivate)
- (UIInterfaceOrientation)_frontMostAppOrientation;
@end

@interface SBStatusBarManager : NSObject
+ (instancetype)sharedInstance;
- (UIStatusBarStyleRequest *)frontmostStatusBarStyleRequest;
@end

@interface SBWindowSceneStatusBarManager : NSObject
+ (instancetype)windowSceneStatusBarManagerForEmbeddedDisplay;
- (UIStatusBarStyleRequest *)frontmostStatusBarStyleRequest;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
@end

NS_ASSUME_NONNULL_BEGIN

@interface KayokoCoreRuntime ()

@property(nonatomic, assign, readwrite, getter=isEnabled) BOOL enabled;
@property(nonatomic, assign, readwrite) NSUInteger activationMethod;
@property(nonatomic, assign, readwrite) BOOL pasteTipsDisabled;

@property(nonatomic, strong, nullable) KayokoMainViewController *mainViewController;
@property(nonatomic, strong, nullable) NSUserDefaults *preferences;
@property(nonatomic, strong, nullable) AVAudioPlayer *clipboardFeedbackSoundPlayer;
@property(nonatomic, strong, nullable) AVAudioPlayer *pasteFeedbackSoundPlayer;

@property(nonatomic, assign) NSUInteger maximumHistoryAmount;
@property(nonatomic, assign) BOOL saveText;
@property(nonatomic, assign) BOOL saveImages;
@property(nonatomic, assign) BOOL swipeToSelectWords;
@property(nonatomic, assign) BOOL automaticallyPaste;
@property(nonatomic, assign) BOOL dismissOnOutsideTouch;
@property(nonatomic, assign) BOOL playSoundEffects;
@property(nonatomic, assign) BOOL playHapticFeedback;
@property(nonatomic, assign) NSUInteger previewLineCount;
@property(nonatomic, assign) CGFloat heightInPoints;

@property(nonatomic, assign, getter=isPasteInProgress) BOOL pasteInProgress;
@property(nonatomic, assign) NSTimeInterval lastPasteFeedbackOccurred;
@property(nonatomic, assign) NSTimeInterval lastCopyFeedbackOccurred;
@property(nonatomic, assign) BOOL pendingHeightPreferenceApply;
@property(nonatomic, assign) BOOL didRequestInitialHistoryPreload;
@property(nonatomic, assign) int lockStateToken;

@end

NS_ASSUME_NONNULL_END

@implementation KayokoCoreRuntime

+ (instancetype)sharedRuntime {
    static KayokoCoreRuntime *runtime = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      runtime = [[self alloc] initPrivate];
    });
    return runtime;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _previewLineCount = 1;
        _heightInPoints = 420;
    }
    return self;
}

- (BOOL)panelVisible {
    return self.mainViewController && ![self.mainViewController isHidden];
}

- (BOOL)fullscreenSearchActive {
    return self.panelVisible && [self.mainViewController isFullscreenSearchActive];
}

#pragma mark - Panel

- (void)installPanelInStatusBarWindow:(UIWindow *)window {
    if (self.mainViewController) {
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

    self.mainViewController = [[KayokoMainViewController alloc]
        initWithFrame:CGRectMake(0, bounds.size.height - self.heightInPoints, bounds.size.width, self.heightInPoints)];
    __weak typeof(self) weakSelf = self;
    [self.mainViewController setFocusRestoreRequestHandler:^{
      [weakSelf requestHelperFocusRestore];
    }];
    [self.mainViewController setOutsideDismissOverlayView:outsideDismissOverlayView];
    [self applyPreferencesToView];
    [window addSubview:[self.mainViewController view]];
    if (self.didRequestInitialHistoryPreload) {
        [self.mainViewController preloadHistoryIfNeeded];
    }
}

- (void)preloadInitialHistory {
    self.didRequestInitialHistoryPreload = YES;

    KayokoPasteboardManager *pasteboardManager = [KayokoPasteboardManager sharedInstance];
    [pasteboardManager warmUpHistoryAccess];

    if (self.mainViewController) {
        [self.mainViewController preloadHistoryIfNeeded];
    }
}

- (void)applyHeightPreferenceToViewApplyingWhenHidden:(BOOL)applyWhenHidden {
    if (!self.mainViewController) {
        return;
    }

    if (!applyWhenHidden && [self.mainViewController isHidden]) {
        return;
    }

    UIView *panelView = [self.mainViewController view];
    UIView *containerView = [panelView superview];
    CGRect bounds = containerView ? [containerView bounds] : [[UIScreen mainScreen] bounds];
    CGFloat height = MIN(self.heightInPoints, CGRectGetHeight(bounds));
    CGRect newFrame = CGRectMake(CGRectGetMinX(bounds), CGRectGetMaxY(bounds) - height, CGRectGetWidth(bounds), height);
    if (!CGRectEqualToRect([panelView frame], newFrame)) {
        if (!CGAffineTransformIsIdentity([panelView transform])) {
            [panelView setTransform:CGAffineTransformIdentity];
        }
        [panelView setFrame:newFrame];
        [panelView setNeedsLayout];
    }
}

- (void)applyPreferencesToView {
    if (!self.mainViewController) {
        return;
    }

    if ([self.mainViewController automaticallyPaste] != self.automaticallyPaste) {
        [self.mainViewController setAutomaticallyPaste:self.automaticallyPaste];
    }
    if ([self.mainViewController dismissOnOutsideTouch] != self.dismissOnOutsideTouch) {
        [self.mainViewController setDismissOnOutsideTouch:self.dismissOnOutsideTouch];
    }
    if ([self.mainViewController swipeToSelectWords] != self.swipeToSelectWords) {
        [self.mainViewController setSwipeToSelectWords:self.swipeToSelectWords];
    }
    if ([self.mainViewController previewLineCount] != self.previewLineCount) {
        [self.mainViewController setPreviewLineCount:self.previewLineCount];
    }
    if ([self.mainViewController shouldPlayFeedback] != self.playHapticFeedback) {
        [self.mainViewController setShouldPlayFeedback:self.playHapticFeedback];
    }

    [self applyHeightPreferenceToViewApplyingWhenHidden:YES];
}

- (void)requestHelperFocusRestore {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kKayokoNotificationKeyHelperRestoreFocus, nil, nil, YES);
}

#pragma mark - Preferences

- (void)readPasteTipPreferencesFromPreferences:(NSUserDefaults *)preferences {
    self.enabled = [[preferences objectForKey:kKayokoPreferenceKeyEnabled] boolValue];
    self.pasteTipsDisabled = [[preferences objectForKey:kKayokoPreferenceKeyDisablePasteTips] boolValue];
}

- (BOOL)refreshPasteTipPreferences {
    NSUserDefaults *preferences = [[NSUserDefaults alloc] initWithSuiteName:kKayokoPreferencesIdentifier];
    [preferences registerDefaults:@{
        kKayokoPreferenceKeyEnabled : @(kKayokoPreferenceKeyEnabledDefaultValue),
        kKayokoPreferenceKeyDisablePasteTips : @(kKayokoPreferenceKeyDisablePasteTipsDefaultValue),
    }];

    [self readPasteTipPreferencesFromPreferences:preferences];
    return self.enabled;
}

- (void)loadPreferences {
    self.preferences = [[NSUserDefaults alloc] initWithSuiteName:kKayokoPreferencesIdentifier];
    [self.preferences registerDefaults:@{
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

    [self readPasteTipPreferencesFromPreferences:self.preferences];
    self.activationMethod = [[self.preferences objectForKey:kKayokoPreferenceKeyActivationMethod] unsignedIntegerValue];
    self.maximumHistoryAmount = [KayokoPasteboardManager
        normalizedMaximumHistoryAmountForValue:[[self.preferences objectForKey:kKayokoPreferenceKeyMaximumHistoryAmount]
                                                   unsignedIntegerValue]];
    self.saveText = [[self.preferences objectForKey:kKayokoPreferenceKeySaveText] boolValue];
    self.saveImages = [[self.preferences objectForKey:kKayokoPreferenceKeySaveImages] boolValue];
    self.swipeToSelectWords = [[self.preferences objectForKey:kKayokoPreferenceKeySwipeToSelectWords] boolValue];
    self.automaticallyPaste = [[self.preferences objectForKey:kKayokoPreferenceKeyAutomaticallyPaste] boolValue];
    self.dismissOnOutsideTouch = [[self.preferences objectForKey:kKayokoPreferenceKeyDismissOnOutsideTouch] boolValue];
    BOOL ignoreRemoteReplication =
        [[self.preferences objectForKey:kKayokoPreferenceKeyIgnoreRemoteReplication] boolValue];
    self.playSoundEffects = [[self.preferences objectForKey:kKayokoPreferenceKeyPlaySoundEffects] boolValue];
    self.playHapticFeedback = [[self.preferences objectForKey:kKayokoPreferenceKeyPlayHapticFeedback] boolValue];
    self.previewLineCount = [[self.preferences objectForKey:kKayokoPreferenceKeyPreviewLineCount] unsignedIntegerValue];
    self.heightInPoints = [[self.preferences objectForKey:kKayokoPreferenceKeyHeightInPoints] doubleValue];

    KayokoPasteboardManager *pasteboardManager = [KayokoPasteboardManager sharedInstance];
    if ([pasteboardManager maximumHistoryAmount] != self.maximumHistoryAmount) {
        [pasteboardManager setMaximumHistoryAmount:self.maximumHistoryAmount];
    }
    if ([pasteboardManager saveText] != self.saveText) {
        [pasteboardManager setSaveText:self.saveText];
    }
    if ([pasteboardManager saveImages] != self.saveImages) {
        [pasteboardManager setSaveImages:self.saveImages];
    }
    if ([pasteboardManager automaticallyPaste] != self.automaticallyPaste) {
        [pasteboardManager setAutomaticallyPaste:self.automaticallyPaste];
    }
    if ([pasteboardManager ignoreRemoteReplication] != ignoreRemoteReplication) {
        [pasteboardManager setIgnoreRemoteReplication:ignoreRemoteReplication];
    }

    [self applyPreferencesToView];
}

- (void)loadHeightPreference {
    NSUserDefaults *heightPreferences = [[NSUserDefaults alloc] initWithSuiteName:kKayokoPreferencesIdentifier];
    [heightPreferences registerDefaults:@{
        kKayokoPreferenceKeyHeightInPoints : @(kKayokoPreferenceKeyHeightInPointsDefaultValue),
    }];
    self.heightInPoints = [[heightPreferences objectForKey:kKayokoPreferenceKeyHeightInPoints] doubleValue];
    if (self.pendingHeightPreferenceApply) {
        return;
    }

    self.pendingHeightPreferenceApply = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
      self.pendingHeightPreferenceApply = NO;
      [self applyHeightPreferenceToViewApplyingWhenHidden:NO];
    });
}

#pragma mark - Device State

- (BOOL)readUILocked:(BOOL *)locked {
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

- (BOOL)frontmostAppIsLandscape {
    UIApplication *application = [UIApplication sharedApplication];
    if (![application respondsToSelector:@selector(_frontMostAppOrientation)]) {
        return NO;
    }

    UIInterfaceOrientation orientation = [application _frontMostAppOrientation];
    return UIInterfaceOrientationIsLandscape(orientation);
}

- (void)startLockStateObserver {
    if (self.lockStateToken != 0) {
        return;
    }

    int status = notify_register_dispatch("com.apple.springboard.lockstate", &_lockStateToken,
                                          dispatch_get_main_queue(), ^(int token) {
                                            (void)token;
                                            [self handleLockStateNotification];
                                          });
    if (status != NOTIFY_STATUS_OK) {
        HBLogDebug(@"Kayoko: Unable to observe SpringBoard lock state: %d", status);
        self.lockStateToken = 0;
    }
}

- (void)handleLockStateNotification {
    BOOL locked = NO;
    if (![self readUILocked:&locked] || !locked) {
        return;
    }

    [self hideImmediately];
}

#pragma mark - Feedback

- (AVAudioPlayer *)audioPlayerForSound:(NSString *)soundName {
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

- (nullable AVAudioPlayer *)playFeedbackSoundWithPlayer:(nullable AVAudioPlayer *)player
                                              soundName:(NSString *)soundName {
    if (!player) {
        player = [self audioPlayerForSound:soundName];
    }

    [player setCurrentTime:0];
    [player play];
    return player;
}

- (void)playSuccessHapticFeedbackIfNeeded {
    if (self.playHapticFeedback) {
        AudioServicesPlaySystemSound(1519);
    }
}

- (void)playFailureHapticFeedbackIfNeeded {
    if (self.playHapticFeedback) {
        AudioServicesPlaySystemSound(1521);
    }
}

- (void)playPasteFeedback {
    NSTimeInterval now = CACurrentMediaTime();
    if (fabs(now - self.lastPasteFeedbackOccurred) < kKayokoMinimumFeedbackInterval) {
        return;
    }
    self.lastPasteFeedbackOccurred = now;
    if (self.playSoundEffects) {
        self.pasteFeedbackSoundPlayer = [self playFeedbackSoundWithPlayer:self.pasteFeedbackSoundPlayer
                                                                soundName:@"Paste"];
    }
    [self playSuccessHapticFeedbackIfNeeded];
}

#pragma mark - Pasteboard

- (void)markPasteWillStart {
    self.pasteInProgress = YES;
}

- (void)capturePasteboardChange {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self capturePasteboardChangeNow];
    });
}

- (void)capturePasteboardChangeNow {
    [[KayokoPasteboardManager sharedInstance] pullPasteboardChangesWithCompletion:^(BOOL didSaveAnyItem) {
      if (self.isPasteInProgress) {
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.pasteInProgress = NO;
          });
          return;
      }
      if (!didSaveAnyItem) {
          return;
      }

      NSTimeInterval now = CACurrentMediaTime();
      if (fabs(now - self.lastCopyFeedbackOccurred) < kKayokoMinimumFeedbackInterval) {
          return;
      }
      self.lastCopyFeedbackOccurred = now;
      if (self.playSoundEffects) {
          self.clipboardFeedbackSoundPlayer = [self playFeedbackSoundWithPlayer:self.clipboardFeedbackSoundPlayer
                                                                      soundName:@"Copy"];
      }
      [self playSuccessHapticFeedbackIfNeeded];
    }];
}

#pragma mark - Visibility

- (void)show {
    if (!self.mainViewController || ![self.mainViewController isHidden]) {
        return;
    }

    BOOL locked = NO;
    if ([self readUILocked:&locked] && locked) {
        [self playFailureHapticFeedbackIfNeeded];
        return;
    }

    if ([self frontmostAppIsLandscape]) {
        [self playFailureHapticFeedbackIfNeeded];
        return;
    }

    [self applyHeightPreferenceToViewApplyingWhenHidden:YES];
    [self.mainViewController applyUserInterfaceStyle:UIUserInterfaceStyleUnspecified];

    SBStatusBarManager *statusBarManager = [objc_getClass("SBStatusBarManager") sharedInstance];
    if (statusBarManager) {
        UIStatusBarStyleRequest *styleRequest = [statusBarManager frontmostStatusBarStyleRequest];
        if (styleRequest) {
            long long style = [styleRequest style];
            BOOL isKindOfDark = style == 1;
            [self.mainViewController
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
            [self.mainViewController
                applyUserInterfaceStyle:isKindOfDark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight];
        }
    }

    [self.mainViewController show];

    if (self.activationMethod & kActivationMethodDictationKey) {
        [self playSuccessHapticFeedbackIfNeeded];
    }
}

- (void)hide {
    if (self.mainViewController && ![self.mainViewController isHidden]) {
        [self.mainViewController hide];
    }
}

- (void)hideImmediately {
    if (self.mainViewController && ![self.mainViewController isHidden]) {
        [self.mainViewController hideImmediately];
    }
}

- (void)reloadHistory {
    if (self.mainViewController) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self.mainViewController handleHistoryChanged];
        });
    }
}

@end
