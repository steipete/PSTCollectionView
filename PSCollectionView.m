//
//  PSCollectionView.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSCollectionView.h"
#import "PSCollectionViewData.h"
#import "PSCollectionViewCell.h"
#import "PSCollectionViewLayout.h"
#import "PSCollectionViewFlowLayout.h"
#import "PSCollectionViewItemKey.h"
#import <QuartzCore/QuartzCore.h>

@interface PSCollectionViewLayout (Internal)
@property (nonatomic, unsafe_unretained) PSCollectionView *collectionView;
@end

@interface PSCollectionView() {
    BOOL _rotationActive;
    NSMutableDictionary *_allVisibleViewsDict;
    NSMutableDictionary *_cellReuseQueues;
    NSMutableDictionary *_supplementaryViewReuseQueues;

    NSMutableDictionary *_cellClassDict;
    NSMutableDictionary *_supplementaryViewClassDict;

    NSUInteger _reloadingSuspendedCount;
    NSMutableSet *_indexPathsForSelectedItems;

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
@property (nonatomic, strong) PSCollectionViewData *collectionViewData;
@end

@implementation PSCollectionView

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame collectionViewLayout:(PSCollectionViewLayout *)layout {
#ifdef kPSCollectionViewRelayToUICollectionViewIfAvailable
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_6_0) {
        self = (PSCollectionView *)[[UICollectionView alloc] initWithFrame:frame collectionViewLayout:(UICollectionViewLayout *)layout];
        return self;
    }
#endif

    if ((self = [super initWithFrame:frame])) {
        // UICollectionViewCommonSetup
        layout.collectionView = self;
        _collectionViewLayout = layout;
        _indexPathsForSelectedItems = [NSMutableSet new];
        _cellReuseQueues = [NSMutableDictionary new];
        _supplementaryViewReuseQueues = [NSMutableDictionary new];
        _allVisibleViewsDict = [NSMutableDictionary new];
        _cellClassDict = [NSMutableDictionary new];
        _supplementaryViewClassDict = [NSMutableDictionary new];
        _collectionViewData = [[PSCollectionViewData alloc] initWithCollectionView:self layout:layout];
        _allowsSelection = YES;
    }
    return self;
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
        transition.duration = 0.25f;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionFade;
        [self.layer addAnimation:transition forKey:@"rotationAnimation"];
        _collectionViewFlags.fadeCellsForBoundsChange = NO;
    }

    // TODO: don't always call
    [_collectionViewData validateLayoutInRect:self.bounds];

    // update cells
    [self updateVisibleCellsNow:YES];

    // do we need to update contentSize?
    CGSize contentSize = [_collectionViewData collectionViewContentRect].size;
    if (!CGSizeEqualToSize(self.contentSize, contentSize)) {
        self.contentSize = contentSize;
    }

    _backgroundView.frame = (CGRect){.size=self.bounds.size};
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

- (id)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath {
    // dequeue cell (if available)
    NSMutableArray *reusableCells = _cellReuseQueues[identifier];
    PSCollectionViewCell *cell = [reusableCells lastObject];
    if (cell) {
        [reusableCells removeObjectAtIndex:[reusableCells count]-1];
    }else {
        Class cellClass = _cellClassDict[identifier];
        // compatiblity layer
        if ([cellClass isEqual:[UICollectionViewCell class]]) {
            cellClass = [PSCollectionViewCell class];
        }
        if (cellClass == nil) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Class not registered for identifier %@", identifier] userInfo:nil];
        }
        if (self.collectionViewLayout) {
            PSCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
            cell = [[cellClass alloc] initWithFrame:attributes.frame];
        } else {
            cell = [cellClass new];
        }
        cell.collectionView = self;
        cell.reuseIdentifier = identifier;
    }
    return cell;
}

