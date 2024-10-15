//
//  KayokoPreviewView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <WebKit/WebKit.h>

@interface KayokoPreviewView : UIView <WKNavigationDelegate>
@property(nonatomic, strong) UITextView *textView;
@property(nonatomic, strong) UIImageView *imageView;
@property(nonatomic, strong) WKWebView *webView;
@property(nonatomic, copy) NSString *name;
- (instancetype)initWithName:(NSString *)name;
- (void)reset;
@end
