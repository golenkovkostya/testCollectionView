//
//  KGSectionHeaderView.h
//  testCollectionView
//
//  Created by Kostya Golenkov on 08/04/2017.
//  Copyright © 2017 home. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface KGSectionHeaderView : UICollectionReusableView

@property (weak, nonatomic) IBOutlet UILabel *label;

+ (UINib *)nib;

@end
