#import "MTCardLayoutHelper.h"
#import "UICollectionView+CardLayout.h"

#define DEFAULT_ANIMATION_DURATION 0.25
#define SCROLLING_SPEED 300.f
#define DRAG_ACTION_LIMIT 150.0

typedef NS_ENUM(NSInteger, MTScrollingDirection) {
    MTScrollingDirectionUnknown = 0,
    MTScrollingDirectionUp,
    MTScrollingDirectionDown,
};

typedef NS_ENUM(NSInteger, MTDraggingAction) {
    MTDraggingActionNone,
    MTDraggingActionDismissPresenting,
};

@interface MTCardLayoutHelper() <UIGestureRecognizerDelegate>

@property (nonatomic, weak) UICollectionView *collectionView;
@property (nonatomic, strong) UITapGestureRecognizer * tapGestureRecognizer;
@property (nonatomic) MTDraggingAction draggingAction;
@property (nonatomic, copy) UICollectionViewLayoutAttributes *movingItemAttributes;
@property (nonatomic) CGPoint movingItemTranslation;
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, strong) CADisplayLink *scrollTimer;
@property (nonatomic) MTScrollingDirection scrollingDirection;

@end

@implementation MTCardLayoutHelper

- (id)initWithCollectionView:(UICollectionView *)collectionView {
    self = [super init];
    if (self) {
        self.collectionView = collectionView;
        self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                            action:@selector(handleTapGesture:)];
        self.tapGestureRecognizer.delegate = self;
        [self.collectionView addGestureRecognizer:self.tapGestureRecognizer];
        
        self.panGestureRecognizer = [[UIPanGestureRecognizer alloc]
                                     initWithTarget:self
                                     action:@selector(handlePanGesture:)];
        self.panGestureRecognizer.maximumNumberOfTouches = 1;
        self.panGestureRecognizer.delegate = self;
        [self.collectionView addGestureRecognizer:self.panGestureRecognizer];
    }
    
    return self;
}

- (CGRect)movingItemFrame {
    return CGRectOffset(self.movingItemAttributes.frame, self.movingItemTranslation.x, self.movingItemTranslation.y);
}

- (CGFloat)movingItemAlpha {
    CGRect frame = self.movingItemAttributes.frame;
    CGPoint translation = self.movingItemTranslation;
    if (frame.size.width == 0 || frame.size.height == 0) return 1.0;
    
    CGFloat alphaH = translation.x > -DRAG_ACTION_LIMIT ? 1.0 : MAX(0.0, (frame.size.width + translation.x + DRAG_ACTION_LIMIT) / frame.size.width - 0.1);
    CGFloat alphaV = translation.y > -DRAG_ACTION_LIMIT ? 1.0 : MAX(0.0, (frame.size.height + translation.y + DRAG_ACTION_LIMIT) / frame.size.height - 0.1);
    
    return MIN(alphaH, alphaV);
}

- (void)updateMovingCell {
    NSIndexPath *indexPath = self.movingItemAttributes.indexPath;
    NSAssert(indexPath, @"movingItemAttributes cannot be nil");
    
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
    if (!cell) return; // Cell is not visible
    
    cell.frame = self.movingItemFrame;
    cell.alpha = self.movingItemAlpha;
}

- (void)clearDraggingAction {
    self.movingItemAttributes = nil;
    self.movingItemTranslation = CGPointZero;
    self.draggingAction = MTDraggingActionNone;
}

#pragma mark - Gesture Recognizers

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint point = [gestureRecognizer locationInView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:point];
    
    if (!indexPath) {
        return NO;
    }
    
    if (gestureRecognizer == self.panGestureRecognizer) {
        if (self.collectionView.viewMode == MTCardLayoutViewModeDefault && !self.movingItemAttributes) {
            CGPoint velocity = [self.panGestureRecognizer velocityInView:self.collectionView];
            if (fabs(velocity.x) < fabs(velocity.y)) {
                return NO;
            }
        }
        return YES;
    }
    return YES;
}

#pragma mark - Tap gesture

