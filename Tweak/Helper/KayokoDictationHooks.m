//
//  KayokoDictationHooks.m
//  Kayoko
//

#define CHUseSubstrate

#import "KayokoHelper.h"

#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>

CHDeclareClass(UIKeyboardDockItem);
CHDeclareClass(UIKeyboardDockItemButton);
CHDeclareClass(UISystemKeyboardDockController);
CHDeclareClass(UIKeyboardImpl);
CHDeclareClass(UIKeyboardLayoutStar);

@interface UIKeyboardDockItem : NSObject
- (id)initWithImageName:(id)arg1 identifier:(id)arg2;
- (void)setImageName:(NSString *)arg1;
@end

@interface UIKeyboardDockItemButton : UIButton
@end

@interface UISystemKeyboardDockController : NSObject
@end

@interface UIKeyboardImpl : UIView
@end

@interface UIKBTree : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *properties;
@end

@interface UIKeyboardLayoutStar : UIView
@end

CHOptimizedMethod2(self, id, UIKeyboardDockItem, initWithImageName, id, arg1, identifier, id, arg2) {
    if ([arg1 isEqualToString:@"mic"]) {
        if (@available(iOS 16, *)) {
            arg1 = @"list.clipboard";
        } else {
            arg1 = @"doc.on.clipboard";
        }
    }
    return CHSuper2(UIKeyboardDockItem, initWithImageName, arg1, identifier, arg2);
}

CHOptimizedMethod1(self, void, UIKeyboardDockItem, setImageName, NSString *, arg1) {
    if ([arg1 isEqualToString:@"mic"]) {
        if (@available(iOS 16, *)) {
            arg1 = @"list.clipboard";
        } else {
            arg1 = @"doc.on.clipboard";
        }
    }
    CHSuper1(UIKeyboardDockItem, setImageName, arg1);
}

CHOptimizedMethod1(self, CGRect, UIKeyboardDockItemButton, imageRectForContentRect, CGRect, arg1) {
    CGRect origRect = CHSuper1(UIKeyboardDockItemButton, imageRectForContentRect, arg1);
    if (@available(iOS 16, *)) {
        if (ABS(origRect.size.width - origRect.size.height) > 1.0) {
            CGSize newSize = CGSizeMake(origRect.size.width * 0.92, origRect.size.height * 0.92);
            CGPoint newOrigin = CGPointMake(origRect.origin.x + (origRect.size.width - newSize.width) / 2,
                                            origRect.origin.y + (origRect.size.height - newSize.height) / 2);
            return CGRectMake(newOrigin.x, newOrigin.y, newSize.width, newSize.height);
        }
    } else {
        if (ABS(origRect.size.width - origRect.size.height) > 1.0) {
            CGSize newSize = CGSizeMake(origRect.size.width * 0.86, origRect.size.height * 0.86);
            CGPoint newOrigin = CGPointMake(origRect.origin.x + (origRect.size.width - newSize.width) / 2,
                                            origRect.origin.y + (origRect.size.height - newSize.height) / 2);
            return CGRectMake(newOrigin.x, newOrigin.y, newSize.width, newSize.height);
        }
    }
    return origRect;
}

CHOptimizedMethod3(self, void, UISystemKeyboardDockController, dictationItemButtonWasPressed, id, arg1, withEvent, id,
                   arg2, isRunningButton, BOOL, arg3) {
    KayokoHelperCaptureCurrentFirstResponder();
    KayokoHelperPostCoreShow();
}

CHOptimizedMethod2(self, void, UISystemKeyboardDockController, dictationItemButtonWasPressed, id, arg1, withEvent,
                   UIEvent *, event) {
    KayokoHelperPostCoreShow();
}

CHOptimizedMethod0(self, BOOL, UIKeyboardImpl, shouldShowDictationKey) { return YES; }

CHOptimizedMethod1(self, UIKBTree *, UIKeyboardLayoutStar, keyHitTest, CGPoint, point) {
    UIKBTree *orig = CHSuper1(UIKeyboardLayoutStar, keyHitTest, point);

    if ([[orig name] isEqualToString:@"Dictation-Key"]) {
        [[orig properties] setValue:@(0) forKey:@"KBinteractionType"];
        KayokoHelperPostCoreShow();
    }

    return orig;
}

void EnableKayokoActivationDictation(void) {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
      CHLoadClass_(&UIKeyboardDockItem$, NSClassFromString(@"UIKeyboardDockItem"));
      CHLoadClass_(&UIKeyboardDockItemButton$, NSClassFromString(@"UIKeyboardDockItemButton"));
      CHLoadClass_(&UISystemKeyboardDockController$, NSClassFromString(@"UISystemKeyboardDockController"));
      CHLoadClass_(&UIKeyboardImpl$, NSClassFromString(@"UIKeyboardImpl"));
      CHLoadClass_(&UIKeyboardLayoutStar$, NSClassFromString(@"UIKeyboardLayoutStar"));

      CHHook2(UIKeyboardDockItem, initWithImageName, identifier);
      CHHook1(UIKeyboardDockItem, setImageName);
      CHHook1(UIKeyboardDockItemButton, imageRectForContentRect);
      CHHook3(UISystemKeyboardDockController, dictationItemButtonWasPressed, withEvent, isRunningButton);
      CHHook2(UISystemKeyboardDockController, dictationItemButtonWasPressed, withEvent);
      CHHook0(UIKeyboardImpl, shouldShowDictationKey);
      CHHook1(UIKeyboardLayoutStar, keyHitTest);
    });
}
