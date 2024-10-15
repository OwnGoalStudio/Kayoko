//
//  SingleContactCell.m
//  Akarii Utils
//
//  Created by Alexandra Aurora Göttlicher
//

#import "SingleContactCell.h"
#import <Foundation/NSDictionary.h>

@implementation SingleContactCell

/**
 * Initializes the single contact cell.
 *
 * @param style
 * @param reuseIdentifier
 * @param specifier
 *
 * @return The cell.
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];

    if (self) {
        [self setDisplayName:[specifier propertyForKey:@"displayName"]];
        [self setUsername:[specifier propertyForKey:@"username"]];

        [self setAvatarImageView:[[UIImageView alloc] init]];

        [self fetchAvatarWithCompletion:^(UIImage *avatar) {
          [UIView transitionWithView:[self avatarImageView]
                            duration:0.2
                             options:UIViewAnimationOptionTransitionCrossDissolve
                          animations:^{
                            [[self avatarImageView] setImage:avatar];
                          }
                          completion:nil];
        }];

        [[self avatarImageView] setContentMode:UIViewContentModeScaleAspectFill];
        [[self avatarImageView] setClipsToBounds:YES];
        [[[self avatarImageView] layer] setCornerRadius:21.5];
        [[[self avatarImageView] layer] setBorderWidth:2];
        [[[self avatarImageView] layer] setBorderColor:[[[UIColor labelColor] colorWithAlphaComponent:0.1] CGColor]];
        [self addSubview:[self avatarImageView]];

        [[self avatarImageView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self avatarImageView] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
            [[[self avatarImageView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:16],
            [[[self avatarImageView] widthAnchor] constraintEqualToConstant:43],
            [[[self avatarImageView] heightAnchor] constraintEqualToConstant:43]
        ]];

        [self setDisplayNameLabel:[[UILabel alloc] init]];
        [[self displayNameLabel] setText:[self displayName]];
        [[self displayNameLabel] setFont:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]];
        [[self displayNameLabel] setTextColor:[UIColor labelColor]];
        [self addSubview:[self displayNameLabel]];

        [[self displayNameLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self displayNameLabel] topAnchor] constraintEqualToAnchor:[[self avatarImageView] topAnchor] constant:4],
            [[[self displayNameLabel] leadingAnchor] constraintEqualToAnchor:[[self avatarImageView] trailingAnchor]
                                                                    constant:8],
            [[[self displayNameLabel] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor] constant:-16]
        ]];

        [self setUsernameLabel:[[UILabel alloc] init]];
        [[self usernameLabel] setText:[NSString stringWithFormat:@"@%@", [self username]]];
        [[self usernameLabel] setFont:[UIFont systemFontOfSize:11 weight:UIFontWeightRegular]];
        [[self usernameLabel] setTextColor:[[UIColor labelColor] colorWithAlphaComponent:0.6]];
        [self addSubview:[self usernameLabel]];

        [[self usernameLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self usernameLabel] leadingAnchor] constraintEqualToAnchor:[[self avatarImageView] trailingAnchor]
                                                                 constant:8],
            [[[self usernameLabel] trailingAnchor] constraintEqualToAnchor:[[self displayNameLabel] trailingAnchor]],
            [[[self usernameLabel] bottomAnchor] constraintEqualToAnchor:[[self avatarImageView] bottomAnchor]
                                                                constant:-4]
        ]];

        [self setTapRecognizerView:[[UIView alloc] init]];
        [self addSubview:[self tapRecognizerView]];

        [[self tapRecognizerView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self tapRecognizerView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self tapRecognizerView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self tapRecognizerView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self tapRecognizerView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setTap:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openUserProfile)]];
        [[self tapRecognizerView] addGestureRecognizer:[self tap]];
    }

    return self;
}

/**
 * Fetches the url for the user's avatar.
 */
- (void)fetchAvatarUrlWithCompletion:(void (^)(NSURL *avatarUrl))completion {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://github.com/%@.png", [self username]]];
    completion(url);
}

/**
 * Fetches the user's avatar.
 */
- (void)fetchAvatarWithCompletion:(void (^)(UIImage *avatar))completion {
    static NSMutableDictionary<NSString *, UIImage *> *cachedAvatars = nil;
    if (self.username && cachedAvatars[self.username]) {
        completion(cachedAvatars[self.username]);
        return;
    }
    if (!cachedAvatars) {
        cachedAvatars = [NSMutableDictionary dictionary];
    }
    [self fetchAvatarUrlWithCompletion:^(NSURL *avatarUrl) {
      if (avatarUrl) {
          dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSString *cacheDir =
                [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *avatarPath = [cacheDir
                stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@.png", NSStringFromClass([self class]),
                                                                          [self username]]];
            UIImage *avatar = nil;
            if (!avatar) {
                avatar = [UIImage imageWithContentsOfFile:avatarPath];
            }
            if (!avatar) {
                NSData *imageData = [NSData dataWithContentsOfURL:avatarUrl];
                if (imageData) {
                    [imageData writeToFile:avatarPath atomically:YES];
                }
                avatar = [UIImage imageWithData:imageData];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
              if (self.username && avatar) {
                  cachedAvatars[self.username] = avatar;
              }
              completion(avatar);
            });
          });
      } else {
          completion(nil);
      }
    }];
}

/**
 * Opens the user's profile.
 */
- (void)openUserProfile {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://github.com/%@", [self username]]];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@end
