#import <UIKit/UIKit.h>
#import "MTCommonTypes.h"

@interface MTCardLayout : UICollectionViewLayout

@property (nonatomic, assign) MTCardLayoutMetrics metrics;

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
                                                                viewMode:(MTCardLayoutViewMode)viewMode;

@end
