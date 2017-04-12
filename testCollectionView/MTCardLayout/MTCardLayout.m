#import "MTCardLayout.h"
#import "UICollectionView+CardLayout.h"

typedef struct {
    CGSize size;
    CGFloat emptyHeight;
    NSUInteger itemsNum;
} CollectionSizeCache;

@interface UICollectionView (CardLayoutPrivate)

- (void)cardLayoutCleanup;

@end

@interface MTCardLayout ()

@property (nonatomic, strong) NSMutableDictionary *sectionFramesCache;  // cache section frame calculations inside one layout invalidation call
@property (nonatomic, assign) CollectionSizeCache collectionSizeCache;  // cache collection size calculations while it's items number or offsets are not changed

@property (nonatomic, strong) NSMutableDictionary *collapsedCardFramesCache;  // cache collapsed card frames calculations while collection items number or offsets are not changed

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
    MTCardLayoutEffects e;
 
    m.presentingInsets = UIEdgeInsetsMake(00, 0, 44, 0);
    m.listingInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    m.minimumVisibleHeight = 74;
	m.flexibleTop = 0.0;
    m.stackedVisibleHeight = 6.0;
    m.maxStackedCards = 5;
    m.bottomCardVisibleHeight = 250;
    m.headerHeight = 44;
    
    e.inheritance = 0.15;
    e.bouncesTop = YES;
    
    _metrics = m;
    _effects = e;
    
    if (invalidate) {
        [self invalidateLayout];
    }
    
    // caches init
    _collapsedCardFramesCache = [[NSMutableDictionary alloc] init];
    _sectionFramesCache = [[NSMutableDictionary alloc] init];
    _collectionSizeCache.size = CGSizeZero;
    _collectionSizeCache.emptyHeight = 0;
    _collectionSizeCache.itemsNum = 0;
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
    _sectionFramesCache = [[NSMutableDictionary alloc] init];
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
    
    NSInteger cellNum = cells.count;
    BOOL visibleSectionsProcessed = NO;
    for (NSInteger sectionIndex = 0; sectionIndex < sectionsNum; sectionIndex++) {
        
        [cells addObjectsFromArray:[self elementsVisibleInRect:rect
                                             forSectionAtIndex:sectionIndex]];
        
        // optimization to stop processing after first invisible section
        if (cells.count != cellNum) {
            visibleSectionsProcessed = YES;
        }
        
        if (visibleSectionsProcessed && cells.count == cellNum) {
            break;
        }
        
        cellNum = cells.count;
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
    
    // collect section cards frames
    for (NSUInteger item = minCellIndex; item < maxCellIndex; item++) {
        [cells addObject:[self layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:item inSection:sectionIndex]
                                                         viewMode:self.collectionView.viewMode]];
    }
    
    // check if we need to apply bouncing effect
    MTCardLayoutEffects e = _effects;
    CGRect b = self.collectionView.bounds;
    UIEdgeInsets contentInset = self.collectionView.contentInset;
    NSInteger index = 0;
    CGRect f;
    if (sectionIndex == 0 && e.bouncesTop && b.origin.y + contentInset.top < 0 &&
        self.collectionView.viewMode == MTCardLayoutViewModeDefault && e.inheritance > 0.0) {
        
        // bouncing only needs to be applied for cards in first section in default mode
        for (UICollectionViewLayoutAttributes *cellAttrs in cells) {
            f = cellAttrs.frame;
            f.origin.y -= (b.origin.y + contentInset.top) * index * e.inheritance;
            cellAttrs.frame = f;
            index++;
        }
        
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
        
        NSValue *cardFrameCachedObj = self.collapsedCardFramesCache[indexPath];
        if (cardFrameCachedObj) {
            // user frame value from cache
            attributes.frame = [cardFrameCachedObj CGRectValue];
        
        } else {
            // Layout collapsed cells (collapsed size)
            CGRect sectionFrame = [self frameForSectionAtIndex:indexPath.section];
            
            attributes.frame = frameForCardAtIndex(indexPath,
                                                   self.collectionView.bounds,
                                                   self.collectionView.contentInset,
                                                   _metrics,
                                                   sectionFrame);
            
            self.collapsedCardFramesCache[indexPath] = [NSValue valueWithCGRect:attributes.frame];
        }
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
    
    CGFloat sectionsHeight = 0;
    CGFloat emptyHeight = (m.flexibleTop + m.listingInsets.top + m.listingInsets.bottom +
                           contentInset.top + contentInset.bottom);
    
    NSUInteger totalItems = [self totalNumberOfItemsInCollection];
    
    if (!CGSizeEqualToSize(self.collectionSizeCache.size, CGSizeZero) &&
        self.collectionSizeCache.emptyHeight == emptyHeight &&
        self.collectionSizeCache.itemsNum == totalItems) {
        // return cached collection size as long as number of items is the same and insets are not changed
        return self.collectionSizeCache.size;
    }

    for (NSInteger i = 0; i < sectionsNum; i++) {
        sectionsHeight += [self frameForSectionAtIndex:i].size.height;
    }
    
    // collection size changed, updating caches
    self.collapsedCardFramesCache = [[NSMutableDictionary alloc] init];
    
    CollectionSizeCache resultSize = {.size = CGSizeMake(bounds.size.width, sectionsHeight + emptyHeight),
                                      .emptyHeight = emptyHeight,
                                      .itemsNum = totalItems};
    self.collectionSizeCache = resultSize;
    return self.collectionSizeCache.size;
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
    
    NSValue *cachedFrameObj = self.sectionFramesCache[@(sectionIndex)];
    if (cachedFrameObj) {
        // return cached section frame
        return [cachedFrameObj CGRectValue];
    }
    
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
    
    self.sectionFramesCache[@(sectionIndex)] = [NSValue valueWithCGRect:f];
    
    return f;
}

#pragma mark - Utils

- (NSUInteger)totalNumberOfItemsInCollection
{
    NSInteger sectionsNum = [self.collectionView numberOfSections];
    NSUInteger total = 0;
    for (NSInteger i = 0; i < sectionsNum; i++) {
        total += [self.collectionView numberOfItemsInSection:i];
    }
    
    return total;
}

@end
