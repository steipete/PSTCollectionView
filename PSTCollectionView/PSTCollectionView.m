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
#import <objc/runtime.h>

@interface PSTCollectionViewLayout (Internal)
@property (nonatomic, unsafe_unretained) PSTCollectionView *collectionView;
@end

CGFloat PSTSimulatorAnimationDragCoefficient(void);
@class PSTCollectionViewExt;

@interface PSTCollectionView() {
    // ivar layout needs to EQUAL to UICollectionView.
    PSTCollectionViewLayout *_layout;
    __unsafe_unretained id<PSTCollectionViewDataSource> _dataSource;
    UIView *_backgroundView;
    NSMutableSet *_indexPathsForSelectedItems;
    NSMutableDictionary *_cellReuseQueues;
    NSMutableDictionary *_supplementaryViewReuseQueues;
    NSMutableSet *_indexPathsForHighlightedItems;
    int _reloadingSuspendedCount;
    PSTCollectionReusableView *_firstResponderView;
    UIView *_newContentView;
    int _firstResponderViewType;
    NSString *_firstResponderViewKind;
    NSIndexPath *_firstResponderIndexPath;
    NSMutableDictionary *_allVisibleViewsDict;
    NSIndexPath *_pendingSelectionIndexPath;
    NSMutableSet *_pendingDeselectionIndexPaths;
    PSTCollectionViewData *_collectionViewData;
    id _update;
    CGRect _visibleBounds;
    CGRect _preRotationBounds;
    CGPoint _rotationBoundsOffset;
    int _rotationAnimationCount;
    int _updateCount;
    NSMutableArray *_insertItems;
    NSMutableArray *_deleteItems;
    NSMutableArray *_reloadItems;
    NSMutableArray *_moveItems;
    NSArray *_originalInsertItems;
    NSArray *_originalDeleteItems;
    UITouch *_currentTouch;
    id _updateCompletionHandler;
    NSMutableDictionary *_cellClassDict;
    NSMutableDictionary *_cellNibDict;
    NSMutableDictionary *_supplementaryViewClassDict;
    NSMutableDictionary *_supplementaryViewNibDict;
    NSMutableDictionary *_cellNibExternalObjectsTables;
    NSMutableDictionary *_supplementaryViewNibExternalObjectsTables;
    struct {
        unsigned int delegateShouldHighlightItemAtIndexPath : 1;
        unsigned int delegateDidHighlightItemAtIndexPath : 1;
        unsigned int delegateDidUnhighlightItemAtIndexPath : 1;
        unsigned int delegateShouldSelectItemAtIndexPath : 1;
        unsigned int delegateShouldDeselectItemAtIndexPath : 1;
        unsigned int delegateDidSelectItemAtIndexPath : 1;
        unsigned int delegateDidDeselectItemAtIndexPath : 1;
        unsigned int delegateSupportsMenus : 1;
        unsigned int delegateDidEndDisplayingCell : 1;
        unsigned int delegateDidEndDisplayingSupplementaryView : 1;
        unsigned int dataSourceNumberOfSections : 1;
        unsigned int dataSourceViewForSupplementaryElement : 1;
        unsigned int reloadSkippedDuringSuspension : 1;
        unsigned int scheduledUpdateVisibleCells : 1;
        unsigned int scheduledUpdateVisibleCellLayoutAttributes : 1;
        unsigned int allowsSelection : 1;
        unsigned int allowsMultipleSelection : 1;
        unsigned int updating : 1;
        unsigned int fadeCellsForBoundsChange : 1;
        unsigned int updatingLayout : 1;
        unsigned int needsReload : 1;
        unsigned int reloading : 1;
        unsigned int skipLayoutDuringSnapshotting : 1;
        unsigned int layoutInvalidatedSinceLastCellUpdate : 1;
        unsigned int doneFirstLayout : 1;
    } _collectionViewFlags;
    CGPoint _lastLayoutOffset;
}
@property (nonatomic, strong) PSTCollectionViewData *collectionViewData;
@property (nonatomic, strong, readonly) PSTCollectionViewExt *extVars;
@end

