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
@property(nonatomic, assign) NSUInteger previewLineCount;
@property(nonatomic, copy) NSString *historyKey;

- (instancetype)initWithName:(NSString *)name;
- (void)reloadDataWithItems:(NSArray *)items;
- (void)updateDataWithItems:(NSArray *)items animatingTopInsertions:(BOOL)animatingTopInsertions;
- (void)clearItems;
- (void)upsertItemDictionaryAtTop:(NSDictionary *)dictionary limit:(NSUInteger)limit;
- (void)removeItemDictionary:(NSDictionary *)dictionary;
- (void)removeItemAtIndexPath:(NSIndexPath *)indexPath completion:(void (^)(BOOL success))completion;
- (void)notifyContentStateChanged;

@end
