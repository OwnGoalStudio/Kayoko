//
//  KayokoPreviewView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoPreviewView.h"

@implementation KayokoPreviewView

- (instancetype)initWithName:(NSString *)name {
    self = [super init];

    if (self) {
        [self setName:name];

        [self setTextView:[[UITextView alloc] init]];
        [[self textView] setBackgroundColor:[UIColor clearColor]];
        [[self textView] setFont:[UIFont systemFontOfSize:14]];
        [[self textView] setEditable:NO];
        [[self textView] setSelectable:NO];
        [[self textView] setTextContainerInset:UIEdgeInsetsMake(8, 16, 8, 16)];
        [[[self textView] textContainer] setLineFragmentPadding:0];
        [[self textView] setHidden:YES];
        [self addSubview:[self textView]];

        [[self textView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self textView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self textView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self textView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self textView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setImageView:[[UIImageView alloc] init]];
        [[self imageView] setContentMode:UIViewContentModeScaleAspectFit];
        [[self imageView] setHidden:YES];
        [self addSubview:[self imageView]];

        [[self imageView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self imageView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self imageView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self imageView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self imageView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];
    }

    return self;
}

- (void)showText:(NSString *)text {
    [[self textView] setText:text];
    [[self textView] setHidden:NO];
    [[self imageView] setHidden:YES];
}

- (void)reset {
    [[self textView] setHidden:YES];
    [[self textView] setText:@""];
    [[self imageView] setHidden:YES];
    [[self imageView] setImage:nil];
}

- (void)scrollToTopAnimated:(BOOL)animated {
    if ([[self textView] isHidden]) {
        return;
    }

    CGPoint contentOffset = [[self textView] contentOffset];
    contentOffset.y = -[[self textView] adjustedContentInset].top;
    [[self textView] setContentOffset:contentOffset animated:animated];
}

@end