// Used by PSTCollectionView for external variables.
// (We need to keep the total class size equal to the UICollectionView variant)
@interface PSTCollectionViewExt : NSObject
@property (nonatomic, strong) id nibObserverToken;
@property (nonatomic, strong) PSTCollectionViewLayout *nibLayout;
@property (nonatomic, strong) NSDictionary *nibCellsExternalObjects;
@property (nonatomic, strong) NSIndexPath *touchingIndexPath;
@end

@implementation PSTCollectionViewExt @end
const char kPSTColletionViewExt;

@implementation PSTCollectionView

@synthesize collectionViewLayout = _layout;

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

static void PSTCollectionViewCommonSetup(PSTCollectionView *_self) {
    _self.allowsSelection = YES;
    _self->_indexPathsForSelectedItems = [NSMutableSet new];
    _self->_indexPathsForHighlightedItems = [NSMutableSet new];
    _self->_cellReuseQueues = [NSMutableDictionary new];
    _self->_supplementaryViewReuseQueues = [NSMutableDictionary new];
    _self->_allVisibleViewsDict = [NSMutableDictionary new];
    _self->_cellClassDict = [NSMutableDictionary new];
    _self->_cellNibDict = [NSMutableDictionary new];
    _self->_supplementaryViewClassDict = [NSMutableDictionary new];

    // add class that saves additional ivars
    objc_setAssociatedObject(_self, &kPSTColletionViewExt, [PSTCollectionViewExt new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
        
        id nibObserverToken = [[NSNotificationCenter defaultCenter] addObserverForName:PSTCollectionViewLayoutAwokeFromNib object:nil queue:nil usingBlock:^(NSNotification *note) {
            self.extVars.nibLayout = note.object;
        }];
        self.extVars.nibObserverToken = nibObserverToken;

        NSDictionary *cellExternalObjects =  [inCoder decodeObjectForKey:@"UICollectionViewCellPrototypeNibExternalObjects"];
        NSDictionary *cellNibs =  [inCoder decodeObjectForKey:@"UICollectionViewCellNibDict"];

        for (NSString *identifier in cellNibs.allKeys) {
            _cellNibDict[identifier] = cellNibs[identifier];
        }
        self.extVars.nibCellsExternalObjects = cellExternalObjects;
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];

    // check if NIB deserialization found a layout.
    id nibObserverToken = self.extVars.nibObserverToken;
    if (nibObserverToken) {
        [[NSNotificationCenter defaultCenter] removeObserver:nibObserverToken];
        self.extVars.nibObserverToken = nil;
    }

    PSTCollectionViewLayout *nibLayout = self.extVars.nibLayout;
    if (nibLayout) {
        self.collectionViewLayout = nibLayout;
        self.extVars.nibLayout = nil;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ collection view layout: %@", [super description], self.collectionViewLayout];
}

- (void)dealloc {
    id nibObserverToken = self.extVars.nibObserverToken;
    if (nibObserverToken) [[NSNotificationCenter defaultCenter] removeObserver:nibObserverToken];
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
            NSDictionary *externalObjects = self.extVars.nibCellsExternalObjects[identifier];
            if (externalObjects) {
                cell = [cellNib instantiateWithOwner:self options:@{UINibExternalObjects:externalObjects}][0];
            } else {
                cell = [cellNib instantiateWithOwner:self options:0][0];
            }
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
    return [[_allVisibleViewsDict allValues] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject isKindOfClass:[PSTCollectionViewCell class]];
    }]];
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
    return [[self collectionViewLayout] layoutAttributesForItemAtIndexPath:indexPath];
}

