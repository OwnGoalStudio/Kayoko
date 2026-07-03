//
//  KayokoHistoryMigrator.h
//  Kayoko
//

#import <Foundation/Foundation.h>

@class KayokoHistoryStore;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHistoryMigrationSource : NSObject

@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *historyPath;
@property(nonatomic, copy, readonly) NSString *imagesPath;

+ (instancetype)sourceWithIdentifier:(NSString *)identifier
                         historyPath:(NSString *)historyPath
                          imagesPath:(NSString *)imagesPath;
- (instancetype)initWithIdentifier:(NSString *)identifier
                       historyPath:(NSString *)historyPath
                        imagesPath:(NSString *)imagesPath NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@interface KayokoHistoryMigrator : NSObject

+ (NSArray<KayokoHistoryMigrationSource *> *)defaultMigrationSources;

- (instancetype)initWithHistoryStore:(KayokoHistoryStore *)historyStore
                    migrationSources:(NSArray<KayokoHistoryMigrationSource *> *)migrationSources
    NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithHistoryStore:(KayokoHistoryStore *)historyStore legacyHistoryPath:(NSString *)legacyHistoryPath;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)migrateIfNeededWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
