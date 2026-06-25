//
//  KayokoHelper.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoHelper.h"
#import "KayokoMenu.h"
#import "NotificationKeys.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"
#import "PreferenceKeys.h"

#import <CoreFoundation/CFNotificationCenter.h>
#import <Foundation/Foundation.h>
#import <libSandy.h>
#import <substrate.h>

NSUserDefaults *kayokoHelperPreferences = nil;

BOOL kayokoHelperPrefsEnabled = NO;
NSUInteger kayokoHelperPrefsActivationMethod = 0;
BOOL kayokoHelperPrefsAutomaticallyPaste = NO;

NSString *const kayokoMenuName = @"Kayoko";
NSString *const kayokoSelectorName = @"_Kayoko_OpenTools_ab2e39c7";
NSString *const kayokoSelectorSignature = @"v@:";

static BOOL shouldShowCustomSuggestions = NO;
static BOOL applicationIsInForeground = YES;

static TIAutocorrectionList *kayokoCreateAutocorrectionList(void);
static void kayokoPaste(void);
static BOOL kayokoIsKeyboardExtensionProcess(void);

#pragma mark - UIKeyboardAutocorrectionController class hooks

/**
 * Updates the prediction bar with the original or custom items.
 *
 * This method usage only works on iOS 14 or lower.
 *
 * @param textSuggestionList The list that is used to update the prediciton bar with.
 */
static void (*orig_UIKeyboardAutocorrectionController_setTextSuggestionList)(UIKeyboardAutocorrectionController *self,
                                                                             SEL _cmd,
                                                                             TIAutocorrectionList *textSuggestionList);
static void
override_UIKeyboardAutocorrectionController_setTextSuggestionList(UIKeyboardAutocorrectionController *self, SEL _cmd,
                                                                  TIAutocorrectionList *textSuggestionList) {
    if (shouldShowCustomSuggestions) {
        orig_UIKeyboardAutocorrectionController_setTextSuggestionList(self, _cmd, kayokoCreateAutocorrectionList());
    } else {
        orig_UIKeyboardAutocorrectionController_setTextSuggestionList(self, _cmd, textSuggestionList);
    }
}

/**
 * Updates the prediction bar with the original or custom items.
 *
 * This method usage only works on iOS 15 or above.
 *
 * @param autoCorrectionList The list that is used to update the prediciton bar with.
 */
static void (*orig_UIKeyboardAutocorrectionController_setAutocorrectionList)(UIKeyboardAutocorrectionController *self,
                                                                             SEL _cmd,
                                                                             TIAutocorrectionList *autoCorrectionList);
static void
override_UIKeyboardAutocorrectionController_setAutocorrectionList(UIKeyboardAutocorrectionController *self, SEL _cmd,
                                                                  TIAutocorrectionList *autoCorrectionList) {
    if (shouldShowCustomSuggestions) {
        orig_UIKeyboardAutocorrectionController_setAutocorrectionList(self, _cmd, kayokoCreateAutocorrectionList());
    } else {
        orig_UIKeyboardAutocorrectionController_setAutocorrectionList(self, _cmd, autoCorrectionList);
    }
}

/**
 * Creates a list with custom prediction bar items.
 *
 * Each item has Kayoko's package id set as its bundle identifier to identify them later on.
 *
 * @return The list of custom items.
 */
static TIAutocorrectionList *kayokoCreateAutocorrectionList() {
    NSArray *labels = @[ @"History", @"Copy", @"Paste" ];
    NSMutableArray *candidates = [[NSMutableArray alloc] init];
    for (NSString *label in labels) {
        TIZephyrCandidate *candidate = [[objc_getClass("TIZephyrCandidate") alloc] init];
        [candidate setLabel:[[PasteboardManager localizationBundle] localizedStringForKey:label
                                                                                    value:nil
                                                                                    table:@"Tweak"]];
        [candidate setCandidate:[NSString stringWithFormat:@"{kayoko-%@}", label]];
        [candidate setFromBundleId:@"codes.aurora.kayoko"];
        [candidates addObject:candidate];
    }

    return [objc_getClass("TIAutocorrectionList") listWithAutocorrection:nil predictions:candidates emojiList:nil];
}

