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
    PSCollectionViewData *_collectionViewData;

    NSUInteger _reloadingSuspendedCount;
    NSMutableSet *_indexPathsForSelectedItems;
}
@end

@implementation PSCollectionView

//static void *kPSKVOToken;

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame collectionViewLayout:(PSCollectionViewLayout *)layout {
    if ((self = [super initWithFrame:frame])) {
        // UICollectionViewCommonSetup
        layout.collectionView = self;
        _collectionViewLayout = layout;
        _indexPathsForSelectedItems = [NSMutableSet new];
        _cellReuseQueues = [NSMutableDictionary new];
        _supplementaryViewReuseQueues = [NSMutableDictionary new];
        _allVisibleViewsDict = [NSMutableDictionary new];
        _cellClassDict = [NSMutableDictionary new];
        _collectionViewData = [[PSCollectionViewData alloc] initWithCollectionView:self layout:layout];
    }
    return self;
}

- (void)dealloc {
}

/*
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == kPSKVOToken) {
        NSLog(@"scroll: %@", NSStringFromCGPoint(self.contentOffset));
    }else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}*/

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ collection view layout: %@", [super description], self.collectionViewLayout];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

- (void)layoutSubviews {
    [super layoutSubviews];

    // TODO: don't always call
    [_collectionViewData validateLayoutInRect:self.bounds];

    // update cells
    [self updateVisibleCellsNow:YES];

    // do we need to update contentSize?
    CGSize contentSize = [_collectionViewData collectionViewContentRect].size;
    if (!CGSizeEqualToSize(self.contentSize, contentSize)) {
        self.contentSize = contentSize;
    }

    /*
    if (_rotationActive) {
        // Adding alpha animation to make the relayouting smooth
        CATransition *transition = [CATransition animation];
        transition.duration = 0.25f;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionFade;
        [self.layer addAnimation:transition forKey:@"rotationAnimation"];
    }*/

/*
    [self applyWithoutAnimation:^{
        [self relayoutItems];
        [self loadRequiredItems];
    }];
 */

    _backgroundView.frame = (CGRect){.size=self.contentSize};
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)registerClass:(Class)cellClass forCellWithReuseIdentifier:(NSString *)identifier {
    NSParameterAssert(cellClass);
    NSParameterAssert(identifier);
    _cellClassDict[identifier] = cellClass;
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
        cell = [cellClass new];
        cell.collectionView = self;
        cell.reuseIdentifier = identifier;
    }
    return cell;
}

- (id)dequeueReusableSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath {
    // TODO
    // _supplementaryViewReuseQueues
    return nil;
}

- (NSArray *)visibleCells {
    return [_allVisibleViewsDict allValues];
}

- (void)reloadData {
    if (_reloadingSuspendedCount != 0) return;
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
    return nil;
}

- (NSIndexPath *)indexPathForCell:(PSCollectionViewCell *)cell {
    return nil;
}

- (PSCollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    /*
    [_allVisibleViewsDict enumerateKeysAndObjectsWithOptions:0 usingBlock:^(id key, id obj, BOOL *stop) {
        PSCollectionViewItemKey *itemKey = (PSCollectionViewItemKey *)key;
        if (itemKey.type == PSCollectionViewItemTypeCell) {
        }
    }*/

    NSInteger index = [_collectionViewData globalIndexForItemAtIndexPath:indexPath];
    // TODO ????
    return nil;
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

    // found a cell?
    CGPoint touchPoint = [[touches anyObject] locationInView:self];
    [_allVisibleViewsDict enumerateKeysAndObjectsWithOptions:0 usingBlock:^(id key, id obj, BOOL *stop) {
        PSCollectionViewItemKey *itemKey = (PSCollectionViewItemKey *)key;
        if (itemKey.type == PSCollectionViewItemTypeCell) {
            PSCollectionViewCell *cell = (PSCollectionViewCell *)obj;
            if (CGRectContainsPoint(cell.frame, touchPoint)) {
                [self userSelectedItemAtIndexPath:itemKey.indexPath];
                *stop = YES;
            }
        }
    }];
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
    return nil;
}
- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(PSCollectionViewScrollPosition)scrollPosition {
    if (!self.allowsMultipleSelection) {
        [_indexPathsForSelectedItems removeAllObjects];
    }
    if (self.allowsSelection) {
        [_indexPathsForSelectedItems addObject:indexPath];
    }
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {
    if ([_indexPathsForSelectedItems containsObject:indexPath]) {
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
        [self addSubview:backgroundView];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (void)invalidateLayout {
    // TODO
}

// update currently visible cells, fetches new cells if needed
// TODO: use now parameter.
- (void)updateVisibleCellsNow:(BOOL)now {
    NSArray *layoutAttributesArray = [_collectionViewData layoutAttributesForElementsInRect:self.bounds];

    NSMutableArray *allVisibleItemKeys = [[_allVisibleViewsDict allKeys] mutableCopy];
    for (PSCollectionViewLayoutAttributes *layoutAttributes in layoutAttributesArray) {
        PSCollectionViewItemKey *itemKey = [PSCollectionViewItemKey collectionItemKeyForLayoutAttributes:layoutAttributes];
        // check if cell is in visible dict; add it if not.
        PSCollectionViewCell *cell = _allVisibleViewsDict[itemKey];
        if (!cell) {
            PSCollectionViewCell *cell = [self _createPreparedCellForItemAtIndexPath:layoutAttributes.indexPath withLayoutAttributes:layoutAttributes];
            _allVisibleViewsDict[itemKey] = cell;
            [self addControlledSubview:cell];
        }

        // remove from current dict
        [allVisibleItemKeys removeObject:itemKey];
    }

    // remove views that have not been processed and prepare them for re-use.
    for (PSCollectionViewItemKey *itemKey in allVisibleItemKeys) {
        PSCollectionReusableView *reusableView = _allVisibleViewsDict[itemKey];
        if (reusableView) {
            [reusableView removeFromSuperview];
            [_allVisibleViewsDict removeObjectForKey:itemKey];
            if (itemKey.type == PSCollectionViewItemTypeCell) {
                [self reuseCell:(PSCollectionViewCell *)reusableView];
            }else if(itemKey.type == PSCollectionViewItemTypeSupplementaryView) {
                [self reuseSupplementaryView:reusableView];
            }
            // TODO: decoration views etc?
        }
    }
}

// fetches a cell from the dataSource and sets the layoutAttributes
- (PSCollectionViewCell *)_createPreparedCellForItemAtIndexPath:(NSIndexPath *)indexPath withLayoutAttributes:(PSCollectionViewLayoutAttributes *)layoutAttributes {
    
    PSCollectionViewCell *cell = [self.dataSource collectionView:self cellForItemAtIndexPath:indexPath];
    [cell applyLayoutAttributes:layoutAttributes];
    return cell;
}


// @steipete optimization
- (void)queueReusableView:(PSCollectionReusableView *)reusableView inQueue:(NSMutableDictionary *)queue {
    NSString *cellIdentifier = reusableView.reuseIdentifier;
    NSParameterAssert([cellIdentifier length]);

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
            IMP underscoreIMP = imp_implementationWithBlock(^(id _self) {
                return objc_msgSend(_self, cleanedSelector);
            });
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

@implementation NSIndexPath (PSCollectionViewAdditions)

+ (NSIndexPath *)indexPathForItem:(NSInteger)item inSection:(NSInteger)section {
    return [NSIndexPath indexPathForRow:item inSection:section];
}

- (NSInteger)item {
    return self.row;
}

@end
