//
//  KayokoPreferenceKeys.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, ActivationMethod) {
    kActivationMethodPredictionBar = 1 << 0,
    kActivationMethodDictationKey = 1 << 1,
    kActivationMethodInputSwitcher = 1 << 2,
    kActivationMethodCalloutBar = 1 << 3,
    kActivationMethodSwipeUp = 1 << 4,
    kActivationMethodExternalKeyboard = 1 << 5
};

typedef NS_ENUM(NSUInteger, KayokoAutomaticPasteMode) {
    kKayokoAutomaticPasteModeClassic = 0,
    kKayokoAutomaticPasteModeSimulated = 1,
    kKayokoAutomaticPasteModeAutomatic = 2
};

typedef NS_ENUM(NSUInteger, KayokoAutomaticPromotionMode) {
    kKayokoAutomaticPromotionModeOff = 0,
    kKayokoAutomaticPromotionModeHistoryOnly = 1,
    kKayokoAutomaticPromotionModeAlways = 2
};

typedef NS_ENUM(NSUInteger, KayokoGestureRecognizerMode) {
    kKayokoGestureRecognizerModeClassic = 0,
    kKayokoGestureRecognizerModeSystem = 1
};

typedef NS_ENUM(NSUInteger, KayokoInitialViewMode) {
    kKayokoInitialViewModeHistory = 0,
    kKayokoInitialViewModeFavorites = 1,
    kKayokoInitialViewModePreviousSelection = 2
};

typedef NS_ENUM(NSUInteger, KayokoItemDetailsMode) {
    kKayokoItemDetailsModeOff = 0,
    kKayokoItemDetailsModeImagesOnly = 1,
    kKayokoItemDetailsModeAll = 2
};

static NSString *const kKayokoPreferencesIdentifier = @"com.82flex.kayoko.preferences";

static NSString *const kKayokoPreferenceKeyEnabled = @"Enabled";
static NSString *const kKayokoPreferenceKeyMaximumHistoryAmount = @"MaximumHistoryAmount";
static NSString *const kKayokoPreferenceKeySaveText = @"SaveText";
static NSString *const kKayokoPreferenceKeySaveImages = @"SaveImages";
static NSString *const kKayokoPreferenceKeySwipeToSelectWords = @"SwipeToSelectWords";
static NSString *const kKayokoPreferenceKeyActivationMethod = @"ActivationMethod";
static NSString *const kKayokoPreferenceKeyGestureRecognizerMode = @"GestureRecognizerMode";
static NSString *const kKayokoPreferenceKeyAutomaticallyPaste = @"AutomaticallyPaste";
static NSString *const kKayokoPreferenceKeyAutomaticPasteMode = @"AutomaticPasteMode";
static NSString *const kKayokoPreferenceKeyAutomaticPromotionMode = @"AutomaticPromotionMode";
static NSString *const kKayokoPreferenceKeyInitialViewMode = @"InitialViewMode";
static NSString *const kKayokoPreferenceKeyDismissOnOutsideTouch = @"DismissOnOutsideTouch";
static NSString *const kKayokoPreferenceKeyDisablePasteTips = @"DisablePasteTips";
static NSString *const kKayokoPreferenceKeyIgnoreRemoteReplication = @"IgnoreRemoteReplication";
static NSString *const kKayokoPreferenceKeyPlaySoundEffects = @"PlaySoundEffects";
static NSString *const kKayokoPreferenceKeyPlayHapticFeedback = @"PlayHapticFeedback";
static NSString *const kKayokoPreferenceKeyPreviewLineCount = @"PreviewLineCount";
static NSString *const kKayokoPreferenceKeyItemDetailsMode = @"ItemDetailsMode";
static NSString *const kKayokoPreferenceKeyHeightInPoints = @"HeightInPoints";

static BOOL const kKayokoPreferenceKeyEnabledDefaultValue = YES;
static NSUInteger const kKayokoPreferenceKeyMaximumHistoryAmountDefaultValue = 200;
static BOOL const kKayokoPreferenceKeySaveTextDefaultValue = YES;
static BOOL const kKayokoPreferenceKeySaveImagesDefaultValue = YES;
static BOOL const kKayokoPreferenceKeySwipeToSelectWordsDefaultValue = YES;
static ActivationMethod const kKayokoPreferenceKeyActivationMethodDefaultValue =
    kActivationMethodDictationKey | kActivationMethodInputSwitcher | kActivationMethodExternalKeyboard;
static KayokoGestureRecognizerMode const kKayokoPreferenceKeyGestureRecognizerModeDefaultValue =
    kKayokoGestureRecognizerModeClassic;
static BOOL const kKayokoPreferenceKeyAutomaticallyPasteDefaultValue = YES;
static KayokoAutomaticPasteMode const kKayokoPreferenceKeyAutomaticPasteModeDefaultValue =
    kKayokoAutomaticPasteModeClassic;
static KayokoAutomaticPromotionMode const kKayokoPreferenceKeyAutomaticPromotionModeDefaultValue =
    kKayokoAutomaticPromotionModeHistoryOnly;
static KayokoInitialViewMode const kKayokoPreferenceKeyInitialViewModeDefaultValue =
    kKayokoInitialViewModePreviousSelection;
static BOOL const kKayokoPreferenceKeyDismissOnOutsideTouchDefaultValue = YES;
static BOOL const kKayokoPreferenceKeyDisablePasteTipsDefaultValue = NO;
static BOOL const kKayokoPreferenceKeyIgnoreRemoteReplicationDefaultValue = NO;
static BOOL const kKayokoPreferenceKeyPlaySoundEffectsDefaultValue = YES;
static BOOL const kKayokoPreferenceKeyPlayHapticFeedbackDefaultValue = YES;
static NSUInteger const kKayokoPreferenceKeyPreviewLineCountDefaultValue = 1;
static KayokoItemDetailsMode const kKayokoPreferenceKeyItemDetailsModeDefaultValue = kKayokoItemDetailsModeImagesOnly;
static CGFloat const kKayokoPreferenceKeyHeightInPointsDefaultValue = 420;
