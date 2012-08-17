//
//  PSCollectionViewFlowLayout.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSCollectionViewFlowLayout.h"
#import "PSCollectionView.h"
#import "PSGridLayoutItem.h"
#import "PSGridLayoutInfo.h"
#import "PSGridLayoutRow.h"
#import "PSGridLayoutSection.h"

NSString *const PSCollectionElementKindSectionHeader = @"UICollectionElementKindSectionHeader";
NSString *const PSCollectionElementKindSectionFooter = @"UICollectionElementKindSectionFooter";

// this is not exposed in UICollectionViewFlowLayout
NSString *const PSFlowLayoutCommonRowHorizontalAlignmentKey = @"UIFlowLayoutCommonRowHorizontalAlignmentKey";
NSString *const PSFlowLayoutLastRowHorizontalAlignmentKey = @"UIFlowLayoutLastRowHorizontalAlignmentKey";
NSString *const PSFlowLayoutRowVerticalAlignmentKey = @"UIFlowLayoutRowVerticalAlignmentKey";


@interface PSCollectionViewFlowLayout() {
    struct {
        unsigned int delegateSizeForItem:1;
        unsigned int delegateReferenceSizeForHeader:1;
        unsigned int delegateReferenceSizeForFooter:1;
        unsigned int delegateInsetForSection:1;
        unsigned int delegateInteritemSpacingForSection:1;
        unsigned int delegateLineSpacingForSection:1;
        unsigned int delegateAlignmentOptions:1;

        unsigned int keepDelegateInfoWhileInvalidating:1;
        unsigned int keepAllDataWhileInvalidating:1;
        unsigned int layoutDataIsValid:1;
        unsigned int delegateInfoIsValid:1;
    } _gridLayoutFlags;

    CGFloat _interitemSpacing;
    CGFloat _lineSpacing;

    PSGridLayoutInfo *_data;
    id _snapshottedData; // ???

    CGSize _currentLayoutSize;
    /*
     NSMutableDictionary* _insertedItemsAttributesDict;
     NSMutableDictionary* _insertedSectionHeadersAttributesDict;
     NSMutableDictionary* _insertedSectionFootersAttributesDict;
     NSMutableDictionary* _deletedItemsAttributesDict;
     NSMutableDictionary* _deletedSectionHeadersAttributesDict;
     NSMutableDictionary* _deletedSectionFootersAttributesDict;
     */
    NSDictionary *_rowAlignmentsOptionsDictionary;
    CGRect _visibleBounds;

    // @steipete cache
    NSArray *_cachedItemRects;
}

@end

@implementation PSCollectionViewFlowLayout

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)init {
#ifdef kPSCollectionViewRelayToUICollectionViewIfAvailable
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_6_0) {
        self = (PSCollectionViewFlowLayout *)[[UICollectionViewFlowLayout alloc] init];
        return self;
    }
