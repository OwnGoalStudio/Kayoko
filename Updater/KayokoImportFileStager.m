//
//  KayokoImportFileStager.m
//  Kayoko
//

#import "KayokoImportFileStager.h"

static NSString *const kKayokoImportFileStagerErrorDomain = @"com.82flex.kayoko.import-file-stager";

@interface KayokoImportStagedFile : NSObject
@property(nonatomic, copy) NSString *stagedPath;
@property(nonatomic, copy) NSString *targetPath;
@end

@implementation KayokoImportStagedFile
@end

@interface KayokoImportFileStager ()
@property(nonatomic, copy) NSString *stagingPath;
@property(nonatomic, strong) NSMutableArray<KayokoImportStagedFile *> *stagedFiles;
@property(nonatomic, strong) NSMutableArray<NSString *> *movedTargetPaths;
@end

@implementation KayokoImportFileStager

- (instancetype)initWithBaseDirectoryPath:(NSString *)baseDirectoryPath prefix:(NSString *)prefix {
    self = [super init];
    if (self) {
        NSString *directoryName = [NSString stringWithFormat:@".%@-%@", prefix, [[NSUUID UUID] UUIDString]];
        _stagingPath = [baseDirectoryPath stringByAppendingPathComponent:directoryName];
        _stagedFiles = [[NSMutableArray alloc] init];
        _movedTargetPaths = [[NSMutableArray alloc] init];
    }
    return self;
}

- (BOOL)addDataByName:(NSDictionary<NSString *, NSData *> *)dataByName
      targetDirectory:(NSString *)targetDirectory
                error:(NSError **)error {
    if ([dataByName count] == 0) {
        return YES;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager createDirectoryAtPath:self.stagingPath
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:error]) {
        return NO;
    }

    for (NSString *name in dataByName) {
        NSData *data = dataByName[name];
        if (![name isKindOfClass:[NSString class]] || [name length] == 0 ||
            ![[name lastPathComponent] isEqualToString:name] || ![data isKindOfClass:[NSData class]] ||
            [data length] == 0) {
            if (error) {
                *error = [NSError errorWithDomain:kKayokoImportFileStagerErrorDomain
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey : @"Imported file data is invalid."}];
            }
            return NO;
        }

        NSString *targetPath = [targetDirectory stringByAppendingPathComponent:name];
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:targetPath isDirectory:&isDirectory]) {
            NSData *existingData = isDirectory ? nil : [NSData dataWithContentsOfFile:targetPath];
            if (![existingData isEqualToData:data]) {
                if (error) {
                    NSString *description =
                        [NSString stringWithFormat:@"Imported file %@ already contains different data.", name];
                    *error = [NSError errorWithDomain:kKayokoImportFileStagerErrorDomain
                                                 code:2
                                             userInfo:@{NSLocalizedDescriptionKey : description}];
                }
                return NO;
            }
            continue;
        }

        NSString *stagedName = [[NSUUID UUID] UUIDString];
        NSString *stagedPath = [self.stagingPath stringByAppendingPathComponent:stagedName];
        if (![data writeToFile:stagedPath options:NSDataWritingAtomic error:error]) {
            return NO;
        }

        KayokoImportStagedFile *stagedFile = [[KayokoImportStagedFile alloc] init];
        stagedFile.stagedPath = stagedPath;
        stagedFile.targetPath = targetPath;
        [self.stagedFiles addObject:stagedFile];
    }
    return YES;
}

- (BOOL)commitWithError:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (KayokoImportStagedFile *stagedFile in self.stagedFiles) {
        if (![fileManager moveItemAtPath:stagedFile.stagedPath toPath:stagedFile.targetPath error:error]) {
            NSError *moveError = error ? *error : nil;
            NSError *rollbackError = nil;
            if (![self rollbackWithError:&rollbackError] && error) {
                *error = rollbackError;
            } else if (error) {
                *error = moveError;
            }
            return NO;
        }
        [self.movedTargetPaths addObject:stagedFile.targetPath];
    }

    NSError *stagingError = nil;
    if ([fileManager fileExistsAtPath:self.stagingPath] && ![fileManager removeItemAtPath:self.stagingPath
                                                                                    error:&stagingError]) {
        NSError *rollbackError = nil;
        if (![self rollbackWithError:&rollbackError] && error) {
            *error = rollbackError;
        } else if (error) {
            *error = stagingError;
        }
        return NO;
    }
    return YES;
}

- (BOOL)rollbackWithError:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *firstError = nil;
    NSMutableArray<NSString *> *remainingTargetPaths = [[NSMutableArray alloc] init];
    for (NSString *targetPath in self.movedTargetPaths) {
        NSError *removeError = nil;
        if ([fileManager fileExistsAtPath:targetPath] && ![fileManager removeItemAtPath:targetPath
                                                                                  error:&removeError]) {
            firstError = firstError ?: removeError;
            [remainingTargetPaths addObject:targetPath];
        }
    }
    self.movedTargetPaths = remainingTargetPaths;

    NSError *stagingError = nil;
    if ([fileManager fileExistsAtPath:self.stagingPath] && ![fileManager removeItemAtPath:self.stagingPath
                                                                                    error:&stagingError]) {
        firstError = firstError ?: stagingError;
    }
    if (error) {
        *error = firstError;
    }
    return firstError == nil;
}

@end
