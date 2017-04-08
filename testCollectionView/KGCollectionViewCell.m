//
//  KGCollectionViewCell.m
//  testCollectionView
//
//  Created by Kostya Golenkov on 08/04/2017.
//  Copyright © 2017 home. All rights reserved.
//

#import "KGCollectionViewCell.h"

@interface KGCollectionViewCell()

@property (weak, nonatomic) IBOutlet UIView *shadedView;

@end

@implementation KGCollectionViewCell

+ (UINib *)nib {
    return [UINib nibWithNibName:NSStringFromClass([KGCollectionViewCell class]) bundle:[NSBundle mainBundle]];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat radius = self.shadedView.layer.shadowRadius;
    self.shadedView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.layer.bounds cornerRadius:radius].CGPath;
}

@end
