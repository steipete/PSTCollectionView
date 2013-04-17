//
//  PSTCollectionView.m
//  PSPDFKit
//
//  Copyright (c) 2012-2013 Peter Steinberger. All rights reserved.
//

#import "PSTCollectionView.h"
#import "PSTCollectionViewController.h"
#import "PSTCollectionViewData.h"
#import "PSTCollectionViewCell.h"
#import "PSTCollectionViewLayout.h"
#import "PSTCollectionViewLayout+Internals.h"
#import "PSTCollectionViewFlowLayout.h"
#import "PSTCollectionViewItemKey.h"
#import "PSTCollectionViewUpdateItem.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface PSTCollectionViewLayout (Internal)
@property (nonatomic, unsafe_unretained) PSTCollectionView *collectionView;
@end

@interface PSTCollectionViewData (Internal)
- (void)prepareToLoadData;
@end

@interface PSTCollectionViewUpdateItem()
- (NSIndexPath *)indexPath;
- (BOOL)isSectionOperation;
@end


CGFloat PSTSimulatorAnimationDragCoefficient(void);
@class PSTCollectionViewExt;

@interface PSTCollectionView() <UIScrollViewDelegate> {
    // ivar layout needs to EQUAL to UICollectionView.
    PSTCollectionViewLayout *_layout;
    __unsafe_unretained id<PSTCollectionViewDataSource> _dataSource;
    UIView *_backgroundView;
    NSMutableSet *_indexPathsForSelectedItems;
    NSMutableDictionary *_cellReuseQueues;
    NSMutableDictionary *_supplementaryViewReuseQueues;
    NSMutableDictionary *_decorationViewReuseQueues;
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
@property (nonatomic, strong) PSTCollectionViewData *collectionViewData;
@property (nonatomic, strong, readonly) PSTCollectionViewExt *extVars;
@property (nonatomic, readonly) id currentUpdate;
@property (nonatomic, readonly) NSDictionary *visibleViewsDict;
@property (nonatomic, assign) CGRect visibleBoundRects;
@end

// Used by PSTCollectionView for external variables.
// (We need to keep the total class size equal to the UICollectionView variant)
@interface PSTCollectionViewExt : NSObject
@property (nonatomic, unsafe_unretained) id<PSTCollectionViewDelegate> collectionViewDelegate;
@property (nonatomic, strong) PSTCollectionViewLayout *nibLayout;
@property (nonatomic, strong) NSDictionary *nibCellsExternalObjects;
@property (nonatomic, strong) NSDictionary *supplementaryViewsExternalObjects;
@property (nonatomic, strong) NSIndexPath *touchingIndexPath;
@property (nonatomic, strong) NSIndexPath *currentIndexPath;
@end

@implementation PSTCollectionViewExt @end
const char kPSTColletionViewExt;

@implementation PSTCollectionView

@synthesize collectionViewLayout = _layout;
@synthesize currentUpdate = _update;
@synthesize visibleViewsDict = _allVisibleViewsDict;

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

static void PSTCollectionViewCommonSetup(PSTCollectionView *_self) {
    _self.allowsSelection = YES;
    _self->_indexPathsForSelectedItems = [NSMutableSet new];
    _self->_indexPathsForHighlightedItems = [NSMutableSet new];
    _self->_cellReuseQueues = [NSMutableDictionary new];
    _self->_supplementaryViewReuseQueues = [NSMutableDictionary new];
    _self->_decorationViewReuseQueues = [NSMutableDictionary new];
    _self->_allVisibleViewsDict = [NSMutableDictionary new];
    _self->_cellClassDict = [NSMutableDictionary new];
    _self->_cellNibDict = [NSMutableDictionary new];
    _self->_supplementaryViewClassDict = [NSMutableDictionary new];
	_self->_supplementaryViewNibDict = [NSMutableDictionary new];

    // add class that saves additional ivars
    objc_setAssociatedObject(_self, &kPSTColletionViewExt, [PSTCollectionViewExt new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame collectionViewLayout:nil];
}

- (id)initWithFrame:(CGRect)frame collectionViewLayout:(PSTCollectionViewLayout *)layout {
    if ((self = [super initWithFrame:frame])) {
        // Set self as the UIScrollView's delegate
        [super setDelegate:self];

        PSTCollectionViewCommonSetup(self);
        self.collectionViewLayout = layout;
        _collectionViewData = [[PSTCollectionViewData alloc] initWithCollectionView:self layout:layout];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)inCoder {
    if ((self = [super initWithCoder:inCoder])) {
        // Set self as the UIScrollView's delegate
        [super setDelegate:self];

        PSTCollectionViewCommonSetup(self);

        self.extVars.nibLayout = [inCoder decodeObjectForKey:@"UICollectionLayout"];

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

    PSTCollectionViewLayout *nibLayout = self.extVars.nibLayout;
    if (nibLayout) {
        self.collectionViewLayout = nibLayout;
        self.extVars.nibLayout = nil;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ collection view layout: %@", [super description], self.collectionViewLayout];
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
#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if ([self.extVars.collectionViewDelegate respondsToSelector:@selector(scrollViewDidScroll:)]) {
        [self.extVars.collectionViewDelegate scrollViewDidScroll:scrollView];
    }
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if ([self.extVars.collectionViewDelegate respondsToSelector:@selector(scrollViewDidZoom:)]) {
        [self.extVars.collectionViewDelegate scrollViewDidZoom:scrollView];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if ([self.extVars.collectionViewDelegate respondsToSelector:@selector(scrollViewWillBeginDragging:)]) {
        [self.extVars.collectionViewDelegate scrollViewWillBeginDragging:scrollView];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    // Let collectionViewLayout decide where to stop.
    *targetContentOffset = [[self collectionViewLayout] targetContentOffsetForProposedContentOffset:*targetContentOffset withScrollingVelocity:velocity];

    if ([self.extVars.collectionViewDelegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)]) {
        //if collectionViewDelegate implements this method, it may modify targetContentOffset as well
        [self.extVars.collectionViewDelegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if ([self.extVars.collectionViewDelegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)]) {
        [self.extVars.collectionViewDelegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    }

    // if we are in the middle of a cell touch event, perform the "touchEnded" simulation
    if (self.extVars.touchingIndexPath) {
        [self cellTouchCancelled];
    }
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    if ([self.extVars.collectionViewDelegate respondsToSelector:@selector(scrollViewWillBeginDecelerating:)]) {
        [self.extVars.collectionViewDelegate scrollViewWillBeginDecelerating:scrollView];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if ([self.extVars.collectionViewDelegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)]) {
        [self.extVars.collectionViewDelegate scrollViewDidEndDecelerating:scrollView];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if ([self.extVars.collectionViewDelegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)]) {
        [self.extVars.collectionViewDelegate scrollViewDidEndScrollingAnimation:scrollView];
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    if ([self.extVars.collectionViewDelegate respondsToSelector:@selector(viewForZoomingInScrollView:)]) {
        return [self.extVars.collectionViewDelegate viewForZoomingInScrollView:scrollView];
    }
    return nil;
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    if ([self.extVars.collectionViewDelegate respondsToSelector:@selector(scrollViewWillBeginZooming:withView:)]) {
        [self.extVars.collectionViewDelegate scrollViewWillBeginZooming:scrollView withView:view];
    }
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale {
    if ([self.extVars.collectionViewDelegate respondsToSelector:@selector(scrollViewDidEndZooming:withView:atScale:)]) {
        [self.extVars.collectionViewDelegate scrollViewDidEndZooming:scrollView withView:view atScale:scale];
    }
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    if ([self.extVars.collectionViewDelegate respondsToSelector:@selector(scrollViewShouldScrollToTop:)]) {
        return [self.extVars.collectionViewDelegate scrollViewShouldScrollToTop:scrollView];
    }
    return YES;
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    if ([self.extVars.collectionViewDelegate respondsToSelector:@selector(scrollViewDidScrollToTop:)]) {
        [self.extVars.collectionViewDelegate scrollViewDidScrollToTop:scrollView];
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
    NSAssert(topLevelObjects.count == 1 && [topLevelObjects[0] isKindOfClass:PSTCollectionViewCell.class], @"must contain exactly 1 top level object which is a PSTCollectionViewCell");

    _cellNibDict[identifier] = nib;
}

- (void)registerNib:(UINib *)nib forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)identifier {
    NSArray *topLevelObjects = [nib instantiateWithOwner:nil options:nil];
#pragma unused(topLevelObjects)
    NSAssert(topLevelObjects.count == 1 && [topLevelObjects[0] isKindOfClass:PSTCollectionReusableView.class], @"must contain exactly 1 top level object which is a PSTCollectionReusableView");

	NSString *kindAndIdentifier = [NSString stringWithFormat:@"%@/%@", kind, identifier];
    _supplementaryViewNibDict[kindAndIdentifier] = nib;
}

- (id)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath {
    // de-queue cell (if available)
    NSMutableArray *reusableCells = _cellReuseQueues[identifier];
    PSTCollectionViewCell *cell = [reusableCells lastObject];
    PSTCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];

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
                cellClass = [PSTCollectionViewCell class];
            }
            if (cellClass == nil) {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Class not registered for identifier %@", identifier] userInfo:nil];
            }
            if (attributes) {
                cell = [[cellClass alloc] initWithFrame:attributes.frame];
            } else {
                cell = [cellClass new];
            }
        }
        PSTCollectionViewLayout *layout = [self collectionViewLayout];
        if ([layout isKindOfClass:[PSTCollectionViewFlowLayout class]]) {
            CGSize itemSize = ((PSTCollectionViewFlowLayout *)layout).itemSize;
            cell.bounds = CGRectMake(0, 0, itemSize.width, itemSize.height);
        }
        cell.collectionView = self;
        cell.reuseIdentifier = identifier;
    }

    [cell applyLayoutAttributes:attributes];

    return cell;
}

- (id)dequeueReusableSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath {
	NSString *kindAndIdentifier = [NSString stringWithFormat:@"%@/%@", elementKind, identifier];
    NSMutableArray *reusableViews = _supplementaryViewReuseQueues[kindAndIdentifier];
    PSTCollectionReusableView *view = [reusableViews lastObject];
    PSTCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForSupplementaryViewOfKind:elementKind
                                                                                                              atIndexPath:indexPath];
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
				viewClass = [PSTCollectionReusableView class];
			}
			if (viewClass == nil) {
				@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Class not registered for kind/identifier %@", kindAndIdentifier] userInfo:nil];
			}
			if (attributes) {
					view = [[viewClass alloc] initWithFrame:attributes.frame];
			} else {
				view = [viewClass new];
			}
        }
        view.collectionView = self;
        view.reuseIdentifier = identifier;
    }
    [view applyLayoutAttributes:attributes];

    return view;
}

- (id)dequeueReusableOrCreateDecorationViewOfKind:(NSString *)elementKind forIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *reusableViews = _decorationViewReuseQueues[elementKind];
    PSTCollectionReusableView *view = [reusableViews lastObject];
    PSTCollectionViewLayout *collectionViewLayout = self.collectionViewLayout;
    PSTCollectionViewLayoutAttributes *attributes = [collectionViewLayout layoutAttributesForDecorationViewOfKind:elementKind atIndexPath:indexPath];

