//
//  KayokoHelperConfiguration.m
//  Kayoko
//

#import "KayokoHelperConfiguration.h"
#import "KayokoPreferenceKeys.h"

#import <libSandy.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHelperConfiguration ()

@property(nonatomic, assign, readwrite, getter=isEnabled) BOOL enabled;
@property(nonatomic, assign, readwrite) NSUInteger activationMethod;
@property(nonatomic, assign, readwrite, getter=isAutomaticallyPasteEnabled) BOOL automaticallyPasteEnabled;
@property(nonatomic, assign, readwrite, getter=isHapticFeedbackEnabled) BOOL hapticFeedbackEnabled;

- (instancetype)initWithPreferences:(NSUserDefaults *)preferences;

@end

NS_ASSUME_NONNULL_END

@implementation KayokoHelperConfiguration

+ (instancetype)currentConfiguration {
    NSUserDefaults *preferences = [[NSUserDefaults alloc]
        initWithSuiteName:[NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist",
                                                     kKayokoPreferencesIdentifier]];

#if THEOS_PACKAGE_SCHEME_ROOTHIDE
    libSandy_applyProfile("Kayoko_RootHide");
#else
    libSandy_applyProfile("Kayoko");
#endif

    [preferences registerDefaults:@{
        kKayokoPreferenceKeyEnabled : @(kKayokoPreferenceKeyEnabledDefaultValue),
        kKayokoPreferenceKeyActivationMethod : @(kKayokoPreferenceKeyActivationMethodDefaultValue),
        kKayokoPreferenceKeyAutomaticallyPaste : @(kKayokoPreferenceKeyAutomaticallyPasteDefaultValue),
        kKayokoPreferenceKeyPlayHapticFeedback : @(kKayokoPreferenceKeyPlayHapticFeedbackDefaultValue)
    }];

    KayokoHelperConfiguration *configuration = [[self alloc] initWithPreferences:preferences];
    return configuration;
}

- (instancetype)initWithPreferences:(NSUserDefaults *)preferences {
    self = [super init];
    if (self) {
        _enabled = [[preferences objectForKey:kKayokoPreferenceKeyEnabled] boolValue];
        _activationMethod = [[preferences objectForKey:kKayokoPreferenceKeyActivationMethod] unsignedIntegerValue];
        _automaticallyPasteEnabled = [[preferences objectForKey:kKayokoPreferenceKeyAutomaticallyPaste] boolValue];
        _hapticFeedbackEnabled = [[preferences objectForKey:kKayokoPreferenceKeyPlayHapticFeedback] boolValue];
    }
    return self;
}

@end