- (PSTCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    return [[self collectionViewLayout] layoutAttributesForSupplementaryViewOfKind:kind atIndexPath:indexPath];
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
	NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:[_allVisibleViewsDict count]];
	
	[_allVisibleViewsDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		PSTCollectionViewItemKey *itemKey = (PSTCollectionViewItemKey *)key;
        if (itemKey.type == PSTCollectionViewItemTypeCell) {
			[indexPaths addObject:itemKey.indexPath];
		}
	}];
	
	return indexPaths;
}

// returns nil or an array of selected index paths
- (NSArray *)indexPathsForSelectedItems {
    return [_indexPathsForSelectedItems allObjects];
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

        if (!self.allowsMultipleSelection) {
            // temporally unhighlight background on touchesBegan (keeps selected by _indexPathsForSelectedItems)
            for (PSTCollectionViewCell* visibleCell in self.visibleCells) {
                visibleCell.highlighted = NO;
                visibleCell.selected = NO;

                // NOTE: doesn't work due to the _indexPathsForHighlightedItems validation
                //[self unhighlightItemAtIndexPath:indexPathForVisibleItem animated:YES notifyDelegate:YES];
            }
        }

        [self highlightItemAtIndexPath:indexPath animated:YES scrollPosition:PSTCollectionViewScrollPositionNone notifyDelegate:YES];

        self.extVars.touchingIndexPath = indexPath;
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];

    if (self.extVars.touchingIndexPath) {
        CGPoint touchPoint = [[touches anyObject] locationInView:self];
        NSIndexPath *indexPath = [self indexPathForItemAtPoint:touchPoint];
        if ([indexPath isEqual:self.extVars.touchingIndexPath]) {
            [self highlightItemAtIndexPath:indexPath animated:YES scrollPosition:PSTCollectionViewScrollPositionNone notifyDelegate:YES];
        }
        else {
            [self unhighlightItemAtIndexPath:self.extVars.touchingIndexPath animated:YES notifyDelegate:YES];
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];

    CGPoint touchPoint = [[touches anyObject] locationInView:self];
    NSIndexPath *indexPath = [self indexPathForItemAtPoint:touchPoint];
    if ([indexPath isEqual:self.extVars.touchingIndexPath]) {
        [self userSelectedItemAtIndexPath:indexPath];

        [self unhighlightAllItems];
        self.extVars.touchingIndexPath = nil;
    }
    else {
        [self cellTouchCancelled];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];

    [self cellTouchCancelled];
}

- (void)cellTouchCancelled {
    // TODO: improve behavior on touchesCancelled
    if (!self.allowsMultipleSelection) {
        // highlight selected-background again
        for (PSTCollectionViewCell* visibleCell in self.visibleCells) {
            NSIndexPath* indexPathForVisibleItem = [self indexPathForCell:visibleCell];
            visibleCell.selected = [_indexPathsForSelectedItems containsObject:indexPathForVisibleItem];
        }
    }

    [self unhighlightAllItems];
    self.extVars.touchingIndexPath = nil;
}

- (void)userSelectedItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.allowsMultipleSelection && [_indexPathsForSelectedItems containsObject:indexPath]) {
        [self deselectItemAtIndexPath:indexPath animated:YES notifyDelegate:YES];
    }
    else {
        [self selectItemAtIndexPath:indexPath animated:YES scrollPosition:PSTCollectionViewScrollPositionNone notifyDelegate:YES];
    }
}