- (id)dequeueReusableSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *reusableViews = _supplementaryViewReuseQueues[identifier];
    PSCollectionReusableView *view = [reusableViews lastObject];
    if (view) {
        [reusableViews removeObjectAtIndex:reusableViews.count - 1];
    } else {
        Class viewClass = _supplementaryViewClassDict[identifier];
        if ([viewClass isEqual:[UICollectionReusableView class]]) {
            viewClass = [PSCollectionReusableView class];
        }
        if (viewClass == nil) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Class not registered for identifier %@", identifier] userInfo:nil];
        }
        if (self.collectionViewLayout) {
            PSCollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForSupplementaryViewOfKind:elementKind
                                                                                                                     atIndexPath:indexPath];
            view = [[viewClass alloc] initWithFrame:attributes.frame];
        } else {
            view = [viewClass new];
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

- (PSCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (PSCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point {
    __block NSIndexPath *indexPath = nil;
    [_allVisibleViewsDict enumerateKeysAndObjectsWithOptions:kNilOptions usingBlock:^(id key, id obj, BOOL *stop) {
        PSCollectionViewItemKey *itemKey = (PSCollectionViewItemKey *)key;
        if (itemKey.type == PSCollectionViewItemTypeCell) {
            PSCollectionViewCell *cell = (PSCollectionViewCell *)obj;
            if (CGRectContainsPoint(cell.frame, point)) {
                indexPath = itemKey.indexPath;
                *stop = YES;
            }
        }
    }];
    return indexPath;
}

- (NSIndexPath *)indexPathForCell:(PSCollectionViewCell *)cell {
    __block NSIndexPath *indexPath = nil;
    [_allVisibleViewsDict enumerateKeysAndObjectsWithOptions:kNilOptions usingBlock:^(id key, id obj, BOOL *stop) {
        PSCollectionViewItemKey *itemKey = (PSCollectionViewItemKey *)key;
        if (itemKey.type == PSCollectionViewItemTypeCell) {
            PSCollectionViewCell *currentCell = (PSCollectionViewCell *)obj;
            if (currentCell == cell) {
                indexPath = itemKey.indexPath;
                *stop = YES;
            }
        }
    }];
    return indexPath;
}

- (PSCollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    //NSInteger index = [_collectionViewData globalIndexForItemAtIndexPath:indexPath];
    // TODO Apple uses some kind of globalIndex for this.
    __block PSCollectionViewCell *cell = nil;
    [_allVisibleViewsDict enumerateKeysAndObjectsWithOptions:0 usingBlock:^(id key, id obj, BOOL *stop) {
        PSCollectionViewItemKey *itemKey = (PSCollectionViewItemKey *)key;
        if (itemKey.type == PSCollectionViewItemTypeCell) {
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
    for (PSCollectionViewCell *cell in [self visibleCells]) {
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
- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(PSCollectionViewScrollPosition)scrollPosition animated:(BOOL)animated {

}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Touch Handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];

    // TODO: highlighting
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];

    CGPoint touchPoint = [[touches anyObject] locationInView:self];
    NSIndexPath *indexPath = [self indexPathForItemAtPoint:touchPoint];
    if (indexPath) {
        [self userSelectedItemAtIndexPath:indexPath];
    }
}

- (void)userSelectedItemAtIndexPath:(NSIndexPath *)indexPath {
    [self selectItemAtIndexPath:indexPath animated:YES scrollPosition:PSCollectionViewScrollPositionNone notifyDelegate:YES];
}

// select item, notify delegate (internal)
- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(PSCollectionViewScrollPosition)scrollPosition notifyDelegate:(BOOL)notifyDelegate {

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
}

// returns nil or an array of selected index paths
- (NSArray *)indexPathsForSelectedItems {
    return [_indexPathsForSelectedItems allObjects];
}

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(PSCollectionViewScrollPosition)scrollPosition {
    if (!self.allowsMultipleSelection) {
        for (NSIndexPath *indexPath in _indexPathsForSelectedItems) {
            [self deselectItemAtIndexPath:indexPath animated:animated];
        }
    }
    if (self.allowsSelection) {
        PSCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:indexPath];
        selectedCell.selected = YES;
        [_indexPathsForSelectedItems addObject:indexPath];
    }
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {
    if ([_indexPathsForSelectedItems containsObject:indexPath]) {
        PSCollectionViewCell *selectedCell = [self cellForItemAtIndexPath:indexPath];
        selectedCell.selected = NO;
        [_indexPathsForSelectedItems removeObject:indexPath];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Update Grid

- (void)setCollectionViewLayout:(PSCollectionViewLayout *)layout animated:(BOOL)animated {
    if (layout != _collectionViewLayout) {
        _collectionViewLayout = layout;
        [self reloadData];
    }
}

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
    for (PSCollectionViewLayoutAttributes *layoutAttributes in layoutAttributesArray) {
        PSCollectionViewItemKey *itemKey = [PSCollectionViewItemKey collectionItemKeyForLayoutAttributes:layoutAttributes];
        itemKeysToAddDict[itemKey] = layoutAttributes;
    }

    // detect what items should be removed and queued back.
    NSMutableSet *allVisibleItemKeys = [NSMutableSet setWithArray:[_allVisibleViewsDict allKeys]];
    [allVisibleItemKeys minusSet:[NSSet setWithArray:[itemKeysToAddDict allKeys]]];

    // remove views that have not been processed and prepare them for re-use.
    for (PSCollectionViewItemKey *itemKey in allVisibleItemKeys) {
        PSCollectionReusableView *reusableView = _allVisibleViewsDict[itemKey];
        if (reusableView) {
            [reusableView removeFromSuperview];
            [_allVisibleViewsDict removeObjectForKey:itemKey];
            if (itemKey.type == PSCollectionViewItemTypeCell) {
                if ([self.delegate respondsToSelector:@selector(collectionView:didEndDisplayingCell:forItemAtIndexPath:)]) {
                    [self.delegate collectionView:self didEndDisplayingCell:(PSCollectionViewCell *)reusableView forItemAtIndexPath:itemKey.indexPath];
                }
                [self reuseCell:(PSCollectionViewCell *)reusableView];
            }else if(itemKey.type == PSCollectionViewItemTypeSupplementaryView) {
                if ([self.delegate respondsToSelector:@selector(collectionView:didEndDisplayingSupplementaryView:forElementOfKind:atIndexPath:)]) {
                    [self.delegate collectionView:self didEndDisplayingSupplementaryView:reusableView forElementOfKind:itemKey.identifier atIndexPath:itemKey.indexPath];
                }
                [self reuseSupplementaryView:reusableView];
            }
            // TODO: decoration views etc?
        }
    }

    // finally add new cells.
    [itemKeysToAddDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {PSCollectionViewItemKey *itemKey = key;
        PSCollectionViewLayoutAttributes *layoutAttributes = obj;

        // check if cell is in visible dict; add it if not.
        PSCollectionReusableView *view = _allVisibleViewsDict[itemKey];
        if (!view) {
            if (itemKey.type == PSCollectionViewItemTypeCell) {
                view = [self _createPreparedCellForItemAtIndexPath:itemKey.indexPath withLayoutAttributes:layoutAttributes];

            } else if (itemKey.type == PSCollectionViewItemTypeSupplementaryView) {
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
- (PSCollectionViewCell *)_createPreparedCellForItemAtIndexPath:(NSIndexPath *)indexPath withLayoutAttributes:(PSCollectionViewLayoutAttributes *)layoutAttributes {

    PSCollectionViewCell *cell = [self.dataSource collectionView:self cellForItemAtIndexPath:indexPath];
    [cell applyLayoutAttributes:layoutAttributes];
    return cell;
}

- (PSCollectionReusableView *)_createPreparedSupplementaryViewForElementOfKind:(NSString *)kind
                                                                   atIndexPath:(NSIndexPath *)indexPath
                                                          withLayoutAttributes:(PSCollectionViewLayoutAttributes *)layoutAttributes
{
    PSCollectionReusableView *view = [self.dataSource collectionView:self
                                   viewForSupplementaryElementOfKind:kind
                                                         atIndexPath:indexPath];
    [view applyLayoutAttributes:layoutAttributes];
    return view;
}


// @steipete optimization
- (void)queueReusableView:(PSCollectionReusableView *)reusableView inQueue:(NSMutableDictionary *)queue {
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
- (void)reuseCell:(PSCollectionViewCell *)cell {
    [self queueReusableView:cell inQueue:_cellReuseQueues];
}

// enqueue supplementary view for reuse
- (void)reuseSupplementaryView:(PSCollectionReusableView *)supplementaryView {
    [self queueReusableView:supplementaryView inQueue:_supplementaryViewReuseQueues];
}

- (void)addControlledSubview:(PSCollectionReusableView *)subview {
    [self addSubview:subview];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSCollection/UICollection interoperability

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
@implementation NSIndexPath (PSCollectionViewAdditions)

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

// Create subclasses that pose as UICollectionView et al, if not available at runtime.
__attribute__((constructor)) static void PSCreateUICollectionViewClasses(void) {
    @autoreleasepool {
        if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_6_0) {
            objc_registerClassPair(objc_allocateClassPair([PSCollectionView class], "UICollectionView", 0));
            objc_registerClassPair(objc_allocateClassPair([PSCollectionViewCell class], "UICollectionViewCell", 0));
            objc_registerClassPair(objc_allocateClassPair([PSCollectionViewLayout class], "UICollectionViewLayout", 0));
            objc_registerClassPair(objc_allocateClassPair([PSCollectionViewFlowLayout class], "UICollectionViewFlowLayout", 0));
        }
    }
}
