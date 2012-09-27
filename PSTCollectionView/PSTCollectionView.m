//
//  PSTCollectionView.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSTCollectionView.h"
#import "PSTCollectionViewController.h"
#import "PSTCollectionViewData.h"
#import "PSTCollectionViewCell.h"
#import "PSTCollectionViewLayout.h"
#import "PSTCollectionViewFlowLayout.h"
#import "PSTCollectionViewItemKey.h"
#import <QuartzCore/QuartzCore.h>

@interface PSTCollectionViewLayout (Internal)
@property (nonatomic, unsafe_unretained) PSTCollectionView *collectionView;
@end

CGFloat PSTSimulatorAnimationDragCoefficient(void);

@interface PSTCollectionView() {
    id _nibObserverToken;
    PSTCollectionViewLayout *_nibLayout;
    
    BOOL _rotationActive;
    NSMutableDictionary *_allVisibleViewsDict;
    NSMutableDictionary *_cellReuseQueues;
    NSMutableDictionary *_supplementaryViewReuseQueues;

    NSMutableDictionary *_cellClassDict, *_cellNibDict;
    NSMutableDictionary *_supplementaryViewClassDict, *_supplementaryViewNibDict;

    NSUInteger _reloadingSuspendedCount;
    NSMutableSet *_indexPathsForSelectedItems;
    NSMutableSet *_indexPathsForHighlightedItems;

    struct {
        /*
         unsigned int reloadSkippedDuringSuspension : 1;
         unsigned int scheduledUpdateVisibleCells : 1;
         unsigned int scheduledUpdateVisibleCellLayoutAttributes : 1;
         unsigned int allowsSelection : 1;
         unsigned int allowsMultipleSelection : 1;
         unsigned int updating : 1;
         */
        unsigned int fadeCellsForBoundsChange : 1;
        /*
         unsigned int updatingLayout : 1;
         unsigned int needsReload : 1;
         unsigned int reloading : 1;
         unsigned int skipLayoutDuringSnapshotting : 1;
         unsigned int layoutInvalidatedSinceLastCellUpdate : 1;
         */
    } _collectionViewFlags;
}
@property (nonatomic, strong) PSTCollectionViewData *collectionViewData;
@property (nonatomic, strong) NSString *collectionViewClassString;

@end

@implementation PSTCollectionView

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

static void PSTCollectionViewCommonSetup(PSTCollectionView *_self) {
    _self.delaysContentTouches = NO;
    _self->_indexPathsForSelectedItems = [NSMutableSet new];
    _self->_indexPathsForHighlightedItems = [NSMutableSet new];
    _self->_cellReuseQueues = [NSMutableDictionary new];
    _self->_supplementaryViewReuseQueues = [NSMutableDictionary new];
    _self->_allVisibleViewsDict = [NSMutableDictionary new];
    _self->_cellClassDict = [NSMutableDictionary new];
    _self->_cellNibDict = [NSMutableDictionary new];
    _self->_supplementaryViewClassDict = [NSMutableDictionary new];
}