// select item, notify delegate (internal)
- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(PSTCollectionViewScrollPosition)scrollPosition notifyDelegate:(BOOL)notifyDelegate {

    BOOL shouldSelect = YES;
	if (notifyDelegate && _collectionViewFlags.delegateShouldSelectItemAtIndexPath) {
        shouldSelect = [self.delegate collectionView:self shouldSelectItemAtIndexPath:indexPath];
    }

    if (shouldSelect) {
        if (!self.allowsMultipleSelection) {
            for (NSIndexPath *selectedIndexPath in [_indexPathsForSelectedItems copy]) {
                if(![indexPath isEqual:selectedIndexPath]) {
                    [self deselectItemAtIndexPath:selectedIndexPath animated:animated notifyDelegate:notifyDelegate];
                }
            }
        }
        if (self.allowsSelection) {
            PSTCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:indexPath];
            selectedCell.selected = YES;
            [_indexPathsForSelectedItems addObject:indexPath];
        }

        // call delegate
        if (notifyDelegate && _collectionViewFlags.delegateDidSelectItemAtIndexPath) {
            [self.delegate collectionView:self didSelectItemAtIndexPath:indexPath];
        }
    }

    [self unhighlightItemAtIndexPath:indexPath animated:animated notifyDelegate:YES];
}

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(PSTCollectionViewScrollPosition)scrollPosition {
    [self selectItemAtIndexPath:indexPath animated:animated scrollPosition:scrollPosition notifyDelegate:NO];
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
    [self deselectItemAtIndexPath:indexPath animated:animated notifyDelegate:NO];
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated notifyDelegate:(BOOL)notify {
    if ([_indexPathsForSelectedItems containsObject:indexPath]) {
        PSTCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:indexPath];
        selectedCell.selected = NO;
        [_indexPathsForSelectedItems removeObject:indexPath];

        [self unhighlightItemAtIndexPath:indexPath animated:animated notifyDelegate:notify];
        
        if (notify && _collectionViewFlags.delegateDidDeselectItemAtIndexPath) {
            [self.delegate collectionView:self didDeselectItemAtIndexPath:indexPath];
        }
    }
}

