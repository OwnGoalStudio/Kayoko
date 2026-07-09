//
//  KayokoKeyboardHostResolver.m
//  Kayoko
//

#import "KayokoKeyboardHostResolver.h"
#import "KayokoSceneSettingKeys.h"

#import <HBLog.h>
#import <objc/runtime.h>

static NSString *const kKayokoSpotlightSceneIdentifier = @"searchScreen";
static NSString *const kKayokoSpotlightBundleIdentifier = @"com.apple.Spotlight";
static NSString *const kKayokoSpringBoardBundleIdentifier = @"com.apple.springboard";
static NSString *const kKayokoSpringBoardProcessName = @"SpringBoard";

@class BSSettings;
@class FBSSceneIdentityToken;

@interface BSSettings : NSObject
- (long long)flagForSetting:(unsigned long long)setting;
@end

@interface FBSSceneClientSettings : NSObject
- (BSSettings *)otherSettings;
- (FBSSceneIdentityToken *)preferredSceneHostIdentity;
@end

@interface FBSSceneIdentityToken : NSObject
- (NSString *)identifier;
@end

@interface FBProcess : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)name;
@end

@interface FBScene : NSObject
- (FBSSceneClientSettings *)clientSettings;
- (FBProcess *)clientProcess;
- (UIApplicationSceneSettings *)settings;
- (NSString *)identifier;
@end

@interface FBSceneManager : NSObject
+ (FBScene *)keyboardScene;
+ (instancetype)sharedInstance;
- (FBScene *)sceneWithIdentifier:(NSString *)identifier;
@end

@protocol KayokoFBSceneManagerClass <NSObject>
+ (FBScene *)keyboardScene;
+ (FBSceneManager *)sharedInstance;
@end

@interface UIKeyboardImpl : NSObject
+ (instancetype)activeInstance;
- (id)inputDelegate;
@end

@protocol KayokoUIKeyboardImplClass <NSObject>
+ (UIKeyboardImpl *)activeInstance;
@end

NS_ASSUME_NONNULL_BEGIN

@interface KayokoKeyboardHostContext ()

#pragma mark - Scene

@property(nonatomic, weak, readwrite, nullable) FBScene *scene;
@property(nonatomic, copy, readwrite) NSString *identifier;
@property(nonatomic, copy, readwrite, nullable) NSString *bundleIdentifier;
@property(nonatomic, assign, readwrite) KayokoKeyboardHostKind kind;

#pragma mark - Helper Marker

@property(nonatomic, assign, readwrite) BOOL helperMarkerAvailable;
@property(nonatomic, assign, readwrite) long long helperInjectedFlag;

#pragma mark - State

@property(nonatomic, assign, readwrite, getter=isKayokoOwned) BOOL kayokoOwned;
@property(nonatomic, assign, readwrite, getter=isCached) BOOL cached;

#pragma mark - Lifecycle

- (instancetype)initWithScene:(nullable FBScene *)scene
                   identifier:(NSString *)identifier
             bundleIdentifier:(nullable NSString *)bundleIdentifier
                         kind:(KayokoKeyboardHostKind)kind NS_DESIGNATED_INITIALIZER;

#pragma mark - State

- (KayokoKeyboardHostContext *)contextMarkedCached;

@end

@interface KayokoKeyboardHostResolver ()

#pragma mark - Cache

@property(nonatomic, strong, nullable) KayokoKeyboardHostContext *lastExternalKeyboardHostContext;

#pragma mark - Lifecycle

- (instancetype)initPrivate;

#pragma mark - Host Context

- (nullable KayokoKeyboardHostContext *)keyboardHostContextForCurrentInputKayokoOwned:(BOOL)kayokoOwned;
- (nullable KayokoKeyboardHostContext *)keyboardHostContextForScene:(FBScene *)hostScene
                                                         identifier:(NSString *)identifier
                                                        kayokoOwned:(BOOL)kayokoOwned
                                                             cached:(BOOL)cached;
