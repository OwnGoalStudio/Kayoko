//
//  KayokoTagCatalog.m
//  Kayoko
//

#import "KayokoTagCatalog.h"

#import "KayokoPasteboardManager.h"
#import "KayokoTag.h"
#import "KayokoTagStore.h"

@interface KayokoTagCatalog ()
@property(nonatomic, copy) NSArray<KayokoTag *> *cachedTags;
@property(nonatomic, copy) NSDictionary<NSString *, KayokoTag *> *cachedTagsByUUID;
@property(nonatomic, assign, getter=hasLoadedTags) BOOL loadedTags;
@end

@implementation KayokoTagCatalog

+ (instancetype)sharedCatalog {
    static KayokoTagCatalog *catalog = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      catalog = [[KayokoTagCatalog alloc] init];
    });
    return catalog;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cachedTags = @[];
        _cachedTagsByUUID = @{};
    }
    return self;
}

- (NSArray<KayokoTag *> *)reloadTags {
    KayokoTagStore *store = [[KayokoTagStore alloc] initWithTagsPath:[KayokoTagStore defaultTagsPath]
                                                  localizationBundle:[KayokoPasteboardManager localizationBundle]];
    NSError *error = nil;
    NSArray<KayokoTag *> *tags = [store readTagsWithError:&error] ?: @[];

    NSMutableDictionary<NSString *, KayokoTag *> *tagsByUUID =
        [[NSMutableDictionary alloc] initWithCapacity:[tags count]];
    for (KayokoTag *tag in tags) {
        if ([[tag uuid] length] > 0) {
            tagsByUUID[[tag uuid]] = tag;
        }
    }

    [self setCachedTags:[tags copy]];
    [self setCachedTagsByUUID:tagsByUUID];
    [self setLoadedTags:YES];
    return [self cachedTags];
}

- (NSArray<KayokoTag *> *)tags {
    if (![self hasLoadedTags]) {
        return [self reloadTags];
    }
    return [self cachedTags];
}

- (KayokoTag *)tagForUUID:(NSString *)uuid {
    if ([uuid length] == 0) {
        return nil;
    }
    if (![self hasLoadedTags]) {
        [self reloadTags];
    }
    return [self cachedTagsByUUID][uuid];
}

@end
