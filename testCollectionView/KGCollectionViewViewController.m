//
//  KGCollectionViewViewController.m
//  testCollectionView
//
//  Created by Kostya Golenkov on 08/04/2017.
//  Copyright © 2017 home. All rights reserved.
//

#import "KGCollectionViewViewController.h"
#import "KGSectionHeaderView.h"
#import "KGCollectionViewCell.h"
#import "UICollectionView+CardLayout.h"

static NSString * const kCellId = @"cell";
static NSString * const kHeaderId = @"header";

@interface KGCollectionViewViewController () <UICollectionViewDelegate, UICollectionViewDataSource>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

@end

@implementation KGCollectionViewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
     [self.collectionView registerNib:[KGCollectionViewCell nib] forCellWithReuseIdentifier:kCellId];
    [self.collectionView registerNib:[KGSectionHeaderView nib] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:kHeaderId];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark <UICollectionViewDataSource>
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return 10;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    KGSectionHeaderView *view = (KGSectionHeaderView *)[collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kHeaderId forIndexPath:indexPath];
    return view;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    KGCollectionViewCell *cell = (KGCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:kCellId forIndexPath:indexPath];
    return cell;
}


#pragma mark <UICollectionViewDelegate>
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self.collectionView setViewMode:MTCardLayoutViewModePresenting animated:YES completion:nil];
}

@end
