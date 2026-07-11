#import <UIKit/UIKit.h>

#import "KayokoPreferenceKeys.h"

NS_ASSUME_NONNULL_BEGIN

@class FBScene;
@class UIApplicationSceneSettings;

@interface KayokoCoreRuntime : NSObject

@property(nonatomic, assign, readonly, getter=isEnabled) BOOL enabled;
@property(nonatomic, assign, readonly) NSUInteger activationMethod;
@property(nonatomic, assign, readonly) KayokoGestureRecognizerMode gestureRecognizerMode;
@property(nonatomic, assign, readonly) BOOL pasteTipsDisabled;
@property(nonatomic, assign, readonly) BOOL panelVisible;
@property(nonatomic, assign, readonly) BOOL fullscreenSearchActive;
@property(nonatomic, assign, readonly) BOOL systemMultitaskingGestureSuppressed;

+ (instancetype)sharedRuntime;

- (void)loadPreferences;
- (BOOL)refreshPasteTipPreferences;
- (void)loadHeightPreference;

- (void)installPanelInStatusBarWindow:(UIWindow *)window;
- (void)preloadInitialHistory;
- (void)startLockStateObserver;

- (void)show;
- (void)hide;
- (void)hideWithStandardDismissAnimation;
- (void)hideForExternalRequest;
- (void)hideForRotation;
- (void)hideImmediately;
- (void)reloadHistory;
- (void)handleApplicationMetadataChanged;
- (void)handleScene:(FBScene *)scene didUpdateSettings:(UIApplicationSceneSettings *)settings;
- (void)checkpointHistoryDatabase;
- (void)prepareForPackageMaintenance;
- (void)resetThumbnailMemoryCache;
- (void)clearFavorites;
- (void)clearHistory;
- (void)capturePasteboardChange;
- (void)markPasteWillStart;
- (void)playPasteFeedback;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
