//
//  KayokoPreviewView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoPreviewView.h"
#import "KayokoWordSelectionView.h"

@implementation KayokoPreviewView

/**
 * Initializes the preview view.
 */
- (instancetype)initWithName:(NSString *)name {
    self = [super init];

    if (self) {
        [self setName:name];

        [self setTextView:[[UITextView alloc] init]];
        [[self textView] setBackgroundColor:[UIColor clearColor]];
        [[self textView] setFont:[UIFont systemFontOfSize:14]];
        [[self textView] setEditable:NO];
        [[self textView] setSelectable:NO];
        [[self textView] setHidden:YES];
        [self addSubview:[self textView]];

        [[self textView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self textView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self textView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:16],
            [[[self textView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor] constant:-16],
            [[[self textView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setWordSelectionView:[[KayokoWordSelectionView alloc] init]];
        [[self wordSelectionView] setHidden:YES];
        [self addSubview:[self wordSelectionView]];

        [[self wordSelectionView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self wordSelectionView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self wordSelectionView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self wordSelectionView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self wordSelectionView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
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

- (NSString *)selectedText {
    if (![[self wordSelectionView] isHidden]) {
        return [[self wordSelectionView] selectedText];
    }

    return [[self textView] text];
}

- (BOOL)showingWordSelection {
    return ![[self wordSelectionView] isHidden];
}

- (BOOL)hasSelectedText {
    return [[self selectedText] length] > 0;
}

- (void)showText:(NSString *)text enablesWordSelection:(BOOL)enablesWordSelection {
    if (enablesWordSelection) {
        [[self wordSelectionView] setText:text];
        [[self wordSelectionView] setHidden:NO];
    } else {
        [[self textView] setText:text];
        [[self textView] setHidden:NO];
    }
}

/**
 * Resets the preview view.
 *
 * Hides the view as well as removes any text, image or web content.
 */
- (void)reset {
    [[self textView] setHidden:YES];
    [[self textView] setText:@""];
    [[self wordSelectionView] setHidden:YES];
    [[self wordSelectionView] reset];
    [[self imageView] setHidden:YES];
    [[self imageView] setImage:nil];
}

@end
