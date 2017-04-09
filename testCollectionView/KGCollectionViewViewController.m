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
@property (nonatomic, strong) NSArray *sections;

@end

@implementation KGCollectionViewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.collectionView registerNib:[KGCollectionViewCell nib] forCellWithReuseIdentifier:kCellId];
    [self.collectionView registerNib:[KGSectionHeaderView nib] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:kHeaderId];
    
    self.sections = @[ @10, @15, @1, @25, @50, @1, @2, @3 ];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark <UICollectionViewDataSource>
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.sections.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.sections[section] integerValue];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    KGSectionHeaderView *view = (KGSectionHeaderView *)[collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kHeaderId forIndexPath:indexPath];
    
    NSString *text = indexPath.section ? @"Карты друзей" : @"Ваши карты";
    
    view.label.text = text;
    
    return view;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    KGCollectionViewCell *cell = (KGCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:kCellId forIndexPath:indexPath];
    
    cell.label.text = [NSString stringWithFormat:@"Карточка №%ld", (long)indexPath.item + 1];
    return cell;
}


#pragma mark <UICollectionViewDelegate>
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self.collectionView setViewMode:MTCardLayoutViewModePresenting animated:YES completion:nil];
}

@end
