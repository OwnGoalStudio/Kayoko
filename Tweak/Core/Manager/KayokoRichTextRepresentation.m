//
//  KayokoRichTextRepresentation.m
//  Kayoko
//

#import "KayokoRichTextRepresentation.h"

#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>
#import <stdint.h>

@interface KayokoRichTextRepresentation ()

@property(nonatomic, copy, readwrite) NSString *typeIdentifier;
@property(nonatomic, copy, readwrite) NSData *data;
@property(nonatomic, copy, readwrite) NSString *fileExtension;
@property(nonatomic, copy) NSString *decodedPlainText;

@end

@implementation KayokoRichTextRepresentation

+ (instancetype)preferredRepresentationFromDictionary:(NSDictionary<NSString *, id> *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSArray<NSArray<NSString *> *> *formats = @[
        @[ @"com.apple.flat-rtfd", @"rtfd" ],
        @[ @"public.rtfd", @"rtfd" ],
        @[ @"public.rtf", @"rtf" ],
        @[ @"public.html", @"html" ],
    ];
    for (NSArray<NSString *> *format in formats) {
        NSString *typeIdentifier = format[0];
        id value = dictionary[typeIdentifier];
        NSData *data = nil;
        if ([value isKindOfClass:[NSData class]]) {
            data = value;
        } else if ([typeIdentifier isEqualToString:@"public.html"] && [value isKindOfClass:[NSString class]]) {
            data = [value dataUsingEncoding:NSUTF8StringEncoding];
        }
        if ([data length] == 0) {
            continue;
        }

        NSAttributedStringDocumentType documentType = NSRTFDTextDocumentType;
        if ([typeIdentifier isEqualToString:@"public.rtf"]) {
            documentType = NSRTFTextDocumentType;
        } else if ([typeIdentifier isEqualToString:@"public.html"]) {
            documentType = NSHTMLTextDocumentType;
        }
        NSMutableDictionary<NSAttributedStringDocumentReadingOptionKey, id> *options =
            [@{NSDocumentTypeDocumentAttribute : documentType} mutableCopy];
        if ([typeIdentifier isEqualToString:@"public.html"]) {
            options[NSCharacterEncodingDocumentAttribute] = @(NSUTF8StringEncoding);
        }

        NSAttributedString *attributedString = nil;
        @try {
            attributedString = [[NSAttributedString alloc] initWithData:data
                                                                options:options
                                                     documentAttributes:nil
                                                                  error:nil];
        } @catch (NSException *exception) {
            (void)exception;
        }
        if (!attributedString) {
            continue;
        }

        KayokoRichTextRepresentation *representation = [[self alloc] init];
        [representation setTypeIdentifier:typeIdentifier];
        [representation setData:data];
        [representation setFileExtension:format[1]];
        [representation setDecodedPlainText:[attributedString string]];
        return representation;
    }

    return nil;
}

- (NSString *)plainText {
    return [[self decodedPlainText] copy];
}

- (NSString *)stableFileName {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);

    const unsigned char *bytes = [[self data] bytes];
    NSUInteger remainingLength = [[self data] length];
    while (remainingLength > 0) {
        CC_LONG chunkLength = (CC_LONG)MIN(remainingLength, (NSUInteger)UINT32_MAX);
        CC_SHA256_Update(&context, bytes, chunkLength);
        bytes += chunkLength;
        remainingLength -= chunkLength;
    }
    CC_SHA256_Final(digest, &context);

    NSMutableString *digestString = [[NSMutableString alloc] initWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        [digestString appendFormat:@"%02x", digest[index]];
    }
    return [NSString stringWithFormat:@"richtext-%@.%@", digestString, [self fileExtension]];
}

@end
