//
//  KayokoRespringControllerSupport.m
//  Kayoko
//

#import "KayokoRespringControllerSupport.h"

#import <UIKit/UIKit.h>

typedef NS_OPTIONS(NSUInteger, SBSRelaunchActionOptions) {
    SBSRelaunchActionOptionsNone,
    SBSRelaunchActionOptionsRestartRenderServer = 1 << 0,
    SBSRelaunchActionOptionsSnapshotTransition = 1 << 1,
    SBSRelaunchActionOptionsFadeToBlackTransition = 1 << 2
};

@interface SBSRelaunchAction : NSObject
+ (instancetype)actionWithReason:(NSString *)reason
                         options:(SBSRelaunchActionOptions)options
                       targetURL:(nullable NSURL *)targetURL;
@end

@interface FBSSystemService : NSObject
+ (instancetype)sharedService;
- (void)sendActions:(NSSet *)actions withResult:(nullable void (^)(NSError *error))result;
@end

static BOOL kayokoSendRelaunchActionWithOptions(SBSRelaunchActionOptions options, NSString *actionName) {
    Class actionClass = NSClassFromString(@"SBSRelaunchAction");
    Class serviceClass = NSClassFromString(@"FBSSystemService");
    if (![actionClass respondsToSelector:@selector(actionWithReason:options:targetURL:)] ||
        ![serviceClass respondsToSelector:@selector(sharedService)]) {
        NSLog(@"Kayoko: Unable to perform %@ because FrontBoard relaunch SPI is unavailable",
              actionName ?: @"relaunch");
        return NO;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      NSURL *kayokoURL = [NSURL URLWithString:@"prefs:root=Kayoko"];
      SBSRelaunchAction *action = [(id)actionClass actionWithReason:@"Kayoko" options:options targetURL:kayokoURL];
      FBSSystemService *service = [(id)serviceClass sharedService];
      if (!action || ![service respondsToSelector:@selector(sendActions:withResult:)]) {
          NSLog(@"Kayoko: FBSSystemService cannot perform %@", actionName ?: @"relaunch");
          return;
      }

      [service sendActions:[NSSet setWithObject:action]
                withResult:^(NSError *error) {
                  if (error) {
                      NSLog(@"Kayoko: %@ failed: %@", actionName ?: @"Relaunch", error);
                  }
                }];
    });
    return YES;
}

@implementation PSListController (KayokoRespringControllerSupport)

- (void)promptToRespring {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *resetAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:@"This option requires restarting SpringBoard to apply. "
                                                               @"Do you want to restart now?"
                                                         value:nil
                                                         table:@"Root"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *respringAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Respring Now"
                                                                                           value:nil
                                                                                           table:@"Root"]
                                                             style:UIAlertActionStyleDestructive
                                                           handler:^(UIAlertAction *action) {
                                                             [self respring];
                                                           }];

    UIAlertAction *notNowAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Not Now"
                                                                                         value:nil
                                                                                         table:@"Root"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [resetAlert addAction:respringAction];
    [resetAlert addAction:notNowAction];

    [self presentViewController:resetAlert animated:YES completion:nil];
}

- (void)respring {
    kayokoSendRelaunchActionWithOptions(SBSRelaunchActionOptionsRestartRenderServer, @"Hard respring");
}

@end