    if (view) {
        [reusableViews removeObjectAtIndex:reusableViews.count - 1];
    } else {
        NSDictionary *decorationViewNibDict = collectionViewLayout.decorationViewNibDict;
        NSDictionary *decorationViewExternalObjects = collectionViewLayout.decorationViewExternalObjectsTables;
        if (decorationViewNibDict[elementKind]) {
            // supplementary view was registered via registerNib:forCellWithReuseIdentifier:
            UINib *supplementaryViewNib = decorationViewNibDict[elementKind];
            NSDictionary *externalObjects = decorationViewExternalObjects[elementKind];
            if (externalObjects) {
                view = [supplementaryViewNib instantiateWithOwner:self options:@{UINibExternalObjects:externalObjects}][0];
            } else {
                view = [supplementaryViewNib instantiateWithOwner:self options:0][0];
            }
        } else {
            NSDictionary *decorationViewClassDict = collectionViewLayout.decorationViewClassDict;
            Class viewClass = decorationViewClassDict[elementKind];
            Class reusableViewClass = NSClassFromString(@"UICollectionReusableView");
            if (reusableViewClass && [viewClass isEqual:reusableViewClass]) {
                viewClass = [PSTCollectionReusableView class];
            }
            if (viewClass == nil) {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Class not registered for identifier %@", elementKind] userInfo:nil];
            }
            if (attributes) {
                view = [[viewClass alloc] initWithFrame:attributes.frame];
            } else {
                view = [viewClass new];
            }
        }
        view.collectionView = self;
        view.reuseIdentifier = elementKind;
    }

    [view applyLayoutAttributes:attributes];

    return view;
}

- (NSArray *)allCells {
    return [[_allVisibleViewsDict allValues] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject isKindOfClass:[PSTCollectionViewCell class]];
    }]];
}

- (NSArray *)visibleCells {
    return [[_allVisibleViewsDict allValues] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject isKindOfClass:[PSTCollectionViewCell class]] && CGRectIntersectsRect(self.bounds, [evaluatedObject frame]);
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
        PSTCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:indexPath];
        selectedCell.selected = NO;
        selectedCell.highlighted = NO;
    }
    [_indexPathsForSelectedItems removeAllObjects];
    [_indexPathsForHighlightedItems removeAllObjects];

    [self setNeedsLayout];
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
    NSArray *visibleCells = self.visibleCells;
	NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:visibleCells.count];

    [visibleCells enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		PSTCollectionViewCell *cell = (PSTCollectionViewCell *)obj;
        [indexPaths addObject:cell.layoutAttributes.indexPath];
    }];

	return indexPaths;
}

// returns nil or an array of selected index paths
- (NSArray *)indexPathsForSelectedItems {
    return [_indexPathsForSelectedItems allObjects];
}

// Interacting with the collection view.
- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(PSTCollectionViewScrollPosition)scrollPosition animated:(BOOL)animated {
    // Ensure grid is laid out; else we can't scroll.
    [self layoutSubviews];

    PSTCollectionViewLayoutAttributes *layoutAttributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
    if (layoutAttributes) {
        CGRect targetRect = [self makeRect:layoutAttributes.frame toScrollPosition:scrollPosition];
        [self scrollRectToVisible:targetRect animated:animated];
    }
}

