//
//  KayokoHistoryTableView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoHistoryTableView.h"
#import "KayokoView.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

@implementation KayokoHistoryTableView

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *actions = [[[super tableView:tableView
        leadingSwipeActionsConfigurationForRowAtIndexPath:indexPath] actions] mutableCopy];
    NSDictionary *dictionary = [self items][[indexPath row]];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];

    UIContextualAction *favoriteAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleDestructive
                            title:@""
                          handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView,
                                    void (^_Nonnull completionHandler)(BOOL)) {
                            [[PasteboardManager sharedInstance]
                                movePasteboardItem:item
                                fromHistoryWithKey:kHistoryKeyHistory
                                  toHistoryWithKey:kHistoryKeyFavorites
                                        completion:^(BOOL success) {
                                          if (!success) {
                                              completionHandler(NO);
                                              return;
                                          }
                                          [self removeItemAtIndexPath:indexPath
                                                           completion:^(BOOL removed) {
                                                             if (removed) {
                                                                 [(KayokoView *)[self superview]
                                                                     handlePasteboardItemDictionary:dictionary
                                                                                movedFromHistoryKey:kHistoryKeyHistory
                                                                                        toHistoryKey:kHistoryKeyFavorites];
                                                             }
                                                             completionHandler(removed);
                                                           }];
                                        }];
                          }];
    [favoriteAction setImage:[UIImage systemImageNamed:@"heart.fill"]];
    [favoriteAction setBackgroundColor:[UIColor systemPinkColor]];
    [actions insertObject:favoriteAction atIndex:0];

    return [UISwipeActionsConfiguration configurationWithActions:actions];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:[self items][[indexPath row]]];

    UIContextualAction *deleteAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleDestructive
                            title:@""
                          handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView,
                                    void (^_Nonnull completionHandler)(BOOL)) {
                            [[PasteboardManager sharedInstance]
                                removePasteboardItem:item
                                  fromHistoryWithKey:kHistoryKeyHistory
                                   shouldRemoveImage:YES
                                          completion:^(BOOL success) {
                                            if (!success) {
                                                completionHandler(NO);
                                                return;
                                            }
                                            [self removeItemAtIndexPath:indexPath completion:completionHandler];
                                          }];
                          }];
    [deleteAction setImage:[UIImage systemImageNamed:@"trash.fill"]];
    [deleteAction setBackgroundColor:[UIColor systemRedColor]];
    [actions addObject:deleteAction];

    return [UISwipeActionsConfiguration configurationWithActions:actions];
}

@end
