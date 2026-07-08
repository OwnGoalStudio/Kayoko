//
//  KayokoTagEditorViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoTag;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTagEditorViewController : UIViewController

@property(nonatomic, copy, nullable) void (^completionHandler)(KayokoTag *tag);
@property(nonatomic, copy, nullable) void (^dismissalTransitionHandler)
    (id<UIViewControllerTransitionCoordinator> _Nullable transitionCoordinator);

- (instancetype)initWithTag:(KayokoTag *)tag localizationBundle:(NSBundle *)localizationBundle;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