- (id)initWithFrame:(CGRect)frame collectionViewLayout:(PSTCollectionViewLayout *)layout {
    if ((self = [super initWithFrame:frame])) {
        PSTCollectionViewCommonSetup(self);
        self.collectionViewLayout = layout;
        _collectionViewData = [[PSTCollectionViewData alloc] initWithCollectionView:self layout:layout];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)inCoder {
    if ((self = [super initWithCoder:inCoder])) {
        PSTCollectionViewCommonSetup(self);
        // add observer for nib deserialization.
        _nibObserverToken = [[NSNotificationCenter defaultCenter] addObserverForName:PSTCollectionViewLayoutAwokeFromNib object:nil queue:nil usingBlock:^(NSNotification *note) { _nibLayout = note.object; }];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    NSString *collectionViewClassString = [self valueForKeyPath:@"collectionViewClassString"];
    if (collectionViewClassString) {
        self.collectionViewLayout = [NSClassFromString(collectionViewClassString) new];
    }

    // check if NIB deserialization found a layout.
    // TODO: is there no better way for this???
    [[NSNotificationCenter defaultCenter] removeObserver:_nibObserverToken]; _nibObserverToken = nil;
    if (_nibLayout) {
        self.collectionViewLayout = _nibLayout; _nibLayout = nil;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ collection view layout: %@", [super description], self.collectionViewLayout];
}

- (void)dealloc {
    if (_nibObserverToken) [[NSNotificationCenter defaultCenter] removeObserver:_nibObserverToken];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

- (void)layoutSubviews {
    [super layoutSubviews];

    // Adding alpha animation to make the relayouting smooth
    if (_collectionViewFlags.fadeCellsForBoundsChange) {
        CATransition *transition = [CATransition animation];
        transition.duration = 0.25f * PSTSimulatorAnimationDragCoefficient();
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionFade;
        [self.layer addAnimation:transition forKey:@"rotationAnimation"];
    }

    [_collectionViewData validateLayoutInRect:self.bounds];

    // update cells
    if (_collectionViewFlags.fadeCellsForBoundsChange) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
    }

    [self updateVisibleCellsNow:YES];

    if (_collectionViewFlags.fadeCellsForBoundsChange) {
        [CATransaction commit];
    }

    // do we need to update contentSize?
    CGSize contentSize = [_collectionViewData collectionViewContentRect].size;
    if (!CGSizeEqualToSize(self.contentSize, contentSize)) {
        self.contentSize = contentSize;

        // if contentSize is different, we need to re-evaluate layout, bounds (contentOffset) might changed
        [_collectionViewData validateLayoutInRect:self.bounds];
        [self updateVisibleCellsNow:YES];
    }

    _backgroundView.frame = (CGRect){.size=self.bounds.size};

    _collectionViewFlags.fadeCellsForBoundsChange = NO;
}

- (void)setFrame:(CGRect)frame {
    if (!CGRectEqualToRect(frame, self.frame)) {
        if ([self.collectionViewLayout shouldInvalidateLayoutForBoundsChange:frame]) {
            [self invalidateLayout];
            _collectionViewFlags.fadeCellsForBoundsChange = YES;
        }
        [super setFrame:frame];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)registerClass:(Class)cellClass forCellWithReuseIdentifier:(NSString *)identifier {
    NSParameterAssert(cellClass);
    NSParameterAssert(identifier);
    _cellClassDict[identifier] = cellClass;
}

- (void)registerClass:(Class)viewClass forSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier {
    NSParameterAssert(viewClass);
    NSParameterAssert(elementKind);
    NSParameterAssert(identifier);
    _supplementaryViewClassDict[identifier] = viewClass;
}

- (void)registerNib:(UINib *)nib forCellWithReuseIdentifier:(NSString *)identifier {
    NSArray *topLevelObjects = [nib instantiateWithOwner:nil options:nil];
    NSAssert(topLevelObjects.count == 1 && [topLevelObjects[0] isKindOfClass:PSTCollectionViewCell.class], @"must contain exactly 1 top level object which is a PSTCollectionViewCell");

    _cellNibDict[identifier] = nib;
}

- (void)registerNib:(UINib *)nib forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)identifier {
    NSArray *topLevelObjects = [nib instantiateWithOwner:nil options:nil];
    NSAssert(topLevelObjects.count == 1 && [topLevelObjects[0] isKindOfClass:PSTCollectionReusableView.class], @"must contain exactly 1 top level object which is a PSTCollectionReusableView");
    
    _cellNibDict[identifier] = nib;
}

- (id)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath {
    // dequeue cell (if available)
    NSMutableArray *reusableCells = _cellReuseQueues[identifier];
    PSTCollectionViewCell *cell = [reusableCells lastObject];
    if (cell) {
        [reusableCells removeObjectAtIndex:[reusableCells count]-1];
    }else {
        if (_cellNibDict[identifier]) {
            // Cell was registered via registerNib:forCellWithReuseIdentifier:
            UINib *cellNib = _cellNibDict[identifier];
            cell = [cellNib instantiateWithOwner:self options:0][0];
        } else {

            Class cellClass = _cellClassDict[identifier];
            // compatiblity layer
            Class collectionViewCellClass = NSClassFromString(@"UICollectionViewCell");
            if (collectionViewCellClass && [cellClass isEqual:collectionViewCellClass]) {
                cellClass = [PSTCollectionViewCell class];
            }
            if (cellClass == nil) {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Class not registered for identifier %@", identifier] userInfo:nil];
            }
            if (self.collectionViewLayout) {
                PSTCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
                cell = [[cellClass alloc] initWithFrame:attributes.frame];
            } else {
                cell = [cellClass new];
            }
        }
        cell.collectionView = self;
        cell.reuseIdentifier = identifier;
    }
    return cell;
}

- (id)dequeueReusableSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *reusableViews = _supplementaryViewReuseQueues[identifier];
    PSTCollectionReusableView *view = [reusableViews lastObject];
    if (view) {
        [reusableViews removeObjectAtIndex:reusableViews.count - 1];
    } else {
        if (_cellNibDict[identifier]) {
            // supplementary view was registered via registerNib:forCellWithReuseIdentifier:
            UINib *supplementaryViewNib = _supplementaryViewNibDict[identifier];
            view = [supplementaryViewNib instantiateWithOwner:self options:0][0];
        } else {
        Class viewClass = _supplementaryViewClassDict[identifier];
        Class reusableViewClass = NSClassFromString(@"UICollectionReusableView");
        if (reusableViewClass && [viewClass isEqual:reusableViewClass]) {
            viewClass = [PSTCollectionReusableView class];
        }
        if (viewClass == nil) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Class not registered for identifier %@", identifier] userInfo:nil];
        }
        if (self.collectionViewLayout) {
            PSTCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForSupplementaryViewOfKind:elementKind
                                                                                                                      atIndexPath:indexPath];
            view = [[viewClass alloc] initWithFrame:attributes.frame];
        } else {
            view = [viewClass new];
        }
        }
        view.collectionView = self;
        view.reuseIdentifier = identifier;
    }
    return view;
}

