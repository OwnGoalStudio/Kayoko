//
//  KayokoSwipeUpGestureRecognizer.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSwipeUpGestureRecognizer : UIGestureRecognizer

@property(nonatomic, assign) CGFloat minimumPrimaryMovement;
@property(nonatomic, assign) CGFloat minimumPrimaryMovementRate;
@property(nonatomic, assign) CGFloat minimumSecondaryMovement;
@property(nonatomic, assign) CGFloat maximumPrimaryMovement;
@property(nonatomic, assign) CGFloat maximumSecondaryMovement;
@property(nonatomic, assign) CGFloat maximumOppositeMovement;
@property(nonatomic, assign) NSTimeInterval maximumDuration;
@property(nonatomic, assign) CGFloat rateOfMinimumMovementDecay;
@property(nonatomic, assign) CGFloat rateOfMaximumMovementDecay;

@end

NS_ASSUME_NONNULL_END
