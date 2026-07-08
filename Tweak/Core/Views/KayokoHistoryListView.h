//
//  KayokoHistoryListView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoEdgeFadingTableView.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHistoryListView : KayokoEdgeFadingTableView

@property(nonatomic, copy) NSString *name;
@property(nonatomic, assign) NSUInteger previewLineCount;
@property(nonatomic, assign) CGFloat keyboardBottomInset;

- (instancetype)initWithName:(NSString *)name;
- (void)setShowsNoSearchResultsPlaceholder:(BOOL)showsNoSearchResultsPlaceholder;
- (void)updateNoSearchResultsPlaceholderLayout;
- (BOOL)isSearchHeaderExposedAtContentOffset:(CGPoint)contentOffset;
- (BOOL)isContentOffsetAtHiddenSearchHeaderBoundary:(CGPoint)contentOffset;
- (CGFloat)minimumBottomInsetForMaintainingHiddenHeaderWithAdditionalContentHeightReduction:(CGFloat)heightReduction;
- (void)prepareHiddenHeaderInsetsForRemovingRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)beginTransientContentOffsetPreservationAtContentOffset:(CGPoint)contentOffset;
- (void)scrollToTopAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
