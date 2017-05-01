#import <objc/runtime.h>
#import "UICollectionView+CardLayout.h"
#import "MTCardLayoutHelper.h"
#import "MTCardLayout.h"

static const char MTCardLayoutHelperKey;

@implementation UICollectionView (CardLayout)

- (MTCardLayoutHelper *)cardLayoutHelper {
    MTCardLayoutHelper *helper = objc_getAssociatedObject(self, &MTCardLayoutHelperKey);
    if(helper == nil) {
        helper = [[MTCardLayoutHelper alloc] initWithCollectionView:self];
        objc_setAssociatedObject(self, &MTCardLayoutHelperKey, helper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return helper;
}

- (void)cardLayoutCleanup {
	MTCardLayoutHelper *helper = objc_getAssociatedObject(self, &MTCardLayoutHelperKey);
	if (helper) {
		objc_setAssociatedObject(self, &MTCardLayoutHelperKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
}

- (MTCardLayoutViewMode)viewMode {
    return self.cardLayoutHelper.viewMode;
}

- (void)setViewMode:(MTCardLayoutViewMode)viewMode {
    [self setViewMode:viewMode animated:NO completion:nil];
}

- (void)setViewMode:(MTCardLayoutViewMode)viewMode animated:(BOOL)animated completion:(void (^)(BOOL))completion {
    void (^setPresenting)() = ^{
        self.cardLayoutHelper.viewMode = viewMode;
        self.scrollEnabled = viewMode == MTCardLayoutViewModeDefault;
        self.scrollsToTop = viewMode == MTCardLayoutViewModeDefault;
    };

    if (animated) {
        void (^animatedUpdate)() = ^{
            [self performBatchUpdates:^{
                setPresenting();
            } completion:^(BOOL finished) {
                if (completion) {
                    completion(finished);
                }
            }];
        };
        
        if (viewMode == MTCardLayoutViewModeDefault) {
            // because we can't animate changing selected card height from inside of MTCardLayout
            // we'll do it here and animate changes in the rest of cards afterwards
            NSIndexPath *selectedIndexPath = [[self indexPathsForSelectedItems] firstObject];
            UICollectionViewCell *selectedCell = [self cellForItemAtIndexPath:selectedIndexPath];
            
            [UIView animateWithDuration:0.3 animations:^{
                CGRect frame;
                MTCardLayout *layout = (MTCardLayout *)self.collectionViewLayout;
                frame = [layout layoutAttributesForItemAtIndexPath:selectedIndexPath viewMode:viewMode].frame;

                selectedCell.frame = frame;
                [selectedCell layoutIfNeeded];
                
            } completion:^(BOOL finished) {
                animatedUpdate();
            }];
            
        } else {
            animatedUpdate();
        }
    } else {
        setPresenting();
        [self.collectionViewLayout invalidateLayout];
        if (completion) {
            completion(YES);
        }
    }
}

- (void)deselectAndNotifyDelegate:(NSIndexPath *)indexPath {
    [self deselectItemAtIndexPath:indexPath animated:NO];
    if ([self.delegate respondsToSelector:@selector(collectionView:didDeselectItemAtIndexPath:)]) {
        [self.delegate collectionView:self didDeselectItemAtIndexPath:indexPath];
    }
}

- (void)selectAndNotifyDelegate:(NSIndexPath *)indexPath {
    if (indexPath.section >= [self numberOfSections] ||
        indexPath.item >= [self numberOfItemsInSection:indexPath.section]) {
        // trying to select item not present in collection dataSource
        [self setViewMode:MTCardLayoutViewModeDefault];
        return;
    }
    
    [self selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
    if ([self.delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        [self.delegate collectionView:self didSelectItemAtIndexPath:indexPath];
    }
}

@end