- (nullable FBScene *)keyboardHostSceneWithIdentifier:(NSString *_Nullable *_Nullable)identifier;
- (nullable NSString *)bundleIdentifierForScene:(FBScene *)scene kind:(KayokoKeyboardHostKind)kind;
- (nullable UIResponder *)activeKeyboardInputDelegate;

#pragma mark - Ownership

- (BOOL)objectHasKayokoClassPrefix:(id)object;
- (BOOL)viewHierarchyIsKayokoOwned:(UIView *)view;
- (BOOL)responderIsKayokoOwned:(UIResponder *)responder;

#pragma mark - Scene Classification

- (BOOL)stringMatchesSpringBoard:(NSString *)string;
- (KayokoKeyboardHostKind)kindForScene:(FBScene *)scene;

@end

NS_ASSUME_NONNULL_END

@implementation KayokoKeyboardHostContext

#pragma mark - Lifecycle

- (instancetype)initWithScene:(nullable FBScene *)scene
                   identifier:(NSString *)identifier
             bundleIdentifier:(nullable NSString *)bundleIdentifier
                         kind:(KayokoKeyboardHostKind)kind {
    self = [super init];
    if (self) {
        _scene = scene;
        _identifier = [identifier copy] ?: @"";
        _bundleIdentifier = [bundleIdentifier copy];
        _kind = kind;
    }
    return self;
}

#pragma mark - State

- (BOOL)isHelperInjected {
    return self.helperInjectedFlag == 1;
}

- (KayokoKeyboardHostContext *)contextMarkedCached {
    KayokoKeyboardHostContext *context = [[KayokoKeyboardHostContext alloc] initWithScene:self.scene
                                                                               identifier:self.identifier
                                                                         bundleIdentifier:self.bundleIdentifier
                                                                                     kind:self.kind];
    context.helperMarkerAvailable = self.helperMarkerAvailable;
    context.helperInjectedFlag = self.helperInjectedFlag;
    context.kayokoOwned = self.kayokoOwned;
    context.cached = YES;
    return context;
}

@end

@implementation KayokoKeyboardHostResolver

#pragma mark - Lifecycle

+ (instancetype)sharedResolver {
    static KayokoKeyboardHostResolver *resolver;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      resolver = [[self alloc] initPrivate];
    });
    return resolver;
}

+ (NSString *)stringForHostKind:(KayokoKeyboardHostKind)kind {
    switch (kind) {
    case KayokoKeyboardHostKindApplication:
        return @"application";
    case KayokoKeyboardHostKindSpringBoard:
        return @"springboard";
    case KayokoKeyboardHostKindSpotlight:
        return @"spotlight";
    case KayokoKeyboardHostKindUnknown:
    default:
        return @"unknown";
    }
}

- (instancetype)initPrivate {
    self = [super init];
    return self;
}

#pragma mark - Public Context

- (KayokoKeyboardHostContext *)currentKeyboardHostContext {
    return [self keyboardHostContextForCurrentInputKayokoOwned:[self currentKeyboardInputIsKayokoOwned]];
}

- (KayokoKeyboardHostContext *)effectiveExternalKeyboardHostContext {
    BOOL kayokoOwned = [self currentKeyboardInputIsKayokoOwned];
    KayokoKeyboardHostContext *currentContext = [self keyboardHostContextForCurrentInputKayokoOwned:kayokoOwned];
    if (currentContext && !currentContext.isKayokoOwned) {
        return currentContext;
    }

    KayokoKeyboardHostContext *cachedContext = [self.lastExternalKeyboardHostContext contextMarkedCached];
    if (cachedContext) {
        HBLogDebug(@"Kayoko: keyboard host resolver using cached external host because current input is %@ "
                   @"currentScene=%@ cachedScene=%@ cachedKind=%@ helperFlag=%lld",
                   kayokoOwned ? @"Kayoko-owned" : @"unavailable", currentContext.identifier ?: @"nil",
                   cachedContext.identifier, [[self class] stringForHostKind:cachedContext.kind],
                   cachedContext.helperInjectedFlag);
    } else {
        HBLogDebug(@"Kayoko: keyboard host resolver has %@ input but no cached external host "
                   @"currentScene=%@",
                   kayokoOwned ? @"Kayoko-owned" : @"unavailable", currentContext.identifier ?: @"nil");
    }
    return cachedContext;
}

