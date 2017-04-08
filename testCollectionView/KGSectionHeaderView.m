//
//  KGSectionHeaderView.m
//  testCollectionView
//
//  Created by Kostya Golenkov on 08/04/2017.
//  Copyright © 2017 home. All rights reserved.
//

#import "KGSectionHeaderView.h"

@implementation KGSectionHeaderView

+ (UINib *)nib {
    return [UINib nibWithNibName:NSStringFromClass([KGSectionHeaderView class]) bundle:[NSBundle mainBundle]];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

@end
