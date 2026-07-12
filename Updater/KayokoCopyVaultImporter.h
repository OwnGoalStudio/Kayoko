//
//  KayokoCopyVaultImporter.h
//  Kayoko
//

#import <Foundation/Foundation.h>

@class KayokoHistoryStore;
@class KayokoTagStore;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoCopyVaultImporter : NSObject

- (instancetype)initWithSourceDirectoryPath:(NSString *)sourceDirectoryPath
                               historyStore:(KayokoHistoryStore *)historyStore
                                   tagStore:(KayokoTagStore *)tagStore NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)runWithSkippedItemCount:(NSUInteger *_Nullable)skippedItemCount error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
