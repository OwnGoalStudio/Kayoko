//
//  KayokoSwipeUpGestureRecognizer.m
//  Kayoko
//

#import "KayokoSwipeUpGestureRecognizer.h"

#include <math.h>

static CGFloat const kKayokoSwipeUpDefaultMinimumPrimaryMovement = 240.0;
static CGFloat const kKayokoSwipeUpDefaultMinimumPrimaryMovementRate = 440.0;
static CGFloat const kKayokoSwipeUpDefaultMinimumSecondaryMovement = 0.0;
static CGFloat const kKayokoSwipeUpDefaultMaximumPrimaryMovement = CGFLOAT_MAX;
static CGFloat const kKayokoSwipeUpDefaultMaximumSecondaryMovement = 64.0;
static CGFloat const kKayokoSwipeUpDefaultMaximumOppositeMovement = 6.0;
static CGFloat const kKayokoSwipeUpDefaultRateOfMinimumMovementDecay = 0.28;
static CGFloat const kKayokoSwipeUpDefaultRateOfMaximumMovementDecay = 0.12;
static NSTimeInterval const kKayokoSwipeUpDefaultMaximumDuration = 0.5;
static NSTimeInterval const kKayokoSwipeUpMovementDecayDuration = 0.5;
static NSTimeInterval const kKayokoSwipeUpMinimumTimeDelta = 0.01;

typedef NS_ENUM(NSUInteger, KayokoSwipeUpCheckResult) {
    KayokoSwipeUpCheckResultPending = 0,
    KayokoSwipeUpCheckResultRecognized,
    KayokoSwipeUpCheckResultFailed,
};

@implementation KayokoSwipeUpGestureRecognizer {
    UITouch *_trackedTouch;
    CGPoint _startLocation;
    CGPoint _previousLocation;
    NSTimeInterval _startTime;
    NSTimeInterval _previousTime;
    BOOL _failed;
}

- (instancetype)initWithTarget:(id)target action:(SEL)action {
    self = [super initWithTarget:target action:action];
    if (self) {
        _minimumPrimaryMovement = kKayokoSwipeUpDefaultMinimumPrimaryMovement;
        _minimumPrimaryMovementRate = kKayokoSwipeUpDefaultMinimumPrimaryMovementRate;
        _minimumSecondaryMovement = kKayokoSwipeUpDefaultMinimumSecondaryMovement;
        _maximumPrimaryMovement = kKayokoSwipeUpDefaultMaximumPrimaryMovement;
        _maximumSecondaryMovement = kKayokoSwipeUpDefaultMaximumSecondaryMovement;
        _maximumOppositeMovement = kKayokoSwipeUpDefaultMaximumOppositeMovement;
        _maximumDuration = kKayokoSwipeUpDefaultMaximumDuration;
        _rateOfMinimumMovementDecay = kKayokoSwipeUpDefaultRateOfMinimumMovementDecay;
        _rateOfMaximumMovementDecay = kKayokoSwipeUpDefaultRateOfMaximumMovementDecay;
    }
    return self;
}

- (void)reset {
    [super reset];

    _trackedTouch = nil;
    _startLocation = CGPointZero;
    _previousLocation = CGPointZero;
    _startTime = 0;
    _previousTime = 0;
    _failed = NO;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.state != UIGestureRecognizerStatePossible) {
        return;
    }

    if (_trackedTouch || touches.count != 1) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }

    _trackedTouch = [touches anyObject];
    _startLocation = [_trackedTouch locationInView:self.view];
    _previousLocation = _startLocation;
    _startTime = _trackedTouch.timestamp;
    _previousTime = _startTime;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.state != UIGestureRecognizerStatePossible || !_trackedTouch || ![touches containsObject:_trackedTouch]) {
        return;
    }

    CGPoint location = [_trackedTouch locationInView:self.view];
    NSTimeInterval timestamp = _trackedTouch.timestamp;
    NSTimeInterval duration = timestamp - _startTime;

    if (duration > self.maximumDuration) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }

    CGPoint delta = CGPointMake(location.x - _startLocation.x, location.y - _startLocation.y);
    CGPoint currentPositionChange = CGPointMake(location.x - _previousLocation.x, location.y - _previousLocation.y);
    NSTimeInterval currentTimeChange = timestamp - _previousTime;

    KayokoSwipeUpCheckResult result = [self checkForSwipeWithDelta:delta
                                                              time:duration
                                             currentPositionChange:currentPositionChange
                                                 currentTimeChange:currentTimeChange];
    _previousLocation = location;
    _previousTime = timestamp;

    if (result == KayokoSwipeUpCheckResultRecognized) {
        self.state = UIGestureRecognizerStateRecognized;
        return;
    }

    if (result == KayokoSwipeUpCheckResultFailed) {
        self.state = UIGestureRecognizerStateFailed;
    }
}

