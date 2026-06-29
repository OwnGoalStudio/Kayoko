//
//  KayokoPostinstallUpdater.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPostinstallUpdater : NSObject

- (BOOL)runPostinstallWithError:(NSError **)error;
- (NSArray<NSString *> *)safelyDeletableLegacyPathsWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