- (BOOL)highlightItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(PSTCollectionViewScrollPosition)scrollPosition notifyDelegate:(BOOL)notifyDelegate {
    BOOL shouldHighlight = YES;
    if (notifyDelegate && _collectionViewFlags.delegateShouldHighlightItemAtIndexPath) {
        shouldHighlight = [self.delegate collectionView:self shouldHighlightItemAtIndexPath:indexPath];
    }

    if (shouldHighlight) {
        PSTCollectionViewCell *highlightedCell = [self cellForItemAtIndexPath:indexPath];
        highlightedCell.highlighted = YES;
        [_indexPathsForHighlightedItems addObject:indexPath];

        if (notifyDelegate && _collectionViewFlags.delegateDidHighlightItemAtIndexPath) {
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

        if (notifyDelegate && _collectionViewFlags.delegateDidUnhighlightItemAtIndexPath) {
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
	// check to see if reload should hold off
	if (_reloadingSuspendedCount != 0 && _collectionViewFlags.reloadSkippedDuringSuspension) {
		[_reloadItems addObjectsFromArray:indexPaths];
		_collectionViewFlags.needsReload = YES;

		return;
	}

	_collectionViewFlags.reloading = YES;

	NSSet *visibleCellKeys = [_allVisibleViewsDict keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
		PSTCollectionViewItemKey *itemKey = (PSTCollectionViewItemKey *)key;
		if (itemKey.type == PSTCollectionViewItemTypeCell && [indexPaths containsObject:itemKey.indexPath]) {
			return YES;
		}

		return NO;
	}];

	for (PSTCollectionViewItemKey *itemKey in visibleCellKeys) {
		PSTCollectionViewCell *reusableView = (PSTCollectionViewCell *)[_allVisibleViewsDict objectForKey:itemKey];

		//Remove the old cell
		[reusableView removeFromSuperview];
		[_allVisibleViewsDict removeObjectForKey:itemKey];

		if ([self.delegate respondsToSelector:@selector(collectionView:didEndDisplayingCell:forItemAtIndexPath:)]) {
			[self.delegate collectionView:self didEndDisplayingCell:(PSTCollectionViewCell *)reusableView forItemAtIndexPath:itemKey.indexPath];
		}

		[self reuseCell:(PSTCollectionViewCell *)reusableView];

		//Reload the cell and redisplay
		PSTCollectionViewLayoutAttributes *layoutAttributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:itemKey.indexPath];
		PSTCollectionViewCell *newCell = [self createPreparedCellForItemAtIndexPath:itemKey.indexPath withLayoutAttributes:layoutAttributes];
		_allVisibleViewsDict[itemKey] = newCell;
		[self addControlledSubview:newCell];
	}

	_collectionViewFlags.reloading = NO;
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
    if (layout != _layout) {
        _layout.collectionView = nil;
        _layout = layout;
        layout.collectionView = self;
        _collectionViewData = [[PSTCollectionViewData alloc] initWithCollectionView:self layout:layout];
        [self reloadData];
    }
}

- (void)setCollectionViewLayout:(PSTCollectionViewLayout *)layout {
    [self setCollectionViewLayout:layout animated:NO];
}

- (void)setDelegate:(id<PSTCollectionViewDelegate>)delegate {
	super.delegate = delegate;
	
	//	Managing the Selected Cells
	_collectionViewFlags.delegateShouldSelectItemAtIndexPath       = [self.delegate respondsToSelector:@selector(collectionView:shouldSelectItemAtIndexPath:)];
	_collectionViewFlags.delegateDidSelectItemAtIndexPath          = [self.delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)];
	_collectionViewFlags.delegateShouldDeselectItemAtIndexPath     = [self.delegate respondsToSelector:@selector(collectionView:shouldDeselectItemAtIndexPath:)];
	_collectionViewFlags.delegateDidDeselectItemAtIndexPath        = [self.delegate respondsToSelector:@selector(collectionView:didDeselectItemAtIndexPath:)];

	//	Managing Cell Highlighting
	_collectionViewFlags.delegateShouldHighlightItemAtIndexPath    = [self.delegate respondsToSelector:@selector(collectionView:shouldHighlightItemAtIndexPath:)];
	_collectionViewFlags.delegateDidHighlightItemAtIndexPath       = [self.delegate respondsToSelector:@selector(collectionView:didHighlightItemAtIndexPath:)];
	_collectionViewFlags.delegateDidUnhighlightItemAtIndexPath     = [self.delegate respondsToSelector:@selector(collectionView:didUnhighlightItemAtIndexPath:)];

	//	Tracking the Removal of Views
	_collectionViewFlags.delegateDidEndDisplayingCell              = [self.delegate respondsToSelector:@selector(collectionView:didEndDisplayingCell:forItemAtIndexPath:)];
	_collectionViewFlags.delegateDidEndDisplayingSupplementaryView = [self.delegate respondsToSelector:@selector(collectionView:didEndDisplayingSupplementaryView:forElementOfKind:atIndexPath:)];

	//	Managing Actions for Cells
	_collectionViewFlags.delegateSupportsMenus                     = [self.delegate respondsToSelector:@selector(collectionView:shouldShowMenuForItemAtIndexPath:)];
	
	// These aren't present in the flags which is a little strange. Not adding them because thet will mess with byte alignment which will affect cross compatibility.
	// The flag names are guesses and are there for documentation purposes.
	//
	// _collectionViewFlags.delegateCanPerformActionForItemAtIndexPath	= [self.delegate respondsToSelector:@selector(collectionView:canPerformAction:forItemAtIndexPath:withSender:)];
	// _collectionViewFlags.delegatePerformActionForItemAtIndexPath		= [self.delegate respondsToSelector:@selector(collectionView:performAction:forItemAtIndexPath:withSender:)];
}

// Might be overkill since two are required and two are handled by PSTCollectionViewData leaving only one flag we actually need to check for
- (void)setDataSource:(id<PSTCollectionViewDataSource>)dataSource {
    if (dataSource != _dataSource) {
		_dataSource = dataSource;
		
		//	Getting Item and Section Metrics
		_collectionViewFlags.dataSourceNumberOfSections = [_dataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)];
		
		//	Getting Views for Items
		_collectionViewFlags.dataSourceViewForSupplementaryElement = [_dataSource respondsToSelector:@selector(collectionView:viewForSupplementaryElementOfKind:atIndexPath:)];
    }
}