- (KayokoSwipeUpCheckResult)checkForSwipeWithDelta:(CGPoint)delta
                                              time:(NSTimeInterval)time
                             currentPositionChange:(CGPoint)currentPositionChange
                                 currentTimeChange:(NSTimeInterval)currentTimeChange {
    if (_failed) {
        return KayokoSwipeUpCheckResultFailed;
    }

    CGFloat effectiveMinimumPrimaryMovement = [self decayedMovementThreshold:self.minimumPrimaryMovement
                                                                        time:time
                                                                        rate:self.rateOfMinimumMovementDecay];
    CGFloat effectiveMaximumPrimaryMovement = [self decayedMovementThreshold:self.maximumPrimaryMovement
                                                                        time:time
                                                                        rate:self.rateOfMaximumMovementDecay];
    CGFloat effectiveMinimumSecondaryMovement = [self decayedMovementThreshold:self.minimumSecondaryMovement
                                                                          time:time
                                                                          rate:self.rateOfMinimumMovementDecay];
    CGFloat effectiveMaximumSecondaryMovement = [self decayedMovementThreshold:self.maximumSecondaryMovement
                                                                          time:time
                                                                          rate:self.rateOfMaximumMovementDecay];

    if (delta.y > self.maximumOppositeMovement) {
        _failed = YES;
        return KayokoSwipeUpCheckResultFailed;
    }

    CGFloat primaryMovement = fabs(delta.y);
    CGFloat secondaryMovement = fabs(delta.x);
    if (primaryMovement > effectiveMaximumPrimaryMovement || secondaryMovement > effectiveMaximumSecondaryMovement) {
        _failed = YES;
        return KayokoSwipeUpCheckResultFailed;
    }

    if (primaryMovement < effectiveMinimumPrimaryMovement || secondaryMovement < effectiveMinimumSecondaryMovement) {
        return KayokoSwipeUpCheckResultPending;
    }

    NSTimeInterval averageDuration = MAX(time, kKayokoSwipeUpMinimumTimeDelta);
    CGFloat averagePrimaryMovementRate = primaryMovement / averageDuration;
    NSTimeInterval movementDuration = MAX(currentTimeChange, kKayokoSwipeUpMinimumTimeDelta);
    CGFloat currentPrimaryMovementRate = fabs(currentPositionChange.y / movementDuration);
    if (averagePrimaryMovementRate < self.minimumPrimaryMovementRate ||
        currentPrimaryMovementRate < self.minimumPrimaryMovementRate) {
        return KayokoSwipeUpCheckResultPending;
    }

    return KayokoSwipeUpCheckResultRecognized;
}

- (CGFloat)decayedMovementThreshold:(CGFloat)threshold time:(NSTimeInterval)time rate:(CGFloat)rate {
    if (threshold == 0.0 || threshold == CGFLOAT_MAX) {
        return threshold;
    }

    NSTimeInterval cappedTime = MIN(time, kKayokoSwipeUpMovementDecayDuration);
    return threshold * (1.0 - cappedTime * (1.0 - rate));
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_trackedTouch && [touches containsObject:_trackedTouch] && self.state == UIGestureRecognizerStatePossible) {
        self.state = UIGestureRecognizerStateFailed;
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_trackedTouch && [touches containsObject:_trackedTouch] && self.state == UIGestureRecognizerStatePossible) {
        self.state = UIGestureRecognizerStateCancelled;
    }
}

@end
