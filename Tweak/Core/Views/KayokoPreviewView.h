//
//  KayokoPreviewView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPreviewView : UIView

@property(nonatomic, strong) UITextView *textView;
@property(nonatomic, strong) UIImageView *imageView;
@property(nonatomic, copy) NSString *name;

- (instancetype)initWithName:(NSString *)name;
- (void)showText:(NSString *)text;
- (void)reset;
- (void)scrollToTopAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
