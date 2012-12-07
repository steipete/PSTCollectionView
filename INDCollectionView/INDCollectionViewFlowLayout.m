//
//  INDCollectionViewFlowLayout.m
//
//  Original Source: Copyright (c) 2012 Peter Steinberger. All rights reserved.
//  AppKit Port: Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import "INDCollectionViewFlowLayout.h"
#import "INDCollectionView.h"
#import "INDGridLayoutItem.h"
#import "INDGridLayoutInfo.h"
#import "INDGridLayoutRow.h"
#import "INDGridLayoutSection.h"
#import "INDGeometryAdditions.h"
#import "NSIndexPath+INDCollectionViewAdditions.h"
#import "NSValue+INDCollectionViewAdditions.h"
#import <objc/runtime.h>

NSString *const INDCollectionElementKindSectionHeader = @"INDCollectionElementKindSectionHeader";
NSString *const INDCollectionElementKindSectionFooter = @"INDCollectionElementKindSectionFooter";

// this is not exposed in UICollectionViewFlowLayout
NSString *const INDFlowLayoutCommonRowHorizontalAlignmentKey = @"INDFlowLayoutCommonRowHorizontalAlignmentKey";
NSString *const INDFlowLayoutLastRowHorizontalAlignmentKey = @"INDFlowLayoutLastRowHorizontalAlignmentKey";
NSString *const INDFlowLayoutRowVerticalAlignmentKey = @"INDFlowLayoutRowVerticalAlignmentKey";

@implementation INDCollectionViewFlowLayout {
    // class needs to have same iVar layout as UICollectionViewLayout
    struct {
        unsigned int delegateSizeForItem : 1;
        unsigned int delegateReferenceSizeForHeader : 1;
        unsigned int delegateReferenceSizeForFooter : 1;
        unsigned int delegateInsetForSection : 1;
        unsigned int delegateInteritemSpacingForSection : 1;
        unsigned int delegateLineSpacingForSection : 1;
        unsigned int delegateAlignmentOptions : 1;
        unsigned int keepDelegateInfoWhileInvalidating : 1;
        unsigned int keepAllDataWhileInvalidating : 1;
        unsigned int layoutDataIsValid : 1;
        unsigned int delegateInfoIsValid : 1;
    } _gridLayoutFlags;
    CGFloat _interitemSpacing;
    CGFloat _lineSpacing;
    CGSize _itemSize;
    CGSize _headerReferenceSize;
    CGSize _footerReferenceSize;
    INDEdgeInsets _sectionInset;
    INDGridLayoutInfo *_data;
    CGSize _currentLayoutSize;
    NSMutableDictionary *_insertedItemsAttributesDict;
    NSMutableDictionary *_insertedSectionHeadersAttributesDict;
    NSMutableDictionary *_insertedSectionFootersAttributesDict;
    NSMutableDictionary *_deletedItemsAttributesDict;
    NSMutableDictionary *_deletedSectionHeadersAttributesDict;
    NSMutableDictionary *_deletedSectionFootersAttributesDict;
    INDCollectionViewScrollDirection _scrollDirection;
    NSDictionary *_rowAlignmentsOptionsDictionary;
    CGRect _visibleBounds;
}

@synthesize rowAlignmentOptions = _rowAlignmentsOptionsDictionary;
@synthesize minimumLineSpacing = _lineSpacing;
@synthesize minimumInteritemSpacing = _interitemSpacing;

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (void)commonInit {
    _itemSize = CGSizeMake(50.f, 50.f);
    _lineSpacing = 10.f;
    _interitemSpacing = 10.f;
    _sectionInset = INDEdgeInsetsZero;
    _scrollDirection = INDCollectionViewScrollDirectionVertical;
    _headerReferenceSize = CGSizeZero;
    _footerReferenceSize = CGSizeZero;
}

