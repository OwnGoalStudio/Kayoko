//
//  KayokoCore.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPasteTipHookInstaller : NSObject

+ (void)installHooks;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