- (KayokoKeyboardHostContext *)keyboardHostContextForSourceAttribution {
    BOOL kayokoOwned = [self currentKeyboardInputIsKayokoOwned];
    KayokoKeyboardHostContext *currentContext = [self keyboardHostContextForCurrentInputKayokoOwned:kayokoOwned];
    if (currentContext && !currentContext.isKayokoOwned) {
        return currentContext;
    }

    KayokoKeyboardHostContext *cachedContext = [self.lastExternalKeyboardHostContext contextMarkedCached];
    if (kayokoOwned) {
        if (cachedContext) {
            HBLogDebug(@"Kayoko: keyboard host resolver using cached external host for source attribution because "
                       @"current input is Kayoko-owned currentScene=%@ cachedScene=%@ cachedKind=%@ helperFlag=%lld",
                       currentContext.identifier ?: @"nil", cachedContext.identifier,
                       [[self class] stringForHostKind:cachedContext.kind], cachedContext.helperInjectedFlag);
        } else {
            HBLogDebug(@"Kayoko: keyboard host resolver has Kayoko-owned input but no cached external host for "
                       @"source attribution currentScene=%@",
                       currentContext.identifier ?: @"nil");
        }
        return cachedContext;
    }

    if (cachedContext) {
        HBLogDebug(@"Kayoko: keyboard host resolver ignoring cached external host for source attribution because "
                   @"current input is unavailable currentScene=%@ cachedScene=%@ cachedKind=%@",
                   currentContext.identifier ?: @"nil", cachedContext.identifier,
                   [[self class] stringForHostKind:cachedContext.kind]);
    } else {
        HBLogDebug(@"Kayoko: keyboard host resolver has unavailable input and no current keyboard host for "
                   @"source attribution currentScene=%@",
                   currentContext.identifier ?: @"nil");
    }
    return nil;
}

- (FBScene *)currentKeyboardHostScene {
    return [[self currentKeyboardHostContext] scene];
}

#pragma mark - Scene Helpers

- (UIApplicationSceneSettings *)settingsForScene:(FBScene *)scene {
    if (![scene respondsToSelector:@selector(settings)]) {
        return nil;
    }
    return [scene settings];
}

- (BOOL)sceneIsCurrentKeyboardHostScene:(FBScene *)scene {
    if (!scene) {
        return NO;
    }
    return scene == [self currentKeyboardHostScene];
}

- (BOOL)sceneIsHostedBySpringBoard:(FBScene *)scene {
    if (!scene) {
        return NO;
    }

    if ([scene respondsToSelector:@selector(identifier)] && [self stringMatchesSpringBoard:[scene identifier]]) {
        return YES;
    }

    if (![scene respondsToSelector:@selector(clientProcess)]) {
        return NO;
    }

    FBProcess *process = [scene clientProcess];
    if ([process respondsToSelector:@selector(bundleIdentifier)] &&
        [self stringMatchesSpringBoard:[process bundleIdentifier]]) {
        return YES;
    }
    return [process respondsToSelector:@selector(name)] && [self stringMatchesSpringBoard:[process name]];
}

- (BOOL)sceneIsSpotlightScene:(FBScene *)scene {
    if (![scene respondsToSelector:@selector(identifier)]) {
        return NO;
    }
    return [[scene identifier] isEqualToString:kKayokoSpotlightSceneIdentifier];
}

