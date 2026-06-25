//
//  KayokoPreviewView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class KayokoWordSelectionView;

@interface KayokoPreviewView : UIView
@property(nonatomic, strong) UITextView *textView;
@property(nonatomic, strong) KayokoWordSelectionView *wordSelectionView;
@property(nonatomic, strong) UIImageView *imageView;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy, readonly) NSString *selectedText;
@property(nonatomic, assign, readonly) BOOL showingWordSelection;
@property(nonatomic, assign, readonly) BOOL hasSelectedText;
- (instancetype)initWithName:(NSString *)name;
- (void)showText:(NSString *)text enablesWordSelection:(BOOL)enablesWordSelection;
- (void)reset;
@end
