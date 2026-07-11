//
//  KayokoThumbnailCache.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^KayokoThumbnailCompletion)(UIImage *_Nullable image);

@interface KayokoThumbnailCache : NSObject

@property(class, nonatomic, copy, readonly) NSString *defaultCacheDirectoryPath;

- (instancetype)init;
- (instancetype)initWithCacheDirectoryPath:(NSString *)cacheDirectoryPath NS_DESIGNATED_INITIALIZER;

// Callers must use a new imageName when source contents can change while this cache instance is alive.
- (void)thumbnailForImageName:(NSString *)imageName
                    imagePath:(NSString *)imagePath
                   targetSize:(CGSize)targetSize
                        scale:(CGFloat)scale
                   completion:(KayokoThumbnailCompletion)completion;
- (void)removeAllMemoryCachedThumbnails;
- (void)performWhenIdle:(dispatch_block_t)completion;

@end

NS_ASSUME_NONNULL_END
