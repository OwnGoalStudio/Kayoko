//
//  KayokoImportFileStager.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoImportFileStager : NSObject

- (instancetype)initWithBaseDirectoryPath:(NSString *)baseDirectoryPath
                                   prefix:(NSString *)prefix NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)addDataByName:(NSDictionary<NSString *, NSData *> *)dataByName
      targetDirectory:(NSString *)targetDirectory
                error:(NSError *_Nullable *_Nullable)error;
- (BOOL)commitWithError:(NSError *_Nullable *_Nullable)error;
- (BOOL)rollbackWithError:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