- (CGRect)makeRect:(CGRect)targetRect toScrollPosition:(PSTCollectionViewScrollPosition)scrollPosition {
    // split parameters
    NSUInteger verticalPosition = scrollPosition   & 0x07; // 0000 0111
    NSUInteger horizontalPosition = scrollPosition & 0x38; // 0011 1000

    if (verticalPosition != PSTCollectionViewScrollPositionNone
        && verticalPosition != PSTCollectionViewScrollPositionTop
        && verticalPosition != PSTCollectionViewScrollPositionCenteredVertically
        && verticalPosition != PSTCollectionViewScrollPositionBottom)
    {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"PSTCollectionViewScrollPosition: attempt to use a scroll position with multiple vertical positioning styles" userInfo:nil];
    }

    if(horizontalPosition != PSTCollectionViewScrollPositionNone
       && horizontalPosition != PSTCollectionViewScrollPositionLeft
       && horizontalPosition != PSTCollectionViewScrollPositionCenteredHorizontally
       && horizontalPosition != PSTCollectionViewScrollPositionRight) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"PSTCollectionViewScrollPosition: attempt to use a scroll position with multiple horizontal positioning styles" userInfo:nil];
    }

    CGRect frame = self.layer.bounds;
    CGFloat calculateX;
    CGFloat calculateY;

    switch(verticalPosition) {
        case PSTCollectionViewScrollPositionCenteredVertically:
            calculateY = fmaxf(targetRect.origin.y-((frame.size.height/2)-(targetRect.size.height/2)), -self.contentInset.top);
            targetRect = CGRectMake(targetRect.origin.x, calculateY, targetRect.size.width, frame.size.height);
            break;
        case PSTCollectionViewScrollPositionTop:
            targetRect = CGRectMake(targetRect.origin.x, targetRect.origin.y, targetRect.size.width, frame.size.height);
            break;

        case PSTCollectionViewScrollPositionBottom:
            calculateY = fmaxf(targetRect.origin.y-(frame.size.height-targetRect.size.height), -self.contentInset.top);
            targetRect = CGRectMake(targetRect.origin.x, calculateY, targetRect.size.width, frame.size.height);
            break;
    }

    switch(horizontalPosition) {
        case PSTCollectionViewScrollPositionCenteredHorizontally:
            calculateX = targetRect.origin.x-((frame.size.width/2)-(targetRect.size.width/2));
            targetRect = CGRectMake(calculateX, targetRect.origin.y, frame.size.width, targetRect.size.height);
            break;

        case PSTCollectionViewScrollPositionLeft:
            targetRect = CGRectMake(targetRect.origin.x, targetRect.origin.y, frame.size.width, targetRect.size.height);
            break;

        case PSTCollectionViewScrollPositionRight:
            calculateX = targetRect.origin.x-(frame.size.width-targetRect.size.width);
            targetRect = CGRectMake(calculateX, targetRect.origin.y, frame.size.width, targetRect.size.height);
            break;
    }

    return targetRect;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Touch Handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];

    // reset touching state vars
    self.extVars.touchingIndexPath = nil;
    self.extVars.currentIndexPath = nil;

    CGPoint touchPoint = [[touches anyObject] locationInView:self];
    NSIndexPath *indexPath = [self indexPathForItemAtPoint:touchPoint];
    if (indexPath) {
        if (![self highlightItemAtIndexPath:indexPath animated:YES scrollPosition:PSTCollectionViewScrollPositionNone notifyDelegate:YES])
            return;

        self.extVars.touchingIndexPath = indexPath;
        self.extVars.currentIndexPath = indexPath;

        if (!self.allowsMultipleSelection) {
            // temporally unhighlight background on touchesBegan (keeps selected by _indexPathsForSelectedItems)
            // single-select only mode only though
            NSIndexPath *tempDeselectIndexPath = _indexPathsForSelectedItems.anyObject;
            if (tempDeselectIndexPath && ![tempDeselectIndexPath isEqual:self.extVars.touchingIndexPath]) {
                // iOS6 UICollectionView deselects cell without notification
                PSTCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:tempDeselectIndexPath];
                selectedCell.selected = NO;
            }
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];

    // allows moving between highlight and unhighlight state only if setHighlighted is not overwritten
    if (self.extVars.touchingIndexPath) {
        CGPoint touchPoint = [[touches anyObject] locationInView:self];
        NSIndexPath *indexPath = [self indexPathForItemAtPoint:touchPoint];

        // moving out of bounds
        if ([self.extVars.currentIndexPath isEqual:self.extVars.touchingIndexPath] &&
            ![indexPath isEqual:self.extVars.touchingIndexPath] &&
            [self unhighlightItemAtIndexPath:self.extVars.touchingIndexPath animated:YES notifyDelegate:YES shouldCheckHighlight:YES]) {
            self.extVars.currentIndexPath = indexPath;
        // moving back into the original touching cell
        } else if (![self.extVars.currentIndexPath isEqual:self.extVars.touchingIndexPath] &&
                   [indexPath isEqual:self.extVars.touchingIndexPath]) {
            [self highlightItemAtIndexPath:self.extVars.touchingIndexPath animated:YES scrollPosition:PSTCollectionViewScrollPositionNone notifyDelegate:YES];
            self.extVars.currentIndexPath = self.extVars.touchingIndexPath;
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];

    if (self.extVars.touchingIndexPath) {
        // first unhighlight the touch operation
        [self unhighlightItemAtIndexPath:self.extVars.touchingIndexPath animated:YES notifyDelegate:YES];

        CGPoint touchPoint = [[touches anyObject] locationInView:self];
        NSIndexPath *indexPath = [self indexPathForItemAtPoint:touchPoint];
        if ([indexPath isEqual:self.extVars.touchingIndexPath]) {
            [self userSelectedItemAtIndexPath:indexPath];
        }
        else if (!self.allowsMultipleSelection) {
            NSIndexPath *tempDeselectIndexPath = _indexPathsForSelectedItems.anyObject;
            if (tempDeselectIndexPath && ![tempDeselectIndexPath isEqual:self.extVars.touchingIndexPath]) {
                [self cellTouchCancelled];
            }
        }

        // for pedantic reasons only - always set to nil on touchesBegan
        self.extVars.touchingIndexPath = nil;
        self.extVars.currentIndexPath = nil;
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];

    // do not mark touchingIndexPath as nil because whoever cancelled this touch will need to signal a touch up event later
    if (self.extVars.touchingIndexPath) {
        // first unhighlight the touch operation
        [self unhighlightItemAtIndexPath:self.extVars.touchingIndexPath animated:YES notifyDelegate:YES];
    }
}

