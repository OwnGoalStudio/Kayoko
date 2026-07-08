//
//  KayokoKeyboardAvoidanceCoordinator.m
//  Kayoko
//

#import "KayokoKeyboardAvoidanceCoordinator.h"

@interface KayokoKeyboardAvoidanceCoordinator ()
@property(nonatomic, weak) UIView *view;
@property(nonatomic, weak) UIScrollView *scrollView;
@property(nonatomic, assign) UIEdgeInsets contentInsetBeforeKeyboard;
@property(nonatomic, assign) UIEdgeInsets verticalScrollIndicatorInsetsBeforeKeyboard;
@property(nonatomic, assign) BOOL keyboardInsetsApplied;
@end

@implementation KayokoKeyboardAvoidanceCoordinator

- (instancetype)initWithView:(UIView *)view scrollView:(UIScrollView *)scrollView {
    self = [super init];
    if (self) {
        _view = view;
        _scrollView = scrollView;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)startObserving {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    [notificationCenter removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(keyboardWillChangeFrame:)
                               name:UIKeyboardWillChangeFrameNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(keyboardWillHide:)
                               name:UIKeyboardWillHideNotification
                             object:nil];
}

- (void)stopObservingAndRestoreInsets {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    [notificationCenter removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [self restoreInsetsAfterKeyboard];
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    CGFloat keyboardOverlap = [self keyboardOverlapForNotification:notification];
    if (keyboardOverlap <= 0.0) {
        [self restoreInsetsWithNotification:notification];
        return;
    }

    UIScrollView *scrollView = [self scrollView];
    if (!scrollView) {
        return;
    }

    if (![self keyboardInsetsApplied]) {
        [self setContentInsetBeforeKeyboard:[scrollView contentInset]];
        [self setVerticalScrollIndicatorInsetsBeforeKeyboard:[scrollView verticalScrollIndicatorInsets]];
        [self setKeyboardInsetsApplied:YES];
    }

    UIEdgeInsets contentInset = [self contentInsetBeforeKeyboard];
    UIEdgeInsets indicatorInsets = [self verticalScrollIndicatorInsetsBeforeKeyboard];
    contentInset.bottom += keyboardOverlap;
    indicatorInsets.bottom += keyboardOverlap;
    [self applyContentInset:contentInset
        verticalScrollIndicatorInsets:indicatorInsets
                  keyboardBottomInset:keyboardOverlap
                         notification:notification];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self restoreInsetsWithNotification:notification];
}

- (CGFloat)keyboardOverlapForNotification:(NSNotification *)notification {
    UIView *view = [self view];
    NSValue *keyboardFrameValue = [[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey];
    if (!view || !keyboardFrameValue) {
        return 0.0;
    }

    CGRect keyboardFrame = [view convertRect:[keyboardFrameValue CGRectValue] fromView:nil];
    CGRect intersection = CGRectIntersection([view bounds], keyboardFrame);
    if (CGRectIsNull(intersection)) {
        return 0.0;
    }

    return MAX(0.0, CGRectGetHeight(intersection) - [self automaticBottomInset]);
}

- (CGFloat)automaticBottomInset {
    UIScrollView *scrollView = [self scrollView];
    if (!scrollView) {
        return [[self view] safeAreaInsets].bottom;
    }

    return MAX(0.0, [scrollView adjustedContentInset].bottom - [scrollView contentInset].bottom);
}

- (void)restoreInsetsWithNotification:(NSNotification *)notification {
    if (![self keyboardInsetsApplied]) {
        return;
    }

    UIEdgeInsets contentInset = [self contentInsetBeforeKeyboard];
    UIEdgeInsets indicatorInsets = [self verticalScrollIndicatorInsetsBeforeKeyboard];
    [self setKeyboardInsetsApplied:NO];
    [self applyContentInset:contentInset
        verticalScrollIndicatorInsets:indicatorInsets
                  keyboardBottomInset:0.0
                         notification:notification];
}

- (void)restoreInsetsAfterKeyboard {
    UIScrollView *scrollView = [self scrollView];
    if (![self keyboardInsetsApplied] || !scrollView) {
        return;
    }

    [scrollView setContentInset:[self contentInsetBeforeKeyboard]];
    [scrollView setVerticalScrollIndicatorInsets:[self verticalScrollIndicatorInsetsBeforeKeyboard]];
    [self setKeyboardInsetsApplied:NO];
    [self notifyKeyboardBottomInsetChange:0.0];
}

- (void)applyContentInset:(UIEdgeInsets)contentInset
    verticalScrollIndicatorInsets:(UIEdgeInsets)indicatorInsets
              keyboardBottomInset:(CGFloat)keyboardBottomInset
                     notification:(NSNotification *)notification {
    UIScrollView *scrollView = [self scrollView];
    if (!scrollView) {
        return;
    }

    void (^changes)(void) = ^{
      [self notifyKeyboardBottomInsetChange:keyboardBottomInset];
      [scrollView setContentInset:contentInset];
      [scrollView setVerticalScrollIndicatorInsets:indicatorInsets];
    };

    NSTimeInterval duration = [self keyboardAnimationDurationForNotification:notification];
    if (duration <= 0.0) {
        changes();
        return;
    }

    [UIView animateWithDuration:duration
                          delay:0.0
                        options:[self keyboardAnimationOptionsForNotification:notification]
                     animations:changes
                     completion:nil];
}

- (NSTimeInterval)keyboardAnimationDurationForNotification:(NSNotification *)notification {
    NSNumber *duration = [[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    return duration ? [duration doubleValue] : 0.25;
}

- (UIViewAnimationOptions)keyboardAnimationOptionsForNotification:(NSNotification *)notification {
    NSNumber *curve = [[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
    if (curve) {
        options |= (UIViewAnimationOptions)([curve unsignedIntegerValue] << 16);
    }
    return options;
}

- (void)notifyKeyboardBottomInsetChange:(CGFloat)keyboardBottomInset {
    if ([self keyboardBottomInsetChangeHandler]) {
        [self keyboardBottomInsetChangeHandler](keyboardBottomInset);
    }
}

@end
