//
//  KayokoHelper.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoHelperConfiguration.h"
#import "KayokoHelperHookInstaller.h"
#import "KayokoHelperProcessContext.h"
#import "KayokoHelperRuntime.h"

__attribute((constructor)) static void initialize() {
    KayokoHelperConfiguration *configuration = [KayokoHelperConfiguration currentConfiguration];
    if (!configuration.isEnabled) {
        return;
    }

    KayokoHelperProcessContext *context = [KayokoHelperProcessContext currentContext];
    switch (context.kind) {
    case KayokoHelperProcessKindKeyboardExtension:
        [KayokoHelperHookInstaller installKeyboardExtensionHooksWithActivationMethod:configuration.activationMethod];
        return;
    case KayokoHelperProcessKindSpringBoard:
        [[KayokoHelperRuntime sharedRuntime] installSpringBoardRuntimeWithConfiguration:configuration];
        [KayokoHelperHookInstaller
            installSpringBoardActivationHooksWithActivationMethod:configuration.activationMethod];
        return;
    case KayokoHelperProcessKindApplication:
        [KayokoHelperHookInstaller installApplicationHooksWithActivationMethod:configuration.activationMethod];
        [[KayokoHelperRuntime sharedRuntime] installApplicationRuntimeWithConfiguration:configuration];
        return;
    case KayokoHelperProcessKindUnsupported:
        return;
    }
}
