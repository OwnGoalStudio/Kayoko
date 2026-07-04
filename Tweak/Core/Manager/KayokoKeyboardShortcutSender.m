//
//  KayokoKeyboardShortcutSender.m
//  Kayoko
//

#import "KayokoKeyboardShortcutSender.h"

#import <CoreFoundation/CoreFoundation.h>
#import <HBLog.h>
#import <mach/boolean.h>
#import <mach/mach_time.h>
#import <unistd.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern IOHIDEventRef IOHIDEventCreateKeyboardEvent(CFAllocatorRef allocator, uint64_t timeStamp, uint32_t usagePage,
                                                   uint32_t usage, boolean_t isDown, uint32_t options);
extern void IOHIDEventSetSenderID(IOHIDEventRef event, uint64_t senderID);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);

static uint32_t const kKayokoHIDPageKeyboardOrKeypad = 0x07;
static uint32_t const kKayokoHIDUsageKeyboardV = 0x19;
static uint32_t const kKayokoHIDUsageKeyboardLeftGUI = 0xE3;
static uint32_t const kKayokoHIDEventOptionNone = 0;
static uint64_t const kKayokoHIDEventSenderID = 0x8000000817319371ULL;
static useconds_t const kKayokoKeyboardShortcutKeyPressDelay = 50000;

@implementation KayokoKeyboardShortcutSender {
    dispatch_queue_t _eventQueue;
    IOHIDEventSystemClientRef _eventSystemClient;
}

+ (instancetype)sharedSender {
    static KayokoKeyboardShortcutSender *sender = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sender = [[self alloc] initPrivate];
    });
    return sender;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _eventQueue = dispatch_queue_create("com.82flex.kayoko.queue.keyboard-shortcut",
                                            DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        _eventSystemClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    }
    return self;
}

- (void)sendCommandV {
    dispatch_async(_eventQueue, ^{
      HBLogDebug(@"Kayoko: dispatching simulated Cmd+V HID shortcut");
      [self dispatchKeyboardUsage:kKayokoHIDUsageKeyboardLeftGUI isKeyDown:YES];
      [self dispatchKeyboardUsage:kKayokoHIDUsageKeyboardV isKeyDown:YES];
      usleep(kKayokoKeyboardShortcutKeyPressDelay);
      [self dispatchKeyboardUsage:kKayokoHIDUsageKeyboardV isKeyDown:NO];
      [self dispatchKeyboardUsage:kKayokoHIDUsageKeyboardLeftGUI isKeyDown:NO];
    });
}

- (void)dispatchKeyboardUsage:(uint32_t)usage isKeyDown:(BOOL)isKeyDown {
    if (!_eventSystemClient) {
        HBLogDebug(@"Kayoko: simulated shortcut skipped because IOHID event system client is unavailable");
        return;
    }

    IOHIDEventRef event =
        IOHIDEventCreateKeyboardEvent(kCFAllocatorDefault, mach_absolute_time(), kKayokoHIDPageKeyboardOrKeypad, usage,
                                      isKeyDown, kKayokoHIDEventOptionNone);
    if (!event) {
        HBLogDebug(@"Kayoko: simulated shortcut failed to create keyboard event usage=0x%x isKeyDown=%@", usage,
                   isKeyDown ? @"YES" : @"NO");
        return;
    }

    IOHIDEventSetSenderID(event, kKayokoHIDEventSenderID);
    IOHIDEventSystemClientDispatchEvent(_eventSystemClient, event);
    CFRelease(event);
}

@end