- (void)handleTapGesture:(UITapGestureRecognizer *)gestureRecognizer {
    if (self.viewMode == MTCardLayoutViewModePresenting) {
        [self.collectionView setViewMode:MTCardLayoutViewModeDefault animated:YES completion:nil];
        NSArray *selectedIndexPaths = [self.collectionView indexPathsForSelectedItems];
        [selectedIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath * indexPath, NSUInteger idx, BOOL *stop) {
            [self.collectionView deselectAndNotifyDelegate:indexPath];
        }];
    } else {
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:[gestureRecognizer locationInView:self.collectionView]];
        if (indexPath) {
            [self.collectionView selectAndNotifyDelegate:indexPath];
        }
    }
}

#pragma mark - Pan gesture

- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer {
    
    UICollectionView *collectionView = self.collectionView;
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        if (self.draggingAction == MTDraggingActionNone) {
            NSIndexPath *indexPath = [collectionView indexPathForItemAtPoint:[gestureRecognizer locationInView:collectionView]];
            if (indexPath == nil) {
                return;
            }
            if (collectionView.viewMode == MTCardLayoutViewModePresenting) {
                if (![indexPath isEqual:[[collectionView indexPathsForSelectedItems] firstObject]]) {
                    return;
                }
                self.draggingAction = MTDraggingActionDismissPresenting;
                self.movingItemAttributes = [collectionView layoutAttributesForItemAtIndexPath:indexPath];
            }
        }
    }
    
    if (self.draggingAction == MTDraggingActionNone) {
        return;
    }
    
    NSIndexPath *indexPath = self.movingItemAttributes.indexPath;
    NSAssert(indexPath, @"movingItemAttributes cannot be nil");
    
    if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        switch (self.draggingAction)
        {
            case MTDraggingActionDismissPresenting:
            {
                self.movingItemTranslation = CGPointMake(0, [gestureRecognizer translationInView:collectionView].y);
                [self updateMovingCell];
                
                if (self.movingItemTranslation.y >= DRAG_ACTION_LIMIT) {
                    [collectionView deselectAndNotifyDelegate:indexPath];
                    [self clearDraggingAction];
                    
                    [collectionView setViewMode:MTCardLayoutViewModeDefault animated:YES completion:nil];
                }
                break;
            }
            default:
                break;
        }
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded | gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
        if (self.draggingAction == MTDraggingActionDismissPresenting) {
            NSIndexPath *indexPath = self.movingItemAttributes.indexPath;
            NSAssert(indexPath, @"movingItemAttributes cannot be nil");
            // Return item to original position
            self.movingItemTranslation = CGPointZero;
            [UIView animateWithDuration:DEFAULT_ANIMATION_DURATION animations:^{
                [self updateMovingCell];
            } completion:nil];
            [self clearDraggingAction];
        }
    }
}

#pragma mark - Moving/Scrolling

- (void)invalidatesScrollTimer {
    if (self.scrollTimer != nil) {
        [self.scrollTimer invalidate];
        self.scrollTimer = nil;
    }
    self.scrollingDirection = MTScrollingDirectionUnknown;
}

- (void)setupScrollTimerInDirection:(MTScrollingDirection)direction {
    self.scrollingDirection = direction;
    if (self.scrollTimer == nil) {
        self.scrollTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleScroll:)];
        [self.scrollTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    }
}

- (void)handleScroll:(NSTimer *)timer {
    CGSize frameSize = self.collectionView.bounds.size;
    CGSize contentSize = self.collectionView.contentSize;
    CGPoint contentOffset = self.collectionView.contentOffset;
    CGFloat distance = SCROLLING_SPEED / 60.f;
    
    switch (self.scrollingDirection)
    {
        case MTScrollingDirectionUp:
        {
            distance = -distance;
            if ((contentOffset.y + distance) <= 0.f) {
                distance = -contentOffset.y;
            }
            break;
        }
        case MTScrollingDirectionDown:
        {
            CGFloat maxY = MAX(contentSize.height, frameSize.height) - frameSize.height;
            if ((contentOffset.y + distance) >= maxY) {
                distance = maxY - contentOffset.y;
            }
            break;
        }
        default:
            break;
    }
    
    contentOffset.y += distance;
    self.collectionView.contentOffset = contentOffset;
    self.movingItemTranslation = CGPointMake(0, [self.panGestureRecognizer translationInView:self.collectionView].y + distance);
    // Reset in the gesture as well
    [self.panGestureRecognizer setTranslation:self.movingItemTranslation inView:self.collectionView];
}

@end