#pragma mark - UIPredictionViewController class hooks

/**
 * Handles the selection of a prediction bar item.
 *
 * @see kayokoCreateAutocorrectionList to learn how the items are identified.
 *
 * @param predictionView The prediction bar on which the item was selected.
 * @param candidate The item that was selected.
 */
static void (*orig_UIPredictionViewController_predictionView_didSelectCandidate)(UIPredictionViewController *self,
                                                                                 SEL _cmd,
                                                                                 TUIPredictionView *predictionView,
                                                                                 TIZephyrCandidate *candidate);
static void override_UIPredictionViewController_predictionView_didSelectCandidate(UIPredictionViewController *self,
                                                                                  SEL _cmd,
                                                                                  TUIPredictionView *predictionView,
                                                                                  TIZephyrCandidate *candidate) {
    if ([candidate respondsToSelector:@selector(fromBundleId)] &&
        [[candidate fromBundleId] isEqualToString:@"codes.aurora.kayoko"]) {
        if ([[candidate candidate] isEqualToString:@"{kayoko-History}"]) {
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                 (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
        } else if ([[candidate candidate] isEqualToString:@"{kayoko-Copy}"]) {
            if (@available(iOS 15.0, *)) {
                UIKBInputDelegateManager *delegateManager =
                    [[objc_getClass("UIKeyboardImpl") activeInstance] inputDelegateManager];
                UITextRange *range = [delegateManager selectedTextRange];
                NSString *text = [delegateManager textInRange:range];

                if (![text isEqualToString:@""]) {
                    [[UIPasteboard generalPasteboard] setString:text];
                }
            } else {
                id delegate = [[objc_getClass("UIKeyboardImpl") activeInstance] inputDelegate];
                UITextRange *range = [delegate selectedTextRange];
                NSString *text = [delegate textInRange:range];

                if (![text isEqualToString:@""]) {
                    [[UIPasteboard generalPasteboard] setString:text];
                }
            }
        } else if ([[candidate candidate] isEqualToString:@"{kayoko-Paste}"]) {
            kayokoPaste();
        }
    } else {
        orig_UIPredictionViewController_predictionView_didSelectCandidate(self, _cmd, predictionView, candidate);
    }
}

/**
 * Makes the prediction bar always visible.
 *
 * @param delegate
 * @param inputViews
 *
 * @return Whether the prediction bar should be visible or not.
 */
static BOOL override_UIPredictionViewController_isVisibleForInputDelegate_inputViews(UIPredictionViewController *self,
                                                                                     SEL _cmd, id delegate,
                                                                                     id inputViews) {
    return YES;
}

#pragma mark - UIKeyboardLayoutStar class hooks

/**
 * Updates the prediction bar with the custom items once the user entered the numeric keyboard.
 *
 * @param name The name of the keyplane that was switched to.
 */
static void (*orig_UIKeyboardLayoutStar_setKeyplaneName)(UIKeyboardLayoutStar *self, SEL _cmd, NSString *name);
static void override_UIKeyboardLayoutStar_setKeyplaneName(UIKeyboardLayoutStar *self, SEL _cmd, NSString *name) {
    orig_UIKeyboardLayoutStar_setKeyplaneName(self, _cmd, name);

    shouldShowCustomSuggestions = [name isEqualToString:@"numbers-and-punctuation"] ||
                                  [name isEqualToString:@"numbers-and-punctuation-alternate"];

    if (@available(iOS 15.0, *)) {
        [[[objc_getClass("UIKeyboardImpl") activeInstance] autocorrectionController] setAutocorrectionList:nil];
    } else {
        [[[objc_getClass("UIKeyboardImpl") activeInstance] autocorrectionController] setTextSuggestionList:nil];
    }
}

/**
 * Shows the history with the dictation button.
 *
 * This method usage only works on devices with the old keyboard.
 * The modern keyboard has a specific dictation icon on the so-called "Keyboard Dock".
 *
 * @param point
 *
 * @return The key that was pressed.
 */
static UIKBTree *(*orig_UIKeyboardLayoutStar_keyHitTest)(UIKeyboardLayoutStar *self, SEL _cmd, CGPoint point);
static UIKBTree *override_UIKeyboardLayoutStar_keyHitTest(UIKeyboardLayoutStar *self, SEL _cmd, CGPoint point) {
    UIKBTree *orig = orig_UIKeyboardLayoutStar_keyHitTest(self, _cmd, point);

    // Unset the original action and tell the core to show the history.
    if ([[orig name] isEqualToString:@"Dictation-Key"]) {
        [[orig properties] setValue:@(0) forKey:@"KBinteractionType"];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
    }

    return orig;
}

/**
 * Hides the history when they keyboard was dismissed, if the history is already visible.
 */
static void (*orig_UIKeyboardLayoutStar_didMoveToWindow)(UIKeyboardLayoutStar *self, SEL _cmd);
static void override_UIKeyboardLayoutStar_didMoveToWindow(UIKeyboardLayoutStar *self, SEL _cmd) {
    orig_UIKeyboardLayoutStar_didMoveToWindow(self, _cmd);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreHide, nil, nil, YES);
}

