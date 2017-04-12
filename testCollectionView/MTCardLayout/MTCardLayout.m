#import "MTCardLayout.h"
#import "UICollectionView+CardLayout.h"

@interface UICollectionView (CardLayoutPrivate)

- (void)cardLayoutCleanup;

@end

@implementation MTCardLayout

#pragma mark - Initialization

- (id)init {
    self = [super init];
    
    if (self) {
        [self useDefaultMetricsAndInvalidate:NO];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    
    if (self) {
        [self useDefaultMetricsAndInvalidate:NO];
    }
    
    return self;
}

- (void)useDefaultMetricsAndInvalidate:(BOOL)invalidate {
    MTCardLayoutMetrics m;
 
    m.presentingInsets = UIEdgeInsetsMake(00, 0, 44, 0);
    m.listingInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    m.minimumVisibleHeight = 74;
	m.flexibleTop = 0.0;
    m.stackedVisibleHeight = 6.0;
    m.maxStackedCards = 5;
    m.bottomCardVisibleHeight = 250;
    m.headerHeight = 44;
    
    _metrics = m;
    
    if (invalidate) {
        [self invalidateLayout];
    }
}

- (void)dealloc {
    [self.collectionView cardLayoutCleanup];
}

#pragma mark - Accessors

- (void)setMetrics:(MTCardLayoutMetrics)metrics {
    _metrics = metrics;
    
    [self invalidateLayout];
}

#pragma mark - Layout

- (void)prepareLayout {
    [super prepareLayout];
	_metrics.visibleHeight = _metrics.minimumVisibleHeight;    
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
	return [self layoutAttributesForItemAtIndexPath:indexPath
                                           viewMode:self.collectionView.viewMode];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind
                                                                     atIndexPath:(NSIndexPath *)indexPath {
    
    UICollectionViewLayoutAttributes *attributes;
    
    if (elementKind == UICollectionElementKindSectionHeader) {
        MTCardLayoutMetrics m = _metrics;
        
        attributes = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:elementKind
                                                                                    withIndexPath:indexPath];
        attributes.zIndex = indexPath.item;  // will be 0 for section header
        CGRect f = [self frameForSectionAtIndex:indexPath.section];
        f.size.height = m.headerHeight;
        attributes.frame = f;
        
    } else {
        attributes = [super layoutAttributesForSupplementaryViewOfKind:elementKind atIndexPath:indexPath];
    }
    
    return attributes;
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    
    CGRect effectiveBounds = self.collectionView.bounds;
    effectiveBounds.origin.y += self.collectionView.contentInset.top;
    effectiveBounds.origin.y += _metrics.listingInsets.top;
    effectiveBounds.size.height -= _metrics.listingInsets.top + _metrics.listingInsets.bottom;
	rect = CGRectIntersection(rect, effectiveBounds);
    
    return [self elementsVisibleInRect:rect];
}

- (NSArray *)elementsVisibleInRect:(CGRect)rect {
    
    MTCardLayoutMetrics m = _metrics;
    rect.origin.y -= m.flexibleTop + m.listingInsets.top;
    
    NSMutableArray *cells = [[NSMutableArray alloc] init];
    NSInteger sectionsNum = [self.collectionView numberOfSections];
    for (NSInteger sectionIndex = 0; sectionIndex < sectionsNum; sectionIndex++) {
        [cells addObjectsFromArray:[self elementsVisibleInRect:rect
                                             forSectionAtIndex:sectionIndex]];
    }
    
    return cells;
}

/*
 * return layouts for elements in the section at index `sectionIndex`
 */
- (NSArray *)elementsVisibleInRect:(CGRect)rect forSectionAtIndex:(NSInteger)sectionIndex {
    
    CGRect sectionRect = [self frameForSectionAtIndex:sectionIndex];
    CGRect intersection = CGRectIntersection(rect, sectionRect);
    
    if (!intersection.size.height) {
        // this section is not shown at all
        return nil;
    }
    
    if (self.collectionView.viewMode == MTCardLayoutViewModePresenting) {
        // we're in selected mode, for section with selected card show first 5 cards at the bottom + selected card itself
        NSIndexPath *selectedIndexPath = [[self.collectionView indexPathsForSelectedItems] firstObject];
        if (!selectedIndexPath) {
            NSLog(@"ERROR: there should be a selected path in MTCardLayoutViewModePresenting mode");
        }
        
        if (selectedIndexPath.section == sectionIndex) {
            return [self elementsForSelectedSection];
        }
    }
    
    // we're in default stack mode or not in section with selected card
    NSMutableArray *cells = [[NSMutableArray alloc] init];
    MTCardLayoutMetrics m = _metrics;
    
    NSInteger currentSectionItemsNum = [self.collectionView numberOfItemsInSection:sectionIndex];
    NSInteger minCellIndex = 0;
    
    if (intersection.origin.y <= sectionRect.origin.y + m.headerHeight) {
        // section header is visible
        [cells addObject:[self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                              atIndexPath:[NSIndexPath indexPathForItem:0 inSection:sectionIndex]]];
    } else {
        // section header is invisible
        minCellIndex = floor((intersection.origin.y - sectionRect.origin.y - (m.headerHeight * 1.5)) / m.visibleHeight);
        minCellIndex = MAX(minCellIndex, 0);
        
        if (minCellIndex > currentSectionItemsNum - 1) {
            // last card is bigger than the rest so this occurs
            minCellIndex = currentSectionItemsNum - 1;
        }
    }
    
    NSInteger maxCellIndex = ceil((intersection.origin.y + intersection.size.height - m.headerHeight - sectionRect.origin.y) / m.visibleHeight);
    
    maxCellIndex = MIN(maxCellIndex, currentSectionItemsNum);
    
    for (NSUInteger item = minCellIndex; item < maxCellIndex; item++) {
        [cells addObject:[self layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:item inSection:sectionIndex]
                                                         viewMode:self.collectionView.viewMode]];
    }
    
    return cells;
}

