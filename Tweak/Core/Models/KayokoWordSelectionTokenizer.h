//
//  KayokoWordSelectionTokenizer.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoWordSelectionTokenizer : NSObject

+ (NSArray<NSDictionary<NSString *, id> *> *)tokensForText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