/**
 * Hides the history when they keyboard was dismissed, if the history is already visible.
 */
static void (*orig_UIKBInputBackdropView_didMoveToWindow)(UIKBInputBackdropView *self, SEL _cmd);
static void override_UIKBInputBackdropView_didMoveToWindow(UIKBInputBackdropView *self, SEL _cmd) {
    orig_UIKBInputBackdropView_didMoveToWindow(self, _cmd);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreHide, nil, nil, YES);
}

#pragma mark - UIKeyboardImpl class hooks

/**
 * Makes the dictation key always show.
 *
 * This applies to devices using the modern keyboard.
 * @see keyHitTest for a more in-depth explanation.
 *
 * @return Whether the dictation key should be shown.
 */
static BOOL override_UIKeyboardImpl_shouldShowDictationKey(UIKeyboardImpl *self, SEL _cmd) { return YES; }

/**
 * Notes that the app will become active.
 *
 * Knowing that, we can prevent pasting from happening in apps that became inactive.
 */
static void (*orig_UIKeyboardImpl_applicationDidBecomeActive)(UIKeyboardImpl *self, SEL _cmd, BOOL didBecomeActive);
static void override_UIKeyboardImpl_applicationDidBecomeActive(UIKeyboardImpl *self, SEL _cmd, BOOL didBecomeActive) {
    orig_UIKeyboardImpl_applicationDidBecomeActive(self, _cmd, didBecomeActive);
    applicationIsInForeground = YES;
}

/**
 * Notes that the app will resign active.
 *
 * @see applicationDidBecomeActive why to save the state of an app.
 */
static void (*orig_UIKeyboardImpl_applicationWillResignActive)(UIKeyboardImpl *self, SEL _cmd, BOOL willResignActive);
static void override_UIKeyboardImpl_applicationWillResignActive(UIKeyboardImpl *self, SEL _cmd, BOOL willResignActive) {
    orig_UIKeyboardImpl_applicationWillResignActive(self, _cmd, willResignActive);
    applicationIsInForeground = NO;
}

/**
 * Notes that the app will suspend.
 *
 * @see applicationDidBecomeActive why to save the state of an app.
 */
static void (*orig_UIKeyboardImpl_applicationWillSuspend)(UIKeyboardImpl *self, SEL _cmd, BOOL willSuspend);
static void override_UIKeyboardImpl_applicationWillSuspend(UIKeyboardImpl *self, SEL _cmd, BOOL willSuspend) {
    orig_UIKeyboardImpl_applicationWillSuspend(self, _cmd, willSuspend);
    applicationIsInForeground = NO;
}

#pragma mark - UISystemKeyboardDockController class hooks

/**
 * Shows the history with the dictation button.
 *
 * This method usage only works on devices with the modern keyboard.
 * @see keyHitTest for a more in-depth explanation.
 *
 * @param event
 */
static void
override_UISystemKeyboardDockController_dictationItemButtonWasPressed_withEvent(UISystemKeyboardDockController *self,
                                                                                SEL _cmd, UIEvent *event) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
}

#pragma mark - _UIEditMenuPresentation class hooks (iOS 16+)

