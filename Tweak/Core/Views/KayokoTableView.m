//
//  KayokoTableView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoTableView.h"
#import "KayokoTableViewCell.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

static CGFloat const kKayokoTableViewBaseRowHeight = 65;
static CGFloat const kKayokoTableViewAdditionalPreviewLineHeight = 18;
static NSUInteger const kKayokoTableViewMaximumPreviewLineCount = 3;

@implementation KayokoTableView

- (NSArray *)indexPathsFromRow:(NSUInteger)startRow count:(NSUInteger)count {
    NSMutableArray *indexPaths = [[NSMutableArray alloc] initWithCapacity:count];
    for (NSUInteger row = startRow; row < startRow + count; row++) {
        [indexPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
    }
    return indexPaths;
}

- (BOOL)canUpdateFromItems:(NSArray *)oldItems
                   toItems:(NSArray *)newItems
      withTopInsertedCount:(NSUInteger *)insertedCount
        bottomRemovedCount:(NSUInteger *)removedCount {
    NSUInteger oldCount = [oldItems count];
    NSUInteger newCount = [newItems count];

    if (newCount == 0 || [oldItems isEqualToArray:newItems]) {
        return NO;
    }

    if (oldCount == 0) {
        if (insertedCount) {
            *insertedCount = newCount;
        }
        if (removedCount) {
            *removedCount = 0;
        }
        return YES;
    }

    for (NSUInteger candidateInsertedCount = 1; candidateInsertedCount <= newCount; candidateInsertedCount++) {
        NSUInteger retainedCount = MIN(oldCount, newCount - candidateInsertedCount);
        if (retainedCount == 0 || candidateInsertedCount + retainedCount != newCount) {
            continue;
        }

        NSArray *newRetainedItems = [newItems subarrayWithRange:NSMakeRange(candidateInsertedCount, retainedCount)];
        NSArray *oldRetainedItems = [oldItems subarrayWithRange:NSMakeRange(0, retainedCount)];
        if (![newRetainedItems isEqualToArray:oldRetainedItems]) {
            continue;
        }

        if (insertedCount) {
            *insertedCount = candidateInsertedCount;
        }
        if (removedCount) {
            *removedCount = oldCount - retainedCount;
        }
        return YES;
    }

    return NO;
}

- (NSUInteger)indexOfItemMatchingDictionary:(NSDictionary *)dictionary inItems:(NSArray *)items {
    NSString *content = dictionary[kItemKeyContent];
    if ([content length] == 0) {
        return NSNotFound;
    }

    for (NSUInteger index = 0; index < [items count]; index++) {
        NSDictionary *item = items[index];
        if ([item[kItemKeyContent] isEqualToString:content]) {
            return index;
        }
    }
    return NSNotFound;
}

- (NSUInteger)normalizedLimit:(NSUInteger)limit {
    return limit == 0 ? NSUIntegerMax : limit;
}

- (instancetype)initWithName:(NSString *)name {
    self = [super init];

    if (self) {
        [self setName:name];
        [self setHistoryKey:kHistoryKeyHistory];
        [self setDelegate:self];
        [self setDataSource:self];
        [self setBackgroundColor:[UIColor clearColor]];
        [self setPreviewLineCount:1];
    }

    return self;
}

- (void)setPreviewLineCount:(NSUInteger)previewLineCount {
    NSUInteger lineCount = MIN(MAX(previewLineCount, 1), kKayokoTableViewMaximumPreviewLineCount);
    _previewLineCount = lineCount;
    [self setRowHeight:kKayokoTableViewBaseRowHeight + (lineCount - 1) * kKayokoTableViewAdditionalPreviewLineHeight];
    [self reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self items] count] ?: 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *dictionary = [self items][[indexPath row]];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];

    KayokoTableViewCell *cell = [[KayokoTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                                   andItem:item
                                                       andPreviewLineCount:[self previewLineCount]
                                                           reuseIdentifier:@"KayokoTableViewCell"];

    // Add long press gesture recognizer to preview the cell's content.
    UILongPressGestureRecognizer *gesture =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGestureRecognizer:)];
    [cell addGestureRecognizer:gesture];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];

    NSDictionary *dictionary = [self items][[indexPath row]];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];
    [[PasteboardManager sharedInstance] performDirectPasteWithPasteboardItem:item
                                                                 historyItem:item
                                                          fromHistoryWithKey:[self historyKey]
                                                             shouldAutoPaste:YES];

    [[self superview] performSelector:@selector(hide)];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:[self items][[indexPath row]]];

    // If automatic paste is enabled and the item has text, add an option to only copy the contents without pasting.
    // If the item has an image we want to instead add an option to save the image to the photo library.
    if ([self automaticallyPaste] || ![[item imageName] isEqualToString:@""]) {
        UIContextualAction *saveAction;

        if ([[item imageName] isEqualToString:@""]) {
            saveAction = [UIContextualAction
                contextualActionWithStyle:UIContextualActionStyleNormal
                                    title:@""
                                  handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView,
                                            void (^_Nonnull completionHandler)(BOOL)) {
                                    BOOL copied =
                                        [[PasteboardManager sharedInstance] copyPasteboardItemToPasteboard:item];
                                    completionHandler(copied);
                                  }];
            [saveAction setImage:[UIImage systemImageNamed:@"doc.on.doc.fill"]];
        } else {
            saveAction = [UIContextualAction
                contextualActionWithStyle:UIContextualActionStyleNormal
                                    title:@""
                                  handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView,
                                            void (^_Nonnull completionHandler)(BOOL)) {
                                    UIImageWriteToSavedPhotosAlbum(
                                        [[PasteboardManager sharedInstance] getImageForItem:item], nil, nil, nil);
                                    completionHandler(YES);
                                  }];
            [saveAction setImage:[UIImage systemImageNamed:@"square.and.arrow.down.fill"]];
        }

        [saveAction setBackgroundColor:[UIColor systemOrangeColor]];
        [actions addObject:saveAction];
    }

    if ([item hasLink]) {
        UIContextualAction *linkAction = [UIContextualAction
            contextualActionWithStyle:UIContextualActionStyleNormal
                                title:@""
                              handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView,
                                        void (^_Nonnull completionHandler)(BOOL)) {
                                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[item content]]
                                                                   options:@{}
                                                         completionHandler:nil];
                                completionHandler(YES);
                              }];
        [linkAction setImage:[UIImage systemImageNamed:@"arrow.up"]];
        [linkAction setBackgroundColor:[UIColor systemGreenColor]];
        [actions addObject:linkAction];
    }

    return [UISwipeActionsConfiguration configurationWithActions:actions];
}