- (id)init {
    if((self = [super init])) {
        [self commonInit];

        // set default values for row alignment.
        _rowAlignmentsOptionsDictionary = @{
        INDFlowLayoutCommonRowHorizontalAlignmentKey : @(INDFlowLayoutHorizontalAlignmentJustify),
        INDFlowLayoutLastRowHorizontalAlignmentKey : @(INDFlowLayoutHorizontalAlignmentJustify),
        // TODO: those values are some enum. find out what what is.
        INDFlowLayoutRowVerticalAlignmentKey : @(1),
        };

        // custom ivars
        objc_setAssociatedObject(self, &kINDCachedItemRectsKey, [NSMutableDictionary dictionary], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if ((self = [super initWithCoder:decoder])) {
        [self commonInit];
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - INDCollectionViewLayout

static char kINDCachedItemRectsKey;

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    // Apple calls _layoutAttributesForItemsInRect

    NSMutableArray *layoutAttributesArray = [NSMutableArray array];
    for (INDGridLayoutSection *section in _data.sections) {
        if (CGRectIntersectsRect(section.frame, rect)) {

            // if we have fixed size, calculate item frames only once.
            // this also uses the default INDFlowLayoutCommonRowHorizontalAlignmentKey alignment
            // for the last row. (we want this effect!)
            NSMutableDictionary *rectCache = objc_getAssociatedObject(self, &kINDCachedItemRectsKey);
            NSUInteger sectionIndex = [_data.sections indexOfObjectIdenticalTo:section];

			CGRect normalizedHeaderFrame = section.headerFrame;
			normalizedHeaderFrame.origin.x += section.frame.origin.x;
			normalizedHeaderFrame.origin.y += section.frame.origin.y;
			if (!CGRectIsEmpty(normalizedHeaderFrame) && CGRectIntersectsRect(normalizedHeaderFrame, rect)) {
				INDCollectionViewLayoutAttributes *layoutAttributes = [INDCollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:INDCollectionElementKindSectionHeader withIndexPath:[NSIndexPath indexPathForItem:0 inSection:sectionIndex]];
				layoutAttributes.frame = normalizedHeaderFrame;
				[layoutAttributesArray addObject:layoutAttributes];
			}

            NSArray *itemRects = rectCache[@(sectionIndex)];
            if (!itemRects && section.fixedItemSize && [section.rows count]) {
                itemRects = [(section.rows)[0] itemRects];
                if(itemRects) rectCache[@(sectionIndex)] = itemRects;
            }

			for (INDGridLayoutRow *row in section.rows) {
                CGRect normalizedRowFrame = row.rowFrame;
                normalizedRowFrame.origin.x += section.frame.origin.x;
                normalizedRowFrame.origin.y += section.frame.origin.y;
                if (CGRectIntersectsRect(normalizedRowFrame, rect)) {
                    // TODO be more fine-graind for items

                    for (NSInteger itemIndex = 0; itemIndex < row.itemCount; itemIndex++) {
                        INDCollectionViewLayoutAttributes *layoutAttributes;
                        NSUInteger sectionItemIndex;
                        CGRect itemFrame;
                        if (row.fixedItemSize) {
                            itemFrame = [itemRects[itemIndex] ind_CGRectValue];
                            sectionItemIndex = row.index * section.itemsByRowCount + itemIndex;
                        }else {
                            INDGridLayoutItem *item = row.items[itemIndex];
                            sectionItemIndex = [section.items indexOfObjectIdenticalTo:item];
                            itemFrame = item.itemFrame;
                        }
                        layoutAttributes = [INDCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:[NSIndexPath indexPathForItem:sectionItemIndex inSection:sectionIndex]];
                        layoutAttributes.frame = CGRectMake(normalizedRowFrame.origin.x + itemFrame.origin.x, normalizedRowFrame.origin.y + itemFrame.origin.y, itemFrame.size.width, itemFrame.size.height);
                        [layoutAttributesArray addObject:layoutAttributes];
                    }
                }
            }

			CGRect normalizedFooterFrame = section.footerFrame;
			normalizedFooterFrame.origin.x += section.frame.origin.x;
			normalizedFooterFrame.origin.y += section.frame.origin.y;
			if (!CGRectIsEmpty(normalizedFooterFrame) && CGRectIntersectsRect(normalizedFooterFrame, rect)) {
				INDCollectionViewLayoutAttributes *layoutAttributes = [INDCollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:INDCollectionElementKindSectionFooter withIndexPath:[NSIndexPath indexPathForItem:0 inSection:sectionIndex]];
				layoutAttributes.frame = normalizedFooterFrame;
				[layoutAttributesArray addObject:layoutAttributes];
			}
        }
    }
    return layoutAttributesArray;
}

- (INDCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    INDGridLayoutSection *section = _data.sections[indexPath.section];
    INDGridLayoutRow *row = nil;
    CGRect itemFrame = CGRectZero;

    if (section.fixedItemSize && indexPath.item / section.itemsByRowCount < (NSInteger)[section.rows count]) {
        row = section.rows[indexPath.item / section.itemsByRowCount];
        NSUInteger itemIndex = indexPath.item % section.itemsByRowCount;
        NSArray *itemRects = [row itemRects];
        itemFrame = [itemRects[itemIndex] ind_CGRectValue];
    } else if (indexPath.item < (NSInteger)[section.items count]) {
        INDGridLayoutItem *item = section.items[indexPath.item];
        row = item.rowObject;
        itemFrame = item.itemFrame;
    }

    INDCollectionViewLayoutAttributes *layoutAttributes = [INDCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];

    // calculate item rect
    CGRect normalizedRowFrame = row.rowFrame;
    normalizedRowFrame.origin.x += section.frame.origin.x;
    normalizedRowFrame.origin.y += section.frame.origin.y;
    layoutAttributes.frame = CGRectMake(normalizedRowFrame.origin.x + itemFrame.origin.x, normalizedRowFrame.origin.y + itemFrame.origin.y, itemFrame.size.width, itemFrame.size.height);

    return layoutAttributes;
}

- (INDCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    NSUInteger sectionIndex = indexPath.section;

    if (sectionIndex < _data.sections.count) {
        INDGridLayoutSection *section = _data.sections[sectionIndex];
        CGRect normalizedHeaderFrame = section.headerFrame;

        if (!CGRectIsEmpty(normalizedHeaderFrame)) {
            normalizedHeaderFrame.origin.x += section.frame.origin.x;
            normalizedHeaderFrame.origin.y += section.frame.origin.y;

            INDCollectionViewLayoutAttributes *layoutAttributes = [INDCollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:INDCollectionElementKindSectionHeader withIndexPath:[NSIndexPath indexPathForItem:0 inSection:sectionIndex]];
            layoutAttributes.frame = normalizedHeaderFrame;

            return layoutAttributes;
        }
    }

    return nil;
}

- (INDCollectionViewLayoutAttributes *)layoutAttributesForDecorationViewWithReuseIdentifier:(NSString*)identifier atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (CGSize)collectionViewContentSize {
    //    return _currentLayoutSize;
    return _data.contentSize;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Invalidating the Layout

- (void)invalidateLayout {
    objc_setAssociatedObject(self, &kINDCachedItemRectsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    // we need to recalculate on width changes
    if ((self.collectionView.bounds.size.width != newBounds.size.width && self.scrollDirection == INDCollectionViewScrollDirectionHorizontal) || (self.collectionView.bounds.size.height != newBounds.size.height && self.scrollDirection == INDCollectionViewScrollDirectionVertical)) {
        return YES;
    }
    return NO;
}

// return a point at which to rest after scrolling - for layouts that want snap-to-point scrolling behavior
- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset withScrollingVelocity:(CGPoint)velocity {
    return proposedContentOffset;
}

- (void)prepareLayout {
    _data = [INDGridLayoutInfo new]; // clear old layout data
    _data.horizontal = self.scrollDirection == INDCollectionViewScrollDirectionHorizontal;
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

    id <INDCollectionViewDelegateFlowLayout> flowDataSource = (id <INDCollectionViewDelegateFlowLayout>)self.collectionView.delegate;

    BOOL implementsSizeDelegate = [flowDataSource respondsToSelector:@selector(collectionView:layout:sizeForItemAtIndexPath:)];
	BOOL implementsHeaderReferenceDelegate = [flowDataSource respondsToSelector:@selector(collectionView:layout:referenceSizeForHeaderInSection:)];
	BOOL implementsFooterReferenceDelegate = [flowDataSource respondsToSelector:@selector(collectionView:layout:referenceSizeForFooterInSection:)];

    NSUInteger numberOfSections = [self.collectionView numberOfSections];
    for (NSUInteger section = 0; section < numberOfSections; section++) {
        INDGridLayoutSection *layoutSection = [_data addSection];
        layoutSection.verticalInterstice = _data.horizontal ? self.minimumInteritemSpacing : self.minimumLineSpacing;
        layoutSection.horizontalInterstice = !_data.horizontal ? self.minimumInteritemSpacing : self.minimumLineSpacing;

        if ([flowDataSource respondsToSelector:@selector(collectionView:layout:insetForSectionAtIndex:)]) {
            layoutSection.sectionMargins = [flowDataSource collectionView:self.collectionView layout:self insetForSectionAtIndex:section];
        } else {
            layoutSection.sectionMargins = self.sectionInset;
        }

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

		CGSize headerReferenceSize;
		if (implementsHeaderReferenceDelegate) {
			headerReferenceSize = [flowDataSource collectionView:self.collectionView layout:self referenceSizeForHeaderInSection:section];
		} else {
			headerReferenceSize = self.headerReferenceSize;
		}
		layoutSection.headerDimension = _data.horizontal ? headerReferenceSize.width : headerReferenceSize.height;

		CGSize footerReferenceSize;
		if (implementsFooterReferenceDelegate) {
			footerReferenceSize = [flowDataSource collectionView:self.collectionView layout:self referenceSizeForFooterInSection:section];
		} else {
			footerReferenceSize = self.footerReferenceSize;
		}
		layoutSection.footerDimension = _data.horizontal ? footerReferenceSize.width : footerReferenceSize.height;

        NSUInteger numberOfItems = [self.collectionView numberOfItemsInSection:section];

        // if delegate implements size delegate, query it for all items
        if (implementsSizeDelegate) {
            for (NSUInteger item = 0; item < numberOfItems; item++) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
                CGSize itemSize = implementsSizeDelegate ? [flowDataSource collectionView:self.collectionView layout:self sizeForItemAtIndexPath:indexPath] : self.itemSize;

                INDGridLayoutItem *layoutItem = [layoutSection addItem];
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
    for (INDGridLayoutSection *section in _data.sections) {
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
	if (_data.horizontal) {
		contentSize.width = MAX(contentSize.width, self.collectionView.bounds.size.width);
	} else {
		contentSize.height = MAX(contentSize.height, self.collectionView.bounds.size.height);
	}
    _data.contentSize = contentSize;
}

@end
