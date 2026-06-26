//
//  KayokoPreviewView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoPreviewView.h"
#import "KayokoWordSelectionView.h"

// Word selection creates one button per token; CJK text can approach one token per character.
static NSUInteger const kKayokoWordSelectionMaximumTextLength = 5000;

static NSString *KayokoPreviewTextByTrimmingBoundaryNewlines(NSString *text) {
    return [(text ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

static BOOL KayokoPreviewTextFitsWordSelectionLimits(NSString *text) {
    return [text length] <= kKayokoWordSelectionMaximumTextLength;
}

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
    NSString *previewText = KayokoPreviewTextByTrimmingBoundaryNewlines(text);
    BOOL shouldUseWordSelection =
        enablesWordSelection && KayokoPreviewTextFitsWordSelectionLimits(previewText);

    if (shouldUseWordSelection) {
        [[self wordSelectionView] setText:previewText];
        [[self wordSelectionView] setHidden:NO];
        [[self textView] setHidden:YES];
    } else {
        [[self textView] setText:previewText];
        [[self textView] setHidden:NO];
        [[self wordSelectionView] setHidden:YES];
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
