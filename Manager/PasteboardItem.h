//
//  PasteboardItem.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

static NSString *const kItemKeyBundleIdentifier = @"bundle_identifier";
static NSString *const kItemKeyContent = @"content";
static NSString *const kItemKeyImageName = @"image_name";
static NSString *const kItemKeyHasLink = @"has_link";

@interface PasteboardItem : NSObject

@property(nonatomic, copy) NSString *bundleIdentifier;
@property(nonatomic, copy) NSString *displayName;
@property(nonatomic, copy) NSString *content;
@property(nonatomic, copy) NSString *imageName;
@property(nonatomic, assign) BOOL hasLink;

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                              andContent:(NSString *)content
                          withImageNamed:(NSString *)imageName;
+ (PasteboardItem *)itemFromDictionary:(NSDictionary *)dictionary;

@end
