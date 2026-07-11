//
//  KayokoPostinstallUpdater.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPostinstallUpdater : NSObject

- (BOOL)runPostinstallWithError:(NSError **)error;
- (BOOL)importCopyVaultWithError:(NSError **)error;
- (BOOL)importCopyVaultWithSkippedItemCount:(NSUInteger *_Nullable)skippedItemCount
                                      error:(NSError *_Nullable *_Nullable)error;
- (BOOL)importCopyLogWithSkippedItemCount:(NSUInteger *_Nullable)skippedItemCount
                                    error:(NSError *_Nullable *_Nullable)error;
- (BOOL)resetThumbnailCacheWithError:(NSError **)error;
- (NSArray<NSString *> *)safelyDeletableLegacyPathsWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
