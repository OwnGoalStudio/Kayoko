//
//  PreferenceKeys.h
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
    kActivationMethodSwipeUp = 1 << 4
};

static NSString *const kPreferencesIdentifier = @"com.82flex.kayoko.preferences";

static NSString *const kPreferenceKeyEnabled = @"Enabled";
static NSString *const kPreferenceKeyMaximumHistoryAmount = @"MaximumHistoryAmount";
static NSString *const kPreferenceKeySaveText = @"SaveText";
static NSString *const kPreferenceKeySaveImages = @"SaveImages";
static NSString *const kPreferenceKeySwipeToSelectWords = @"SwipeToSelectWords";
static NSString *const kPreferenceKeyActivationMethod = @"ActivationMethod";
static NSString *const kPreferenceKeyAutomaticallyPaste = @"AutomaticallyPaste";
static NSString *const kPreferenceKeyDismissOnOutsideTouch = @"DismissOnOutsideTouch";
static NSString *const kPreferenceKeyDisablePasteTips = @"DisablePasteTips";
static NSString *const kPreferenceKeyPlaySoundEffects = @"PlaySoundEffects";
static NSString *const kPreferenceKeyPlayHapticFeedback = @"PlayHapticFeedback";
static NSString *const kPreferenceKeyPreviewLineCount = @"PreviewLineCount";
static NSString *const kPreferenceKeyHeightInPoints = @"HeightInPoints";

static BOOL const kPreferenceKeyEnabledDefaultValue = YES;
static NSUInteger const kPreferenceKeyMaximumHistoryAmountDefaultValue = 200;
static BOOL const kPreferenceKeySaveTextDefaultValue = YES;
static BOOL const kPreferenceKeySaveImagesDefaultValue = YES;
static BOOL const kPreferenceKeySwipeToSelectWordsDefaultValue = YES;
static ActivationMethod const kPreferenceKeyActivationMethodDefaultValue =
    kActivationMethodDictationKey | kActivationMethodInputSwitcher;
static BOOL const kPreferenceKeyAutomaticallyPasteDefaultValue = YES;
static BOOL const kPreferenceKeyDismissOnOutsideTouchDefaultValue = YES;
static BOOL const kPreferenceKeyDisablePasteTipsDefaultValue = NO;
static BOOL const kPreferenceKeyPlaySoundEffectsDefaultValue = YES;
static BOOL const kPreferenceKeyPlayHapticFeedbackDefaultValue = YES;
static NSUInteger const kPreferenceKeyPreviewLineCountDefaultValue = 1;
static CGFloat const kPreferenceKeyHeightInPointsDefaultValue = 420;
