//
//  KayokoRespringControllerSupport.h
//  Kayoko
//

#import <Preferences/PSListController.h>

NS_ASSUME_NONNULL_BEGIN

@interface PSListController (KayokoRespringControllerSupport)

- (void)promptToRespring;
- (void)respring;

@end

NS_ASSUME_NONNULL_END
