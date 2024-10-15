#import <HBLog.h>
#import <substrate.h>

@import Foundation;
@import UIKit;

#import "KayokoCore.h"
#import "NotificationKeys.h"

%group DruidUI

%hook DRPasteAnnouncer

- (void)announceDeniedPaste {
    if (kayokoPrefsDisablePasteTips) return;
    %orig;
}

- (void)announcePaste:(id)arg1 {
    if (kayokoPrefsDisablePasteTips) return;
    %orig;
}

%end

%end

void EnableKayokoDisablePasteTips(void) {
    %init(DruidUI);
}