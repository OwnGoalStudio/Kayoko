//
//  KayokoSearchBar.m
//  Kayoko
//

#import "KayokoSearchBar.h"

@implementation KayokoSearchBar

- (CGRect)kayokoFrameByApplyingHorizontalInsetToFrame:(CGRect)frame {
    CGFloat inset = [self kayokoHorizontalFrameInset];
    if (inset <= 0 || CGRectGetWidth(frame) <= inset * 2) {
        return frame;
    }

    if (fabs(CGRectGetMinX(frame)) > 0.5) {
        return frame;
    }

    UIView *superview = [self superview];
    if (superview && fabs(CGRectGetWidth(frame) - CGRectGetWidth([superview bounds])) > 0.5) {
        return frame;
    }

    frame.origin.x += inset;
    frame.size.width -= inset * 2;
    return frame;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:[self kayokoFrameByApplyingHorizontalInsetToFrame:frame]];
}

@end
