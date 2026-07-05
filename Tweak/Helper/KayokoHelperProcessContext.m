//
//  KayokoHelperProcessContext.m
//  Kayoko
//

#import "KayokoHelperProcessContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHelperProcessContext ()
@property(nonatomic, assign, readwrite) KayokoHelperProcessKind kind;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoHelperProcessContext

+ (instancetype)currentContext {
    if ([self isKeyboardExtensionProcess]) {
        return [[self alloc] initWithKind:KayokoHelperProcessKindKeyboardExtension];
    }
    if ([self isSpringBoardProcess]) {
        return [[self alloc] initWithKind:KayokoHelperProcessKindSpringBoard];
    }
    if ([self isApplicationProcess]) {
        return [[self alloc] initWithKind:KayokoHelperProcessKindApplication];
    }
    return [[self alloc] initWithKind:KayokoHelperProcessKindUnsupported];
}

- (instancetype)initWithKind:(KayokoHelperProcessKind)kind {
    self = [super init];
    if (self) {
        _kind = kind;
    }
    return self;
}

+ (BOOL)isSpringBoardProcess {
    return [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
}

+ (BOOL)isKeyboardExtensionProcess {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *bundlePath = [mainBundle bundlePath];
    BOOL isPluginBundle = [[bundlePath pathExtension] isEqualToString:@"appex"] ||
                          [bundlePath rangeOfString:@"/PlugIns/"].location != NSNotFound;
    if (!isPluginBundle) {
        return NO;
    }

    NSDictionary<NSString *, id> *extensionInfo = [[mainBundle infoDictionary] objectForKey:@"NSExtension"];
    NSString *extensionPointIdentifier = [extensionInfo objectForKey:@"NSExtensionPointIdentifier"];
    return [extensionPointIdentifier isEqualToString:@"com.apple.keyboard-service"];
}

+ (BOOL)isApplicationProcess {
    if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.Spotlight"]) {
        return YES;
    }

    NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
    NSUInteger count = [args count];
    if (count == 0) {
        return NO;
    }

    NSString *executablePath = args[0];
    if (executablePath.length == 0) {
        return NO;
    }

    BOOL isApplication = [executablePath rangeOfString:@"/Application/"].location != NSNotFound ||
                         [executablePath rangeOfString:@"/Applications/"].location != NSNotFound;
    if (!isApplication) {
        return NO;
    }

    NSString *processName = [executablePath lastPathComponent];
    BOOL isFileProvider = [[processName lowercaseString] rangeOfString:@"fileprovider"].location != NSNotFound;
    if (isFileProvider) {
        return NO;
    }

    BOOL isProtectedApplication = [processName isEqualToString:@"AdSheet"] ||
                                  [processName isEqualToString:@"CoreAuthUI"] ||
                                  [processName isEqualToString:@"InCallService"] ||
                                  [processName isEqualToString:@"MessagesNotificationViewService"];
    if (isProtectedApplication) {
        return NO;
    }

    BOOL isApplicationExtension = [executablePath rangeOfString:@".appex/"].location != NSNotFound;
    return !isApplicationExtension;
}

@end
