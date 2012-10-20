//
//  PSTCollectionViewFlowLayout.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSTCollectionViewFlowLayout.h"
#import "PSTCollectionView.h"
#import "PSTGridLayoutItem.h"
#import "PSTGridLayoutInfo.h"
#import "PSTGridLayoutRow.h"
#import "PSTGridLayoutSection.h"
#import <objc/runtime.h>

NSString *const PSTCollectionElementKindSectionHeader = @"UICollectionElementKindSectionHeader";
NSString *const PSTCollectionElementKindSectionFooter = @"UICollectionElementKindSectionFooter";

// this is not exposed in UICollectionViewFlowLayout
NSString *const PSTFlowLayoutCommonRowHorizontalAlignmentKey = @"UIFlowLayoutCommonRowHorizontalAlignmentKey";
NSString *const PSTFlowLayoutLastRowHorizontalAlignmentKey = @"UIFlowLayoutLastRowHorizontalAlignmentKey";
NSString *const PSTFlowLayoutRowVerticalAlignmentKey = @"UIFlowLayoutRowVerticalAlignmentKey";

@implementation PSTCollectionViewFlowLayout {
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
    float _interitemSpacing;
    float _lineSpacing;
    CGSize _itemSize;
    CGSize _headerReferenceSize;
    CGSize _footerReferenceSize;
    UIEdgeInsets _sectionInset;
    PSTGridLayoutInfo *_data;
    CGSize _currentLayoutSize;
    NSMutableDictionary *_insertedItemsAttributesDict;
    NSMutableDictionary *_insertedSectionHeadersAttributesDict;
    NSMutableDictionary *_insertedSectionFootersAttributesDict;
    NSMutableDictionary *_deletedItemsAttributesDict;
    NSMutableDictionary *_deletedSectionHeadersAttributesDict;
    NSMutableDictionary *_deletedSectionFootersAttributesDict;
    PSTCollectionViewScrollDirection _scrollDirection;
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
    _sectionInset = UIEdgeInsetsZero;
    _scrollDirection = PSTCollectionViewScrollDirectionVertical;
    _headerReferenceSize = CGSizeZero;
    _footerReferenceSize = CGSizeZero;
}