static void (*orig__UIEditMenuPresentation_displayMenu_configuration_)(id, SEL, UIMenu *, id);
static void override__UIEditMenuPresentation_displayMenu_configuration_(id self, SEL _cmd, UIMenu *menu,
                                                                        id configuration) {
    NSMutableArray *build = [NSMutableArray new];
    for (id item in [menu children]) {
        if (KayokoMenuItemIsWritingTool(item)) {
            continue;
        }
        if (![item isKindOfClass:[UIMenu class]]) {
            [build addObject:item];
            continue;
        }
        UIMenu *submenu = item;
        if (![submenu.identifier isEqualToString:KayokoAppleMenuIdentifier()]) {
            [build addObject:submenu];
            continue;
        }
        NSMutableArray *rebuildAppleEditMenu = [submenu.children mutableCopy];
        [rebuildAppleEditMenu addObject:KayokoMenuItemUICommand()];
        UIMenu *rebuildAppleMenu = [submenu menuByReplacingChildren:rebuildAppleEditMenu];
        [build addObject:rebuildAppleMenu];
    }
    UIMenu *newMenu = [menu menuByReplacingChildren:build];
    orig__UIEditMenuPresentation_displayMenu_configuration_(self, _cmd, newMenu, configuration);
}

#pragma mark - UICalloutBar class hooks (iOS 15)

static void (*orig_UICalloutBar_setExtraItems_)(UICalloutBar *, SEL, NSArray<UIMenuItem *> *);
static void override_UICalloutBar_setExtraItems_(UICalloutBar *self, SEL _cmd, NSArray<UIMenuItem *> *items) {
    NSMutableArray<UIMenuItem *> *newItems = [NSMutableArray arrayWithCapacity:items.count];
    for (UIMenuItem *item in items) {
        NSString *selectorName = NSStringFromSelector(item.action);
        if ([selectorName isEqualToString:kayokoSelectorName]) {
            item.action = NSSelectorFromString(@"__kayoko_dummy__");
        }
        [newItems addObject:item];
    }
    orig_UICalloutBar_setExtraItems_(self, _cmd, [newItems copy]);
}

static void (*orig_UICalloutBar_updateAvailableButtons)(UICalloutBar *, SEL);
static void override_UICalloutBar_updateAvailableButtons(UICalloutBar *self, SEL _cmd) {
    Class cbsbdCls = NSClassFromString(@"_UICalloutBarSystemButtonDescription");
    if (!cbsbdCls || ![cbsbdCls respondsToSelector:@selector(buttonDescriptionWithTitle:action:type:)]) {
        return orig_UICalloutBar_updateAvailableButtons(self, _cmd);
    }

    UIMenuItem *kayokoNowItem = KayokoMenuItem();
    _UICalloutBarSystemButtonDescription *buttonDescription =
        [cbsbdCls buttonDescriptionWithTitle:kayokoNowItem.title
                                      action:NSSelectorFromString(kayokoSelectorName)
                                        type:1];

    if (!buttonDescription) {
        return orig_UICalloutBar_updateAvailableButtons(self, _cmd);
    }

    Ivar msbd = class_getInstanceVariable(object_getClass(self), "m_systemButtonDescriptions");
    if (!msbd) {
        return orig_UICalloutBar_updateAvailableButtons(self, _cmd);
    }

    NSMutableArray *buttonDescriptions = object_getIvar(self, msbd);
    for (_UICalloutBarSystemButtonDescription *description in buttonDescriptions) {
        if (!description.action) {
            continue;
        }
        NSString *selectorName = NSStringFromSelector(description.action);
        if ([selectorName isEqualToString:NSStringFromSelector(buttonDescription.action)]) {
            return orig_UICalloutBar_updateAvailableButtons(self, _cmd);
        }
    }

    NSInteger insertIndex = NSNotFound;
    NSInteger currentIndex = 0;
    for (_UICalloutBarSystemButtonDescription *description in buttonDescriptions) {
        if (!description.action) {
            continue;
        }
        if ([NSStringFromSelector(description.action) hasPrefix:@"_"]) {
            insertIndex = currentIndex;
            break;
        }
        currentIndex++;
    }

    if (insertIndex == 0) {
        return orig_UICalloutBar_updateAvailableButtons(self, _cmd);
    }

    if (insertIndex == NSNotFound) {
        [buttonDescriptions addObject:buttonDescription];
    } else {
        [buttonDescriptions insertObject:buttonDescription atIndex:insertIndex];
    }

    return orig_UICalloutBar_updateAvailableButtons(self, _cmd);
}

