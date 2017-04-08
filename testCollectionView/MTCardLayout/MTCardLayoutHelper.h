#import <UIKit/UIKit.h>
#import "MTCommonTypes.h"

@interface MTCardLayoutHelper : NSObject

@property (nonatomic) MTCardLayoutViewMode viewMode;

@property (nonatomic, readonly) UICollectionViewLayoutAttributes *movingItemAttributes;
@property (nonatomic, readonly) CGRect movingItemFrame;
@property (nonatomic, readonly) CGFloat movingItemAlpha;

- (id)initWithCollectionView:(UICollectionView *)collectionView;

@end
