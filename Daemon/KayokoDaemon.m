//
//  KayokoDaemon.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoDaemon.h"
#import "NotificationKeys.h"
#import <notify.h>

@implementation KayokoDaemon

/**
 * Notifies the core about pasteboard changes.
 */
- (instancetype)init {
    self = [super init];
    if (self) {
        notify_register_dispatch("com.apple.pasteboard.notify.changed", &(_token), dispatch_get_main_queue(), ^(int _) {
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                 (CFStringRef)kNotificationKeyObserverPasteboardChanged, nil, nil, YES);
          });
        });
    }
    return self;
}

/**
 * Deallocates the daemon.
 */
- (void)dealloc {
    notify_cancel(_token);
}

@end

/**
 * Starts the daemon.
 */
int main(int argc, char **argv, char **envp) {
    @autoreleasepool {
        static KayokoDaemon *daemon = nil;
        daemon = [[KayokoDaemon alloc] init];
        (void)daemon;
        [[NSRunLoop currentRunLoop] run];
        return EXIT_SUCCESS;
    }
}