#pragma mark - UIResponder additions

static void addon_UIResponder_openKayoko(id self, SEL _cmd) {
    dispatch_async(dispatch_get_main_queue(), ^{
      CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                           (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
    });
}

static BOOL kayokoApplicationHasActiveKeyWindow(UIApplication *application) {
    if (!application || [application applicationState] != UIApplicationStateActive) {
        return NO;
    }

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [application connectedScenes]) {
            if ([scene activationState] != UISceneActivationStateForegroundActive ||
                ![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            for (UIWindow *window in [(UIWindowScene *)scene windows]) {
                if ([window isKeyWindow]) {
                    return YES;
                }
            }
        }

        return NO;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIWindow *keyWindow = [application keyWindow];
#pragma clang diagnostic pop
    return keyWindow && [keyWindow isKeyWindow];
}

#pragma mark - Notification callbacks

/**
 * Pastes the last copied item from the history.
 */
static void kayokoPaste() {
    if (!applicationIsInForeground) {
        return;
    }

    UIApplication *application = [UIApplication sharedApplication];
    if (!kayokoApplicationHasActiveKeyWindow(application)) {
        return;
    }

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyPasteWillStart, nil, nil, YES);

    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];

    // Get the latest copied item if the pasteboard cleared itself.
    // The pasteboard clears itself after inactivity.
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

    [application sendAction:@selector(paste:) to:nil from:nil forEvent:nil];
}

@interface KayokoKeyboardObserver : NSObject
@end

@implementation KayokoKeyboardObserver

- (void)windowDidResignKey:(NSNotification *)notification {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreHide, nil, nil, YES);
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    BOOL isLocalKeyboard = [userInfo[UIKeyboardIsLocalUserInfoKey] boolValue];
    if (!isLocalKeyboard) {
        return;
    }

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreHide, nil, nil, YES);
}

@end

#pragma mark - Preferences

/**
 * Loads the user's preferences.
 */