- (void)handleLongPressGestureRecognizer:(UILongPressGestureRecognizer *)recognizer {
    if ([recognizer state] == UIGestureRecognizerStateBegan) {
        KayokoTableViewCell *cell = (KayokoTableViewCell *)[recognizer view];
        NSIndexPath *indexPath = [self indexPathForCell:cell];

        NSDictionary *dictionary = [self items][[indexPath row]];
        PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];

        [[self superview] performSelector:@selector(showPreviewWithItem:) withObject:item];
    }
}

- (void)reloadDataWithItems:(NSArray *)items {
    [self updateDataWithItems:items animatingTopInsertions:NO];
}

- (void)updateDataWithItems:(NSArray *)items animatingTopInsertions:(BOOL)animatingTopInsertions {
    NSArray *oldItems = [self items] ?: @[];
    NSArray *newItems = items ?: @[];
    if ([oldItems isEqualToArray:newItems] && [self numberOfRowsInSection:0] == [oldItems count]) {
        return;
    }

    NSUInteger insertedCount = 0;
    NSUInteger removedCount = 0;
    BOOL canAnimateTopInsertion = animatingTopInsertions && [self numberOfRowsInSection:0] == [oldItems count] &&
                                  [self canUpdateFromItems:oldItems
                                                   toItems:newItems
                                      withTopInsertedCount:&insertedCount
                                        bottomRemovedCount:&removedCount];

    if (!canAnimateTopInsertion) {
        [self setItems:newItems];
        [self reloadData];
        return;
    }

    NSArray *insertedIndexPaths = [self indexPathsFromRow:0 count:insertedCount];
    NSArray *removedIndexPaths = [self indexPathsFromRow:[oldItems count] - removedCount count:removedCount];

    [self
        performBatchUpdates:^{
          [self setItems:newItems];
          if ([insertedIndexPaths count] > 0) {
              [self insertRowsAtIndexPaths:insertedIndexPaths withRowAnimation:UITableViewRowAnimationTop];
          }
          if ([removedIndexPaths count] > 0) {
              [self deleteRowsAtIndexPaths:removedIndexPaths withRowAnimation:UITableViewRowAnimationFade];
          }
        }
                 completion:nil];
}

