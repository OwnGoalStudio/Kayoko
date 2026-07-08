//
//  KayokoEdgeFadingTableView.m
//  Kayoko
//

#import "KayokoEdgeFadingTableView.h"

#import "KayokoEdgeFadeMaskController.h"

@interface KayokoEdgeFadingTableView ()
@property(nonatomic, strong) KayokoEdgeFadeMaskController *edgeFadeMaskController;
@end

@implementation KayokoEdgeFadingTableView

- (instancetype)init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style {
    self = [super initWithFrame:frame style:style];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    if ([self edgeFadeMaskController]) {
        return;
    }
    [self setEdgeFadeMaskController:[[KayokoEdgeFadeMaskController alloc] initWithScrollView:self]];
}

- (CGFloat)edgeFadeWidth {
    return [[self edgeFadeMaskController] fadeWidth];
}

- (void)setEdgeFadeWidth:(CGFloat)edgeFadeWidth {
    [[self edgeFadeMaskController] setFadeWidth:edgeFadeWidth];
}

- (CGFloat)edgeFadeLeadingScrollOffset {
    return [[self edgeFadeMaskController] leadingFadeScrollOffset];
}

- (void)setEdgeFadeLeadingScrollOffset:(CGFloat)edgeFadeLeadingScrollOffset {
    [[self edgeFadeMaskController] setLeadingFadeScrollOffset:edgeFadeLeadingScrollOffset];
}

- (KayokoEdgeFadeAxis)edgeFadeAxis {
    return [[self edgeFadeMaskController] axis];
}

- (void)setEdgeFadeAxis:(KayokoEdgeFadeAxis)edgeFadeAxis {
    [[self edgeFadeMaskController] setAxis:edgeFadeAxis];
}

- (BOOL)isEdgeFadeEnabled {
    return [[self edgeFadeMaskController] isEnabled];
}

- (void)setEdgeFadeEnabled:(BOOL)edgeFadeEnabled {
    [[self edgeFadeMaskController] setEnabled:edgeFadeEnabled];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateEdgeFadeMask];
}

- (void)setContentOffset:(CGPoint)contentOffset {
    [super setContentOffset:contentOffset];
    [self updateEdgeFadeMask];
}

- (void)setContentSize:(CGSize)contentSize {
    [super setContentSize:contentSize];
    [self updateEdgeFadeMask];
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    [super setContentInset:contentInset];
    [self updateEdgeFadeMask];
}

- (void)updateEdgeFadeMask {
    [[self edgeFadeMaskController] updateMask];
}

@end