#pragma mark - Host Context

- (BOOL)currentKeyboardInputIsKayokoOwned {
    UIResponder *keyboardInputDelegate = [self activeKeyboardInputDelegate];
    return [self responderIsKayokoOwned:keyboardInputDelegate];
}

- (KayokoKeyboardHostContext *)keyboardHostContextForCurrentInputKayokoOwned:(BOOL)kayokoOwned {
    NSString *hostSceneIdentifier = nil;
    FBScene *hostScene = [self keyboardHostSceneWithIdentifier:&hostSceneIdentifier];
    if (!hostScene || [hostSceneIdentifier length] == 0) {
        return nil;
    }

    KayokoKeyboardHostContext *context = [self keyboardHostContextForScene:hostScene
                                                                identifier:hostSceneIdentifier
                                                               kayokoOwned:kayokoOwned
                                                                    cached:NO];
    if (context && !kayokoOwned) {
        self.lastExternalKeyboardHostContext = context;
    }
    return context;
}

- (KayokoKeyboardHostContext *)keyboardHostContextForScene:(FBScene *)hostScene
                                                identifier:(NSString *)identifier
                                               kayokoOwned:(BOOL)kayokoOwned
                                                    cached:(BOOL)cached {
    BOOL helperMarkerAvailable = NO;
    long long helperInjectedFlag = 0;

    if ([hostScene respondsToSelector:@selector(clientSettings)]) {
        FBSSceneClientSettings *hostClientSettings = [hostScene clientSettings];
        if ([hostClientSettings respondsToSelector:@selector(otherSettings)]) {
            BSSettings *otherSettings = [hostClientSettings otherSettings];
            if ([otherSettings respondsToSelector:@selector(flagForSetting:)]) {
                helperMarkerAvailable = YES;
                helperInjectedFlag = [otherSettings flagForSetting:kKayokoSceneClientSettingHelperInjected];
            }
        }
    }

    KayokoKeyboardHostKind kind = [self kindForScene:hostScene];
    KayokoKeyboardHostContext *context =
        [[KayokoKeyboardHostContext alloc] initWithScene:hostScene
                                              identifier:identifier
                                        bundleIdentifier:[self bundleIdentifierForScene:hostScene kind:kind]
                                                    kind:kind];
    context.helperMarkerAvailable = helperMarkerAvailable;
    context.helperInjectedFlag = helperInjectedFlag;
    context.kayokoOwned = kayokoOwned;
    context.cached = cached;
    return context;
}

- (FBScene *)keyboardHostSceneWithIdentifier:(NSString **)identifier {
    Class<KayokoFBSceneManagerClass> managerClass =
        (Class<KayokoFBSceneManagerClass>)NSClassFromString(@"FBSceneManager");
    if (![managerClass respondsToSelector:@selector(keyboardScene)] ||
        ![managerClass respondsToSelector:@selector(sharedInstance)]) {
        return nil;
    }

    FBScene *keyboardScene = [managerClass keyboardScene];
    FBSceneManager *sceneManager = [managerClass sharedInstance];
    if (![keyboardScene respondsToSelector:@selector(clientSettings)] ||
        ![sceneManager respondsToSelector:@selector(sceneWithIdentifier:)]) {
        return nil;
    }

    FBSSceneClientSettings *keyboardClientSettings = [keyboardScene clientSettings];
    if (![keyboardClientSettings respondsToSelector:@selector(preferredSceneHostIdentity)]) {
        return nil;
    }

    FBSSceneIdentityToken *hostIdentity = [keyboardClientSettings preferredSceneHostIdentity];
    if (![hostIdentity respondsToSelector:@selector(identifier)]) {
        return nil;
    }

    NSString *hostSceneIdentifier = [hostIdentity identifier];
    if (![hostSceneIdentifier isKindOfClass:[NSString class]] || [hostSceneIdentifier length] == 0) {
        return nil;
    }

    if (identifier) {
        *identifier = hostSceneIdentifier;
    }
    return [sceneManager sceneWithIdentifier:hostSceneIdentifier];
}