#endif

    if((self = [super init])) {
        _itemSize = CGSizeMake(10, 10);
        _scrollDirection = PSCollectionViewScrollDirectionVertical;

        // set default values for row alignment.
        _rowAlignmentsOptionsDictionary = @{
        PSFlowLayoutCommonRowHorizontalAlignmentKey : @(PSFlowLayoutHorizontalAlignmentJustify),
        PSFlowLayoutLastRowHorizontalAlignmentKey : @(PSFlowLayoutHorizontalAlignmentLeft),
        // TODO: those values are some enum. find out what what is.
        PSFlowLayoutRowVerticalAlignmentKey : @(1),
        };
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSCollectionViewLayout

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    // Apple calls _layoutAttributesForItemsInRect

    NSMutableArray *layoutAttributesArray = [NSMutableArray array];
    for (PSGridLayoutSection *section in _data.sections) {
        if (CGRectIntersectsRect(section.frame, rect)) {

            // if we have fixed size, calculate item frames only once.
            // this also uses the default PSFlowLayoutCommonRowHorizontalAlignmentKey alignment
            // for the last row. (we want this effect!)
            NSArray *itemRects = _cachedItemRects;
            if (!_cachedItemRects && section.fixedItemSize && [section.rows count]) {
                itemRects = _cachedItemRects = [[section.rows objectAtIndex:0] itemRects];
            }

            for (PSGridLayoutRow *row in section.rows) {
                CGRect normalizedRowFrame = row.rowFrame;
                normalizedRowFrame.origin.x += section.frame.origin.x;
                normalizedRowFrame.origin.y += section.frame.origin.y;
                if (CGRectIntersectsRect(normalizedRowFrame, rect)) {
                    // TODO be more fine-graind for items

                    for (NSUInteger itemIndex = 0; itemIndex < row.itemCount; itemIndex++) {
                        PSCollectionViewLayoutAttributes *layoutAttributes;
                        NSUInteger sectionIndex = [section.layoutInfo.sections indexOfObject:section];
                        NSUInteger sectionItemIndex;
                        CGRect itemFrame;
                        if (row.fixedItemSize) {
                            itemFrame = [itemRects[itemIndex] CGRectValue];
                            sectionItemIndex = row.index * section.itemsByRowCount + itemIndex;
                        }else {
                            PSGridLayoutItem *item = row.items[itemIndex];
                            sectionItemIndex = [section.items indexOfObject:item];
                            itemFrame = item.itemFrame;
                        }
                        layoutAttributes = [PSCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:[NSIndexPath indexPathForItem:sectionItemIndex inSection:sectionIndex]];
                        layoutAttributes.frame = CGRectMake(normalizedRowFrame.origin.x + itemFrame.origin.x, normalizedRowFrame.origin.y + itemFrame.origin.y, itemFrame.size.width, itemFrame.size.height);
                        [layoutAttributesArray addObject:layoutAttributes];
                    }
                }
            }
        }
    }
    return layoutAttributesArray;
}

- (PSCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    // TODO: check if index path is valid?
    PSGridLayoutSection *section = _data.sections[indexPath.section];
    PSGridLayoutRow *row = nil;
    CGRect itemFrame;
    if (section.fixedItemSize) {
        row = section.rows[indexPath.item/section.itemsByRowCount];
        NSUInteger itemIndex = indexPath.item % section.itemsByRowCount;
        NSArray *itemRects = [row itemRects];
        itemFrame = [itemRects[itemIndex] CGRectValue];
    }else {
        PSGridLayoutItem *item = section.items[indexPath.item];
        row = item.rowObject;
        itemFrame = item.itemFrame;
    }

    PSCollectionViewLayoutAttributes *layoutAttributes = [PSCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];

    // calculate item rect
    CGRect normalizedRowFrame = row.rowFrame;
    normalizedRowFrame.origin.x += section.frame.origin.x;
    normalizedRowFrame.origin.y += section.frame.origin.y;
    layoutAttributes.frame = CGRectMake(normalizedRowFrame.origin.x + itemFrame.origin.x, normalizedRowFrame.origin.y + itemFrame.origin.y, itemFrame.size.width, itemFrame.size.height);

    return layoutAttributes;
}

