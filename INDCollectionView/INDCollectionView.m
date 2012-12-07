//
//  INDCollectionView.m
//
//  Original Source: Copyright (c) 2012 Peter Steinberger. All rights reserved.
//  AppKit Port: Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import "INDCollectionView.h"
#import "INDCollectionViewController.h"
#import "INDCollectionViewData.h"
#import "INDCollectionViewCell.h"
#import "INDCollectionViewLayout.h"
#import "INDCollectionViewFlowLayout.h"
#import "INDCollectionViewItemKey.h"
#import "INDCollectionViewUpdateItem.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface INDCollectionViewLayout (Internal)
@property (nonatomic, unsafe_unretained) INDCollectionView *collectionView;
@end

@interface INDCollectionViewData (Internal)
- (void)prepareToLoadData;
@end


@interface INDCollectionViewUpdateItem()
- (NSIndexPath *)indexPath;
- (BOOL)isSectionOperation;
@end


CGFloat INDSimulatorAnimationDragCoefficient(void);
@class INDCollectionViewExt;

@interface INDCollectionView() {
    // ivar layout needs to EQUAL to UICollectionView.
    INDCollectionViewLayout *_layout;
    __unsafe_unretained id<INDCollectionViewDataSource> _dataSource;
    UIView *_backgroundView;
    NSMutableSet *_indexPathsForSelectedItems;
    NSMutableDictionary *_cellReuseQueues;
    NSMutableDictionary *_supplementaryViewReuseQueues;
    NSMutableSet *_indexPathsForHighlightedItems;
    int _reloadingSuspendedCount;
    INDCollectionReusableView *_firstResponderView;
    UIView *_newContentView;
    int _firstResponderViewType;
    NSString *_firstResponderViewKind;
    NSIndexPath *_firstResponderIndexPath;
    NSMutableDictionary *_allVisibleViewsDict;
    NSIndexPath *_pendingSelectionIndexPath;
    NSMutableSet *_pendingDeselectionIndexPaths;
    INDCollectionViewData *_collectionViewData;
    id _update;
    CGRect _visibleBoundRects;
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
    void (^_updateCompletionHandler)(BOOL finished);
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
@property (nonatomic, strong) INDCollectionViewData *collectionViewData;
@property (nonatomic, strong, readonly) INDCollectionViewExt *extVars;
@property (nonatomic, readonly) id currentUpdate;
@property (nonatomic, readonly) NSDictionary *visibleViewsDict;
@property (nonatomic, assign) CGRect visibleBoundRects;
@end

// Used by INDCollectionView for external variables.
// (We need to keep the total class size equal to the UICollectionView variant)
@interface INDCollectionViewExt : NSObject
@property (nonatomic, strong) id nibObserverToken;
@property (nonatomic, strong) INDCollectionViewLayout *nibLayout;
@property (nonatomic, strong) NSDictionary *nibCellsExternalObjects;
@property (nonatomic, strong) NSDictionary *supplementaryViewsExternalObjects;
@property (nonatomic, strong) NSIndexPath *touchingIndexPath;
@end

@implementation INDCollectionViewExt @end
const char kINDColletionViewExt;

@implementation INDCollectionView

@synthesize collectionViewLayout = _layout;
@synthesize currentUpdate = _update;
@synthesize visibleViewsDict = _allVisibleViewsDict;

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

static void INDCollectionViewCommonSetup(INDCollectionView *_self) {
    _self.allowsSelection = YES;
    _self->_indexPathsForSelectedItems = [NSMutableSet new];
    _self->_indexPathsForHighlightedItems = [NSMutableSet new];
    _self->_cellReuseQueues = [NSMutableDictionary new];
    _self->_supplementaryViewReuseQueues = [NSMutableDictionary new];
    _self->_allVisibleViewsDict = [NSMutableDictionary new];
    _self->_cellClassDict = [NSMutableDictionary new];
    _self->_cellNibDict = [NSMutableDictionary new];
    _self->_supplementaryViewClassDict = [NSMutableDictionary new];
	_self->_supplementaryViewNibDict = [NSMutableDictionary new];

    // add class that saves additional ivars
    objc_setAssociatedObject(_self, &kINDColletionViewExt, [INDCollectionViewExt new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)initWithFrame:(CGRect)frame collectionViewLayout:(INDCollectionViewLayout *)layout {
    if ((self = [super initWithFrame:frame])) {
        INDCollectionViewCommonSetup(self);
        self.collectionViewLayout = layout;
        _collectionViewData = [[INDCollectionViewData alloc] initWithCollectionView:self layout:layout];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)inCoder {
    if ((self = [super initWithCoder:inCoder])) {

        INDCollectionViewCommonSetup(self);
        // add observer for nib deserialization.

        id nibObserverToken = [[NSNotificationCenter defaultCenter] addObserverForName:INDCollectionViewLayoutAwokeFromNib object:nil queue:nil usingBlock:^(NSNotification *note) {
            self.extVars.nibLayout = note.object;
        }];
        self.extVars.nibObserverToken = nibObserverToken;

        NSDictionary *cellExternalObjects =  [inCoder decodeObjectForKey:@"UICollectionViewCellPrototypeNibExternalObjects"];
        NSDictionary *cellNibs =  [inCoder decodeObjectForKey:@"UICollectionViewCellNibDict"];

        for (NSString *identifier in cellNibs.allKeys) {
            _cellNibDict[identifier] = cellNibs[identifier];
        }

        self.extVars.nibCellsExternalObjects = cellExternalObjects;

		NSDictionary *supplementaryViewExternalObjects =  [inCoder decodeObjectForKey:@"UICollectionViewSupplementaryViewPrototypeNibExternalObjects"];
		NSDictionary *supplementaryViewNibs =  [inCoder decodeObjectForKey:@"UICollectionViewSupplementaryViewNibDict"];

		for (NSString *identifier in supplementaryViewNibs.allKeys) {
			_supplementaryViewNibDict[identifier] = supplementaryViewNibs[identifier];
		}

		self.extVars.supplementaryViewsExternalObjects = supplementaryViewExternalObjects;
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

    INDCollectionViewLayout *nibLayout = self.extVars.nibLayout;
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
        transition.duration = 0.25f * INDSimulatorAnimationDragCoefficient();
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

    if(!_collectionViewFlags.updatingLayout)
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
    
    if (_backgroundView) {
        _backgroundView.frame = (CGRect){.origin=self.contentOffset,.size=self.bounds.size};
    }

    _collectionViewFlags.fadeCellsForBoundsChange = NO;
    _collectionViewFlags.doneFirstLayout = YES;
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
	NSString *kindAndIdentifier = [NSString stringWithFormat:@"%@/%@", elementKind, identifier];
    _supplementaryViewClassDict[kindAndIdentifier] = viewClass;
}

- (void)registerNib:(UINib *)nib forCellWithReuseIdentifier:(NSString *)identifier {
    NSArray *topLevelObjects = [nib instantiateWithOwner:nil options:nil];
#pragma unused(topLevelObjects)
    NSAssert(topLevelObjects.count == 1 && [topLevelObjects[0] isKindOfClass:INDCollectionViewCell.class], @"must contain exactly 1 top level object which is a INDCollectionViewCell");

    _cellNibDict[identifier] = nib;
}

- (void)registerNib:(UINib *)nib forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)identifier {
    NSArray *topLevelObjects = [nib instantiateWithOwner:nil options:nil];
#pragma unused(topLevelObjects)
    NSAssert(topLevelObjects.count == 1 && [topLevelObjects[0] isKindOfClass:INDCollectionReusableView.class], @"must contain exactly 1 top level object which is a INDCollectionReusableView");

	NSString *kindAndIdentifier = [NSString stringWithFormat:@"%@/%@", kind, identifier];
    _supplementaryViewNibDict[kindAndIdentifier] = nib;
}

- (id)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath {
    // de-queue cell (if available)
    NSMutableArray *reusableCells = _cellReuseQueues[identifier];
    INDCollectionViewCell *cell = [reusableCells lastObject];
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
                cell = [cellNib instantiateWithOwner:self options:nil][0];
            }
        } else {
            Class cellClass = _cellClassDict[identifier];
            // compatibility layer
            Class collectionViewCellClass = NSClassFromString(@"UICollectionViewCell");
            if (collectionViewCellClass && [cellClass isEqual:collectionViewCellClass]) {
                cellClass = [INDCollectionViewCell class];
            }
            if (cellClass == nil) {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Class not registered for identifier %@", identifier] userInfo:nil];
            }
            if (self.collectionViewLayout) {
                INDCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
                cell = [[cellClass alloc] initWithFrame:attributes.frame];
            } else {
                cell = [cellClass new];
            }
        }
        INDCollectionViewLayout *layout = [self collectionViewLayout];
        if ([layout isKindOfClass:[INDCollectionViewFlowLayout class]]) {
            CGSize itemSize = ((INDCollectionViewFlowLayout *)layout).itemSize;
            cell.bounds = CGRectMake(0, 0, itemSize.width, itemSize.height);
        }
        cell.collectionView = self;
        cell.reuseIdentifier = identifier;
    }
    return cell;
}

- (id)dequeueReusableSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath {
	NSString *kindAndIdentifier = [NSString stringWithFormat:@"%@/%@", elementKind, identifier];
    NSMutableArray *reusableViews = _supplementaryViewReuseQueues[kindAndIdentifier];
    INDCollectionReusableView *view = [reusableViews lastObject];
    if (view) {
        [reusableViews removeObjectAtIndex:reusableViews.count - 1];
    } else {
        if (_supplementaryViewNibDict[kindAndIdentifier]) {
            // supplementary view was registered via registerNib:forCellWithReuseIdentifier:
            UINib *supplementaryViewNib = _supplementaryViewNibDict[kindAndIdentifier];
			NSDictionary *externalObjects = self.extVars.supplementaryViewsExternalObjects[kindAndIdentifier];
			if (externalObjects) {
				view = [supplementaryViewNib instantiateWithOwner:self options:@{UINibExternalObjects:externalObjects}][0];
			} else {
				view = [supplementaryViewNib instantiateWithOwner:self options:0][0];
			}
        } else {
			Class viewClass = _supplementaryViewClassDict[kindAndIdentifier];
			Class reusableViewClass = NSClassFromString(@"UICollectionReusableView");
			if (reusableViewClass && [viewClass isEqual:reusableViewClass]) {
				viewClass = [INDCollectionReusableView class];
			}
			if (viewClass == nil) {
				@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Class not registered for kind/identifier %@", kindAndIdentifier] userInfo:nil];
			}
			if (self.collectionViewLayout) {
				INDCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForSupplementaryViewOfKind:elementKind
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


- (NSArray *)allCells {
    return [[_allVisibleViewsDict allValues] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject isKindOfClass:[INDCollectionViewCell class]];
    }]];
}

- (NSArray *)visibleCells {
    return [[_allVisibleViewsDict allValues] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject isKindOfClass:[INDCollectionViewCell class]] && CGRectIntersectsRect(self.bounds, [evaluatedObject frame]);
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

    for(NSIndexPath *indexPath in _indexPathsForSelectedItems) {
        INDCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:indexPath];
        selectedCell.selected = NO;
        selectedCell.highlighted = NO;
    }
    [_indexPathsForSelectedItems removeAllObjects];
    [_indexPathsForHighlightedItems removeAllObjects];

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

- (INDCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [[self collectionViewLayout] layoutAttributesForItemAtIndexPath:indexPath];
}

- (INDCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    return [[self collectionViewLayout] layoutAttributesForSupplementaryViewOfKind:kind atIndexPath:indexPath];
}

- (NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point {
    __block NSIndexPath *indexPath = nil;
    [_allVisibleViewsDict enumerateKeysAndObjectsWithOptions:kNilOptions usingBlock:^(id key, id obj, BOOL *stop) {
        INDCollectionViewItemKey *itemKey = (INDCollectionViewItemKey *)key;
        if (itemKey.type == INDCollectionViewItemTypeCell) {
            INDCollectionViewCell *cell = (INDCollectionViewCell *)obj;
            if (CGRectContainsPoint(cell.frame, point)) {
                indexPath = itemKey.indexPath;
                *stop = YES;
            }
        }
    }];
    return indexPath;
}

- (NSIndexPath *)indexPathForCell:(INDCollectionViewCell *)cell {
    __block NSIndexPath *indexPath = nil;
    [_allVisibleViewsDict enumerateKeysAndObjectsWithOptions:kNilOptions usingBlock:^(id key, id obj, BOOL *stop) {
        INDCollectionViewItemKey *itemKey = (INDCollectionViewItemKey *)key;
        if (itemKey.type == INDCollectionViewItemTypeCell) {
            INDCollectionViewCell *currentCell = (INDCollectionViewCell *)obj;
            if (currentCell == cell) {
                indexPath = itemKey.indexPath;
                *stop = YES;
            }
        }
    }];
    return indexPath;
}

- (INDCollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    // NSInteger index = [_collectionViewData globalIndexForItemAtIndexPath:indexPath];
    // TODO Apple uses some kind of globalIndex for this.
    __block INDCollectionViewCell *cell = nil;
    [_allVisibleViewsDict enumerateKeysAndObjectsWithOptions:0 usingBlock:^(id key, id obj, BOOL *stop) {
        INDCollectionViewItemKey *itemKey = (INDCollectionViewItemKey *)key;
        if (itemKey.type == INDCollectionViewItemTypeCell) {
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
		INDCollectionViewItemKey *itemKey = (INDCollectionViewItemKey *)key;
        if (itemKey.type == INDCollectionViewItemTypeCell) {
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
- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(INDCollectionViewScrollPosition)scrollPosition animated:(BOOL)animated {

    // ensure grid is layouted; else we can't scroll.
    [self layoutSubviews];

    INDCollectionViewLayoutAttributes *layoutAttributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
    if (layoutAttributes) {
        CGRect targetRect = layoutAttributes.frame;

        // hack to add proper margins to flowlayout.
        // TODO: how to pack this into INDCollectionViewFlowLayout?
        if ([self.collectionViewLayout isKindOfClass:[INDCollectionViewFlowLayout class]]) {
            INDCollectionViewFlowLayout *flowLayout = (INDCollectionViewFlowLayout *)self.collectionViewLayout;
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
            for (INDCollectionViewCell* visibleCell in [self allCells]) {
                visibleCell.highlighted = NO;
                visibleCell.selected = NO;

                // NOTE: doesn't work due to the _indexPathsForHighlightedItems validation
                //[self unhighlightItemAtIndexPath:indexPathForVisibleItem animated:YES notifyDelegate:YES];
            }
        }

        [self highlightItemAtIndexPath:indexPath animated:YES scrollPosition:INDCollectionViewScrollPositionNone notifyDelegate:YES];

        self.extVars.touchingIndexPath = indexPath;
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];

    if (self.extVars.touchingIndexPath) {
        CGPoint touchPoint = [[touches anyObject] locationInView:self];
        NSIndexPath *indexPath = [self indexPathForItemAtPoint:touchPoint];
        if ([indexPath isEqual:self.extVars.touchingIndexPath]) {
            [self highlightItemAtIndexPath:indexPath animated:YES scrollPosition:INDCollectionViewScrollPositionNone notifyDelegate:YES];
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
        for (INDCollectionViewCell* visibleCell in [self allCells]) {
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
        [self selectItemAtIndexPath:indexPath animated:YES scrollPosition:INDCollectionViewScrollPositionNone notifyDelegate:YES];
    }
}

// select item, notify delegate (internal)
- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(INDCollectionViewScrollPosition)scrollPosition notifyDelegate:(BOOL)notifyDelegate {

    if (self.allowsMultipleSelection && [_indexPathsForSelectedItems containsObject:indexPath]) {

        BOOL shouldDeselect = YES;
        if (notifyDelegate && _collectionViewFlags.delegateShouldDeselectItemAtIndexPath) {
            shouldDeselect = [self.delegate collectionView:self shouldDeselectItemAtIndexPath:indexPath];
        }

        if (shouldDeselect) {
            [self deselectItemAtIndexPath:indexPath animated:animated];

            if (notifyDelegate && _collectionViewFlags.delegateDidDeselectItemAtIndexPath) {
                [self.delegate collectionView:self didDeselectItemAtIndexPath:indexPath];
            }
        }

    } else {
        // either single selection, or wasn't already selected in multiple selection mode
        
        if (!self.allowsMultipleSelection) {
            for (NSIndexPath *selectedIndexPath in [_indexPathsForSelectedItems copy]) {
                if(![indexPath isEqual:selectedIndexPath]) {
                    [self deselectItemAtIndexPath:selectedIndexPath animated:animated notifyDelegate:notifyDelegate];
                }
            }
        }

        BOOL shouldSelect = YES;
        if (notifyDelegate && _collectionViewFlags.delegateShouldSelectItemAtIndexPath) {
            shouldSelect = [self.delegate collectionView:self shouldSelectItemAtIndexPath:indexPath];
        }

        if (shouldSelect) {
            INDCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:indexPath];
            selectedCell.selected = YES;
            [_indexPathsForSelectedItems addObject:indexPath];

            if (notifyDelegate && _collectionViewFlags.delegateDidSelectItemAtIndexPath) {
                [self.delegate collectionView:self didSelectItemAtIndexPath:indexPath];
            }
        }
    }

    [self unhighlightItemAtIndexPath:indexPath animated:animated notifyDelegate:YES];
}

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(INDCollectionViewScrollPosition)scrollPosition {
    [self selectItemAtIndexPath:indexPath animated:animated scrollPosition:scrollPosition notifyDelegate:NO];
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
    [self deselectItemAtIndexPath:indexPath animated:animated notifyDelegate:NO];
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated notifyDelegate:(BOOL)notify {
    if ([_indexPathsForSelectedItems containsObject:indexPath]) {
        INDCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:indexPath];
        selectedCell.selected = NO;
        [_indexPathsForSelectedItems removeObject:indexPath];

        [self unhighlightItemAtIndexPath:indexPath animated:animated notifyDelegate:notify];

        if (notify && _collectionViewFlags.delegateDidDeselectItemAtIndexPath) {
            [self.delegate collectionView:self didDeselectItemAtIndexPath:indexPath];
        }
    }
}

- (BOOL)highlightItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(INDCollectionViewScrollPosition)scrollPosition notifyDelegate:(BOOL)notifyDelegate {
    BOOL shouldHighlight = YES;
    if (notifyDelegate && _collectionViewFlags.delegateShouldHighlightItemAtIndexPath) {
        shouldHighlight = [self.delegate collectionView:self shouldHighlightItemAtIndexPath:indexPath];
    }

    if (shouldHighlight) {
        INDCollectionViewCell *highlightedCell = [self cellForItemAtIndexPath:indexPath];
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
        INDCollectionViewCell *highlightedCell = [self cellForItemAtIndexPath:indexPath];
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
    [self updateSections:sections updateAction:INDCollectionUpdateActionInsert];
}

- (void)deleteSections:(NSIndexSet *)sections {
    [self updateSections:sections updateAction:INDCollectionUpdateActionInsert];
}

- (void)reloadSections:(NSIndexSet *)sections {
    [self updateSections:sections updateAction:INDCollectionUpdateActionReload];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection {
    NSMutableArray *moveUpdateItems = [self arrayForUpdateAction:INDCollectionUpdateActionMove];
    [moveUpdateItems addObject:
     [[INDCollectionViewUpdateItem alloc] initWithInitialIndexPath:[NSIndexPath indexPathForItem:NSNotFound inSection:section]
                                                    finalIndexPath:[NSIndexPath indexPathForItem:NSNotFound inSection:newSection]
                                                      updateAction:INDCollectionUpdateActionMove]];
    if(!_collectionViewFlags.updating) {
        [self setupCellAnimations];
        [self endItemAnimations];
    }
}

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths {
    [self updateRowsAtIndexPaths:indexPaths updateAction:INDCollectionUpdateActionInsert];
}

- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths {
    [self updateRowsAtIndexPaths:indexPaths updateAction:INDCollectionUpdateActionDelete];

}

- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths {
    [self updateRowsAtIndexPaths:indexPaths updateAction:INDCollectionUpdateActionReload];
}

- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath {
    NSMutableArray* moveUpdateItems = [self arrayForUpdateAction:INDCollectionUpdateActionMove];
    [moveUpdateItems addObject:
     [[INDCollectionViewUpdateItem alloc] initWithInitialIndexPath:indexPath
                                                    finalIndexPath:newIndexPath
                                                      updateAction:INDCollectionUpdateActionMove]];
    if(!_collectionViewFlags.updating) {
        [self setupCellAnimations];
        [self endItemAnimations];
    }

}

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion {
    if(!updates) return;
    
    [self setupCellAnimations];

    updates();
    
    if(completion) _updateCompletionHandler = completion;
        
    [self endItemAnimations];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Properties

- (void)setBackgroundView:(UIView *)backgroundView {
    if (backgroundView != _backgroundView) {
        [_backgroundView removeFromSuperview];
        _backgroundView = backgroundView;
        backgroundView.frame = (CGRect){.origin=self.contentOffset,.size=self.bounds.size};
        backgroundView.autoresizesSubviews = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
        [self addSubview:backgroundView];
        [self sendSubviewToBack:backgroundView];
    }
}

- (void)setCollectionViewLayout:(INDCollectionViewLayout *)layout animated:(BOOL)animated {
    if (layout == _layout) return;

    // not sure it was it original code, but here this prevents crash
    // in case we switch layout before previous one was initially loaded
    if(CGRectIsEmpty(self.bounds) || !_collectionViewFlags.doneFirstLayout) {
        _layout.collectionView = nil;
        _collectionViewData = [[INDCollectionViewData alloc] initWithCollectionView:self layout:layout];
        layout.collectionView = self;
        _layout = layout;
        
        // originally the use method
        // _setNeedsVisibleCellsUpdate:withLayoutAttributes:
        // here with CellsUpdate set to YES and LayoutAttributes parameter set to NO
        // inside this method probably some flags are set and finally
        // setNeedsDisplay is called
        
        _collectionViewFlags.scheduledUpdateVisibleCells= YES;
        _collectionViewFlags.scheduledUpdateVisibleCellLayoutAttributes = NO;

        [self setNeedsDisplay];
    }
    else {
        layout.collectionView = self;
        
        _collectionViewData = [[INDCollectionViewData alloc] initWithCollectionView:self layout:layout];
        [_collectionViewData prepareToLoadData];

        NSArray *previouslySelectedIndexPaths = [self indexPathsForSelectedItems];
        NSMutableSet *selectedCellKeys = [NSMutableSet setWithCapacity:[previouslySelectedIndexPaths count]];
        
        for(NSIndexPath *indexPath in previouslySelectedIndexPaths) {
            [selectedCellKeys addObject:[INDCollectionViewItemKey collectionItemKeyForCellWithIndexPath:indexPath]];
        }
        
        NSArray *previouslyVisibleItemsKeys = [_allVisibleViewsDict allKeys];
        NSSet *previouslyVisibleItemsKeysSet = [NSSet setWithArray:previouslyVisibleItemsKeys];
        NSMutableSet *previouslyVisibleItemsKeysSetMutable = [NSMutableSet setWithArray:previouslyVisibleItemsKeys];

        if([selectedCellKeys intersectsSet:selectedCellKeys]) {
            [previouslyVisibleItemsKeysSetMutable intersectSet:previouslyVisibleItemsKeysSetMutable];
        }
        
        [self bringSubviewToFront: _allVisibleViewsDict[[previouslyVisibleItemsKeysSetMutable anyObject]]];
        
        CGRect rect = [_collectionViewData collectionViewContentRect];
        NSArray *newlyVisibleLayoutAttrs = [_collectionViewData layoutAttributesForElementsInRect:rect];
        
        NSMutableDictionary *layoutInterchangeData = [NSMutableDictionary dictionaryWithCapacity:
                                                     [newlyVisibleLayoutAttrs count] + [previouslyVisibleItemsKeysSet count]];
        
        NSMutableSet *newlyVisibleItemsKeys = [NSMutableSet set];
        for(INDCollectionViewLayoutAttributes *attr in newlyVisibleLayoutAttrs) {
            INDCollectionViewItemKey *newKey = [INDCollectionViewItemKey collectionItemKeyForLayoutAttributes:attr];
            [newlyVisibleItemsKeys addObject:newKey];
            
            INDCollectionViewLayoutAttributes *prevAttr = nil;
            INDCollectionViewLayoutAttributes *newAttr = nil;
            
            if(newKey.type == INDCollectionViewItemTypeDecorationView) {
                prevAttr = [self.collectionViewLayout layoutAttributesForDecorationViewWithReuseIdentifier:attr.representedElementKind
                                                                                               atIndexPath:newKey.indexPath];
                newAttr = [layout layoutAttributesForDecorationViewWithReuseIdentifier:attr.representedElementKind
                                                                           atIndexPath:newKey.indexPath];
            }
            else if(newKey.type == INDCollectionViewItemTypeCell) {
                prevAttr = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:newKey.indexPath];
                newAttr = [layout layoutAttributesForItemAtIndexPath:newKey.indexPath];
            }
            else {
                prevAttr = [self.collectionViewLayout layoutAttributesForSupplementaryViewOfKind:attr.representedElementKind
                                                                                     atIndexPath:newKey.indexPath];
                newAttr = [layout layoutAttributesForSupplementaryViewOfKind:attr.representedElementKind
                                                                 atIndexPath:newKey.indexPath];
            }
            
            layoutInterchangeData[newKey] = [NSDictionary dictionaryWithObjects:@[prevAttr,newAttr]
                                                                        forKeys:@[@"previousLayoutInfos", @"newLayoutInfos"]];
        }
        
        for(INDCollectionViewItemKey *key in previouslyVisibleItemsKeysSet) {
            INDCollectionViewLayoutAttributes *prevAttr = nil;
            INDCollectionViewLayoutAttributes *newAttr = nil;
            
            if(key.type == INDCollectionViewItemTypeDecorationView) {
                INDCollectionReusableView *decorView = _allVisibleViewsDict[key];
                prevAttr = [self.collectionViewLayout layoutAttributesForDecorationViewWithReuseIdentifier:decorView.reuseIdentifier
                                                                                               atIndexPath:key.indexPath];
                newAttr = [layout layoutAttributesForDecorationViewWithReuseIdentifier:decorView.reuseIdentifier
                                                                           atIndexPath:key.indexPath];
            }
            else if(key.type == INDCollectionViewItemTypeCell) {
                prevAttr = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:key.indexPath];
                newAttr = [layout layoutAttributesForItemAtIndexPath:key.indexPath];
            }
            else {
                INDCollectionReusableView* suuplView = _allVisibleViewsDict[key];
                prevAttr = [self.collectionViewLayout layoutAttributesForSupplementaryViewOfKind:suuplView.layoutAttributes.representedElementKind
                                                                                     atIndexPath:key.indexPath];
                newAttr = [layout layoutAttributesForSupplementaryViewOfKind:suuplView.layoutAttributes.representedElementKind
                                                                 atIndexPath:key.indexPath];
            }
            
            layoutInterchangeData[key] = [NSDictionary dictionaryWithObjects:@[prevAttr,newAttr]
                                                                     forKeys:@[@"previousLayoutInfos", @"newLayoutInfos"]];
        }

        for(INDCollectionViewItemKey *key in [layoutInterchangeData keyEnumerator]) {
            if(key.type == INDCollectionViewItemTypeCell) {
                INDCollectionViewCell* cell = _allVisibleViewsDict[key];
                
                if (!cell) {
                    cell = [self createPreparedCellForItemAtIndexPath:key.indexPath
                                                 withLayoutAttributes:layoutInterchangeData[key][@"previousLayoutInfos"]];
                    _allVisibleViewsDict[key] = cell;
                    [self addControlledSubview:cell];
                }
                else [cell applyLayoutAttributes:layoutInterchangeData[key][@"previousLayoutInfos"]];
            }
            else if(key.type == INDCollectionViewItemTypeSupplementaryView) {
                INDCollectionReusableView *view = _allVisibleViewsDict[key];
                if (!view) {
                    INDCollectionViewLayoutAttributes *attrs = layoutInterchangeData[key][@"previousLayoutInfos"];
                    view = [self createPreparedSupplementaryViewForElementOfKind:attrs.representedElementKind
                                                                     atIndexPath:attrs.indexPath
                                                            withLayoutAttributes:attrs];
                }
            }
        };
        
        CGRect contentRect = [_collectionViewData collectionViewContentRect];
        [self setContentSize:contentRect.size];
        [self setContentOffset:contentRect.origin];
        
        void (^applyNewLayoutBlock)(void) = ^{
            NSEnumerator *keys = [layoutInterchangeData keyEnumerator];
            for(INDCollectionViewItemKey *key in keys) {
                [(INDCollectionViewCell *)_allVisibleViewsDict[key] applyLayoutAttributes:layoutInterchangeData[key][@"newLayoutInfos"]];
            }
        };
        
        void (^freeUnusedViews)(void) = ^ {
            for(INDCollectionViewItemKey *key in [_allVisibleViewsDict keyEnumerator]) {
                if(![newlyVisibleItemsKeys containsObject:key]) {
                    if(key.type == INDCollectionViewItemTypeCell) [self reuseCell:_allVisibleViewsDict[key]];
                    else if(key.type == INDCollectionViewItemTypeSupplementaryView)
                        [self reuseSupplementaryView:_allVisibleViewsDict[key]];
                }
            }
        };
        
        if(animated) {
            [UIView animateWithDuration:.3 animations:^ {
                 _collectionViewFlags.updatingLayout = YES;
                 applyNewLayoutBlock();
             } completion:^(BOOL finished) {
                 freeUnusedViews();
                 _collectionViewFlags.updatingLayout = NO;
             }];
        }
        else {
            applyNewLayoutBlock();
            freeUnusedViews();
        }
        
        _layout.collectionView = nil;
        _layout = layout;
    }
}

- (void)setCollectionViewLayout:(INDCollectionViewLayout *)layout {
    [self setCollectionViewLayout:layout animated:NO];
}

- (void)setDelegate:(id<INDCollectionViewDelegate>)delegate {
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

// Might be overkill since two are required and two are handled by INDCollectionViewData leaving only one flag we actually need to check for
- (void)setDataSource:(id<INDCollectionViewDataSource>)dataSource {
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

    // Deselect all objects if allows multiple selection is false
    if (!allowsMultipleSelection && _indexPathsForSelectedItems.count) {

        // Note: Apple's implementation leaves a mostly random item selected. Presumably they
        //       have a good reason for this, but I guess it's just skipping the last or first index.
        for (NSIndexPath *selectedIndexPath in [_indexPathsForSelectedItems copy]) {
            if (_indexPathsForSelectedItems.count == 1) continue;
            [self deselectItemAtIndexPath:selectedIndexPath animated:YES notifyDelegate:YES];
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (INDCollectionViewExt *)extVars {
    return objc_getAssociatedObject(self, &kINDColletionViewExt);
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
    for (INDCollectionViewLayoutAttributes *layoutAttributes in layoutAttributesArray) {
        INDCollectionViewItemKey *itemKey = [INDCollectionViewItemKey collectionItemKeyForLayoutAttributes:layoutAttributes];
        itemKeysToAddDict[itemKey] = layoutAttributes;
    }

    // detect what items should be removed and queued back.
    NSMutableSet *allVisibleItemKeys = [NSMutableSet setWithArray:[_allVisibleViewsDict allKeys]];
    [allVisibleItemKeys minusSet:[NSSet setWithArray:[itemKeysToAddDict allKeys]]];

    // remove views that have not been processed and prepare them for re-use.
    for (INDCollectionViewItemKey *itemKey in allVisibleItemKeys) {
        INDCollectionReusableView *reusableView = _allVisibleViewsDict[itemKey];
        if (reusableView) {
            [reusableView removeFromSuperview];
            [_allVisibleViewsDict removeObjectForKey:itemKey];
            if (itemKey.type == INDCollectionViewItemTypeCell) {
                if (_collectionViewFlags.delegateDidEndDisplayingCell) {
                    [self.delegate collectionView:self didEndDisplayingCell:(INDCollectionViewCell *)reusableView forItemAtIndexPath:itemKey.indexPath];
                }
                [self reuseCell:(INDCollectionViewCell *)reusableView];
            }else if(itemKey.type == INDCollectionViewItemTypeSupplementaryView) {
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
        INDCollectionViewItemKey *itemKey = key;
        INDCollectionViewLayoutAttributes *layoutAttributes = obj;

        // check if cell is in visible dict; add it if not.
        INDCollectionReusableView *view = _allVisibleViewsDict[itemKey];
        if (!view) {
            if (itemKey.type == INDCollectionViewItemTypeCell) {
                view = [self createPreparedCellForItemAtIndexPath:itemKey.indexPath withLayoutAttributes:layoutAttributes];

            } else if (itemKey.type == INDCollectionViewItemTypeSupplementaryView) {
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
- (INDCollectionViewCell *)createPreparedCellForItemAtIndexPath:(NSIndexPath *)indexPath withLayoutAttributes:(INDCollectionViewLayoutAttributes *)layoutAttributes {

    INDCollectionViewCell *cell = [self.dataSource collectionView:self cellForItemAtIndexPath:indexPath];

    // reset selected/highlight state
    [cell setHighlighted:[_indexPathsForHighlightedItems containsObject:indexPath]];
    [cell setSelected:[_indexPathsForSelectedItems containsObject:indexPath]];

    // voiceover support
    cell.isAccessibilityElement = YES;

    [cell applyLayoutAttributes:layoutAttributes];
    return cell;
}

- (INDCollectionReusableView *)createPreparedSupplementaryViewForElementOfKind:(NSString *)kind
																   atIndexPath:(NSIndexPath *)indexPath
														  withLayoutAttributes:(INDCollectionViewLayoutAttributes *)layoutAttributes {
	if (_collectionViewFlags.dataSourceViewForSupplementaryElement) {
		INDCollectionReusableView *view = [self.dataSource collectionView:self
										viewForSupplementaryElementOfKind:kind
															  atIndexPath:indexPath];
		[view applyLayoutAttributes:layoutAttributes];
		return view;
	}
	return nil;
}

// @steipete optimization
- (void)queueReusableView:(INDCollectionReusableView *)reusableView inQueue:(NSMutableDictionary *)queue {
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
- (void)reuseCell:(INDCollectionViewCell *)cell {
    [self queueReusableView:cell inQueue:_cellReuseQueues];
}

// enqueue supplementary view for reuse
- (void)reuseSupplementaryView:(INDCollectionReusableView *)supplementaryView {
    [self queueReusableView:supplementaryView inQueue:_supplementaryViewReuseQueues];
}

- (void)addControlledSubview:(INDCollectionReusableView *)subview {
	// avoids placing views above the scroll indicator
    [self insertSubview:subview atIndex:self.subviews.count - (self.dragging ? 1 : 0)];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Updating grid internal functionality

- (void)suspendReloads {
    _reloadingSuspendedCount++;
}

- (void)resumeReloads {
    _reloadingSuspendedCount--;
}

-(NSMutableArray *)arrayForUpdateAction:(INDCollectionUpdateAction)updateAction {
    NSMutableArray *ret = nil;

    switch (updateAction) {
        case INDCollectionUpdateActionInsert:
            if(!_insertItems) _insertItems = [[NSMutableArray alloc] init];
            ret = _insertItems;
            break;
        case INDCollectionUpdateActionDelete:
            if(!_deleteItems) _deleteItems = [[NSMutableArray alloc] init];
            ret = _deleteItems;
            break;
        case INDCollectionUpdateActionMove:
            if(_moveItems) _moveItems = [[NSMutableArray alloc] init];
            ret = _moveItems;
            break;
        case INDCollectionUpdateActionReload:
            if(!_reloadItems) _reloadItems = [[NSMutableArray alloc] init];
            ret = _reloadItems;
            break;
        default: break;
    }
    return ret;
}


- (void)prepareLayoutForUpdates {
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    [arr addObjectsFromArray: [_originalDeleteItems sortedArrayUsingSelector:@selector(inverseCompareIndexPaths:)]];
    [arr addObjectsFromArray:[_originalInsertItems sortedArrayUsingSelector:@selector(compareIndexPaths:)]];
    [arr addObjectsFromArray:[_reloadItems sortedArrayUsingSelector:@selector(compareIndexPaths:)]];
    [arr addObjectsFromArray: [_moveItems sortedArrayUsingSelector:@selector(compareIndexPaths:)]];
    [_layout prepareForCollectionViewUpdates:arr];
}

- (void)updateWithItems:(NSArray *) items {
    [self prepareLayoutForUpdates];
    
    NSMutableArray *animations = [[NSMutableArray alloc] init];
    NSMutableDictionary *newAllVisibleView = [[NSMutableDictionary alloc] init];

    for (INDCollectionViewUpdateItem *updateItem in items) {
        if (updateItem.isSectionOperation) continue;
        
        if (updateItem.updateAction == INDCollectionUpdateActionDelete) {
            NSIndexPath *indexPath = updateItem.indexPathBeforeUpdate;
            
            INDCollectionViewLayoutAttributes *finalAttrs = [_layout finalLayoutAttributesForDisappearingItemAtIndexPath:indexPath];
            INDCollectionViewItemKey *key = [INDCollectionViewItemKey collectionItemKeyForCellWithIndexPath:indexPath];
            INDCollectionReusableView *view = _allVisibleViewsDict[key];
            if (view) {
                INDCollectionViewLayoutAttributes *startAttrs = view.layoutAttributes;
                
                if (!finalAttrs) {
                    finalAttrs = [startAttrs copy];
                    finalAttrs.alpha = 0;
                }
                [animations addObject:@{@"view": view, @"previousLayoutInfos": startAttrs, @"newLayoutInfos": finalAttrs}];
                [_allVisibleViewsDict removeObjectForKey:key];
            }
        }
        else if(updateItem.updateAction == INDCollectionUpdateActionInsert) {
            NSIndexPath *indexPath = updateItem.indexPathAfterUpdate;
            INDCollectionViewItemKey *key = [INDCollectionViewItemKey collectionItemKeyForCellWithIndexPath:indexPath];
            INDCollectionViewLayoutAttributes *startAttrs = [_layout initialLayoutAttributesForAppearingItemAtIndexPath:indexPath];
            INDCollectionViewLayoutAttributes *finalAttrs = [_layout layoutAttributesForItemAtIndexPath:indexPath];
            
            CGRect startRect = CGRectMake(CGRectGetMidX(startAttrs.frame)-startAttrs.center.x,
                                          CGRectGetMidY(startAttrs.frame)-startAttrs.center.y,
                                          startAttrs.frame.size.width,
                                          startAttrs.frame.size.height);
            CGRect finalRect = CGRectMake(CGRectGetMidX(finalAttrs.frame)-finalAttrs.center.x,
                                         CGRectGetMidY(finalAttrs.frame)-finalAttrs.center.y,
                                         finalAttrs.frame.size.width,
                                         finalAttrs.frame.size.height);
            
            if(CGRectIntersectsRect(_visibleBoundRects, startRect) || CGRectIntersectsRect(_visibleBoundRects, finalRect)) {
                INDCollectionReusableView *view = [self createPreparedCellForItemAtIndexPath:indexPath
                                                                        withLayoutAttributes:startAttrs];
                [self addControlledSubview:view];
                
                newAllVisibleView[key] = view;
                [animations addObject:@{@"view": view, @"previousLayoutInfos": startAttrs?startAttrs:finalAttrs, @"newLayoutInfos": finalAttrs}];
            }
        }
        else if(updateItem.updateAction == INDCollectionUpdateActionMove) {
            NSIndexPath *indexPathBefore = updateItem.indexPathBeforeUpdate;
            NSIndexPath *indexPathAfter = updateItem.indexPathAfterUpdate;
            
            INDCollectionViewItemKey *keyBefore = [INDCollectionViewItemKey collectionItemKeyForCellWithIndexPath:indexPathBefore];
            INDCollectionViewItemKey *keyAfter = [INDCollectionViewItemKey collectionItemKeyForCellWithIndexPath:indexPathAfter];
            INDCollectionReusableView *view = _allVisibleViewsDict[keyBefore];
            
            INDCollectionViewLayoutAttributes *startAttrs = nil;
            INDCollectionViewLayoutAttributes *finalAttrs = [_layout layoutAttributesForItemAtIndexPath:indexPathAfter];
            
            if(view) {
                startAttrs = view.layoutAttributes;
                [_allVisibleViewsDict removeObjectForKey:keyBefore];
                newAllVisibleView[keyAfter] = view;
            }
            else {
                startAttrs = [finalAttrs copy];
                startAttrs.alpha = 0;
                view = [self createPreparedCellForItemAtIndexPath:indexPathAfter withLayoutAttributes:startAttrs];
                [self addControlledSubview:view];
                newAllVisibleView[keyAfter] = view;
            }
            
            [animations addObject:@{@"view": view, @"previousLayoutInfos": startAttrs, @"newLayoutInfos": finalAttrs}];
        }
    }
    
    for (INDCollectionViewItemKey *key in [_allVisibleViewsDict keyEnumerator]) {
        INDCollectionReusableView *view = _allVisibleViewsDict[key];
        NSInteger oldGlobalIndex = [_update[@"oldModel"] globalIndexForItemAtIndexPath:key.indexPath];
        NSInteger newGlobalIndex = [_update[@"oldToNewIndexMap"][oldGlobalIndex] intValue];
        NSIndexPath *newIndexPath = [_update[@"newModel"] indexPathForItemAtGlobalIndex:newGlobalIndex];
        
        INDCollectionViewLayoutAttributes* startAttrs =
        [_layout initialLayoutAttributesForAppearingItemAtIndexPath:newIndexPath];
        
        INDCollectionViewLayoutAttributes* finalAttrs =
        [_layout layoutAttributesForItemAtIndexPath:newIndexPath];
        
        [animations addObject:@{@"view":view, @"previousLayoutInfos": startAttrs, @"newLayoutInfos": finalAttrs}];
        INDCollectionViewItemKey* newKey = [key copy];
        [newKey setIndexPath:newIndexPath];
        newAllVisibleView[newKey] = view;
    }

    NSArray *allNewlyVisibleItems = [_layout layoutAttributesForElementsInRect:_visibleBoundRects];
    for (INDCollectionViewLayoutAttributes *attrs in allNewlyVisibleItems) {
        INDCollectionViewItemKey *key = [INDCollectionViewItemKey collectionItemKeyForLayoutAttributes:attrs];
        
        if (![[newAllVisibleView allKeys] containsObject:key]) {
            INDCollectionViewLayoutAttributes* startAttrs =
            [_layout initialLayoutAttributesForAppearingItemAtIndexPath:attrs.indexPath];
            
            INDCollectionReusableView *view = [self createPreparedCellForItemAtIndexPath:attrs.indexPath
                                                                    withLayoutAttributes:startAttrs];
            [self addControlledSubview:view];
            newAllVisibleView[key] = view;
            
            [animations addObject:@{@"view":view, @"previousLayoutInfos": startAttrs?startAttrs:attrs, @"newLayoutInfos": attrs}];
        }
    }
    
    _allVisibleViewsDict = newAllVisibleView;

    for(NSDictionary *animation in animations) {
        INDCollectionReusableView *view = animation[@"view"];
        INDCollectionViewLayoutAttributes *attr = animation[@"previousLayoutInfos"];
        [view applyLayoutAttributes:attr];
    };

    [UIView animateWithDuration:.3 animations:^{
         _collectionViewFlags.updatingLayout = YES;
         for(NSDictionary *animation in animations) {
             INDCollectionReusableView* view = animation[@"view"];
             INDCollectionViewLayoutAttributes* attrs = animation[@"newLayoutInfos"];
             [view applyLayoutAttributes:attrs];
         }
     } completion:^(BOOL finished) {
         NSMutableSet *set = [NSMutableSet set];
         NSArray *visibleItems = [_layout layoutAttributesForElementsInRect:_visibleBoundRects];
         for(INDCollectionViewLayoutAttributes *attrs in visibleItems)
             [set addObject: [INDCollectionViewItemKey collectionItemKeyForLayoutAttributes:attrs]];

         NSMutableSet *toRemove =  [NSMutableSet set];
         for(INDCollectionViewItemKey *key in [_allVisibleViewsDict keyEnumerator]) {
             if(![set containsObject:key]) {
                 [self reuseCell:_allVisibleViewsDict[key]];
                 [toRemove addObject:key];
             }
         }
         for(id key in toRemove)
             [_allVisibleViewsDict removeObjectForKey:key];
         
         _collectionViewFlags.updatingLayout = NO;
         
         if(_updateCompletionHandler) {
             _updateCompletionHandler(finished);
             _updateCompletionHandler = nil;
         }
     }];

    [_layout finalizeCollectionViewUpdates];
}

- (void)setupCellAnimations {
    [self updateVisibleCellsNow:YES];
    [self suspendReloads];
    _collectionViewFlags.updating = YES;
}

- (void)endItemAnimations {
    _updateCount++;
    INDCollectionViewData *oldCollectionViewData = _collectionViewData;
    _collectionViewData = [[INDCollectionViewData alloc] initWithCollectionView:self layout:_layout];
    
    [_layout invalidateLayout];
    [_collectionViewData prepareToLoadData];

    NSMutableArray *someMutableArr1 = [[NSMutableArray alloc] init];

    NSArray *removeUpdateItems = [[self arrayForUpdateAction:INDCollectionUpdateActionDelete]
                                  sortedArrayUsingSelector:@selector(inverseCompareIndexPaths:)];
    
    NSArray *insertUpdateItems = [[self arrayForUpdateAction:INDCollectionUpdateActionInsert]
                                  sortedArrayUsingSelector:@selector(compareIndexPaths:)];

    NSMutableArray *sortedMutableReloadItems = [[_reloadItems sortedArrayUsingSelector:@selector(compareIndexPaths:)] mutableCopy];
    NSMutableArray *sortedMutableMoveItems = [[_moveItems sortedArrayUsingSelector:@selector(compareIndexPaths:)] mutableCopy];
    
    _originalDeleteItems = [removeUpdateItems copy];
    _originalInsertItems = [insertUpdateItems copy];

    NSMutableArray *someMutableArr2 = [[NSMutableArray alloc] init];
    NSMutableArray *someMutableArr3 =[[NSMutableArray alloc] init];
    NSMutableDictionary *operations = [[NSMutableDictionary alloc] init];
    
    for(INDCollectionViewUpdateItem *updateItem in sortedMutableReloadItems) {
        NSAssert(updateItem.indexPathBeforeUpdate.section< [oldCollectionViewData numberOfSections],
                 @"attempt to reload item (%@) that doesn't exist (there are only %d sections before update)",
                 updateItem.indexPathBeforeUpdate, [oldCollectionViewData numberOfSections]);
        NSAssert(updateItem.indexPathBeforeUpdate.item<[oldCollectionViewData numberOfItemsInSection:updateItem.indexPathBeforeUpdate.section],
                 @"attempt to reload item (%@) that doesn't exist (there are only %d items in section %d before udpate)",
                 updateItem.indexPathBeforeUpdate,
                 [oldCollectionViewData numberOfItemsInSection:updateItem.indexPathBeforeUpdate.section],
                 updateItem.indexPathBeforeUpdate.section);
        
        [someMutableArr2 addObject:[[INDCollectionViewUpdateItem alloc] initWithAction:INDCollectionUpdateActionDelete
                                                                          forIndexPath:updateItem.indexPathBeforeUpdate]];
        [someMutableArr3 addObject:[[INDCollectionViewUpdateItem alloc] initWithAction:INDCollectionUpdateActionInsert
                                                                          forIndexPath:updateItem.indexPathAfterUpdate]];
    }
    
    NSMutableArray *sortedDeletedMutableItems = [[_deleteItems sortedArrayUsingSelector:@selector(inverseCompareIndexPaths:)] mutableCopy];
    NSMutableArray *sortedInsertMutableItems = [[_insertItems sortedArrayUsingSelector:@selector(compareIndexPaths:)] mutableCopy];
    
    for(INDCollectionViewUpdateItem *deleteItem in sortedDeletedMutableItems) {
        if([deleteItem isSectionOperation]) {
            NSAssert(deleteItem.indexPathBeforeUpdate.section<[oldCollectionViewData numberOfSections],
                     @"attempt to delete section (%d) that doesn't exist (there are only %d sections before update)",
                     deleteItem.indexPathBeforeUpdate.section,
                     [oldCollectionViewData numberOfSections]);
            
            for(INDCollectionViewUpdateItem *moveItem in sortedMutableMoveItems) {
                if(moveItem.indexPathBeforeUpdate.section == deleteItem.indexPathBeforeUpdate.section) {
                    if(moveItem.isSectionOperation)
                        NSAssert(NO, @"attempt to delete and move from the same section %d", deleteItem.indexPathBeforeUpdate.section);
                    else
                        NSAssert(NO, @"attempt to delete and move from the same section (%@)", moveItem.indexPathBeforeUpdate);
                }
            }
        } else {
            NSAssert(deleteItem.indexPathBeforeUpdate.section<[oldCollectionViewData numberOfSections],
                     @"attempt to delete item (%@) that doesn't exist (there are only %d sections before update)",
                     deleteItem.indexPathBeforeUpdate,
                     [oldCollectionViewData numberOfSections]);
            NSAssert(deleteItem.indexPathBeforeUpdate.item<[oldCollectionViewData numberOfItemsInSection:deleteItem.indexPathBeforeUpdate.section],
                     @"attempt to delete item (%@) that doesn't exist (there are only %d items in section %d before update)",
                     deleteItem.indexPathBeforeUpdate,
                     [oldCollectionViewData numberOfItemsInSection:deleteItem.indexPathBeforeUpdate.section],
                     deleteItem.indexPathBeforeUpdate.section);
            
            for(INDCollectionViewUpdateItem *moveItem in sortedMutableMoveItems) {
                NSAssert([deleteItem.indexPathBeforeUpdate isEqual:moveItem.indexPathBeforeUpdate],
                         @"attempt to delete and move the same item (%@)", deleteItem.indexPathBeforeUpdate);
            }
            
            if(!operations[@(deleteItem.indexPathBeforeUpdate.section)])
                operations[@(deleteItem.indexPathBeforeUpdate.section)] = [NSMutableDictionary dictionary];
            
            operations[@(deleteItem.indexPathBeforeUpdate.section)][@"deleted"] =
            @([operations[@(deleteItem.indexPathBeforeUpdate.section)][@"deleted"] intValue]+1);
        }
    }
                      
    for(NSInteger i=0; i<[sortedInsertMutableItems count]; i++) {
        INDCollectionViewUpdateItem *insertItem = sortedInsertMutableItems[i];
        NSIndexPath *indexPath = insertItem.indexPathAfterUpdate;

        BOOL sectionOperation = [insertItem isSectionOperation];
        if(sectionOperation) {
            NSAssert([indexPath section]<[_collectionViewData numberOfSections],
                     @"attempt to insert %d but there are only %d sections after update",
                     [indexPath section], [_collectionViewData numberOfSections]);
            
            for(INDCollectionViewUpdateItem *moveItem in sortedMutableMoveItems) {
                if([moveItem.indexPathAfterUpdate isEqual:indexPath]) {
                    if(moveItem.isSectionOperation)
                        NSAssert(NO, @"attempt to perform an insert and a move to the same section (%d)",indexPath.section);
//                    else
//                        NSAssert(NO, @"attempt to perform an insert and a move to the same index path (%@)",indexPath);
                }
            }
            
            NSInteger j=i+1;
            while(j<[sortedInsertMutableItems count]) {
                INDCollectionViewUpdateItem *nextInsertItem = sortedInsertMutableItems[j];
                
                if(nextInsertItem.indexPathAfterUpdate.section == indexPath.section) {
                    NSAssert(nextInsertItem.indexPathAfterUpdate.item<[_collectionViewData numberOfItemsInSection:indexPath.section],
                             @"attempt to insert item %d into section %d, but there are only %d items in section %d after the update",
                             nextInsertItem.indexPathAfterUpdate.item,
                             indexPath.section,
                             [_collectionViewData numberOfItemsInSection:indexPath.section],
                             indexPath.section);
                    [sortedInsertMutableItems removeObjectAtIndex:j];
                }
                else break;
            }
        } else {
            NSAssert(indexPath.item< [_collectionViewData numberOfItemsInSection:indexPath.section],
                     @"attempt to insert item to (%@) but there are only %d items in section %d after update",
                     indexPath,
                     [_collectionViewData numberOfItemsInSection:indexPath.section],
                     indexPath.section);
            
            if(!operations[@(indexPath.section)])
                operations[@(indexPath.section)] = [NSMutableDictionary dictionary];

            operations[@(indexPath.section)][@"inserted"] =
            @([operations[@(indexPath.section)][@"inserted"] intValue]+1);
        }
    }

    for(INDCollectionViewUpdateItem * sortedItem in sortedMutableMoveItems) {
        if(sortedItem.isSectionOperation) {
            NSAssert(sortedItem.indexPathBeforeUpdate.section<[oldCollectionViewData numberOfSections],
                     @"attempt to move section (%d) that doesn't exist (%d sections before update)",
                     sortedItem.indexPathBeforeUpdate.section,
                     [oldCollectionViewData numberOfSections]);
            NSAssert(sortedItem.indexPathAfterUpdate.section<[_collectionViewData numberOfSections],
                     @"attempt to move section to %d but there are only %d sections after update",
                     sortedItem.indexPathAfterUpdate.section,
                     [_collectionViewData numberOfSections]);
        } else {
            NSAssert(sortedItem.indexPathBeforeUpdate.section<[oldCollectionViewData numberOfSections],
                     @"attempt to move item (%@) that doesn't exist (%d sections before update)",
                     sortedItem, [oldCollectionViewData numberOfSections]);
            NSAssert(sortedItem.indexPathBeforeUpdate.item<[oldCollectionViewData numberOfItemsInSection:sortedItem.indexPathBeforeUpdate.section],
                     @"attempt to move item (%@) that doesn't exist (%d items in section %d before update)",
                     sortedItem,
                     [oldCollectionViewData numberOfItemsInSection:sortedItem.indexPathBeforeUpdate.section],
                     sortedItem.indexPathBeforeUpdate.section);
            
            NSAssert(sortedItem.indexPathAfterUpdate.section<[_collectionViewData numberOfSections],
                     @"attempt to move item to (%@) but there are only %d sections after update",
                     sortedItem.indexPathAfterUpdate,
                     [_collectionViewData numberOfSections]);
            NSAssert(sortedItem.indexPathAfterUpdate.item<[_collectionViewData numberOfItemsInSection:sortedItem.indexPathAfterUpdate.section],
                     @"attempt to move item to (%@) but there are only %d items in section %d after update",
                     sortedItem,
                     [_collectionViewData numberOfItemsInSection:sortedItem.indexPathAfterUpdate.section],
                     sortedItem.indexPathAfterUpdate.section);
        }
        
        if(!operations[@(sortedItem.indexPathBeforeUpdate.section)])
            operations[@(sortedItem.indexPathBeforeUpdate.section)] = [NSMutableDictionary dictionary];
        if(!operations[@(sortedItem.indexPathAfterUpdate.section)])
            operations[@(sortedItem.indexPathAfterUpdate.section)] = [NSMutableDictionary dictionary];
        
        operations[@(sortedItem.indexPathBeforeUpdate.section)][@"movedOut"] =
        @([operations[@(sortedItem.indexPathBeforeUpdate.section)][@"movedOut"] intValue]+1);

        operations[@(sortedItem.indexPathAfterUpdate.section)][@"movedIn"] =
        @([operations[@(sortedItem.indexPathAfterUpdate.section)][@"movedIn"] intValue]+1);
    }

#if !defined  NS_BLOCK_ASSERTIONS
    for(NSNumber *sectionKey in [operations keyEnumerator]) {
        NSInteger section = [sectionKey intValue];
        
        NSInteger insertedCount = [operations[sectionKey][@"inserted"] intValue];
        NSInteger deletedCount = [operations[sectionKey][@"deleted"] intValue];
        NSInteger movedInCount = [operations[sectionKey][@"movedIn"] intValue];
        NSInteger movedOutCount = [operations[sectionKey][@"movedOut"] intValue];
        
        NSAssert([oldCollectionViewData numberOfItemsInSection:section]+insertedCount-deletedCount+movedInCount-movedOutCount ==
                 [_collectionViewData numberOfItemsInSection:section],
                 @"invalide update in section %d: number of items after update (%d) should be equal to the number of items before update (%d) "\
                 "plus count of inserted items (%d), minus count of deleted items (%d), plus count of items moved in (%d), minus count of items moved out (%d)",
                 section,
                  [_collectionViewData numberOfItemsInSection:section],
                 [oldCollectionViewData numberOfItemsInSection:section],
                 insertedCount,deletedCount,movedInCount, movedOutCount);
    }
#endif

    [someMutableArr2 addObjectsFromArray:sortedDeletedMutableItems];
    [someMutableArr3 addObjectsFromArray:sortedInsertMutableItems];
    [someMutableArr1 addObjectsFromArray:[someMutableArr2 sortedArrayUsingSelector:@selector(inverseCompareIndexPaths:)]];
    [someMutableArr1 addObjectsFromArray:sortedMutableMoveItems];
    [someMutableArr1 addObjectsFromArray:[someMutableArr3 sortedArrayUsingSelector:@selector(compareIndexPaths:)]];
    
    NSMutableArray *layoutUpdateItems = [[NSMutableArray alloc] init];

    [layoutUpdateItems addObjectsFromArray:sortedDeletedMutableItems];
    [layoutUpdateItems addObjectsFromArray:sortedMutableMoveItems];
    [layoutUpdateItems addObjectsFromArray:sortedInsertMutableItems];
    
    
    NSMutableArray* newModel = [NSMutableArray array];
    for(NSInteger i=0;i<[oldCollectionViewData numberOfSections];i++) {
        NSMutableArray * sectionArr = [NSMutableArray array];
        for(NSInteger j=0;j< [oldCollectionViewData numberOfItemsInSection:i];j++)
            [sectionArr addObject: @([oldCollectionViewData globalIndexForItemAtIndexPath:[NSIndexPath indexPathForItem:j inSection:i]])];
        [newModel addObject:sectionArr];
    }
    
    for(INDCollectionViewUpdateItem *updateItem in layoutUpdateItems) {
        switch (updateItem.updateAction) {
            case INDCollectionUpdateActionDelete: {
                if(updateItem.isSectionOperation) {
                    [newModel removeObjectAtIndex:updateItem.indexPathBeforeUpdate.section];
                } else {
                    [(NSMutableArray*)newModel[updateItem.indexPathBeforeUpdate.section]
                     removeObjectAtIndex:updateItem.indexPathBeforeUpdate.item];
                }
            }break;
            case INDCollectionUpdateActionInsert: {
                if(updateItem.isSectionOperation) {
                    [newModel insertObject:[[NSMutableArray alloc] init]
                                   atIndex:updateItem.indexPathAfterUpdate.section];
                } else {
                    [(NSMutableArray *)newModel[updateItem.indexPathAfterUpdate.section]
                     insertObject:@(NSNotFound)
                     atIndex:updateItem.indexPathAfterUpdate.item];
                }
            }break;
                
            case INDCollectionUpdateActionMove: {
                if(updateItem.isSectionOperation) {
                    id section = newModel[updateItem.indexPathBeforeUpdate.section];
                    [newModel insertObject:section atIndex:updateItem.indexPathAfterUpdate.section];
                }
                else {
                    id object = newModel[updateItem.indexPathBeforeUpdate.section][updateItem.indexPathBeforeUpdate.item];
                    [newModel[updateItem.indexPathBeforeUpdate.section] removeObjectAtIndex:updateItem.indexPathBeforeUpdate.item];
                    [newModel[updateItem.indexPathAfterUpdate.section] insertObject:object
                                                                            atIndex:updateItem.indexPathAfterUpdate.item];
                }
            }break;
            default: break;
        }
    }
    
    NSMutableArray *oldToNewMap = [NSMutableArray arrayWithCapacity:[oldCollectionViewData numberOfItems]];
    NSMutableArray *newToOldMap = [NSMutableArray arrayWithCapacity:[_collectionViewData numberOfItems]];

    for(NSInteger i=0; i < [oldCollectionViewData numberOfItems]; i++)
        [oldToNewMap addObject:@(NSNotFound)];

    for(NSInteger i=0; i < [_collectionViewData numberOfItems]; i++)
        [newToOldMap addObject:@(NSNotFound)];
    
    for(NSInteger i=0; i < [newModel count]; i++) {
        NSMutableArray* section = newModel[i];
        for(NSInteger j=0; j<[section count];j++) {
            NSInteger newGlobalIndex = [_collectionViewData globalIndexForItemAtIndexPath:[NSIndexPath indexPathForItem:j inSection:i]];
            if([section[j] intValue] != NSNotFound)
                oldToNewMap[[section[j] intValue]] = @(newGlobalIndex);
            if(newGlobalIndex != NSNotFound)
                newToOldMap[newGlobalIndex] = section[j];
        }
    }

    _update = @{@"oldModel":oldCollectionViewData, @"newModel":_collectionViewData, @"oldToNewIndexMap":oldToNewMap, @"newToOldIndexMap":newToOldMap};

    [self updateWithItems:someMutableArr1];
    
    _originalInsertItems = nil;
    _originalDeleteItems = nil;
    _insertItems = nil;
    _deleteItems = nil;
    _moveItems = nil;
    _reloadItems = nil;
    _update = nil;
    _updateCount--;
    _collectionViewFlags.updating = NO;
    [self resumeReloads];
}


- (void)updateRowsAtIndexPaths:(NSArray *)indexPaths updateAction:(INDCollectionUpdateAction)updateAction {
    BOOL updating = _collectionViewFlags.updating;
    if(!updating) {
        [self setupCellAnimations];
    }
    
    NSMutableArray *array = [self arrayForUpdateAction:updateAction]; //returns appropriate empty array if not exists
    
    for(NSIndexPath *indexPath in indexPaths) {
        INDCollectionViewUpdateItem *updateItem = [[INDCollectionViewUpdateItem alloc] initWithAction:updateAction
                                                                                         forIndexPath:indexPath];
        [array addObject:updateItem];
    }
    
    if(!updating) [self endItemAnimations];
}


- (void)updateSections:(NSIndexSet *)sections updateAction:(INDCollectionUpdateAction)updateAction {
    BOOL updating = _collectionViewFlags.updating;
    if(updating) {
        [self setupCellAnimations];
    }
    
    NSMutableArray *updateActions = [self arrayForUpdateAction:updateAction];
    NSInteger section = [sections firstIndex];
    
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        INDCollectionViewUpdateItem *updateItem =
        [[INDCollectionViewUpdateItem alloc] initWithAction:updateAction
                                               forIndexPath:[NSIndexPath indexPathForItem:NSNotFound
                                                                                inSection:section]];
        [updateActions addObject:updateItem];
    }];
    
    if (!updating) {
        [self endItemAnimations];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - INDCollection/UICollection interoperability

#ifdef kPSUIInteroperabilityEnabled
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
#endif

@end

#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
@implementation NSIndexPath (INDCollectionViewAdditions)

// Simple NSIndexPath addition to allow using "item" instead of "row".
+ (NSIndexPath *)indexPathForItem:(NSInteger)item inSection:(NSInteger)section {
    return [NSIndexPath indexPathForRow:item inSection:section];
}

- (NSInteger)item {
    return self.row;
}
@end
#endif