- (id)init {
    if((self = [super init])) {
        [self commonInit];

        // set default values for row alignment.
        _rowAlignmentsOptionsDictionary = @{
        PSTFlowLayoutCommonRowHorizontalAlignmentKey : @(PSTFlowLayoutHorizontalAlignmentJustify),
        PSTFlowLayoutLastRowHorizontalAlignmentKey : @(PSTFlowLayoutHorizontalAlignmentJustify),
        // TODO: those values are some enum. find out what what is.
        PSTFlowLayoutRowVerticalAlignmentKey : @(1),
        };

        // custom ivars
        objc_setAssociatedObject(self, &kPSTCachedItemRectsKey, [NSMutableArray array], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if ((self = [super initWithCoder:decoder])) {
        [self commonInit];

        // some properties are not set if they're default (like minimumInteritemSpacing == 10)
        if ([decoder containsValueForKey:@"UIItemSize"])
            self.itemSize = [decoder decodeCGSizeForKey:@"UIItemSize"];
        if ([decoder containsValueForKey:@"UIInteritemSpacing"])
            self.minimumInteritemSpacing = [decoder decodeFloatForKey:@"UIInteritemSpacing"];
        if ([decoder containsValueForKey:@"UILineSpacing"])
            self.minimumLineSpacing = [decoder decodeFloatForKey:@"UILineSpacing"];
        if ([decoder containsValueForKey:@"UIFooterReferenceSize"])
            self.footerReferenceSize = [decoder decodeCGSizeForKey:@"UIFooterReferenceSize"];
        if ([decoder containsValueForKey:@"UIHeaderReferenceSize"])
            self.headerReferenceSize = [decoder decodeCGSizeForKey:@"UIHeaderReferenceSize"];
        if ([decoder containsValueForKey:@"UISectionInset"])
            self.sectionInset = [decoder decodeUIEdgeInsetsForKey:@"UISectionInset"];
        if ([decoder containsValueForKey:@"UIScrollDirection"])
            self.scrollDirection = [decoder decodeIntegerForKey:@"UIScrollDirection"];
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSTCollectionViewLayout

static char kPSTCachedItemRectsKey;

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    // Apple calls _layoutAttributesForItemsInRect

    NSMutableArray *layoutAttributesArray = [NSMutableArray array];
    for (PSTGridLayoutSection *section in _data.sections) {
        if (CGRectIntersectsRect(section.frame, rect)) {

            // if we have fixed size, calculate item frames only once.
            // this also uses the default PSTFlowLayoutCommonRowHorizontalAlignmentKey alignment
            // for the last row. (we want this effect!)
            NSMutableDictionary *rectCache = objc_getAssociatedObject(self, &kPSTCachedItemRectsKey);
            NSUInteger sectionIndex = [_data.sections indexOfObjectIdenticalTo:section];
            NSArray *itemRects = rectCache[@(sectionIndex)];
            if (!itemRects && section.fixedItemSize && [section.rows count]) {
                itemRects = [(section.rows)[0] itemRects];
                if(itemRects) rectCache[@(sectionIndex)] = itemRects;
            }

            for (PSTGridLayoutRow *row in section.rows) {
                CGRect normalizedRowFrame = row.rowFrame;
                normalizedRowFrame.origin.x += section.frame.origin.x;
                normalizedRowFrame.origin.y += section.frame.origin.y;
                if (CGRectIntersectsRect(normalizedRowFrame, rect)) {
                    // TODO be more fine-graind for items

                    for (NSInteger itemIndex = 0; itemIndex < row.itemCount; itemIndex++) {
                        PSTCollectionViewLayoutAttributes *layoutAttributes;
                        NSUInteger sectionItemIndex;
                        CGRect itemFrame;
                        if (row.fixedItemSize) {
                            itemFrame = [itemRects[itemIndex] CGRectValue];
                            sectionItemIndex = row.index * section.itemsByRowCount + itemIndex;
                        }else {
                            PSTGridLayoutItem *item = row.items[itemIndex];
                            sectionItemIndex = [section.items indexOfObjectIdenticalTo:item];
                            itemFrame = item.itemFrame;
                        }
                        layoutAttributes = [PSTCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:[NSIndexPath indexPathForItem:sectionItemIndex inSection:sectionIndex]];
                        layoutAttributes.frame = CGRectMake(normalizedRowFrame.origin.x + itemFrame.origin.x, normalizedRowFrame.origin.y + itemFrame.origin.y, itemFrame.size.width, itemFrame.size.height);
                        [layoutAttributesArray addObject:layoutAttributes];
                    }
                }
            }
        }
    }
    return layoutAttributesArray;
}

- (PSTCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    PSTGridLayoutSection *section = _data.sections[indexPath.section];
    PSTGridLayoutRow *row = nil;
    CGRect itemFrame = CGRectZero;

    if (section.fixedItemSize && indexPath.item / section.itemsByRowCount < (NSInteger)[section.rows count]) {
        row = section.rows[indexPath.item / section.itemsByRowCount];
        NSUInteger itemIndex = indexPath.item % section.itemsByRowCount;
        NSArray *itemRects = [row itemRects];
        itemFrame = [itemRects[itemIndex] CGRectValue];
    } else if (indexPath.item < (NSInteger)[section.items count]) {
        PSTGridLayoutItem *item = section.items[indexPath.item];
        row = item.rowObject;
        itemFrame = item.itemFrame;
    }

    PSTCollectionViewLayoutAttributes *layoutAttributes = [PSTCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];

    // calculate item rect
    CGRect normalizedRowFrame = row.rowFrame;
    normalizedRowFrame.origin.x += section.frame.origin.x;
    normalizedRowFrame.origin.y += section.frame.origin.y;
    layoutAttributes.frame = CGRectMake(normalizedRowFrame.origin.x + itemFrame.origin.x, normalizedRowFrame.origin.y + itemFrame.origin.y, itemFrame.size.width, itemFrame.size.height);

    return layoutAttributes;
}

- (PSTCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (PSTCollectionViewLayoutAttributes *)layoutAttributesForDecorationViewWithReuseIdentifier:(NSString*)identifier atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (CGSize)collectionViewContentSize {
    //    return _currentLayoutSize;
    return _data.contentSize;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Invalidating the Layout

- (void)invalidateLayout {
    objc_setAssociatedObject(self, &kPSTCachedItemRectsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    // we need to recalculate on width changes
    if ((self.collectionView.bounds.size.width != newBounds.size.width && self.scrollDirection == PSTCollectionViewScrollDirectionHorizontal) || (self.collectionView.bounds.size.height != newBounds.size.height && self.scrollDirection == PSTCollectionViewScrollDirectionVertical)) {
        return YES;
    }
    return NO;
}

// return a point at which to rest after scrolling - for layouts that want snap-to-point scrolling behavior
- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset withScrollingVelocity:(CGPoint)velocity {
    return proposedContentOffset;
}

- (void)prepareLayout {
    _data = [PSTGridLayoutInfo new]; // clear old layout data
    _data.horizontal = self.scrollDirection == PSTCollectionViewScrollDirectionHorizontal;
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

    id <PSTCollectionViewDelegateFlowLayout> flowDataSource = (id <PSTCollectionViewDelegateFlowLayout>)self.collectionView.dataSource;

    BOOL implementsSizeDelegate = [flowDataSource respondsToSelector:@selector(collectionView:layout:sizeForItemAtIndexPath:)];

    NSUInteger numberOfSections = [self.collectionView numberOfSections];
    for (NSUInteger section = 0; section < numberOfSections; section++) {
        PSTGridLayoutSection *layoutSection = [_data addSection];
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

        NSUInteger numberOfItems = [self.collectionView numberOfItemsInSection:section];

        // if delegate implements size delegate, query it for all items
        if (implementsSizeDelegate) {
            for (NSUInteger item = 0; item < numberOfItems; item++) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
                CGSize itemSize = implementsSizeDelegate ? [flowDataSource collectionView:self.collectionView layout:self sizeForItemAtIndexPath:indexPath] : self.itemSize;

                PSTGridLayoutItem *layoutItem = [layoutSection addItem];
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
    for (PSTGridLayoutSection *section in _data.sections) {
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