- (void)cellTouchCancelled {
    // turn on ALL the *should be selected* cells (iOS6 UICollectionView does no state keeping or other fancy optimizations)
    // there should be no notifications as this is a silent "turn everything back on"
    for (NSIndexPath *tempDeselectedIndexPath in [_indexPathsForSelectedItems copy]) {
        PSTCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:tempDeselectedIndexPath];
        selectedCell.selected = YES;
    }
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
    if (self.allowsMultipleSelection && [_indexPathsForSelectedItems containsObject:indexPath]) {
        BOOL shouldDeselect = YES;
        if (notifyDelegate && _collectionViewFlags.delegateShouldDeselectItemAtIndexPath) {
            shouldDeselect = [self.delegate collectionView:self shouldDeselectItemAtIndexPath:indexPath];
        }

        if (shouldDeselect) {
            [self deselectItemAtIndexPath:indexPath animated:animated notifyDelegate:notifyDelegate];
        }
    }
    else {
        // either single selection, or wasn't already selected in multiple selection mode
        BOOL shouldSelect = YES;
        if (notifyDelegate && _collectionViewFlags.delegateShouldSelectItemAtIndexPath) {
            shouldSelect = [self.delegate collectionView:self shouldSelectItemAtIndexPath:indexPath];
        }

        if (!self.allowsMultipleSelection) {
            // now unselect the previously selected cell for single selection
            NSIndexPath *tempDeselectIndexPath = _indexPathsForSelectedItems.anyObject;
            if (tempDeselectIndexPath && ![tempDeselectIndexPath isEqual:indexPath]) {
                [self deselectItemAtIndexPath:tempDeselectIndexPath animated:YES notifyDelegate:YES];
            }
        }

        if (shouldSelect) {
            PSTCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:indexPath];
            selectedCell.selected = YES;

            [_indexPathsForSelectedItems addObject:indexPath];

            if (scrollPosition != PSTCollectionViewScrollPositionNone) {
                [self scrollToItemAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
            }

            if (notifyDelegate && _collectionViewFlags.delegateDidSelectItemAtIndexPath) {
                [self.delegate collectionView:self didSelectItemAtIndexPath:indexPath];
            }
        }
    }
}

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(PSTCollectionViewScrollPosition)scrollPosition {
    [self selectItemAtIndexPath:indexPath animated:animated scrollPosition:scrollPosition notifyDelegate:NO];
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {
    [self deselectItemAtIndexPath:indexPath animated:animated notifyDelegate:NO];
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated notifyDelegate:(BOOL)notifyDelegate {
    BOOL shouldDeselect = YES;
    // deselect only relevant during multi mode
    if (self.allowsMultipleSelection && notifyDelegate && _collectionViewFlags.delegateShouldDeselectItemAtIndexPath) {
        shouldDeselect = [self.delegate collectionView:self shouldDeselectItemAtIndexPath:indexPath];
    }

    if (shouldDeselect && [_indexPathsForSelectedItems containsObject:indexPath]) {
        PSTCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:indexPath];
        if (selectedCell) {
            if (selectedCell.selected) {
                selectedCell.selected = NO;
            }
        }
        [_indexPathsForSelectedItems removeObject:indexPath];

        if (notifyDelegate && _collectionViewFlags.delegateDidDeselectItemAtIndexPath) {
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

        if (scrollPosition != PSTCollectionViewScrollPositionNone) {
            [self scrollToItemAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
        }

        if (notifyDelegate && _collectionViewFlags.delegateDidHighlightItemAtIndexPath) {
            [self.delegate collectionView:self didHighlightItemAtIndexPath:indexPath];
        }
    }
    return shouldHighlight;
}

- (BOOL)unhighlightItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated notifyDelegate:(BOOL)notifyDelegate {
    return [self unhighlightItemAtIndexPath:indexPath animated:animated notifyDelegate:notifyDelegate shouldCheckHighlight:NO];
}

- (BOOL)unhighlightItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated notifyDelegate:(BOOL)notifyDelegate shouldCheckHighlight:(BOOL)check {
    if ([_indexPathsForHighlightedItems containsObject:indexPath]) {
        PSTCollectionViewCell *highlightedCell = [self cellForItemAtIndexPath:indexPath];
        // iOS6 does not notify any delegate if the cell was never highlighted (setHighlighted overwritten) during touchMoved
        if (check && !highlightedCell.highlighted) {
            return NO;
        }

        // if multiple selection or not unhighlighting a selected item we don't perform any op
        if (highlightedCell.highlighted && [_indexPathsForSelectedItems containsObject:indexPath]) {
            highlightedCell.highlighted = YES;
        } else {
            highlightedCell.highlighted = NO;
        }

        [_indexPathsForHighlightedItems removeObject:indexPath];

        if (notifyDelegate && _collectionViewFlags.delegateDidUnhighlightItemAtIndexPath) {
            [self.delegate collectionView:self didUnhighlightItemAtIndexPath:indexPath];
        }

        return YES;
    }
    return NO;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Update Grid

- (void)insertSections:(NSIndexSet *)sections {
    [self updateSections:sections updateAction:PSTCollectionUpdateActionInsert];
}

- (void)deleteSections:(NSIndexSet *)sections {
    [self updateSections:sections updateAction:PSTCollectionUpdateActionDelete];
}

- (void)reloadSections:(NSIndexSet *)sections {
    [self updateSections:sections updateAction:PSTCollectionUpdateActionDelete];
    [self updateSections:sections updateAction:PSTCollectionUpdateActionInsert];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection {
    NSMutableArray *moveUpdateItems = [self arrayForUpdateAction:PSTCollectionUpdateActionMove];
    [moveUpdateItems addObject:
     [[PSTCollectionViewUpdateItem alloc] initWithInitialIndexPath:[NSIndexPath indexPathForItem:NSNotFound inSection:section]
                                                    finalIndexPath:[NSIndexPath indexPathForItem:NSNotFound inSection:newSection]
                                                      updateAction:PSTCollectionUpdateActionMove]];
    if(!_collectionViewFlags.updating) {
        [self setupCellAnimations];
        [self endItemAnimations];
    }
}

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths {
    [self updateRowsAtIndexPaths:indexPaths updateAction:PSTCollectionUpdateActionInsert];
}

- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths {
    [self updateRowsAtIndexPaths:indexPaths updateAction:PSTCollectionUpdateActionDelete];

}

- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths {
    [self updateRowsAtIndexPaths:indexPaths updateAction:PSTCollectionUpdateActionReload];
}

- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath {
    NSMutableArray* moveUpdateItems = [self arrayForUpdateAction:PSTCollectionUpdateActionMove];
    [moveUpdateItems addObject:
     [[PSTCollectionViewUpdateItem alloc] initWithInitialIndexPath:indexPath
                                                    finalIndexPath:newIndexPath
                                                      updateAction:PSTCollectionUpdateActionMove]];
    if(!_collectionViewFlags.updating) {
        [self setupCellAnimations];
        [self endItemAnimations];
    }

}

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion {
    [self setupCellAnimations];

    if (updates) updates();
    if (completion) _updateCompletionHandler = completion;

    [self endItemAnimations];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Properties

- (void)setBackgroundView:(UIView *)backgroundView {
    if (backgroundView != _backgroundView) {
        [_backgroundView removeFromSuperview];
        _backgroundView = backgroundView;
        backgroundView.frame = (CGRect){.origin=self.contentOffset,.size=self.bounds.size};
        backgroundView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
        [self addSubview:backgroundView];
        [self sendSubviewToBack:backgroundView];
    }
}

- (void)setCollectionViewLayout:(PSTCollectionViewLayout *)layout animated:(BOOL)animated {
    if (layout == _layout) return;

    // not sure it was it original code, but here this prevents crash
    // in case we switch layout before previous one was initially loaded
    if(CGRectIsEmpty(self.bounds) || !_collectionViewFlags.doneFirstLayout) {
        _layout.collectionView = nil;
        _collectionViewData = [[PSTCollectionViewData alloc] initWithCollectionView:self layout:layout];
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

        _collectionViewData = [[PSTCollectionViewData alloc] initWithCollectionView:self layout:layout];
        [_collectionViewData prepareToLoadData];

        NSArray *previouslySelectedIndexPaths = [self indexPathsForSelectedItems];
        NSMutableSet *selectedCellKeys = [NSMutableSet setWithCapacity:[previouslySelectedIndexPaths count]];

        for(NSIndexPath *indexPath in previouslySelectedIndexPaths) {
            [selectedCellKeys addObject:[PSTCollectionViewItemKey collectionItemKeyForCellWithIndexPath:indexPath]];
        }

        NSArray *previouslyVisibleItemsKeys = [_allVisibleViewsDict allKeys];
        NSSet *previouslyVisibleItemsKeysSet = [NSSet setWithArray:previouslyVisibleItemsKeys];
        NSMutableSet *previouslyVisibleItemsKeysSetMutable = [NSMutableSet setWithArray:previouslyVisibleItemsKeys];

        if([selectedCellKeys intersectsSet:selectedCellKeys]) {
            [previouslyVisibleItemsKeysSetMutable intersectSet:previouslyVisibleItemsKeysSetMutable];
        }

        [self bringSubviewToFront: _allVisibleViewsDict[[previouslyVisibleItemsKeysSetMutable anyObject]]];

        CGPoint targetOffset = self.contentOffset;
        CGPoint centerPoint = CGPointMake(self.bounds.origin.x + self.bounds.size.width / 2.0,
                                          self.bounds.origin.y + self.bounds.size.height / 2.0);
        NSIndexPath *centerItemIndexPath = [self indexPathForItemAtPoint:centerPoint];

        if (!centerItemIndexPath) {
            NSArray *visibleItems = [self indexPathsForVisibleItems];
            if (visibleItems.count > 0) {
                centerItemIndexPath = visibleItems[visibleItems.count / 2];
            }
        }

        if (centerItemIndexPath) {
            PSTCollectionViewLayoutAttributes *layoutAttributes = [layout layoutAttributesForItemAtIndexPath:centerItemIndexPath];
            if (layoutAttributes) {
                PSTCollectionViewScrollPosition scrollPosition = PSTCollectionViewScrollPositionCenteredVertically | PSTCollectionViewScrollPositionCenteredHorizontally;
                CGRect targetRect = [self makeRect:layoutAttributes.frame toScrollPosition:scrollPosition];
                targetOffset = CGPointMake(fmax(0.0, targetRect.origin.x), fmax(0.0, targetRect.origin.y));
            }
        }

        CGRect newlyBounds = CGRectMake(targetOffset.x, targetOffset.y, self.bounds.size.width, self.bounds.size.height);
        NSArray *newlyVisibleLayoutAttrs = [_collectionViewData layoutAttributesForElementsInRect:newlyBounds];

        NSMutableDictionary *layoutInterchangeData = [NSMutableDictionary dictionaryWithCapacity:
                                                      [newlyVisibleLayoutAttrs count] + [previouslyVisibleItemsKeysSet count]];

        NSMutableSet *newlyVisibleItemsKeys = [NSMutableSet set];
        for(PSTCollectionViewLayoutAttributes *attr in newlyVisibleLayoutAttrs) {
            PSTCollectionViewItemKey *newKey = [PSTCollectionViewItemKey collectionItemKeyForLayoutAttributes:attr];
            [newlyVisibleItemsKeys addObject:newKey];

            PSTCollectionViewLayoutAttributes *prevAttr = nil;
            PSTCollectionViewLayoutAttributes *newAttr = nil;

            if(newKey.type == PSTCollectionViewItemTypeDecorationView) {
                prevAttr = [self.collectionViewLayout layoutAttributesForDecorationViewOfKind:attr.representedElementKind
                                                                                               atIndexPath:newKey.indexPath];
                newAttr = [layout layoutAttributesForDecorationViewOfKind:attr.representedElementKind
                                                                           atIndexPath:newKey.indexPath];
            }
            else if(newKey.type == PSTCollectionViewItemTypeCell) {
                prevAttr = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:newKey.indexPath];
                newAttr = [layout layoutAttributesForItemAtIndexPath:newKey.indexPath];
            }
            else {
                prevAttr = [self.collectionViewLayout layoutAttributesForSupplementaryViewOfKind:attr.representedElementKind
                                                                                     atIndexPath:newKey.indexPath];
                newAttr = [layout layoutAttributesForSupplementaryViewOfKind:attr.representedElementKind
                                                                 atIndexPath:newKey.indexPath];
            }

            if (prevAttr != nil && newAttr != nil) {
                layoutInterchangeData[newKey] = [NSDictionary dictionaryWithObjects:@[prevAttr,newAttr]
                                                                            forKeys:@[@"previousLayoutInfos", @"newLayoutInfos"]];
            }
        }

        for(PSTCollectionViewItemKey *key in previouslyVisibleItemsKeysSet) {
            PSTCollectionViewLayoutAttributes *prevAttr = nil;
            PSTCollectionViewLayoutAttributes *newAttr = nil;

            if(key.type == PSTCollectionViewItemTypeDecorationView) {
                PSTCollectionReusableView *decorView = _allVisibleViewsDict[key];
                prevAttr = [self.collectionViewLayout layoutAttributesForDecorationViewOfKind:decorView.reuseIdentifier
                                                                                               atIndexPath:key.indexPath];
                newAttr = [layout layoutAttributesForDecorationViewOfKind:decorView.reuseIdentifier
                                                                           atIndexPath:key.indexPath];
            }
            else if(key.type == PSTCollectionViewItemTypeCell) {
                prevAttr = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:key.indexPath];
                newAttr = [layout layoutAttributesForItemAtIndexPath:key.indexPath];
            }
            else if(key.type == PSTCollectionViewItemTypeSupplementaryView) {
                PSTCollectionReusableView* suuplView = _allVisibleViewsDict[key];
                prevAttr = [self.collectionViewLayout layoutAttributesForSupplementaryViewOfKind:suuplView.layoutAttributes.representedElementKind
                                                                                     atIndexPath:key.indexPath];
                newAttr = [layout layoutAttributesForSupplementaryViewOfKind:suuplView.layoutAttributes.representedElementKind
                                                                 atIndexPath:key.indexPath];
            }

            layoutInterchangeData[key] = [NSDictionary dictionaryWithObjects:@[prevAttr,newAttr]
                                                                     forKeys:@[@"previousLayoutInfos", @"newLayoutInfos"]];
        }

        for(PSTCollectionViewItemKey *key in [layoutInterchangeData keyEnumerator]) {
            if(key.type == PSTCollectionViewItemTypeCell) {
                PSTCollectionViewCell* cell = _allVisibleViewsDict[key];

                if (!cell) {
                    cell = [self createPreparedCellForItemAtIndexPath:key.indexPath
                                                 withLayoutAttributes:layoutInterchangeData[key][@"previousLayoutInfos"]];
                    _allVisibleViewsDict[key] = cell;
                    [self addControlledSubview:cell];
                }
                else [cell applyLayoutAttributes:layoutInterchangeData[key][@"previousLayoutInfos"]];
            }
            else if(key.type == PSTCollectionViewItemTypeSupplementaryView) {
                PSTCollectionReusableView *view = _allVisibleViewsDict[key];
                if (!view) {
                    PSTCollectionViewLayoutAttributes *attrs = layoutInterchangeData[key][@"previousLayoutInfos"];
                    view = [self createPreparedSupplementaryViewForElementOfKind:attrs.representedElementKind
                                                                     atIndexPath:attrs.indexPath
                                                            withLayoutAttributes:attrs];
                    _allVisibleViewsDict[key] = view;
                    [self addControlledSubview:view];
                }
            }
            else if(key.type == PSTCollectionViewItemTypeDecorationView) {
                PSTCollectionReusableView *view = _allVisibleViewsDict[key];
                if (!view) {
                    PSTCollectionViewLayoutAttributes *attrs = layoutInterchangeData[key][@"previousLayoutInfos"];
                    view = [self dequeueReusableOrCreateDecorationViewOfKind:attrs.reuseIdentifier forIndexPath:attrs.indexPath];
                    _allVisibleViewsDict[key] = view;
                    [self addControlledSubview:view];
                }
            }
        };

        CGRect contentRect = [_collectionViewData collectionViewContentRect];

        void (^applyNewLayoutBlock)(void) = ^{
            NSEnumerator *keys = [layoutInterchangeData keyEnumerator];
            for(PSTCollectionViewItemKey *key in keys) {
                // TODO: This is most likely not 100% the same time as in UICollectionView. Needs to be investigated.
                PSTCollectionViewCell *cell = (PSTCollectionViewCell *)_allVisibleViewsDict[key];
                [cell willTransitionFromLayout:_layout toLayout:layout];
                [cell applyLayoutAttributes:layoutInterchangeData[key][@"newLayoutInfos"]];
                [cell didTransitionFromLayout:_layout toLayout:layout];
            }
        };

        void (^freeUnusedViews)(void) = ^ {
            NSMutableSet *toRemove =  [NSMutableSet set];
            for(PSTCollectionViewItemKey *key in [_allVisibleViewsDict keyEnumerator]) {
                if(![newlyVisibleItemsKeys containsObject:key]) {
                    if(key.type == PSTCollectionViewItemTypeCell) {
                        [self reuseCell:_allVisibleViewsDict[key]];
                        [toRemove addObject:key];
                    }
                    else if(key.type == PSTCollectionViewItemTypeSupplementaryView) {
                        [self reuseSupplementaryView:_allVisibleViewsDict[key]];
                        [toRemove addObject:key];
                    }
                    else if(key.type == PSTCollectionViewItemTypeDecorationView) {
                        [self reuseDecorationView:_allVisibleViewsDict[key]];
                        [toRemove addObject:key];
                    }
                }
            }

            for(id key in toRemove)
                [_allVisibleViewsDict removeObjectForKey:key];
        };

        if(animated) {
            [UIView animateWithDuration:.3 animations:^ {
                _collectionViewFlags.updatingLayout = YES;
                self.contentOffset = targetOffset;
                self.contentSize = contentRect.size;
                applyNewLayoutBlock();
            } completion:^(BOOL finished) {
                freeUnusedViews();
                _collectionViewFlags.updatingLayout = NO;

                // layout subviews for updating content offset or size while updating layout
                if (!CGPointEqualToPoint(self.contentOffset, targetOffset)
                    || !CGSizeEqualToSize(self.contentSize, contentRect.size)) {
                    [self layoutSubviews];
                }
            }];
        }
        else {
            self.contentOffset = targetOffset;
            self.contentSize = contentRect.size;
            applyNewLayoutBlock();
            freeUnusedViews();
        }

        _layout.collectionView = nil;
        _layout = layout;
    }
}

- (void)setCollectionViewLayout:(PSTCollectionViewLayout *)layout {
    [self setCollectionViewLayout:layout animated:NO];
}

- (id<PSTCollectionViewDelegate>)delegate {
    return self.extVars.collectionViewDelegate;
}

- (void)setDelegate:(id<PSTCollectionViewDelegate>)delegate {
	self.extVars.collectionViewDelegate = delegate;

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

	// These aren't present in the flags which is a little strange. Not adding them because that will mess with byte alignment which will affect cross compatibility.
	// The flag names are guesses and are there for documentation purposes.
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

- (CGRect)visibleBoundRects {
    // in original UICollectionView implementation they
    // check for _visibleBounds and can union self.bounds
    // with this value. Don't know the meaning of _visibleBounds however.
    return self.bounds;
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

    if (layoutAttributesArray == nil || [layoutAttributesArray count] == 0) {
        // If our layout source isn't providing any layout information, we should just
        // stop, otherwise we'll blow away all the currently existing cells.
        return;
    }

	// create ItemKey/Attributes dictionary
    NSMutableDictionary *itemKeysToAddDict = [NSMutableDictionary dictionary];

	// Add new cells.
    for (PSTCollectionViewLayoutAttributes *layoutAttributes in layoutAttributesArray) {
        PSTCollectionViewItemKey *itemKey = [PSTCollectionViewItemKey collectionItemKeyForLayoutAttributes:layoutAttributes];
        itemKeysToAddDict[itemKey] = layoutAttributes;

        // check if cell is in visible dict; add it if not.
        PSTCollectionReusableView *view = _allVisibleViewsDict[itemKey];
        if (!view) {
            if (itemKey.type == PSTCollectionViewItemTypeCell) {
                view = [self createPreparedCellForItemAtIndexPath:itemKey.indexPath withLayoutAttributes:layoutAttributes];

            } else if (itemKey.type == PSTCollectionViewItemTypeSupplementaryView) {
                view = [self createPreparedSupplementaryViewForElementOfKind:layoutAttributes.representedElementKind
																 atIndexPath:layoutAttributes.indexPath
														withLayoutAttributes:layoutAttributes];
			} else if (itemKey.type == PSTCollectionViewItemTypeDecorationView) {
				view = [self dequeueReusableOrCreateDecorationViewOfKind:layoutAttributes.reuseIdentifier forIndexPath:layoutAttributes.indexPath];
			}

			// Supplementary views are optional
			if (view) {
				_allVisibleViewsDict[itemKey] = view;
				[self addControlledSubview:view];

                // Always apply attributes. Fixes #203.
                [view applyLayoutAttributes:layoutAttributes];
			}
        }else {
            // just update cell
            [view applyLayoutAttributes:layoutAttributes];
        }
    }

	// Detect what items should be removed and queued back.
    NSMutableSet *allVisibleItemKeys = [NSMutableSet setWithArray:[_allVisibleViewsDict allKeys]];
    [allVisibleItemKeys minusSet:[NSSet setWithArray:[itemKeysToAddDict allKeys]]];

    // Finally remove views that have not been processed and prepare them for re-use.
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
            }
            else if(itemKey.type == PSTCollectionViewItemTypeSupplementaryView) {
                if (_collectionViewFlags.delegateDidEndDisplayingSupplementaryView) {
                    [self.delegate collectionView:self didEndDisplayingSupplementaryView:reusableView forElementOfKind:itemKey.identifier atIndexPath:itemKey.indexPath];
                }
                [self reuseSupplementaryView:reusableView];
            }
            else if(itemKey.type == PSTCollectionViewItemTypeDecorationView) {
                [self reuseDecorationView:reusableView];
            }
        }
    }
 }

// fetches a cell from the dataSource and sets the layoutAttributes
- (PSTCollectionViewCell *)createPreparedCellForItemAtIndexPath:(NSIndexPath *)indexPath withLayoutAttributes:(PSTCollectionViewLayoutAttributes *)layoutAttributes {

    PSTCollectionViewCell *cell = [self.dataSource collectionView:self cellForItemAtIndexPath:indexPath];

    // Apply attributes
    [cell applyLayoutAttributes: layoutAttributes];

    // reset selected/highlight state
    [cell setHighlighted:[_indexPathsForHighlightedItems containsObject:indexPath]];
    [cell setSelected:[_indexPathsForSelectedItems containsObject:indexPath]];

    // voiceover support
    cell.isAccessibilityElement = YES;

    return cell;
}

- (PSTCollectionReusableView *)createPreparedSupplementaryViewForElementOfKind:(NSString *)kind
																   atIndexPath:(NSIndexPath *)indexPath
														  withLayoutAttributes:(PSTCollectionViewLayoutAttributes *)layoutAttributes {
	if (_collectionViewFlags.dataSourceViewForSupplementaryElement) {
		PSTCollectionReusableView *view = [self.dataSource collectionView:self
										viewForSupplementaryElementOfKind:kind
															  atIndexPath:indexPath];
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

// enqueue decoration view for reuse
- (void)reuseDecorationView:(PSTCollectionReusableView *)decorationView {
    [self queueReusableView:decorationView inQueue:_decorationViewReuseQueues];
}

- (void)addControlledSubview:(PSTCollectionReusableView *)subview {
    // avoids placing views above the scroll indicator
	// If the collection view is not displaying scrollIndicators then self.subviews.count can be 0.
	// We take the max to ensure we insert at a non negative index because a negative index will silently fail to insert the view
	NSInteger insertionIndex = MAX((NSInteger)(self.subviews.count - (self.dragging ? 1 : 0)), 0);
    [self insertSubview:subview atIndex:insertionIndex];
    UIView *scrollIndicatorView = nil;
    if (self.dragging) {
        scrollIndicatorView = [self.subviews lastObject];
    }

    NSMutableArray *floatingViews = [[NSMutableArray alloc] init];
    for (UIView *uiView in [self subviews]) {
        if ([uiView isKindOfClass:[PSTCollectionReusableView class]] && [[(PSTCollectionReusableView*)uiView layoutAttributes] zIndex] > 0) {
            [floatingViews addObject:uiView];
        }
    }

    [floatingViews sortUsingComparator:^NSComparisonResult(PSTCollectionReusableView *obj1, PSTCollectionReusableView *obj2) {
        CGFloat z1 = [[obj1 layoutAttributes] zIndex];
        CGFloat z2 = [[obj2 layoutAttributes] zIndex];
        if (z1 > z2) {
            return (NSComparisonResult)NSOrderedDescending;
        } else if (z1 < z2) {
            return (NSComparisonResult)NSOrderedAscending;
        } else {
            return (NSComparisonResult)NSOrderedSame;
        }
    }];

    for (PSTCollectionReusableView *uiView in floatingViews) {
        [self bringSubviewToFront:uiView];
    }

    if (floatingViews.count && scrollIndicatorView) {
        [self bringSubviewToFront:scrollIndicatorView];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Updating grid internal functionality

- (void)suspendReloads {
    _reloadingSuspendedCount++;
}

- (void)resumeReloads {
    if (0 < _reloadingSuspendedCount)
        _reloadingSuspendedCount--;
}

- (NSMutableArray *)arrayForUpdateAction:(PSTCollectionUpdateAction)updateAction {
    NSMutableArray *ret = nil;

    switch (updateAction) {
        case PSTCollectionUpdateActionInsert:
            if (!_insertItems) _insertItems = [[NSMutableArray alloc] init];
            ret = _insertItems;
            break;
        case PSTCollectionUpdateActionDelete:
            if (!_deleteItems) _deleteItems = [[NSMutableArray alloc] init];
            ret = _deleteItems;
            break;
        case PSTCollectionUpdateActionMove:
            if (!_moveItems)      _moveItems = [[NSMutableArray alloc] init];
            ret = _moveItems;
            break;
        case PSTCollectionUpdateActionReload:
            if (!_reloadItems) _reloadItems = [[NSMutableArray alloc] init];
            ret = _reloadItems;
            break;
        default: break;
    }
    return ret;
}

- (void)prepareLayoutForUpdates {
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [array addObjectsFromArray:[_originalDeleteItems sortedArrayUsingSelector:@selector(inverseCompareIndexPaths:)]];
    [array addObjectsFromArray:[_originalInsertItems sortedArrayUsingSelector:@selector(compareIndexPaths:)]];
    [array addObjectsFromArray:[_reloadItems sortedArrayUsingSelector:@selector(compareIndexPaths:)]];
    [array addObjectsFromArray:[_moveItems sortedArrayUsingSelector:@selector(compareIndexPaths:)]];
    [_layout prepareForCollectionViewUpdates:array];
}

- (void)updateWithItems:(NSArray *)items {
    [self prepareLayoutForUpdates];

    NSMutableArray *animations = [[NSMutableArray alloc] init];
    NSMutableDictionary *newAllVisibleView = [[NSMutableDictionary alloc] init];

    NSMutableDictionary *viewsToRemove = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          [NSMutableArray array], @(PSTCollectionViewItemTypeCell),
                                          [NSMutableArray array], @(PSTCollectionViewItemTypeDecorationView),
                                          [NSMutableArray array], @(PSTCollectionViewItemTypeSupplementaryView),nil];
    
    for (PSTCollectionViewUpdateItem *updateItem in items) {
        if (updateItem.isSectionOperation) continue;

        if (updateItem.updateAction == PSTCollectionUpdateActionDelete) {
            NSIndexPath *indexPath = updateItem.indexPathBeforeUpdate;

            PSTCollectionViewLayoutAttributes *finalAttrs = [_layout finalLayoutAttributesForDisappearingItemAtIndexPath:indexPath];
            PSTCollectionViewItemKey *key = [PSTCollectionViewItemKey collectionItemKeyForCellWithIndexPath:indexPath];
            PSTCollectionReusableView *view = _allVisibleViewsDict[key];
            if (view) {
                PSTCollectionViewLayoutAttributes *startAttrs = view.layoutAttributes;

                if (!finalAttrs) {
                    finalAttrs = [startAttrs copy];
                    finalAttrs.alpha = 0;
                }
                [animations addObject:@{@"view": view, @"previousLayoutInfos": startAttrs, @"newLayoutInfos": finalAttrs}];
                
                [_allVisibleViewsDict removeObjectForKey:key];
                
                [viewsToRemove[@(key.type)] addObject:view];
                
            }
            
        }
        else if(updateItem.updateAction == PSTCollectionUpdateActionInsert) {
            NSIndexPath *indexPath = updateItem.indexPathAfterUpdate;
            PSTCollectionViewItemKey *key = [PSTCollectionViewItemKey collectionItemKeyForCellWithIndexPath:indexPath];
            PSTCollectionViewLayoutAttributes *startAttrs = [_layout initialLayoutAttributesForAppearingItemAtIndexPath:indexPath];
            PSTCollectionViewLayoutAttributes *finalAttrs = [_layout layoutAttributesForItemAtIndexPath:indexPath];

            CGRect startRect = startAttrs.frame;
            CGRect finalRect = finalAttrs.frame;

            if(CGRectIntersectsRect(self.visibleBoundRects, startRect) || CGRectIntersectsRect(self.visibleBoundRects, finalRect)) {

                if(!startAttrs){
                    startAttrs = [finalAttrs copy];
                    startAttrs.alpha = 0;
                }

                PSTCollectionReusableView *view = [self createPreparedCellForItemAtIndexPath:indexPath
                                                                        withLayoutAttributes:startAttrs];
                [self addControlledSubview:view];

                newAllVisibleView[key] = view;
                [animations addObject:@{@"view": view, @"previousLayoutInfos": startAttrs, @"newLayoutInfos": finalAttrs}];
            }
        }
        else if(updateItem.updateAction == PSTCollectionUpdateActionMove) {
            NSIndexPath *indexPathBefore = updateItem.indexPathBeforeUpdate;
            NSIndexPath *indexPathAfter = updateItem.indexPathAfterUpdate;

            PSTCollectionViewItemKey *keyBefore = [PSTCollectionViewItemKey collectionItemKeyForCellWithIndexPath:indexPathBefore];
            PSTCollectionViewItemKey *keyAfter = [PSTCollectionViewItemKey collectionItemKeyForCellWithIndexPath:indexPathAfter];
            PSTCollectionReusableView *view = _allVisibleViewsDict[keyBefore];

            PSTCollectionViewLayoutAttributes *startAttrs = nil;
            PSTCollectionViewLayoutAttributes *finalAttrs = [_layout layoutAttributesForItemAtIndexPath:indexPathAfter];

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

    for (PSTCollectionViewItemKey *key in [_allVisibleViewsDict keyEnumerator]) {
        PSTCollectionReusableView *view = _allVisibleViewsDict[key];

        if (key.type == PSTCollectionViewItemTypeCell) {
            NSInteger oldGlobalIndex = [_update[@"oldModel"] globalIndexForItemAtIndexPath:key.indexPath];
            NSArray *oldToNewIndexMap = _update[@"oldToNewIndexMap"];
            NSInteger newGlobalIndex = NSNotFound;
            if (oldGlobalIndex >= 0 && oldGlobalIndex < [oldToNewIndexMap count]) {
                newGlobalIndex = [oldToNewIndexMap[oldGlobalIndex] intValue];
            }
            NSIndexPath *newIndexPath = newGlobalIndex == NSNotFound ? nil : [_update[@"newModel"] indexPathForItemAtGlobalIndex:newGlobalIndex];
            NSIndexPath *oldIndexPath = oldGlobalIndex == NSNotFound ? nil : [_update[@"oldModel"] indexPathForItemAtGlobalIndex:oldGlobalIndex];
            
            if (newIndexPath) {


                PSTCollectionViewLayoutAttributes* startAttrs = nil;
                PSTCollectionViewLayoutAttributes* finalAttrs = nil;
                
                startAttrs  = [_layout initialLayoutAttributesForAppearingItemAtIndexPath:oldIndexPath];
                finalAttrs = [_layout layoutAttributesForItemAtIndexPath:newIndexPath];

                NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:@{@"view":view}];
                if (startAttrs) dic[@"previousLayoutInfos"] = startAttrs;
                if (finalAttrs) dic[@"newLayoutInfos"] = finalAttrs;

                [animations addObject:dic];
                PSTCollectionViewItemKey* newKey = [key copy];
                [newKey setIndexPath:newIndexPath];
                newAllVisibleView[newKey] = view;
                
            }
        } else if (key.type == PSTCollectionViewItemTypeSupplementaryView) {
            PSTCollectionViewLayoutAttributes* startAttrs = nil;
            PSTCollectionViewLayoutAttributes* finalAttrs = nil;

            startAttrs = view.layoutAttributes;
            finalAttrs = [_layout layoutAttributesForSupplementaryViewOfKind:view.layoutAttributes.representedElementKind atIndexPath:key.indexPath];

            NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:@{@"view":view}];
            if (startAttrs) dic[@"previousLayoutInfos"] = startAttrs;
            if (finalAttrs) dic[@"newLayoutInfos"] = finalAttrs;

            [animations addObject:dic];
            PSTCollectionViewItemKey* newKey = [key copy];
            newAllVisibleView[newKey] = view;

        }
    }
    NSArray *allNewlyVisibleItems = [_layout layoutAttributesForElementsInRect:self.visibleBoundRects];
    for (PSTCollectionViewLayoutAttributes *attrs in allNewlyVisibleItems) {
        PSTCollectionViewItemKey *key = [PSTCollectionViewItemKey collectionItemKeyForLayoutAttributes:attrs];

        if (key.type == PSTCollectionViewItemTypeCell && ![[newAllVisibleView allKeys] containsObject:key]) {
            PSTCollectionViewLayoutAttributes* startAttrs =
            [_layout initialLayoutAttributesForAppearingItemAtIndexPath:attrs.indexPath];

            PSTCollectionReusableView *view = [self createPreparedCellForItemAtIndexPath:attrs.indexPath
                                                                    withLayoutAttributes:startAttrs];
            [self addControlledSubview:view];
            newAllVisibleView[key] = view;

            [animations addObject:@{@"view":view, @"previousLayoutInfos": startAttrs?startAttrs:attrs, @"newLayoutInfos": attrs}];
        }
    }

    _allVisibleViewsDict = newAllVisibleView;

    for(NSDictionary *animation in animations) {
        PSTCollectionReusableView *view = animation[@"view"];
        PSTCollectionViewLayoutAttributes *attr = animation[@"previousLayoutInfos"];
        [view applyLayoutAttributes:attr];
    };
    
    
    
    [UIView animateWithDuration:.3 animations:^{
        _collectionViewFlags.updatingLayout = YES;

        [CATransaction begin];
        [CATransaction setAnimationDuration:.3];
        
        // You might wonder why we use CATransaction to handle animation completion
        // here instead of using the completion: parameter of UIView's animateWithDuration:.
        // The problem is that animateWithDuration: calls this completion block
        // when other animations are finished. This means that the block is called
        // after the user releases his finger and the scroll view has finished scrolling.
        // This can be a large delay, which causes the layout of the cells to be greatly
        // delayed, and thus, be unrendered. I assume that was done for performance
        // purposes but it completely breaks our layout logic here.
        // To get the completion block called immediately after the animation actually
        // finishes, I switched to use CATransaction.
        // The only thing I'm not sure about - _completed_ flag. I don't know where to get it
        // in terms of CATransaction's API, so I use animateWithDuration's completion block
        // to call _updateCompletionHandler with that flag.
        // Ideally, _updateCompletionHandler should be called along with the other logic in
        // CATransaction's completionHandler but I simply don't know where to get that flag.
        [CATransaction setCompletionBlock:^{
            // Iterate through all the views that we are going to remove.
            [viewsToRemove enumerateKeysAndObjectsUsingBlock:^(NSNumber *keyObj, NSArray *views, BOOL *stop) {
                PSTCollectionViewItemType type = [keyObj unsignedIntegerValue];
                for (PSTCollectionReusableView *view in views) {
                    if(type == PSTCollectionViewItemTypeCell) {
                        [self reuseCell:(PSTCollectionViewCell *)view];
                    } else if (type == PSTCollectionViewItemTypeSupplementaryView) {
                        [self reuseSupplementaryView:view];
                    } else if (type == PSTCollectionViewItemTypeDecorationView) {
                        [self reuseDecorationView:view];
                    }
                }
            }];
            _collectionViewFlags.updatingLayout = NO;
        }];
        
        for (NSDictionary *animation in animations) {
            PSTCollectionReusableView* view = animation[@"view"];
            PSTCollectionViewLayoutAttributes* attrs = animation[@"newLayoutInfos"];
            [view applyLayoutAttributes:attrs];
        }
        [CATransaction commit];
    } completion:^(BOOL finished) {
        
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
    PSTCollectionViewData *oldCollectionViewData = _collectionViewData;
    _collectionViewData = [[PSTCollectionViewData alloc] initWithCollectionView:self layout:_layout];

    [_layout invalidateLayout];
    [_collectionViewData prepareToLoadData];

    NSMutableArray *someMutableArr1 = [[NSMutableArray alloc] init];

    NSArray *removeUpdateItems = [[self arrayForUpdateAction:PSTCollectionUpdateActionDelete]
                                  sortedArrayUsingSelector:@selector(inverseCompareIndexPaths:)];

    NSArray *insertUpdateItems = [[self arrayForUpdateAction:PSTCollectionUpdateActionInsert]
                                  sortedArrayUsingSelector:@selector(compareIndexPaths:)];

    NSMutableArray *sortedMutableReloadItems = [[_reloadItems sortedArrayUsingSelector:@selector(compareIndexPaths:)] mutableCopy];
    NSMutableArray *sortedMutableMoveItems = [[_moveItems sortedArrayUsingSelector:@selector(compareIndexPaths:)] mutableCopy];

    _originalDeleteItems = [removeUpdateItems copy];
    _originalInsertItems = [insertUpdateItems copy];

    NSMutableArray *someMutableArr2 = [[NSMutableArray alloc] init];
    NSMutableArray *someMutableArr3 =[[NSMutableArray alloc] init];
    NSMutableDictionary *operations = [[NSMutableDictionary alloc] init];

    for(PSTCollectionViewUpdateItem *updateItem in sortedMutableReloadItems) {
        NSAssert(updateItem.indexPathBeforeUpdate.section< [oldCollectionViewData numberOfSections],
                 @"attempt to reload item (%@) that doesn't exist (there are only %d sections before update)",
                 updateItem.indexPathBeforeUpdate, [oldCollectionViewData numberOfSections]);

        NSAssert(updateItem.indexPathBeforeUpdate.item<[oldCollectionViewData numberOfItemsInSection:updateItem.indexPathBeforeUpdate.section],
                 @"attempt to reload item (%@) that doesn't exist (there are only %d items in section %d before update)",
                 updateItem.indexPathBeforeUpdate,
                 [oldCollectionViewData numberOfItemsInSection:updateItem.indexPathBeforeUpdate.section],
                 updateItem.indexPathBeforeUpdate.section);

        [someMutableArr2 addObject:[[PSTCollectionViewUpdateItem alloc] initWithAction:PSTCollectionUpdateActionDelete
                                                                          forIndexPath:updateItem.indexPathBeforeUpdate]];
        [someMutableArr3 addObject:[[PSTCollectionViewUpdateItem alloc] initWithAction:PSTCollectionUpdateActionInsert
                                                                          forIndexPath:updateItem.indexPathAfterUpdate]];
    }

    NSMutableArray *sortedDeletedMutableItems = [[_deleteItems sortedArrayUsingSelector:@selector(inverseCompareIndexPaths:)] mutableCopy];
    NSMutableArray *sortedInsertMutableItems =  [[_insertItems sortedArrayUsingSelector:@selector(compareIndexPaths:)] mutableCopy];

    for(PSTCollectionViewUpdateItem *deleteItem in sortedDeletedMutableItems) {
        if([deleteItem isSectionOperation]) {
            NSAssert(deleteItem.indexPathBeforeUpdate.section<[oldCollectionViewData numberOfSections],
                     @"attempt to delete section (%d) that doesn't exist (there are only %d sections before update)",
                     deleteItem.indexPathBeforeUpdate.section,
                     [oldCollectionViewData numberOfSections]);

            for(PSTCollectionViewUpdateItem *moveItem in sortedMutableMoveItems) {
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

            for(PSTCollectionViewUpdateItem *moveItem in sortedMutableMoveItems) {
                NSAssert(![deleteItem.indexPathBeforeUpdate isEqual:moveItem.indexPathBeforeUpdate],
                         @"attempt to delete and move the same item (%@)", deleteItem.indexPathBeforeUpdate);
            }

            if(!operations[@(deleteItem.indexPathBeforeUpdate.section)])
                operations[@(deleteItem.indexPathBeforeUpdate.section)] = [NSMutableDictionary dictionary];

            operations[@(deleteItem.indexPathBeforeUpdate.section)][@"deleted"] =
            @([operations[@(deleteItem.indexPathBeforeUpdate.section)][@"deleted"] intValue]+1);
        }
    }

    for(NSInteger i=0; i<[sortedInsertMutableItems count]; i++) {
        PSTCollectionViewUpdateItem *insertItem = sortedInsertMutableItems[i];
        NSIndexPath *indexPath = insertItem.indexPathAfterUpdate;

        BOOL sectionOperation = [insertItem isSectionOperation];
        if(sectionOperation) {
            NSAssert([indexPath section]<[_collectionViewData numberOfSections],
                     @"attempt to insert %d but there are only %d sections after update",
                     [indexPath section], [_collectionViewData numberOfSections]);

            for(PSTCollectionViewUpdateItem *moveItem in sortedMutableMoveItems) {
                if([moveItem.indexPathAfterUpdate isEqual:indexPath]) {
                    if(moveItem.isSectionOperation)
                        NSAssert(NO, @"attempt to perform an insert and a move to the same section (%d)",indexPath.section);
                    //                    else
                    //                        NSAssert(NO, @"attempt to perform an insert and a move to the same index path (%@)",indexPath);
                }
            }

            NSInteger j=i+1;
            while(j<[sortedInsertMutableItems count]) {
                PSTCollectionViewUpdateItem *nextInsertItem = sortedInsertMutableItems[j];

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

    for(PSTCollectionViewUpdateItem * sortedItem in sortedMutableMoveItems) {
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
                 @"invalid update in section %d: number of items after update (%d) should be equal to the number of items before update (%d) "\
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

    for(PSTCollectionViewUpdateItem *updateItem in layoutUpdateItems) {
        switch (updateItem.updateAction) {
            case PSTCollectionUpdateActionDelete: {
                if(updateItem.isSectionOperation) {
                    [newModel removeObjectAtIndex:updateItem.indexPathBeforeUpdate.section];
                } else {
                    [(NSMutableArray*)newModel[updateItem.indexPathBeforeUpdate.section]
                     removeObjectAtIndex:updateItem.indexPathBeforeUpdate.item];
                }
            }break;
            case PSTCollectionUpdateActionInsert: {
                if(updateItem.isSectionOperation) {
                    [newModel insertObject:[[NSMutableArray alloc] init]
                                   atIndex:updateItem.indexPathAfterUpdate.section];
                } else {
                    [(NSMutableArray *)newModel[updateItem.indexPathAfterUpdate.section]
                     insertObject:@(NSNotFound)
                     atIndex:updateItem.indexPathAfterUpdate.item];
                }
            }break;

            case PSTCollectionUpdateActionMove: {
                if(updateItem.isSectionOperation) {
                    id section = newModel[updateItem.indexPathBeforeUpdate.section];
                    [newModel insertObject:section atIndex:updateItem.indexPathAfterUpdate.section];
                }
                else {
                    NSUInteger originalIndex = [newModel[updateItem.indexPathBeforeUpdate.section] indexOfObject:@(updateItem.indexPathBeforeUpdate.item)];
                    id object = newModel[updateItem.indexPathBeforeUpdate.section][originalIndex];
                    [newModel[updateItem.indexPathBeforeUpdate.section] removeObjectAtIndex:originalIndex];
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

- (void)updateRowsAtIndexPaths:(NSArray *)indexPaths updateAction:(PSTCollectionUpdateAction)updateAction {
    BOOL updating = _collectionViewFlags.updating;
    if (!updating) [self setupCellAnimations];

    NSMutableArray *array = [self arrayForUpdateAction:updateAction]; //returns appropriate empty array if not exists

    for (NSIndexPath *indexPath in indexPaths) {
        PSTCollectionViewUpdateItem *updateItem = [[PSTCollectionViewUpdateItem alloc] initWithAction:updateAction forIndexPath:indexPath];
        [array addObject:updateItem];
    }

    if(!updating) [self endItemAnimations];
}


- (void)updateSections:(NSIndexSet *)sections updateAction:(PSTCollectionUpdateAction)updateAction {
    BOOL updating = _collectionViewFlags.updating;
    if (!updating) [self setupCellAnimations];

    NSMutableArray *updateActions = [self arrayForUpdateAction:updateAction];
    NSInteger section = [sections firstIndex];

    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        PSTCollectionViewUpdateItem *updateItem =
        [[PSTCollectionViewUpdateItem alloc] initWithAction:updateAction
                                               forIndexPath:[NSIndexPath indexPathForItem:NSNotFound
                                                                                inSection:section]];
        [updateActions addObject:updateItem];
    }];

    if (!updating) [self endItemAnimations];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSTCollection/UICollection interoperability

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
        // Dynamically change superclasses of the PSUICollectionView* classes to UICollectionView*. Crazy stuff.
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
