//
//  KayokoTableView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@interface KayokoTableView : UITableView <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, copy) NSString *name;
@property(nonatomic, strong) NSArray *items;
@property(nonatomic, assign) BOOL automaticallyPaste;
- (instancetype)initWithName:(NSString *)name;
- (void)reloadDataWithItems:(NSArray *)items;
@end