- (PSCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (PSCollectionViewLayoutAttributes *)layoutAttributesForDecorationViewWithReuseIdentifier:(NSString*)identifier atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (CGSize)collectionViewContentSize {
    //    return _currentLayoutSize;
    return _data.contentSize;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Invalidating the Layout

- (void)invalidateLayout {
    _cachedItemRects = nil;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    // we need to recalculate on width changes
    if ((self.collectionView.bounds.size.width != newBounds.size.width && self.scrollDirection == PSCollectionViewScrollDirectionHorizontal) || (self.collectionView.bounds.size.height != newBounds.size.height && self.scrollDirection == PSCollectionViewScrollDirectionVertical)) {
        return YES;
    }
    return NO;
}

// return a point at which to rest after scrolling - for layouts that want snap-to-point scrolling behavior
- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset withScrollingVelocity:(CGPoint)velocity {
    return proposedContentOffset;
}

- (void)prepareLayout {
    _data = [PSGridLayoutInfo new]; // clear old layout data
    _data.horizontal = self.scrollDirection == PSCollectionViewScrollDirectionHorizontal;
    CGSize collectionViewSize = self.collectionView.bounds.size;
    _data.dimension = _data.horizontal ? collectionViewSize.height : collectionViewSize.width;
    _data.rowAlignmentOptions = _rowAlignmentsOptionsDictionary;
    [self fetchItemsInfo];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (void)fetchItemsInfo {
    [self getSizingInfos];
    [self updateItemsLayout];
}

// get size of all items (if delegate is implemented)
- (void)getSizingInfos {
    NSAssert([_data.sections count] == 0, @"Grid layout is already populated?");

    id <PSCollectionViewDelegateFlowLayout> flowDataSource = (id <PSCollectionViewDelegateFlowLayout>)self.collectionView.dataSource;

    BOOL implementsSizeDelegate = [flowDataSource respondsToSelector:@selector(collectionView:layout:sizeForItemAtIndexPath:)];

    NSUInteger numberOfSections = [self.collectionView numberOfSections];
    for (NSUInteger section = 0; section < numberOfSections; section++) {
        PSGridLayoutSection *layoutSection = [_data addSection];
        layoutSection.verticalInterstice = _data.horizontal ? self.minimumInteritemSpacing : self.minimumLineSpacing;
        layoutSection.horizontalInterstice = !_data.horizontal ? self.minimumInteritemSpacing : self.minimumLineSpacing;
        layoutSection.sectionMargins = self.sectionInset;

        if ([flowDataSource respondsToSelector:@selector(collectionView:layout:minimumLineSpacingForSectionAtIndex:)]) {
            CGFloat minimumLineSpacing = [flowDataSource collectionView:self.collectionView layout:self minimumLineSpacingForSectionAtIndex:section];
            if (_data.horizontal) {
                layoutSection.horizontalInterstice = minimumLineSpacing;
            }else {
                layoutSection.verticalInterstice = minimumLineSpacing;
            }
        }

        if ([flowDataSource respondsToSelector:@selector(collectionView:layout:minimumInteritemSpacingForSectionAtIndex:)]) {
            CGFloat minimumInterimSpacing = [flowDataSource collectionView:self.collectionView layout:self minimumInteritemSpacingForSectionAtIndex:section];
            if (_data.horizontal) {
                layoutSection.verticalInterstice = minimumInterimSpacing;
            }else {
                layoutSection.horizontalInterstice = minimumInterimSpacing;
            }
        }

        NSUInteger numberOfItems = [self.collectionView numberOfItemsInSection:section];

        // if delegate implements size delegate, query it for all items
        if (implementsSizeDelegate) {
            for (NSUInteger item = 0; item < numberOfItems; item++) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
                CGSize itemSize = implementsSizeDelegate ? [flowDataSource collectionView:self.collectionView layout:self sizeForItemAtIndexPath:indexPath] : self.itemSize;

                PSGridLayoutItem *layoutItem = [layoutSection addItem];
                layoutItem.itemFrame = (CGRect){.size=itemSize};
            }
            // if not, go the fast path
        }else {
            layoutSection.fixedItemSize = YES;
            layoutSection.itemSize = self.itemSize;
            layoutSection.itemsCount = numberOfItems;
        }
    }
}

- (void)updateItemsLayout {
    CGSize contentSize = CGSizeZero;
    for (PSGridLayoutSection *section in _data.sections) {
        [section computeLayout];

        // update section offset to make frame absolute (section only calculates relative)
        CGRect sectionFrame = section.frame;
        if (_data.horizontal) {
            sectionFrame.origin.x += contentSize.width;
            contentSize.width += section.frame.size.width + section.frame.origin.x;
            contentSize.height = fmaxf(contentSize.height, sectionFrame.size.height + section.frame.origin.y);
        }else {
            sectionFrame.origin.y += contentSize.height;
            contentSize.height += sectionFrame.size.height + section.frame.origin.y;
            contentSize.width = fmaxf(contentSize.width, sectionFrame.size.width + section.frame.origin.x);
        }
        section.frame = sectionFrame;
    }
    _data.contentSize = contentSize;
}

@end