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

    NSMutableDictionary* _insertedItemsAttributesDict;
    NSMutableDictionary* _insertedSectionHeadersAttributesDict;
    NSMutableDictionary* _insertedSectionFootersAttributesDict;
    NSMutableDictionary* _deletedItemsAttributesDict;
    NSMutableDictionary* _deletedSectionHeadersAttributesDict;
    NSMutableDictionary* _deletedSectionFootersAttributesDict;

    NSDictionary *_rowAlignmentsOptionsDictionary;
    CGRect _visibleBounds;
}

@end

@implementation PSCollectionViewFlowLayout

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)init {
    if((self = [super init])) {
        _scrollDirection = PSCollectionViewScrollDirectionVertical;

        // set default values for row alignment.
        // TODO: those values are some enum. find out what what is.
        // 3 = justified; 0 = left;  center, right?
        _rowAlignmentsOptionsDictionary = @{
            PSFlowLayoutCommonRowHorizontalAlignmentKey : @(3),
            PSFlowLayoutLastRowHorizontalAlignmentKey : @(0),
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
            for (PSGridLayoutRow *row in section.rows) {
                CGRect normalizedRowFrame = row.rowFrame;
                if (_data.horizontal) {
                    normalizedRowFrame.origin.x += section.frame.origin.x;
                }else {
                    normalizedRowFrame.origin.y += section.frame.origin.y;
                }
                if (CGRectIntersectsRect(normalizedRowFrame, rect)) {
                    // TODO be more fine-graind for items
                    for (NSUInteger itemIndex = 0; itemIndex < row.itemCount; itemIndex++) {
                        PSCollectionViewLayoutAttributes *layoutAttributes;
                        NSUInteger sectionIndex = [section.layoutInfo.sections indexOfObject:section];
                        NSUInteger sectionItemIndex;
                        CGRect itemFrame;
                        if (row.fixedItemSize) {
                            sectionItemIndex = row.index * section.itemsByRowCount + itemIndex;
                            if (_data.horizontal) {
                                itemFrame = CGRectMake(0, section.frame.origin.y + section.itemSize.height * itemIndex + section.verticalInterstice * itemIndex, section.itemSize.width, section.itemSize.height);
                            }else {
                                itemFrame = CGRectMake(section.frame.origin.x + section.itemSize.width * itemIndex + section.horizontalInterstice * itemIndex, 0, section.itemSize.width, section.itemSize.height);
                            }
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
    return nil;
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

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    // we need to recalculate on width changes
    if (self.collectionView.bounds.size.width != newBounds.size.width) {
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
        layoutSection.verticalInterstice = _data.horizontal ? self.minimumInteritemSpacing : 0.f;
        layoutSection.horizontalInterstice = !_data.horizontal ? self.minimumInteritemSpacing : 0.f;
        layoutSection.sectionMargins = self.sectionInset;
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