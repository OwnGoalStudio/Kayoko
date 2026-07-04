//
//  KayokoCreditsListController.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoCreditsListController.h"

@implementation KayokoCreditsListController

- (NSArray<PSSpecifier *> *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Credits" target:self];
    }

    return _specifiers;
}

@end
