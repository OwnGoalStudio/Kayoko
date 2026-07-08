//
//  KayokoEdgeFadingTableView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

#import "KayokoEdgeFadeMaskController.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoEdgeFadingTableView : UITableView
@property(nonatomic, assign) CGFloat edgeFadeWidth;
@property(nonatomic, assign) CGFloat edgeFadeLeadingScrollOffset;
@property(nonatomic, assign) KayokoEdgeFadeAxis edgeFadeAxis;
@property(nonatomic, assign, getter=isEdgeFadeEnabled) BOOL edgeFadeEnabled;
- (void)updateEdgeFadeMask;
@end

NS_ASSUME_NONNULL_END