- (NSArray *)visibleCells {
    return [_allVisibleViewsDict allValues];
}

- (void)reloadData {
    if (_reloadingSuspendedCount != 0) return;
    [self invalidateLayout];
    [_allVisibleViewsDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([obj isKindOfClass:[UIView class]]) {
            [obj removeFromSuperview];
        }
    }];
    [_allVisibleViewsDict removeAllObjects];
    [self setNeedsLayout];
    //NSAssert(sectionCount == 1, @"Sections are currently not supported.");
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Query Grid

- (NSInteger)numberOfSections {
    return [_collectionViewData numberOfSections];
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section {
    return [_collectionViewData numberOfItemsInSection:section];
}

- (PSTCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (PSTCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point {
    __block NSIndexPath *indexPath = nil;
    [_allVisibleViewsDict enumerateKeysAndObjectsWithOptions:kNilOptions usingBlock:^(id key, id obj, BOOL *stop) {
        PSTCollectionViewItemKey *itemKey = (PSTCollectionViewItemKey *)key;
        if (itemKey.type == PSTCollectionViewItemTypeCell) {
            PSTCollectionViewCell *cell = (PSTCollectionViewCell *)obj;
            if (CGRectContainsPoint(cell.frame, point)) {
                indexPath = itemKey.indexPath;
                *stop = YES;
            }
        }
    }];
    return indexPath;
}

- (NSIndexPath *)indexPathForCell:(PSTCollectionViewCell *)cell {
    __block NSIndexPath *indexPath = nil;
    [_allVisibleViewsDict enumerateKeysAndObjectsWithOptions:kNilOptions usingBlock:^(id key, id obj, BOOL *stop) {
        PSTCollectionViewItemKey *itemKey = (PSTCollectionViewItemKey *)key;
        if (itemKey.type == PSTCollectionViewItemTypeCell) {
            PSTCollectionViewCell *currentCell = (PSTCollectionViewCell *)obj;
            if (currentCell == cell) {
                indexPath = itemKey.indexPath;
                *stop = YES;
            }
        }
    }];
    return indexPath;
}

- (PSTCollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    // NSInteger index = [_collectionViewData globalIndexForItemAtIndexPath:indexPath];
    // TODO Apple uses some kind of globalIndex for this.
    __block PSTCollectionViewCell *cell = nil;
    [_allVisibleViewsDict enumerateKeysAndObjectsWithOptions:0 usingBlock:^(id key, id obj, BOOL *stop) {
        PSTCollectionViewItemKey *itemKey = (PSTCollectionViewItemKey *)key;
        if (itemKey.type == PSTCollectionViewItemTypeCell) {
            if ([itemKey.indexPath isEqual:indexPath]) {
                cell = obj;
                *stop = YES;
            }
        }
    }];
    return cell;
}

- (NSArray *)indexPathsForVisibleItems {
    NSMutableArray *visibleItems = [NSMutableArray array];
    for (PSTCollectionViewCell *cell in [self visibleCells]) {
        NSIndexPath *indexPath = [self indexPathForCell:cell];
        if (indexPath) {
            [visibleItems addObject:indexPath];
        }else {
            NSLog(@"Error: indexPath not found");
        }
    }
    return visibleItems;
}

// Interacting with the collection view.
- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(PSTCollectionViewScrollPosition)scrollPosition animated:(BOOL)animated {

    // ensure grid is layouted; else we can't scroll.
    [self layoutSubviews];

    PSTCollectionViewLayoutAttributes *layoutAttributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
    if (layoutAttributes) {
        CGRect targetRect = layoutAttributes.frame;

        // hack to add proper margins to flowlayout.
        // TODO: how to pack this into PSTCollectionViewFlowLayout?
        if ([self.collectionViewLayout isKindOfClass:[PSTCollectionViewFlowLayout class]]) {
            PSTCollectionViewFlowLayout *flowLayout = (PSTCollectionViewFlowLayout *)self.collectionViewLayout;
            targetRect.size.height += flowLayout.scrollDirection == UICollectionViewScrollDirectionVertical ? flowLayout.minimumLineSpacing : flowLayout.minimumInteritemSpacing;
            targetRect.size.width += flowLayout.scrollDirection == UICollectionViewScrollDirectionVertical ? flowLayout.minimumInteritemSpacing : flowLayout.minimumLineSpacing;
        }
        [self scrollRectToVisible:targetRect animated:animated];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Touch Handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];

    CGPoint touchPoint = [[touches anyObject] locationInView:self];
    NSIndexPath *indexPath = [self indexPathForItemAtPoint:touchPoint];
    if (indexPath) {
        [self highlightItemAtIndexPath:indexPath animated:YES scrollPosition:PSTCollectionViewScrollPositionNone notifyDelegate:YES];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];

    CGPoint touchPoint = [[touches anyObject] locationInView:self];
    NSIndexPath *indexPath = [self indexPathForItemAtPoint:touchPoint];
    if (indexPath) {
        [self userSelectedItemAtIndexPath:indexPath];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [self unhighlightAllItems];
}

- (void)userSelectedItemAtIndexPath:(NSIndexPath *)indexPath {
    [self selectItemAtIndexPath:indexPath animated:YES scrollPosition:PSTCollectionViewScrollPositionNone notifyDelegate:YES];
}

// select item, notify delegate (internal)
- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(PSTCollectionViewScrollPosition)scrollPosition notifyDelegate:(BOOL)notifyDelegate {

    BOOL shouldSelect = YES;
    if ([self.delegate respondsToSelector:@selector(collectionView:shouldSelectItemAtIndexPath:)]) {
        shouldSelect = [self.delegate collectionView:self shouldSelectItemAtIndexPath:indexPath];
    }

    if (shouldSelect) {
        [self selectItemAtIndexPath:indexPath animated:animated scrollPosition:scrollPosition];

        // call delegate
        if (notifyDelegate && [self.delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
            [self.delegate collectionView:self didSelectItemAtIndexPath:indexPath];
        }
    }

    [self unhighlightItemAtIndexPath:indexPath animated:animated notifyDelegate:YES];
}

// returns nil or an array of selected index paths
- (NSArray *)indexPathsForSelectedItems {
    return [_indexPathsForSelectedItems allObjects];
}

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(PSTCollectionViewScrollPosition)scrollPosition {
    if (!self.allowsMultipleSelection) {
        for (NSIndexPath *selectedIndexPath in [_indexPathsForSelectedItems copy]) {
            [self deselectItemAtIndexPath:selectedIndexPath animated:animated];
        }
    }
    if (self.allowsSelection) {
        PSTCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:indexPath];
        selectedCell.selected = YES;
        [_indexPathsForSelectedItems addObject:indexPath];
    }
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {
    if ([_indexPathsForSelectedItems containsObject:indexPath]) {
        PSTCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:indexPath];
        selectedCell.selected = NO;
        [_indexPathsForSelectedItems removeObject:indexPath];
    }
}

- (BOOL)highlightItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(PSTCollectionViewScrollPosition)scrollPosition notifyDelegate:(BOOL)notifyDelegate {
    BOOL shouldHighlight = YES;
    if ([self.delegate respondsToSelector:@selector(collectionView:shouldHighlightItemAtIndexPath:)]) {
        shouldHighlight = [self.delegate collectionView:self shouldHighlightItemAtIndexPath:indexPath];
    }

    if (shouldHighlight) {
        PSTCollectionViewCell *highlightedCell = [self cellForItemAtIndexPath:indexPath];
        highlightedCell.highlighted = YES;
        [_indexPathsForHighlightedItems addObject:indexPath];

        if (notifyDelegate && [self.delegate respondsToSelector:@selector(collectionView:didHighlightItemAtIndexPath:)]) {
            [self.delegate collectionView:self didHighlightItemAtIndexPath:indexPath];
        }
    }
    return shouldHighlight;
}

- (void)unhighlightItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated notifyDelegate:(BOOL)notifyDelegate {
    if ([_indexPathsForHighlightedItems containsObject:indexPath]) {
        PSTCollectionViewCell *highlightedCell = [self cellForItemAtIndexPath:indexPath];
        highlightedCell.highlighted = NO;
        [_indexPathsForHighlightedItems removeObject:indexPath];

        if (notifyDelegate && [self.delegate respondsToSelector:@selector(collectionView:didUnhighlightItemAtIndexPath:)]) {
            [self.delegate collectionView:self didUnhighlightItemAtIndexPath:indexPath];
        }
    }
}

- (void)unhighlightAllItems {
    for (NSIndexPath *indexPath in [_indexPathsForHighlightedItems copy]) {
        [self unhighlightItemAtIndexPath:indexPath animated:NO notifyDelegate:YES];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Update Grid

- (void)insertSections:(NSIndexSet *)sections {
    [self reloadData];
}

- (void)deleteSections:(NSIndexSet *)sections {
    [self reloadData];
}

- (void)reloadSections:(NSIndexSet *)sections {
    [self reloadData];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection {
    [self reloadData];
}

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths {
    [self reloadData];
}

- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths {
    [self reloadData];
}

- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths {
    [self reloadData];
}

- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath {
    [self reloadData];
}

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion {
    [self reloadData];
    if (completion) {
        completion(YES);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Properties

- (void)setBackgroundView:(UIView *)backgroundView {
    if (backgroundView != _backgroundView) {
        [_backgroundView removeFromSuperview];
        _backgroundView = backgroundView;
        [self.superview addSubview:_backgroundView];
        [self.superview sendSubviewToBack:_backgroundView];
    }
}

- (void)setCollectionViewLayout:(PSTCollectionViewLayout *)layout animated:(BOOL)animated {
    if (layout != _collectionViewLayout) {
        _collectionViewLayout.collectionView = nil;
        _collectionViewLayout = layout;
        layout.collectionView = self;
        _collectionViewData = [[PSTCollectionViewData alloc] initWithCollectionView:self layout:layout];
        [self reloadData];
    }
}

- (void)setCollectionViewLayout:(PSTCollectionViewLayout *)layout {
    [self setCollectionViewLayout:layout animated:NO];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (void)invalidateLayout {
    [self.collectionViewLayout invalidateLayout];
    [self.collectionViewData invalidate]; // invalidate layout cache
}

// update currently visible cells, fetches new cells if needed
// TODO: use now parameter.
- (void)updateVisibleCellsNow:(BOOL)now {
    NSArray *layoutAttributesArray = [_collectionViewData layoutAttributesForElementsInRect:self.bounds];

    // create ItemKey/Attributes dictionary
    NSMutableDictionary *itemKeysToAddDict = [NSMutableDictionary dictionary];
    for (PSTCollectionViewLayoutAttributes *layoutAttributes in layoutAttributesArray) {
        PSTCollectionViewItemKey *itemKey = [PSTCollectionViewItemKey collectionItemKeyForLayoutAttributes:layoutAttributes];
        itemKeysToAddDict[itemKey] = layoutAttributes;
    }

    // detect what items should be removed and queued back.
    NSMutableSet *allVisibleItemKeys = [NSMutableSet setWithArray:[_allVisibleViewsDict allKeys]];
    [allVisibleItemKeys minusSet:[NSSet setWithArray:[itemKeysToAddDict allKeys]]];

    // remove views that have not been processed and prepare them for re-use.
    for (PSTCollectionViewItemKey *itemKey in allVisibleItemKeys) {
        PSTCollectionReusableView *reusableView = _allVisibleViewsDict[itemKey];
        if (reusableView) {
            [reusableView removeFromSuperview];
            [_allVisibleViewsDict removeObjectForKey:itemKey];
            if (itemKey.type == PSTCollectionViewItemTypeCell) {
                if ([self.delegate respondsToSelector:@selector(collectionView:didEndDisplayingCell:forItemAtIndexPath:)]) {
                    [self.delegate collectionView:self didEndDisplayingCell:(PSTCollectionViewCell *)reusableView forItemAtIndexPath:itemKey.indexPath];
                }
                [self reuseCell:(PSTCollectionViewCell *)reusableView];
            }else if(itemKey.type == PSTCollectionViewItemTypeSupplementaryView) {
                if ([self.delegate respondsToSelector:@selector(collectionView:didEndDisplayingSupplementaryView:forElementOfKind:atIndexPath:)]) {
                    [self.delegate collectionView:self didEndDisplayingSupplementaryView:reusableView forElementOfKind:itemKey.identifier atIndexPath:itemKey.indexPath];
                }
                [self reuseSupplementaryView:reusableView];
            }
            // TODO: decoration views etc?
        }
    }

    // finally add new cells.
    [itemKeysToAddDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {PSTCollectionViewItemKey *itemKey = key;
        PSTCollectionViewLayoutAttributes *layoutAttributes = obj;

        // check if cell is in visible dict; add it if not.
        PSTCollectionReusableView *view = _allVisibleViewsDict[itemKey];
        if (!view) {
            if (itemKey.type == PSTCollectionViewItemTypeCell) {
                view = [self _createPreparedCellForItemAtIndexPath:itemKey.indexPath withLayoutAttributes:layoutAttributes];

            } else if (itemKey.type == PSTCollectionViewItemTypeSupplementaryView) {
                view = [self _createPreparedSupplementaryViewForElementOfKind:layoutAttributes.representedElementKind
                                                                  atIndexPath:layoutAttributes.indexPath
                                                         withLayoutAttributes:layoutAttributes];

            }
            _allVisibleViewsDict[itemKey] = view;
            [self addControlledSubview:view];
        }else {
            // just update cell
            [view applyLayoutAttributes:layoutAttributes];
        }
    }];
}

// fetches a cell from the dataSource and sets the layoutAttributes
- (PSTCollectionViewCell *)_createPreparedCellForItemAtIndexPath:(NSIndexPath *)indexPath withLayoutAttributes:(PSTCollectionViewLayoutAttributes *)layoutAttributes {

    PSTCollectionViewCell *cell = [self.dataSource collectionView:self cellForItemAtIndexPath:indexPath];

    // voiceover support
    cell.isAccessibilityElement = YES;

    [cell applyLayoutAttributes:layoutAttributes];
    return cell;
}

- (PSTCollectionReusableView *)_createPreparedSupplementaryViewForElementOfKind:(NSString *)kind
                                                                    atIndexPath:(NSIndexPath *)indexPath
                                                           withLayoutAttributes:(PSTCollectionViewLayoutAttributes *)layoutAttributes
{
    PSTCollectionReusableView *view = [self.dataSource collectionView:self
                                    viewForSupplementaryElementOfKind:kind
                                                          atIndexPath:indexPath];
    [view applyLayoutAttributes:layoutAttributes];
    return view;
}


// @steipete optimization
- (void)queueReusableView:(PSTCollectionReusableView *)reusableView inQueue:(NSMutableDictionary *)queue {
    NSString *cellIdentifier = reusableView.reuseIdentifier;
    NSParameterAssert([cellIdentifier length]);

    [reusableView removeFromSuperview];
    [reusableView prepareForReuse];

    // enqueue cell
    NSMutableArray *reuseableViews = queue[cellIdentifier];
    if (!reuseableViews) {
        reuseableViews = [NSMutableArray array];
        queue[cellIdentifier] = reuseableViews;
    }
    [reuseableViews addObject:reusableView];
}


// enqueue cell for reuse
- (void)reuseCell:(PSTCollectionViewCell *)cell {
    [self queueReusableView:cell inQueue:_cellReuseQueues];
}

// enqueue supplementary view for reuse
- (void)reuseSupplementaryView:(PSTCollectionReusableView *)supplementaryView {
    [self queueReusableView:supplementaryView inQueue:_supplementaryViewReuseQueues];
}

- (void)addControlledSubview:(PSTCollectionReusableView *)subview {
    [self addSubview:subview];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSTCollection/UICollection interoperability

#import <objc/runtime.h>
#import <objc/message.h>
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *sig = [super methodSignatureForSelector:selector];
    if(!sig) {
        NSString *selString = NSStringFromSelector(selector);
        if ([selString hasPrefix:@"_"]) {
            SEL cleanedSelector = NSSelectorFromString([selString substringFromIndex:1]);
            sig = [super methodSignatureForSelector:cleanedSelector];
        }
    }
    return sig;
}
- (void)forwardInvocation:(NSInvocation *)inv {
    NSString *selString = NSStringFromSelector([inv selector]);
    if ([selString hasPrefix:@"_"]) {
        SEL cleanedSelector = NSSelectorFromString([selString substringFromIndex:1]);
        if ([self respondsToSelector:cleanedSelector]) {
            // dynamically add method for faster resolving
            Method newMethod = class_getInstanceMethod([self class], [inv selector]);
            IMP underscoreIMP = imp_implementationWithBlock(PSBlockImplCast(^(id _self) {
                return objc_msgSend(_self, cleanedSelector);
            }));
            class_addMethod([self class], [inv selector], underscoreIMP, method_getTypeEncoding(newMethod));
            // invoke now
            inv.selector = cleanedSelector;
            [inv invokeWithTarget:self];
        }
    }else {
        [super forwardInvocation:inv];
    }
}

@end

#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
@implementation NSIndexPath (PSTCollectionViewAdditions)

// Simple NSIndexPath addition to allow using "item" instead of "row".
+ (NSIndexPath *)indexPathForItem:(NSInteger)item inSection:(NSInteger)section {
    return [NSIndexPath indexPathForRow:item inSection:section];
}

- (NSInteger)item {
    return self.row;
}
@end
#endif

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Runtime Additions to create UICollectionView

#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
@implementation PSUICollectionView_ @end
@implementation PSUICollectionViewCell_ @end
@implementation PSUICollectionReusableView_ @end
@implementation PSUICollectionViewLayout_ @end
@implementation PSUICollectionViewFlowLayout_ @end
@implementation PSUICollectionViewLayoutAttributes_ @end
@implementation PSUICollectionViewController_ @end

// Create subclasses that pose as UICollectionView et al, if not available at runtime.
__attribute__((constructor)) static void PSTCreateUICollectionViewClasses(void) {
    @autoreleasepool {

// class_setSuperclass is deprecated, but once iOS7 is out we hopefully can drop iOS5 and don't need this code anymore anyway.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        // Dynamically change superclasses of the PSUICollectionView* clases to UICollectioView*. Crazy stuff.
        if ([UICollectionView class]) class_setSuperclass([PSUICollectionView_ class], [UICollectionView class]);
		if ([UICollectionViewCell class]) class_setSuperclass([PSUICollectionViewCell_ class], [UICollectionViewCell class]);
		if ([UICollectionReusableView class]) class_setSuperclass([PSUICollectionReusableView_ class], [UICollectionReusableView class]);
		if ([UICollectionViewLayout class]) class_setSuperclass([PSUICollectionViewLayout_ class], [UICollectionViewLayout class]);
		if ([UICollectionViewFlowLayout class]) class_setSuperclass([PSUICollectionViewFlowLayout_ class], [UICollectionViewFlowLayout class]);
		if ([UICollectionViewLayoutAttributes class]) class_setSuperclass([PSUICollectionViewLayoutAttributes_ class], [UICollectionViewLayoutAttributes class]);
		if ([UICollectionViewController class]) class_setSuperclass([PSUICollectionViewController_ class], [UICollectionViewController class]);
#pragma clang diagnostic pop
        
        if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_6_0) {
            objc_registerClassPair(objc_allocateClassPair([PSTCollectionView class], "UICollectionView", 0));
            objc_registerClassPair(objc_allocateClassPair([PSTCollectionViewCell class], "UICollectionViewCell", 0));
            objc_registerClassPair(objc_allocateClassPair([PSTCollectionReusableView class], "UICollectionReusableView", 0));
            objc_registerClassPair(objc_allocateClassPair([PSTCollectionViewLayout class], "UICollectionViewLayout", 0));
            objc_registerClassPair(objc_allocateClassPair([PSTCollectionViewFlowLayout class], "UICollectionViewFlowLayout", 0));
            objc_registerClassPair(objc_allocateClassPair([PSTCollectionViewLayoutAttributes class], "UICollectionViewLayoutAttributes", 0));
            objc_registerClassPair(objc_allocateClassPair([PSTCollectionViewController class], "UICollectionViewController", 0));
        }

        // add PSUI classes at rumtime to make Interface Builder sane.
        objc_registerClassPair(objc_allocateClassPair([PSUICollectionView_ class], "PSUICollectionView", 0));
        objc_registerClassPair(objc_allocateClassPair([PSUICollectionViewCell_ class], "PSUICollectionViewCell", 0));
        objc_registerClassPair(objc_allocateClassPair([PSUICollectionReusableView_ class], "PSUICollectionReusableView", 0));
        objc_registerClassPair(objc_allocateClassPair([PSUICollectionViewLayout_ class], "PSUICollectionViewLayout", 0));
        objc_registerClassPair(objc_allocateClassPair([PSUICollectionViewFlowLayout_ class], "PSUICollectionViewFlowLayout", 0));
        objc_registerClassPair(objc_allocateClassPair([PSUICollectionViewLayoutAttributes_ class], "PSUICollectionViewLayoutAttributes", 0));
        objc_registerClassPair(objc_allocateClassPair([PSUICollectionViewController_ class], "PSUICollectionViewController", 0));
    }
}

#endif

CGFloat PSTSimulatorAnimationDragCoefficient(void) {
    static CGFloat (*UIAnimationDragCoefficient)(void) = NULL;
#if TARGET_IPHONE_SIMULATOR
#import <dlfcn.h>
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *UIKit = dlopen([[[NSBundle bundleForClass:[UIApplication class]] executablePath] fileSystemRepresentation], RTLD_LAZY);
        UIAnimationDragCoefficient = (CGFloat (*)(void))dlsym(UIKit, "UIAnimationDragCoefficient");
    });
#endif
    return UIAnimationDragCoefficient ? UIAnimationDragCoefficient() : 1.f;
}