- (nullable NSString *)bundleIdentifierForScene:(FBScene *)scene kind:(KayokoKeyboardHostKind)kind {
    if (kind == KayokoKeyboardHostKindSpotlight) {
        return kKayokoSpotlightBundleIdentifier;
    }
    if (kind == KayokoKeyboardHostKindSpringBoard) {
        return kKayokoSpringBoardBundleIdentifier;
    }

    if (![scene respondsToSelector:@selector(clientProcess)]) {
        return nil;
    }

    FBProcess *process = [scene clientProcess];
    if (![process respondsToSelector:@selector(bundleIdentifier)]) {
        return nil;
    }

    NSString *bundleIdentifier = [process bundleIdentifier];
    return [bundleIdentifier length] > 0 ? bundleIdentifier : nil;
}

- (UIResponder *)activeKeyboardInputDelegate {
    Class<KayokoUIKeyboardImplClass> keyboardImplClass =
        (Class<KayokoUIKeyboardImplClass>)NSClassFromString(@"UIKeyboardImpl");
    if (![keyboardImplClass respondsToSelector:@selector(activeInstance)]) {
        return nil;
    }

    UIKeyboardImpl *keyboardImpl = [keyboardImplClass activeInstance];
    if (![keyboardImpl respondsToSelector:@selector(inputDelegate)]) {
        return nil;
    }

    id inputDelegate = [keyboardImpl inputDelegate];
    return [inputDelegate isKindOfClass:[UIResponder class]] ? inputDelegate : nil;
}

#pragma mark - Ownership

- (BOOL)objectHasKayokoClassPrefix:(id)object {
    if (!object) {
        return NO;
    }

    Class cls = [object class];
    while (cls) {
        if ([NSStringFromClass(cls) hasPrefix:@"Kayoko"]) {
            return YES;
        }
        cls = class_getSuperclass(cls);
    }
    return NO;
}

- (BOOL)viewHierarchyIsKayokoOwned:(UIView *)view {
    NSUInteger depth = 0;
    while (view && depth < 64) {
        if ([self objectHasKayokoClassPrefix:view]) {
            return YES;
        }
        view = [view superview];
        depth++;
    }
    return NO;
}

- (BOOL)responderIsKayokoOwned:(UIResponder *)responder {
    UIResponder *currentResponder = responder;
    NSUInteger depth = 0;
    while (currentResponder && depth < 64) {
        if ([self objectHasKayokoClassPrefix:currentResponder]) {
            return YES;
        }
        if ([currentResponder isKindOfClass:[UIView class]] &&
            [self viewHierarchyIsKayokoOwned:[(UIView *)currentResponder superview]]) {
            return YES;
        }
        currentResponder = [currentResponder nextResponder];
        depth++;
    }
    return NO;
}

#pragma mark - Scene Classification

- (BOOL)stringMatchesSpringBoard:(NSString *)string {
    if (![string isKindOfClass:[NSString class]] || [string length] == 0) {
        return NO;
    }

    return [string caseInsensitiveCompare:kKayokoSpringBoardBundleIdentifier] == NSOrderedSame ||
           [string caseInsensitiveCompare:kKayokoSpringBoardProcessName] == NSOrderedSame;
}

- (KayokoKeyboardHostKind)kindForScene:(FBScene *)scene {
    if ([self sceneIsSpotlightScene:scene]) {
        return KayokoKeyboardHostKindSpotlight;
    }
    if ([self sceneIsHostedBySpringBoard:scene]) {
        return KayokoKeyboardHostKindSpringBoard;
    }
    return scene ? KayokoKeyboardHostKindApplication : KayokoKeyboardHostKindUnknown;
}

@end
