#import <UIKit/UIKit.h>
#import "MTCommonTypes.h"

@interface MTCardLayout : UICollectionViewLayout

@property (nonatomic, assign) MTCardLayoutMetrics metrics;
@property (nonatomic, assign) MTCardLayoutEffects effects;

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
                                                                viewMode:(MTCardLayoutViewMode)viewMode;

@end
