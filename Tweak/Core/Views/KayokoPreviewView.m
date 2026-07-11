//
//  KayokoPreviewView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoPreviewView.h"

#import "KayokoEdgeFadingTextView.h"
#import "KayokoHeaderView.h"
#import "KayokoMainView.h"
#import "KayokoTagChipBarView.h"

static CGFloat const kKayokoPreviewViewVerticalFadeHeight = 20;
static CGFloat const kKayokoPreviewImageMaximumZoomMultiplier = 4.0;

@interface KayokoPreviewView () <UITextViewDelegate, UIScrollViewDelegate>

#pragma mark - Views

@property(nonatomic, strong) KayokoTagChipBarView *tagChipBarView;
@property(nonatomic, strong) UIScrollView *imageScrollView;
@property(nonatomic, strong, readwrite) KayokoHeaderView *headerView;
@property(nonatomic, strong, readwrite) UIView *transitionContentView;

#pragma mark - Image State

@property(nonatomic, assign) BOOL imageScrollViewNeedsReset;
@property(nonatomic, assign) CGSize imageScrollViewLayoutSize;
@property(nonatomic, assign) CGFloat imageScrollViewLayoutBottomInset;
@end

@implementation KayokoPreviewView

#pragma mark - Lifecycle

- (instancetype)initWithName:(NSString *)name {
    self = [super init];

    if (self) {
        [self setClipsToBounds:YES];
        [self setName:name];
        [self setHeaderView:[[KayokoHeaderView alloc] initWithTitle:name]];
        [self addSubview:[self headerView]];

        [[self headerView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[ [[[self headerView] heightAnchor]
                                                    constraintEqualToConstant:[KayokoHeaderView preferredHeight]] ]];

        [self setTransitionContentView:[[UIView alloc] init]];
        [self insertSubview:[self transitionContentView] belowSubview:[self headerView]];
        [[self transitionContentView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self transitionContentView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self transitionContentView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self transitionContentView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self transitionContentView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        KayokoEdgeFadingTextView *textView = [[KayokoEdgeFadingTextView alloc] init];
        [textView setEdgeFadeAxis:KayokoEdgeFadeAxisVertical];
        [textView setEdgeFadeWidth:kKayokoPreviewViewVerticalFadeHeight];
        [textView setEdgeFadeEnabled:YES];
        [self setTextView:textView];
        [[self textView] setBackgroundColor:[UIColor clearColor]];
        [[self textView] setFont:[UIFont systemFontOfSize:14]];
        [[self textView] setEditable:NO];
        [[self textView] setSelectable:NO];
        [[self textView] setAutomaticallyAdjustsScrollIndicatorInsets:NO];
        [[self textView] setDelegate:self];
        [[self textView] setTextContainerInset:UIEdgeInsetsMake(8, 16, 8, 16)];
        [[[self textView] textContainer] setLineFragmentPadding:0];
        [[self textView] setHidden:YES];
        [[self transitionContentView] addSubview:[self textView]];

        [[self textView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self textView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor]
                                                        constant:kKayokoHeaderContentSpacing],
            [[[self textView] leadingAnchor] constraintEqualToAnchor:[[self safeAreaLayoutGuide] leadingAnchor]],
            [[[self textView] trailingAnchor] constraintEqualToAnchor:[[self safeAreaLayoutGuide] trailingAnchor]],
            [[[self textView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setImageScrollView:[[UIScrollView alloc] init]];
        [[self imageScrollView] setBackgroundColor:[UIColor clearColor]];
        [[self imageScrollView] setHidden:YES];
        [[self imageScrollView] setDelegate:self];
        [[self imageScrollView] setBounces:NO];
        [[self imageScrollView] setBouncesZoom:NO];
        [[self imageScrollView] setShowsHorizontalScrollIndicator:NO];
        [[self imageScrollView] setShowsVerticalScrollIndicator:NO];
        [[self imageScrollView] setAutomaticallyAdjustsScrollIndicatorInsets:NO];
        [[self imageScrollView] setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentNever];
        [[self transitionContentView] addSubview:[self imageScrollView]];

        [[self imageScrollView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self imageScrollView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor]
                                                               constant:kKayokoHeaderContentSpacing],
            [[[self imageScrollView] leadingAnchor] constraintEqualToAnchor:[[self safeAreaLayoutGuide] leadingAnchor]],
            [[[self imageScrollView] trailingAnchor]
                constraintEqualToAnchor:[[self safeAreaLayoutGuide] trailingAnchor]],
            [[[self imageScrollView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setImageView:[[UIImageView alloc] init]];
        [[self imageView] setContentMode:UIViewContentModeScaleAspectFit];
        [[self imageScrollView] addSubview:[self imageView]];

        [self setTagChipBarView:[[KayokoTagChipBarView alloc] initWithFrame:CGRectZero]];
        [[self transitionContentView] addSubview:[self tagChipBarView]];
    }

    return self;
}

#pragma mark - Tag Bar

- (void)setKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    keyboardBottomInset = MAX(keyboardBottomInset, 0);
    if (_keyboardBottomInset == keyboardBottomInset) {
        return;
    }

    _keyboardBottomInset = keyboardBottomInset;
    [self layoutTagChipBarView];
    [self updateTextViewScrollInsets];
    [self updateImageScrollInsets];
    [self setNeedsLayout];
}

- (CGFloat)visibleTagBarHeight {
    return [[self tagChipBarView] isHidden] ? 0 : [KayokoTagChipBarView preferredHeight];
}

- (BOOL)hasVisibleTagBar {
    return [self visibleTagBarHeight] > 0;
}

- (CGFloat)safeAreaBottomInsetForScrollContent {
    UIView *view = self;
    while (view) {
        if ([view isKindOfClass:[KayokoMainView class]]) {
            return [(KayokoMainView *)view safeAreaBottomInsetForContentView:self];
        }
        view = [view superview];
    }

    return MAX([self safeAreaInsets].bottom, 0);
}

- (CGFloat)scrollBottomInset {
    CGFloat tagBarHeight = [self visibleTagBarHeight];
    if ([self keyboardBottomInset] > 0) {
        return [self keyboardBottomInset] + tagBarHeight;
    }
    return tagBarHeight > 0 ? tagBarHeight : [self safeAreaBottomInsetForScrollContent];
}

- (CGFloat)imageScrollBottomInset {
    return [self keyboardBottomInset] + [self visibleTagBarHeight];
}

- (void)layoutTagChipBarView {
    CGFloat tagBarHeight = [self visibleTagBarHeight];
    if (tagBarHeight <= 0) {
        [[self tagChipBarView] setFrame:CGRectZero];
        return;
    }

    UIEdgeInsets safeAreaInsets = [self safeAreaInsets];
    CGFloat x = safeAreaInsets.left;
    CGFloat width = MAX(CGRectGetWidth([self bounds]) - safeAreaInsets.left - safeAreaInsets.right, 0);
    CGFloat y = MAX(CGRectGetHeight([self bounds]) - [self keyboardBottomInset] - tagBarHeight, 0);
    void (^layoutUpdates)(void) = ^{
      [[self tagChipBarView] setBottomMaterialExtension:0];
      [[self tagChipBarView] setFrame:CGRectMake(x, y, width, tagBarHeight)];
      [[self tagChipBarView] layoutIfNeeded];
    };
    if ([UIView inheritedAnimationDuration] > 0) {
        layoutUpdates();
    } else {
        [UIView performWithoutAnimation:layoutUpdates];
    }
}

- (void)updateTagBarFloatingProgressAnimated:(BOOL)animated {
    if ([[self tagChipBarView] isHidden]) {
        return;
    }

    CGFloat floatingProgress = 0.0;
    if (![[self textView] isHidden]) {
        floatingProgress = [KayokoTagChipBarView floatingProgressForScrollView:[self textView]];
    } else if (![[self imageScrollView] isHidden]) {
        floatingProgress = [KayokoTagChipBarView floatingProgressForScrollView:[self imageScrollView]];
    }

    [[self tagChipBarView] setFloatingProgress:floatingProgress animated:animated];
}

#pragma mark - Scroll Insets

- (void)updateTextViewScrollInsets {
    CGFloat tagBarHeight = [self visibleTagBarHeight];
    CGFloat bottomInset = [self scrollBottomInset];

    UIEdgeInsets contentInset = [[self textView] contentInset];
    contentInset.bottom = bottomInset;
    [[self textView] setContentInset:contentInset];

    UIEdgeInsets indicatorInsets = UIEdgeInsetsMake(0, 0, bottomInset, 0);
    [[self textView] setVerticalScrollIndicatorInsets:indicatorInsets];
    [(KayokoEdgeFadingTextView *)[self textView]
        setEdgeFadeInsets:UIEdgeInsetsMake(0, 0, [self keyboardBottomInset] + tagBarHeight, 0)];
}

- (void)updateImageScrollInsets {
    CGFloat bottomInset = [self imageScrollBottomInset];
    UIEdgeInsets contentInset = [[self imageScrollView] contentInset];
    if (fabs(contentInset.bottom - bottomInset) <= 0.5 && contentInset.top == 0 && contentInset.left == 0 &&
        contentInset.right == 0) {
        return;
    }

    contentInset = UIEdgeInsetsMake(0, 0, bottomInset, 0);
    [[self imageScrollView] setContentInset:contentInset];
    [[self imageScrollView] setScrollIndicatorInsets:contentInset];
}

#pragma mark - Image Layout

- (CGSize)imageSizeForCurrentImage {
    UIImage *image = [[self imageView] image];
    CGSize imageSize = [image size];
    if (imageSize.width <= 0 || imageSize.height <= 0) {
        return CGSizeZero;
    }
    return imageSize;
}

- (CGSize)imageViewportSizeForCurrentLayout {
    UIEdgeInsets safeAreaInsets = [self safeAreaInsets];
    CGFloat viewportTop = CGRectGetMaxY([[self headerView] frame]) + kKayokoHeaderContentSpacing;
    CGFloat viewportWidth = MAX(CGRectGetWidth([self bounds]) - safeAreaInsets.left - safeAreaInsets.right, 0);
    CGFloat viewportHeight = MAX(CGRectGetHeight([self bounds]) - viewportTop, 0);
    return CGSizeMake(viewportWidth, viewportHeight);
}

- (CGFloat)minimumImageZoomScaleForImageSize:(CGSize)imageSize {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
        return 1.0;
    }

    UIScrollView *scrollView = [self imageScrollView];
    UIEdgeInsets contentInset = [scrollView contentInset];
    CGSize viewportSize = [self imageViewportSizeForCurrentLayout];
    CGFloat availableWidth = MAX(viewportSize.width - contentInset.left - contentInset.right, 1.0);
    CGFloat availableHeight = MAX(viewportSize.height - contentInset.top - contentInset.bottom, 1.0);
    CGFloat widthScale = availableWidth / imageSize.width;
    CGFloat heightScale = availableHeight / imageSize.height;
    return MAX(MIN(widthScale, heightScale), 0.01);
}

- (void)updateImageViewFrameForCurrentZoom {
    UIScrollView *scrollView = [self imageScrollView];
    UIImageView *imageView = [self imageView];
    if (![imageView image]) {
        return;
    }

    CGRect imageFrame = [imageView frame];
    UIEdgeInsets contentInset = [scrollView contentInset];
    CGSize viewportSize = [self imageViewportSizeForCurrentLayout];
    CGFloat availableWidth = MAX(viewportSize.width - contentInset.left - contentInset.right, 0);
    CGFloat availableHeight = MAX(viewportSize.height - contentInset.top - contentInset.bottom, 0);

    if (imageFrame.size.width < availableWidth) {
        imageFrame.origin.x = contentInset.left + floor((availableWidth - imageFrame.size.width) / 2.0);
    } else {
        imageFrame.origin.x = 0;
    }

    if (imageFrame.size.height < availableHeight) {
        imageFrame.origin.y = contentInset.top + floor((availableHeight - imageFrame.size.height) / 2.0);
    } else {
        imageFrame.origin.y = 0;
    }
    [imageView setFrame:imageFrame];
}

- (CGPoint)defaultImageContentOffset {
    UIEdgeInsets contentInset = [[self imageScrollView] contentInset];
    return CGPointMake(-contentInset.left, -contentInset.top);
}

- (void)resetImageScrollViewForCurrentLayout {
    CGSize imageSize = [self imageSizeForCurrentImage];
    CGSize viewportSize = [self imageViewportSizeForCurrentLayout];
    if (imageSize.width <= 0 || imageSize.height <= 0 || viewportSize.width <= 0 || viewportSize.height <= 0) {
        return;
    }

    UIScrollView *scrollView = [self imageScrollView];
    UIImageView *imageView = [self imageView];
    CGFloat minimumZoomScale = [self minimumImageZoomScaleForImageSize:imageSize];
    CGFloat maximumZoomScale =
        MAX(minimumZoomScale * kKayokoPreviewImageMaximumZoomMultiplier, minimumZoomScale + 0.01);

    [UIView performWithoutAnimation:^{
      [scrollView setMinimumZoomScale:1.0];
      [scrollView setMaximumZoomScale:1.0];
      [scrollView setZoomScale:1.0 animated:NO];
      [imageView setFrame:CGRectMake(0, 0, imageSize.width, imageSize.height)];
      [scrollView setContentSize:imageSize];
      [scrollView setMinimumZoomScale:minimumZoomScale];
      [scrollView setMaximumZoomScale:maximumZoomScale];
      [scrollView setZoomScale:minimumZoomScale animated:NO];
      [self updateImageViewFrameForCurrentZoom];
      [scrollView setContentOffset:[self defaultImageContentOffset] animated:NO];
    }];
}

- (void)layoutImageScrollViewIfNeeded {
    if ([[self imageScrollView] isHidden] || ![[self imageView] image]) {
        return;
    }

    [self updateImageScrollInsets];

    // During the fullscreen collapse, Auto Layout updates the nested scroll view one pass after this view's bounds.
    // Use the viewport implied by this view and its header so the final zoom does not inherit stale geometry.
    CGSize viewportSize = [self imageViewportSizeForCurrentLayout];
    CGFloat bottomInset = [[self imageScrollView] contentInset].bottom;
    BOOL layoutSizeChanged = !CGSizeEqualToSize(viewportSize, [self imageScrollViewLayoutSize]);
    BOOL bottomInsetChanged = fabs(bottomInset - [self imageScrollViewLayoutBottomInset]) > 0.5;
    if ([self imageScrollViewNeedsReset] || layoutSizeChanged || bottomInsetChanged) {
        [self resetImageScrollViewForCurrentLayout];
        [self setImageScrollViewNeedsReset:NO];
        [self setImageScrollViewLayoutSize:viewportSize];
        [self setImageScrollViewLayoutBottomInset:bottomInset];
    } else {
        [self updateImageViewFrameForCurrentZoom];
    }
}

#pragma mark - Content

- (void)showText:(NSString *)text {
    [[self textView] setText:text];
    [[self textView] setHidden:NO];
    [[self imageScrollView] setHidden:YES];
    [[self imageView] setImage:nil];
    [self updateTextViewScrollInsets];
    [self updateTagBarFloatingProgressAnimated:NO];
}

- (void)showImage:(nullable UIImage *)image {
    [[self textView] setHidden:YES];
    [[self imageView] setImage:image];
    [[self imageScrollView] setHidden:(image == nil)];
    [self setImageScrollViewNeedsReset:YES];
    [self updateImageScrollInsets];
    [self setNeedsLayout];
    [self layoutIfNeeded];
    [self updateTagBarFloatingProgressAnimated:NO];
}

#pragma mark - Tag Configuration

- (void)configureTagBarWithTags:(NSArray<KayokoTag *> *)tags
                selectedTagUUID:(NSString *)selectedTagUUID
               selectionHandler:(void (^)(NSString *_Nullable tagUUID))selectionHandler {
    [[self tagChipBarView] setSelectionHandler:selectionHandler];
    [[self tagChipBarView] configureWithTags:tags ?: @[] selectedTagUUID:selectedTagUUID];
    [self layoutTagChipBarView];
    [self updateTextViewScrollInsets];
    if (![[self imageScrollView] isHidden]) {
        [self setImageScrollViewNeedsReset:YES];
        [self updateImageScrollInsets];
        [self layoutImageScrollViewIfNeeded];
    }
    [self updateTagBarFloatingProgressAnimated:NO];
}

- (void)setSelectedTagUUID:(NSString *)selectedTagUUID {
    [[self tagChipBarView] setSelectedTagUUID:selectedTagUUID];
}

#pragma mark - State

- (void)reset {
    [[self textView] setHidden:YES];
    [[self textView] setText:@""];
    [[self imageScrollView] setHidden:YES];
    [[self imageView] setImage:nil];
    [[self imageScrollView] setMinimumZoomScale:1.0];
    [[self imageScrollView] setMaximumZoomScale:1.0];
    [[self imageScrollView] setZoomScale:1.0 animated:NO];
    [[self imageScrollView] setContentSize:CGSizeZero];
    [[self imageScrollView] setContentInset:UIEdgeInsetsZero];
    [[self imageScrollView] setScrollIndicatorInsets:UIEdgeInsetsZero];
    [self setImageScrollViewNeedsReset:NO];
    [self setImageScrollViewLayoutSize:CGSizeZero];
    [self setImageScrollViewLayoutBottomInset:0];
    [[self tagChipBarView] configureWithTags:@[] selectedTagUUID:nil];
    [[self tagChipBarView] setSelectionHandler:nil];
}

- (void)scrollToTopAnimated:(BOOL)animated {
    if (![[self textView] isHidden]) {
        CGPoint contentOffset = [[self textView] contentOffset];
        contentOffset.y = -[[self textView] adjustedContentInset].top;
        [[self textView] setContentOffset:contentOffset animated:animated];
    } else if (![[self imageScrollView] isHidden]) {
        [[self imageScrollView] setContentOffset:[self defaultImageContentOffset] animated:animated];
    }
}

#pragma mark - Gestures

- (BOOL)canBeginEdgeBackGesture {
    if ([[self imageScrollView] isHidden] || ![[self imageView] image]) {
        return YES;
    }

    UIScrollView *scrollView = [self imageScrollView];
    if ([scrollView zoomScale] <= [scrollView minimumZoomScale] + 0.01) {
        return YES;
    }

    CGFloat leftBoundary = -[scrollView adjustedContentInset].left;
    return [scrollView contentOffset].x <= leftBoundary + 0.5;
}

- (void)requireImagePanGestureRecognizerToFailGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer) {
        [[[self imageScrollView] panGestureRecognizer] requireGestureRecognizerToFail:gestureRecognizer];
    }
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    [self layoutTagChipBarView];
    [self updateTextViewScrollInsets];
    [self layoutImageScrollViewIfNeeded];
    [self updateTagBarFloatingProgressAnimated:NO];
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    [self layoutTagChipBarView];
    [self updateTextViewScrollInsets];
    [self updateImageScrollInsets];
    [self layoutImageScrollViewIfNeeded];
    [self updateTagBarFloatingProgressAnimated:NO];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == [self textView] || scrollView == [self imageScrollView]) {
        [self updateTagBarFloatingProgressAnimated:NO];
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    if (scrollView == [self imageScrollView]) {
        return [self imageView];
    }
    return nil;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if (scrollView == [self imageScrollView]) {
        [self updateImageViewFrameForCurrentZoom];
        [self updateTagBarFloatingProgressAnimated:NO];
    }
}

@end
