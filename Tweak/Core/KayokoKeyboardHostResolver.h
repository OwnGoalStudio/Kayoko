#import <UIKit/UIKit.h>

@class FBScene;
@class UIApplicationSceneSettings;

typedef NS_ENUM(NSUInteger, KayokoKeyboardHostKind) {
    KayokoKeyboardHostKindUnknown = 0,
    KayokoKeyboardHostKindApplication,
    KayokoKeyboardHostKindSpringBoard,
    KayokoKeyboardHostKindSpotlight
};

NS_ASSUME_NONNULL_BEGIN

@interface KayokoKeyboardHostContext : NSObject

@property(nonatomic, weak, readonly, nullable) FBScene *scene;
@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly, nullable) NSString *bundleIdentifier;
@property(nonatomic, assign, readonly) KayokoKeyboardHostKind kind;
@property(nonatomic, assign, readonly) BOOL helperMarkerAvailable;
@property(nonatomic, assign, readonly) long long helperInjectedFlag;
@property(nonatomic, assign, readonly, getter=isHelperInjected) BOOL helperInjected;
@property(nonatomic, assign, readonly, getter=isKayokoOwned) BOOL kayokoOwned;
@property(nonatomic, assign, readonly, getter=isCached) BOOL cached;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

@interface KayokoKeyboardHostResolver : NSObject

+ (instancetype)sharedResolver;
+ (NSString *)stringForHostKind:(KayokoKeyboardHostKind)kind;

- (nullable KayokoKeyboardHostContext *)currentKeyboardHostContext;
- (nullable KayokoKeyboardHostContext *)effectiveExternalKeyboardHostContext;
- (nullable KayokoKeyboardHostContext *)keyboardHostContextForSourceAttribution;
- (nullable FBScene *)currentKeyboardHostScene;
- (nullable UIApplicationSceneSettings *)settingsForScene:(FBScene *)scene;
- (BOOL)sceneIsCurrentKeyboardHostScene:(FBScene *)scene;
- (BOOL)sceneIsHostedBySpringBoard:(FBScene *)scene;
- (BOOL)sceneIsSpotlightScene:(FBScene *)scene;
- (BOOL)currentKeyboardInputIsKayokoOwned;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
