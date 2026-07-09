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
@property(nonatomic, assign) CGFloat searchBarSnapHeight;

- (instancetype)initWithName:(NSString *)name;
- (void)setShowsNoSearchResultsPlaceholder:(BOOL)showsNoSearchResultsPlaceholder;
- (void)updateNoSearchResultsPlaceholderLayout;
- (BOOL)isSearchHeaderExposedAtContentOffset:(CGPoint)contentOffset;
- (BOOL)isContentOffsetAtHiddenSearchHeaderBoundary:(CGPoint)contentOffset;
- (void)adjustTargetContentOffsetForSearchBarSnap:(CGPoint *)targetContentOffset;
- (CGFloat)minimumBottomInsetForMaintainingHiddenHeaderWithAdditionalContentHeightReduction:(CGFloat)heightReduction;
- (void)prepareHiddenHeaderInsetsForRemovingRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)beginTransientContentOffsetPreservationAtContentOffset:(CGPoint)contentOffset;
- (void)scrollToTopAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