/*
 * return layouts for elements in the section that contains selected card
 */
- (NSArray *)elementsForSelectedSection {
    NSIndexPath *selectedIndexPath = [[self.collectionView indexPathsForSelectedItems] firstObject];
    if (!selectedIndexPath) {
        NSLog(@"ERROR: there should be a selected path in MTCardLayoutViewModePresenting mode");
    }
    
    NSMutableArray *cells = [[NSMutableArray alloc] init];
    NSInteger selectedSection = selectedIndexPath.section;
    
    [cells addObject:[self layoutAttributesForItemAtIndexPath:selectedIndexPath
                                                     viewMode:self.collectionView.viewMode]];
    MTCardLayoutMetrics m = _metrics;
    NSInteger maxStackedCardIndex = m.maxStackedCards;
    
    if (selectedIndexPath.item <= maxStackedCardIndex) {
        maxStackedCardIndex++;
    }
    
    NSInteger bottomStackNum = MIN([self.collectionView numberOfItemsInSection:selectedSection],
                                   maxStackedCardIndex);
    
    for (NSInteger i = 0; i < bottomStackNum; i++) {
        if (i == selectedIndexPath.item) {
            continue;
        }
        
        [cells addObject:[self layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:i inSection:selectedSection]
                                                         viewMode:self.collectionView.viewMode]];
    }
    
    return cells;
}

/*
 * return cell attributes with respect to current viewing mode
 */
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
                                                                viewMode:(MTCardLayoutViewMode)viewMode {

    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    attributes.zIndex = indexPath.item + 1;
    attributes.transform3D = CATransform3DMakeTranslation(0, 0, indexPath.item * 0.0001);
    
    
    if (viewMode == MTCardLayoutViewModePresenting) {
        NSIndexPath *selectedIndexPath = [[self.collectionView indexPathsForSelectedItems] firstObject];
        
        if (selectedIndexPath && [selectedIndexPath isEqual:indexPath]) {
            // Layout selected cell (normal size)
            attributes.frame = frameForSelectedCard(self.collectionView.bounds, self.collectionView.contentInset, _metrics);
        
        } else {
            // Layout unselected cell (bottom-stuck)
            attributes.frame = [self frameForUnselectedCard:indexPath];
        }
    
    } else {
        // stack mode
        
        // Layout collapsed cells (collapsed size)
        CGRect sectionFrame = [self frameForSectionAtIndex:indexPath.section];

        attributes.frame = frameForCardAtIndex(indexPath,
                                               self.collectionView.bounds,
                                               self.collectionView.contentInset,
                                               _metrics,
                                               sectionFrame);
    }
    
    attributes.hidden = attributes.frame.size.height == 0;
    
    return attributes;
}

- (CGSize)collectionViewContentSize {
    
    // content size height is affected by heights of individual sections (complete with headers)
    // as well as insets and flexibleTop
    MTCardLayoutMetrics m = _metrics;
    CGRect bounds = self.collectionView.bounds;
    UIEdgeInsets contentInset = self.collectionView.contentInset;
    NSInteger sectionsNum = [self.collectionView numberOfSections];
    
    CGFloat totalHeight = (m.flexibleTop + m.listingInsets.top + m.listingInsets.bottom +
                           contentInset.top + contentInset.bottom);
    
    for (NSInteger i = 0; i < sectionsNum; i++) {
        totalHeight += [self frameForSectionAtIndex:i].size.height;
    }
    
    return CGSizeMake(bounds.size.width, totalHeight);
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    
    return YES;
}

