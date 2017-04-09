#import "MTCardLayout.h"
#import "UICollectionView+CardLayout.h"

@interface UICollectionView (CardLayoutPrivate)
- (void)cardLayoutCleanup;
@end

@interface MTCardLayout ()

@property (nonatomic, strong) NSIndexPath *firstVisibleIndexPath;  // hacky way to track order in which cards should collapse

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
    
    _firstVisibleIndexPath = nil;
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
	NSArray *selectedIndexPaths = [self.collectionView indexPathsForSelectedItems];
    
	return [self layoutAttributesForItemAtIndexPath:indexPath
                                  selectedIndexPath:[selectedIndexPaths firstObject]
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
    
    NSMutableArray *cells = [[NSMutableArray alloc] init];
    MTCardLayoutMetrics m = _metrics;
    rect.origin.y -= m.flexibleTop + m.listingInsets.top;
    
    NSInteger sectionsNum = [self.collectionView numberOfSections];
    for (NSInteger sectionIndex = 0; sectionIndex < sectionsNum; sectionIndex++) {
        
        [cells addObjectsFromArray:[self elementsVisibleInRect:rect
                                             forSectionAtIndex:sectionIndex]];
    }
    
    return cells;
}

- (NSArray *)elementsVisibleInRect:(CGRect)rect forSectionAtIndex:(NSInteger)sectionIndex {
    CGRect sectionRect = [self frameForSectionAtIndex:sectionIndex];
    CGRect intersection = CGRectIntersection(rect, sectionRect);
    
    if (!intersection.size.height) {
        // this section is not shown at all
        return nil;
    }
    
    NSMutableArray *cells = [[NSMutableArray alloc] init];
    MTCardLayoutMetrics m = _metrics;
    NSIndexPath *selectedIndexPath = [[self.collectionView indexPathsForSelectedItems] firstObject];
    
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
                                                selectedIndexPath:selectedIndexPath
                                                         viewMode:self.collectionView.viewMode]];
    }
    
    return cells;
}


/*
 * return cell attributes with respect to current viewing mode
 */
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
                                                       selectedIndexPath:(NSIndexPath *)selectedIndexPath
                                                                viewMode:(MTCardLayoutViewMode)viewMode {

    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    attributes.zIndex = indexPath.item + 1;
    attributes.transform3D = CATransform3DMakeTranslation(0, 0, indexPath.item * 0.0001);
    
    if (self.collectionView.viewMode == MTCardLayoutViewModePresenting) {
        // setting ref to first visible card after switching to MTCardLayoutViewModePresenting
        self.firstVisibleIndexPath = self.firstVisibleIndexPath ?: indexPath;
        
        if (selectedIndexPath && [selectedIndexPath isEqual:indexPath]) {
            // Layout selected cell (normal size)
            BOOL singleCard = ([self.collectionView numberOfItemsInSection:indexPath.section] == 1);
            attributes.frame = frameForSelectedCard(self.collectionView.bounds, self.collectionView.contentInset, _metrics, singleCard);
        
        } else {
            // Layout unselected cell (bottom-stuck)
            attributes.frame = frameForUnselectedCard(indexPath, selectedIndexPath, self.firstVisibleIndexPath,
                                                      self.collectionView.bounds, _metrics);
        }
    
    } else {
        // stack mode

        // we're not in MTCardLayoutViewModePresenting so we'll null this ref until the next time
        self.firstVisibleIndexPath = nil;
        
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
 * Normal collapsed cell, it's height is set to be from it's origin.y to the bottom of the collection
 * but in the interface cells after it will be on top so height will look like `m.visibleHeight`
 */
CGRect frameForCardAtIndex(NSIndexPath *indexPath, CGRect b, UIEdgeInsets contentInset,
                           MTCardLayoutMetrics m, CGRect sectionFrame) {
    
    CGFloat y = sectionFrame.origin.y + m.headerHeight + indexPath.item * m.visibleHeight;
    
    CGRect f = CGRectMake(sectionFrame.origin.x, y,
                          sectionFrame.size.width, sectionFrame.size.height + sectionFrame.origin.y - y);
    
    return f;
}

/*
 * Selected cell, full height
 */
CGRect frameForSelectedCard(CGRect b, UIEdgeInsets contentInset, MTCardLayoutMetrics m, BOOL singleCard) {
    return UIEdgeInsetsInsetRect(UIEdgeInsetsInsetRect(b, contentInset), m.presentingInsets);
}

/*
 * Unselected cells. 
 * Cells from the same section are moved to the bottom stack (used when there is selected cell). Their height is `m.stackedVisibleHeight`,
 * Cells from the previous section are moved up to the top screen edge with height 0.
 * Cells from the next section are moved down to the bottom screen edge with the height 0.
 */
CGRect frameForUnselectedCard(NSIndexPath *indexPath, NSIndexPath *indexPathSelected,
                              NSIndexPath *firstVisibleIndexPath, CGRect b, MTCardLayoutMetrics m) {
    
    if (indexPath.section < indexPathSelected.section) {
        // cell from the upper section relative to selected
        return CGRectMake(0, 0, b.size.width, 0);
        
    } else if (indexPath.section > indexPathSelected.section) {
        // cell from the lower section relative to selected
        return CGRectMake(0, b.origin.y + b.size.height, b.size.width, 0);
    }
    
    // cell is from the same section as selected
    
    // check order in the bottom stack
    NSInteger itemOrder;
    if (firstVisibleIndexPath.section == indexPath.section) {
        itemOrder = indexPath.item - firstVisibleIndexPath.item;
    } else {
        itemOrder = indexPath.item;
    }

    if (indexPathSelected && indexPath.item > indexPathSelected.item) itemOrder--;
	
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
- (CGRect)frameForSectionAtIndex:(NSInteger)sectionIndex
{
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