- (BOOL)allowsSelection {
    return _collectionViewFlags.allowsSelection;
}

- (void)setAllowsSelection:(BOOL)allowsSelection {
    _collectionViewFlags.allowsSelection = allowsSelection;
}

- (BOOL)allowsMultipleSelection {
    return _collectionViewFlags.allowsMultipleSelection;
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection {
    _collectionViewFlags.allowsMultipleSelection = allowsMultipleSelection;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (PSTCollectionViewExt *)extVars {
    return objc_getAssociatedObject(self, &kPSTColletionViewExt);
}

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
                if (_collectionViewFlags.delegateDidEndDisplayingCell) {
                    [self.delegate collectionView:self didEndDisplayingCell:(PSTCollectionViewCell *)reusableView forItemAtIndexPath:itemKey.indexPath];
                }
                [self reuseCell:(PSTCollectionViewCell *)reusableView];
            }else if(itemKey.type == PSTCollectionViewItemTypeSupplementaryView) {
                if (_collectionViewFlags.delegateDidEndDisplayingSupplementaryView) {
                    [self.delegate collectionView:self didEndDisplayingSupplementaryView:reusableView forElementOfKind:itemKey.identifier atIndexPath:itemKey.indexPath];
                }
                [self reuseSupplementaryView:reusableView];
            }
            // TODO: decoration views etc?
        }
    }

    // finally add new cells.
    [itemKeysToAddDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        PSTCollectionViewItemKey *itemKey = key;
        PSTCollectionViewLayoutAttributes *layoutAttributes = obj;

        // check if cell is in visible dict; add it if not.
        PSTCollectionReusableView *view = _allVisibleViewsDict[itemKey];
        if (!view) {
            if (itemKey.type == PSTCollectionViewItemTypeCell) {
                view = [self createPreparedCellForItemAtIndexPath:itemKey.indexPath withLayoutAttributes:layoutAttributes];

            } else if (itemKey.type == PSTCollectionViewItemTypeSupplementaryView) {
                view = [self createPreparedSupplementaryViewForElementOfKind:layoutAttributes.representedElementKind
																 atIndexPath:layoutAttributes.indexPath
														withLayoutAttributes:layoutAttributes];

            }
			
			//Supplementary views are optional
			if (view) {
				_allVisibleViewsDict[itemKey] = view;
				[self addControlledSubview:view];
			}
        }else {
            // just update cell
            [view applyLayoutAttributes:layoutAttributes];
        }
    }];
}

// fetches a cell from the dataSource and sets the layoutAttributes
- (PSTCollectionViewCell *)createPreparedCellForItemAtIndexPath:(NSIndexPath *)indexPath withLayoutAttributes:(PSTCollectionViewLayoutAttributes *)layoutAttributes {

    PSTCollectionViewCell *cell = [self.dataSource collectionView:self cellForItemAtIndexPath:indexPath];

    // reset selected/highlight state
    [cell setHighlighted:[_indexPathsForHighlightedItems containsObject:indexPath]];
    [cell setSelected:[_indexPathsForSelectedItems containsObject:indexPath]];

    // voiceover support
    cell.isAccessibilityElement = YES;

    [cell applyLayoutAttributes:layoutAttributes];
    return cell;
}