static void load_preferences() {
    kayokoHelperPreferences = [[NSUserDefaults alloc]
        initWithSuiteName:[NSString
                              stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", kPreferencesIdentifier]];

#if THEOS_PACKAGE_SCHEME_ROOTHIDE
    libSandy_applyProfile("Kayoko_RootHide");
#else
    libSandy_applyProfile("Kayoko");
#endif

    [kayokoHelperPreferences registerDefaults:@{
        kPreferenceKeyEnabled : @(kPreferenceKeyEnabledDefaultValue),
        kPreferenceKeyActivationMethod : @(kPreferenceKeyActivationMethodDefaultValue),
        kPreferenceKeyAutomaticallyPaste : @(kPreferenceKeyAutomaticallyPasteDefaultValue)
    }];

    kayokoHelperPrefsEnabled = [[kayokoHelperPreferences objectForKey:kPreferenceKeyEnabled] boolValue];
    kayokoHelperPrefsActivationMethod =
        [[kayokoHelperPreferences objectForKey:kPreferenceKeyActivationMethod] unsignedIntegerValue];
    kayokoHelperPrefsAutomaticallyPaste =
        [[kayokoHelperPreferences objectForKey:kPreferenceKeyAutomaticallyPaste] boolValue];
}

#pragma mark - Constructor

static BOOL kayokoIsKeyboardExtensionProcess() {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *bundlePath = [mainBundle bundlePath];
    BOOL isPluginBundle = [[bundlePath pathExtension] isEqualToString:@"appex"] ||
                          [bundlePath rangeOfString:@"/PlugIns/"].location != NSNotFound;
    if (!isPluginBundle) {
        return NO;
    }

    NSDictionary *extensionInfo = [[mainBundle infoDictionary] objectForKey:@"NSExtension"];
    NSString *extensionPointIdentifier = [extensionInfo objectForKey:@"NSExtensionPointIdentifier"];
    return [extensionPointIdentifier isEqualToString:@"com.apple.keyboard-service"];
}

/**
 * Initializes the helper.
 *
 * First it loads the preferences and continues if Kayoko is enabled.
 * Secondly it checks if the helper should run in the injected process.
 * Finally it sets up the hooks.
 */
__attribute((constructor)) static void initialize() {
    load_preferences();

    if (!kayokoHelperPrefsEnabled) {
        return;
    }

    if (![NSProcessInfo processInfo]) {
        return;
    }

    NSString *processName = [[NSProcessInfo processInfo] processName];
    BOOL isSpringBoard = [@"SpringBoard" isEqualToString:processName];
    BOOL isKeyboardExtension = kayokoIsKeyboardExtensionProcess();

    BOOL shouldLoad = NO;
    NSArray *args = [[objc_getClass("NSProcessInfo") processInfo] arguments];
    NSUInteger count = [args count];
    if (count != 0) {
        NSString *executablePath = args[0];
        if (executablePath) {
            NSString *processName = [executablePath lastPathComponent];
            BOOL isApplication = [executablePath rangeOfString:@"/Application/"].location != NSNotFound ||
                                 [executablePath rangeOfString:@"/Applications/"].location != NSNotFound;
            BOOL isFileProvider = [[processName lowercaseString] rangeOfString:@"fileprovider"].location != NSNotFound;
            BOOL skip = [processName isEqualToString:@"AdSheet"] || [processName isEqualToString:@"CoreAuthUI"] ||
                        [processName isEqualToString:@"InCallService"] ||
                        [processName isEqualToString:@"MessagesNotificationViewService"];
            if (((!isFileProvider && isApplication && !skip) || isSpringBoard) &&
                ([executablePath rangeOfString:@".appex/"].location == NSNotFound || isKeyboardExtension)) {
                shouldLoad = YES;
            }
        }
    }

    if (!shouldLoad) {
        return;
    }

    applicationIsInForeground = [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;

    if (isKeyboardExtension) {
        if (kayokoHelperPrefsActivationMethod & kActivationMethodSwipeUp) {
            EnableKayokoActivationSwipeUpForKeyboardExtension();
        }
        return;
    }

    // Prediction Bar
    if (kayokoHelperPrefsActivationMethod & kActivationMethodPredictionBar) {
        if (@available(iOS 15.0, *)) {
            MSHookMessageEx(objc_getClass("UIKeyboardAutocorrectionController"), @selector(setAutocorrectionList:),
                            (IMP)&override_UIKeyboardAutocorrectionController_setAutocorrectionList,
                            (IMP *)&orig_UIKeyboardAutocorrectionController_setAutocorrectionList);
        } else {
            MSHookMessageEx(objc_getClass("UIKeyboardAutocorrectionController"), @selector(setTextSuggestionList:),
                            (IMP)&override_UIKeyboardAutocorrectionController_setTextSuggestionList,
                            (IMP *)&orig_UIKeyboardAutocorrectionController_setTextSuggestionList);
        }
        MSHookMessageEx(objc_getClass("UIPredictionViewController"), @selector(isVisibleForInputDelegate:inputViews:),
                        (IMP)&override_UIPredictionViewController_isVisibleForInputDelegate_inputViews, (IMP *)nil);
        MSHookMessageEx(objc_getClass("UIKeyboardLayoutStar"), @selector(setKeyplaneName:),
                        (IMP)&override_UIKeyboardLayoutStar_setKeyplaneName,
                        (IMP *)&orig_UIKeyboardLayoutStar_setKeyplaneName);
        MSHookMessageEx(objc_getClass("UIPredictionViewController"), @selector(predictionView:didSelectCandidate:),
                        (IMP)&override_UIPredictionViewController_predictionView_didSelectCandidate,
                        (IMP *)&orig_UIPredictionViewController_predictionView_didSelectCandidate);
    }

    // Dictation Key
    if (kayokoHelperPrefsActivationMethod & kActivationMethodDictationKey) {
        EnableKayokoActivationDictation();
        MSHookMessageEx(objc_getClass("UISystemKeyboardDockController"),
                        @selector(dictationItemButtonWasPressed:withEvent:),
                        (IMP)&override_UISystemKeyboardDockController_dictationItemButtonWasPressed_withEvent, nil);
        MSHookMessageEx(objc_getClass("UIKeyboardImpl"), @selector(shouldShowDictationKey),
                        (IMP)&override_UIKeyboardImpl_shouldShowDictationKey, nil);
        MSHookMessageEx(objc_getClass("UIKeyboardLayoutStar"), @selector(keyHitTest:),
                        (IMP)&override_UIKeyboardLayoutStar_keyHitTest, (IMP *)&orig_UIKeyboardLayoutStar_keyHitTest);
    }

    // Input Switcher
    if (kayokoHelperPrefsActivationMethod & kActivationMethodInputSwitcher) {
        EnableKayokoActivationGlobe();
    }

    // One-Finger Swipe Up
    if (kayokoHelperPrefsActivationMethod & kActivationMethodSwipeUp) {
        EnableKayokoActivationSwipeUp();
    }

    // Callout Bar
    if (kayokoHelperPrefsActivationMethod & kActivationMethodCalloutBar) {
        class_addMethod(NSClassFromString(@"UIResponder"), NSSelectorFromString(kayokoSelectorName),
                        (IMP)addon_UIResponder_openKayoko, "v@:");

        if (@available(iOS 16, *)) {
            Class targetCls = NSClassFromString(@"_UIEditMenuContentPresentation");
            if (!targetCls) {
                targetCls = NSClassFromString(@"_UIEditMenuPresentation");
            }
            MSHookMessageEx(targetCls, @selector(displayMenu:configuration:),
                            (IMP)override__UIEditMenuPresentation_displayMenu_configuration_,
                            (IMP *)&orig__UIEditMenuPresentation_displayMenu_configuration_);
        } else {
            MSHookMessageEx(NSClassFromString(@"UICalloutBar"), @selector(setExtraItems:),
                            (IMP)override_UICalloutBar_setExtraItems_, (IMP *)&orig_UICalloutBar_setExtraItems_);
            MSHookMessageEx(NSClassFromString(@"UICalloutBar"), @selector(updateAvailableButtons),
                            (IMP)override_UICalloutBar_updateAvailableButtons,
                            (IMP *)&orig_UICalloutBar_updateAvailableButtons);
        }
    }

    MSHookMessageEx(objc_getClass("UIKeyboardLayoutStar"), @selector(didMoveToWindow),
                    (IMP)&override_UIKeyboardLayoutStar_didMoveToWindow,
                    (IMP *)&orig_UIKeyboardLayoutStar_didMoveToWindow);
    MSHookMessageEx(objc_getClass("UIKBInputBackdropView"), @selector(didMoveToWindow),
                    (IMP)&override_UIKBInputBackdropView_didMoveToWindow,
                    (IMP *)&orig_UIKBInputBackdropView_didMoveToWindow);
    MSHookMessageEx(objc_getClass("UIKeyboardImpl"), @selector(applicationDidBecomeActive:),
                    (IMP)&override_UIKeyboardImpl_applicationDidBecomeActive,
                    (IMP *)&orig_UIKeyboardImpl_applicationDidBecomeActive);
    MSHookMessageEx(objc_getClass("UIKeyboardImpl"), @selector(applicationWillResignActive:),
                    (IMP)&override_UIKeyboardImpl_applicationWillResignActive,
                    (IMP *)&orig_UIKeyboardImpl_applicationWillResignActive);
    MSHookMessageEx(objc_getClass("UIKeyboardImpl"), @selector(applicationWillSuspend:),
                    (IMP)&override_UIKeyboardImpl_applicationWillSuspend,
                    (IMP *)&orig_UIKeyboardImpl_applicationWillSuspend);

    if (kayokoHelperPrefsAutomaticallyPaste) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                        (CFNotificationCallback)kayokoPaste, (CFStringRef)kNotificationKeyHelperPaste,
                                        NULL, (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDrop);
    }

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
}
