//
//  KayokoTagStore.h
//  Kayoko
//

#import <Foundation/Foundation.h>

@class KayokoTag;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kKayokoTagStoreErrorDomain;

@interface KayokoTagStore : NSObject

@property(nonatomic, copy, readonly) NSString *tagsPath;
@property(nonatomic, strong, readonly) NSBundle *localizationBundle;

+ (NSString *)defaultTagsPath;

- (instancetype)initWithTagsPath:(NSString *)tagsPath
              localizationBundle:(NSBundle *)localizationBundle NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable NSMutableArray<KayokoTag *> *)loadTagsWithError:(NSError **)error;
- (nullable NSMutableArray<KayokoTag *> *)readTagsWithError:(NSError **)error;
- (BOOL)ensureDefaultTagsFileExistsWithError:(NSError **)error;
- (BOOL)saveTags:(NSArray<KayokoTag *> *)tags error:(NSError **)error;
- (BOOL)restoreDefaultTagsWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