- (void)clearItems {
    NSArray *oldItems = [self items] ?: @[];
    if ([oldItems count] == 0) {
        return;
    }

    [self setItems:@[]];
    [self reloadData];
    [self notifyContentStateChanged];
}

- (void)upsertItemDictionaryAtTop:(NSDictionary *)dictionary limit:(NSUInteger)limit {
    if (!dictionary || [dictionary[kItemKeyContent] length] == 0) {
        return;
    }

    NSArray *oldItems = [self items] ?: @[];
    NSMutableArray *newItems = [oldItems mutableCopy];
    NSUInteger existingIndex = [self indexOfItemMatchingDictionary:dictionary inItems:newItems];
    NSUInteger normalizedLimit = [self normalizedLimit:limit];

    if (existingIndex != NSNotFound) {
        [newItems removeObjectAtIndex:existingIndex];
    }
    [newItems insertObject:dictionary atIndex:0];
    while ([newItems count] > normalizedLimit) {
        [newItems removeLastObject];
    }

    if ([oldItems isEqualToArray:newItems] && [self numberOfRowsInSection:0] == [oldItems count]) {
        return;
    }

    if ([self numberOfRowsInSection:0] != [oldItems count]) {
        [self updateDataWithItems:newItems animatingTopInsertions:YES];
        return;
    }

    if (existingIndex == 0) {
        [self setItems:newItems];
        [self reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:0 inSection:0] ]
                     withRowAnimation:UITableViewRowAnimationNone];
        [self notifyContentStateChanged];
        return;
    }

    if (existingIndex != NSNotFound && existingIndex < [oldItems count] && [newItems count] == [oldItems count]) {
        [self
            performBatchUpdates:^{
              [self setItems:newItems];
              [self moveRowAtIndexPath:[NSIndexPath indexPathForRow:existingIndex inSection:0]
                            toIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            }
            completion:^(__unused BOOL finished) {
              [self notifyContentStateChanged];
            }];
        return;
    }

    NSUInteger removedCount = [oldItems count] + 1 > [newItems count] ? [oldItems count] + 1 - [newItems count] : 0;
    NSMutableArray *removedIndexPaths = [[NSMutableArray alloc] initWithCapacity:removedCount];
    for (NSUInteger row = [oldItems count] - removedCount; row < [oldItems count]; row++) {
        [removedIndexPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
    }

    [self
        performBatchUpdates:^{
          [self setItems:newItems];
          [self insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:0 inSection:0] ]
                      withRowAnimation:UITableViewRowAnimationTop];
          if ([removedIndexPaths count] > 0) {
              [self deleteRowsAtIndexPaths:removedIndexPaths withRowAnimation:UITableViewRowAnimationFade];
          }
        }
        completion:^(__unused BOOL finished) {
          [self notifyContentStateChanged];
        }];
}

- (void)removeItemDictionary:(NSDictionary *)dictionary {
    NSArray *oldItems = [self items] ?: @[];
    NSUInteger existingIndex = [self indexOfItemMatchingDictionary:dictionary inItems:oldItems];
    if (existingIndex == NSNotFound) {
        return;
    }

    [self removeItemAtIndexPath:[NSIndexPath indexPathForRow:existingIndex inSection:0] completion:nil];
}

- (void)removeItemAtIndexPath:(NSIndexPath *)indexPath completion:(void (^)(BOOL success))completion {
    if ([indexPath row] >= [[self items] count]) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [self
        performBatchUpdates:^{
          NSMutableArray *items = [[self items] mutableCopy];
          [items removeObjectAtIndex:[indexPath row]];
          [self setItems:items];
          [self deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        completion:^(__unused BOOL finished) {
          [self notifyContentStateChanged];
          if (completion) {
              completion(YES);
          }
        }];
}

- (void)notifyContentStateChanged {
    SEL selector = NSSelectorFromString(@"updateContentState");
    UIView *superview = [self superview];
    if ([superview respondsToSelector:selector]) {
        ((void (*)(id, SEL))[superview methodForSelector:selector])(superview, selector);
    }
}

@end