#pragma mark Cell positioning

/*
 * Normal collapsed cell, it's height is set to be from it's origin.y to the bottom of the section
 * but in the interface cells after it will be on top so height will look like `m.visibleHeight`
 */
CGRect frameForCardAtIndex(NSIndexPath *indexPath, CGRect b, UIEdgeInsets contentInset,
                           MTCardLayoutMetrics m, CGRect sectionFrame) {
    
    CGFloat y = sectionFrame.origin.y + m.headerHeight + indexPath.item * m.visibleHeight;
    
    CGRect selectedFrame = frameForSelectedCard(b, contentInset, m);
    
    CGRect f = CGRectMake(sectionFrame.origin.x, y,
                          sectionFrame.size.width, sectionFrame.size.height + sectionFrame.origin.y - y);
    
    // frame in stack can't be bigger than card height in presentation mode
    // (happens when section is bigger than screen)
    f.size.height = MIN(f.size.height, selectedFrame.size.height);
    
    return f;
}

/*
 * Selected cell, full height
 */
CGRect frameForSelectedCard(CGRect b, UIEdgeInsets contentInset, MTCardLayoutMetrics m) {
    return UIEdgeInsetsInsetRect(UIEdgeInsetsInsetRect(b, contentInset), m.presentingInsets);
}

/*
 * Unselected cells. 
 * Cells from the same section are moved to the bottom stack (used when there is selected cell). Their height is `m.stackedVisibleHeight`,
 * Cells from the previous section are moved up behind the top screen edge.
 * Cells from the next section are moved down to the bottom screen edge with the height 0.
 */
- (CGRect)frameForUnselectedCard:(NSIndexPath *)indexPath {
    
    MTCardLayoutMetrics m = _metrics;
    CGRect b = self.collectionView.bounds;
    NSIndexPath *selectedIndexPath = [[self.collectionView indexPathsForSelectedItems] firstObject];
    
    if (indexPath.section < selectedIndexPath.section) {
        // cell from the upper section relative to selected will move up
        return CGRectMake(0, b.origin.y - m.bottomCardVisibleHeight, b.size.width, m.bottomCardVisibleHeight);
        
    } else if (indexPath.section > selectedIndexPath.section) {
        // cell from the lower section relative to selected will hide
        return CGRectMake(0, b.origin.y + b.size.height, b.size.width, 0);
    }
    
    // cards is from the same section as selected
    
    // this is called only for `m.maxStackedCards` from the start of section with selected cards,
    // so we can use `indexPath` as an order
    NSInteger itemOrder = indexPath.item;

    if (selectedIndexPath && indexPath.item > selectedIndexPath.item) itemOrder--;
	
    if (itemOrder >= m.maxStackedCards) {
        return CGRectMake(0, b.origin.y + b.size.height, b.size.width, 0);
    }
    
    CGFloat bottomStackedTotalHeight = m.stackedVisibleHeight * m.maxStackedCards;
    
    CGRect f = UIEdgeInsetsInsetRect(b, m.presentingInsets);
    f.origin.y = b.origin.y + b.size.height + m.stackedVisibleHeight * itemOrder - bottomStackedTotalHeight;
    
    // Off screen card may be
    if (f.origin.y >= CGRectGetMaxY(b)) {
        f.origin.y = CGRectGetMaxY(b) - 0.5;
    }
    
    return f;
}

/*
 * return frame for section at index `sectionIndex`
 * where section consists of a header and number of cards, the last card has height == `bottomCardVisibleHeight`
 */
- (CGRect)frameForSectionAtIndex:(NSInteger)sectionIndex {
    
    MTCardLayoutMetrics m = _metrics;
    CGRect b = self.collectionView.bounds;
    UIEdgeInsets contentInset = self.collectionView.contentInset;

    CGRect f = CGRectMake(0, 0, b.size.width, b.size.height);
    f = UIEdgeInsetsInsetRect(UIEdgeInsetsInsetRect(f, contentInset),
                                     m.listingInsets);
    
    NSInteger cardsNum = [self.collectionView numberOfItemsInSection:sectionIndex];
    // bottom card has different height from the rest
    f.size.height = m.headerHeight + (cardsNum - 1) * m.visibleHeight + m.bottomCardVisibleHeight;
    
    if (sectionIndex <= 0) {
        return f;
    }
    
    CGRect previousSectionFrame = [self frameForSectionAtIndex:(sectionIndex - 1)];
    f.origin.y = previousSectionFrame.origin.y + previousSectionFrame.size.height;
    return f;
}

@end