- (PSTCollectionReusableView *)createPreparedSupplementaryViewForElementOfKind:(NSString *)kind
																   atIndexPath:(NSIndexPath *)indexPath
														  withLayoutAttributes:(PSTCollectionViewLayoutAttributes *)layoutAttributes
{
	if (_collectionViewFlags.dataSourceViewForSupplementaryElement) {
		PSTCollectionReusableView *view = [self.dataSource collectionView:self
										viewForSupplementaryElementOfKind:kind
															  atIndexPath:indexPath];
		[view applyLayoutAttributes:layoutAttributes];
		return view;
	}
	
	return nil;
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
        else objc_registerClassPair(objc_allocateClassPair([PSTCollectionView class], "UICollectionView", 0));
        
		if ([UICollectionViewCell class]) class_setSuperclass([PSUICollectionViewCell_ class], [UICollectionViewCell class]);
        else objc_registerClassPair(objc_allocateClassPair([PSTCollectionViewCell class], "UICollectionViewCell", 0));

		if ([UICollectionReusableView class]) class_setSuperclass([PSUICollectionReusableView_ class], [UICollectionReusableView class]);
        else objc_registerClassPair(objc_allocateClassPair([PSTCollectionReusableView class], "UICollectionReusableView", 0));
        
		if ([UICollectionViewLayout class]) class_setSuperclass([PSUICollectionViewLayout_ class], [UICollectionViewLayout class]);
        else objc_registerClassPair(objc_allocateClassPair([PSTCollectionViewLayout class], "UICollectionViewLayout", 0));
        
		if ([UICollectionViewFlowLayout class]) class_setSuperclass([PSUICollectionViewFlowLayout_ class], [UICollectionViewFlowLayout class]);
        else objc_registerClassPair(objc_allocateClassPair([PSTCollectionViewFlowLayout class], "UICollectionViewFlowLayout", 0));
        
		if ([UICollectionViewLayoutAttributes class]) class_setSuperclass([PSUICollectionViewLayoutAttributes_ class], [UICollectionViewLayoutAttributes class]);
        else objc_registerClassPair(objc_allocateClassPair([PSTCollectionViewLayoutAttributes class], "UICollectionViewLayoutAttributes", 0));
        
		if ([UICollectionViewController class]) class_setSuperclass([PSUICollectionViewController_ class], [UICollectionViewController class]);
        else objc_registerClassPair(objc_allocateClassPair([PSTCollectionViewController class], "UICollectionViewController", 0));
#pragma clang diagnostic pop

        // add PSUI classes at runtime to make Interface Builder sane
        // (IB doesn't allow adding the PSUICollectionView_ types but doesn't complain on unknown classes)
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

// helper to check for ivar layout
#if 0
static void PSTPrintIvarsForClass(Class aClass) {
    unsigned int varCount;
    Ivar *vars = class_copyIvarList(aClass, &varCount);
    for (int i = 0; i < varCount; i++) {
        NSLog(@"%s %s", ivar_getTypeEncoding(vars[i]), ivar_getName(vars[i]));
    }
    free(vars);
}

__attribute__((constructor)) static void PSTCheckIfIVarLayoutIsEqualSize(void) {
    @autoreleasepool {
        NSLog(@"PSTCollectionView size = %zd, UICollectionView size = %zd", class_getInstanceSize([PSTCollectionView class]),class_getInstanceSize([UICollectionView class]));
        NSLog(@"PSTCollectionViewCell size = %zd, UICollectionViewCell size = %zd", class_getInstanceSize([PSTCollectionViewCell class]),class_getInstanceSize([UICollectionViewCell class]));
        NSLog(@"PSTCollectionViewController size = %zd, UICollectionViewController size = %zd", class_getInstanceSize([PSTCollectionViewController class]),class_getInstanceSize([UICollectionViewController class]));
        NSLog(@"PSTCollectionViewLayout size = %zd, UICollectionViewLayout size = %zd", class_getInstanceSize([PSTCollectionViewLayout class]),class_getInstanceSize([UICollectionViewLayout class]));
        NSLog(@"PSTCollectionViewFlowLayout size = %zd, UICollectionViewFlowLayout size = %zd", class_getInstanceSize([PSTCollectionViewFlowLayout class]),class_getInstanceSize([UICollectionViewFlowLayout class]));
        //PSTPrintIvarsForClass([PSTCollectionViewFlowLayout class]); NSLog(@"\n\n\n");PSTPrintIvarsForClass([UICollectionViewFlowLayout class]);
    }
}
#endif
