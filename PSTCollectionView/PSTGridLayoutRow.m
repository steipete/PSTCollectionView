//
//  PSTGridLayoutRow.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSTCollectionView.h"
#import "PSTGridLayoutRow.h"
#import "PSTGridLayoutSection.h"
#import "PSTGridLayoutItem.h"
#import "PSTGridLayoutInfo.h"
#import "PSTCollectionViewFlowLayout.h"

@interface PSTGridLayoutRow() {
    NSMutableArray *_items;
    BOOL _isValid;
    int _verticalAlignement;
    int _horizontalAlignement;
}
@property (nonatomic, strong) NSArray *items;
@end

@implementation PSTGridLayoutRow

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)init {
    if((self = [super init])) {
        _items = [NSMutableArray new];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p frame:%@ index:%d items:%@>", NSStringFromClass([self class]), self, NSStringFromCGRect(self.rowFrame), self.index, self.items];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)invalidate {
    _isValid = NO;
    _rowSize = CGSizeZero;
    _rowFrame = CGRectZero;
}

- (NSArray *)itemRects {
    return [self layoutRowAndGenerateRectArray:YES];
}

- (void)layoutRow {
    [self layoutRowAndGenerateRectArray:NO];
}

- (NSArray *)layoutRowAndGenerateRectArray:(BOOL)generateRectArray {
    NSMutableArray *rects = generateRectArray ? [NSMutableArray array] : nil;
    if (!_isValid || generateRectArray) {
        // properties for aligning
        BOOL isHorizontal = self.section.layoutInfo.horizontal;
        BOOL isLastRow = self.section.indexOfImcompleteRow == self.index;
        PSTFlowLayoutHorizontalAlignment horizontalAlignment = [self.section.rowAlignmentOptions[isLastRow ? PSTFlowLayoutLastRowHorizontalAlignmentKey : PSTFlowLayoutCommonRowHorizontalAlignmentKey] integerValue];

        // calculate space that's left over if we would align it from left to right.
        CGFloat leftOverSpace = self.section.layoutInfo.dimension;
        if (isHorizontal) {
            leftOverSpace -= self.section.sectionMargins.top + self.section.sectionMargins.bottom;
        }else {
            leftOverSpace -= self.section.sectionMargins.left + self.section.sectionMargins.right;
        }

        // calculate the space that we have left after counting all items.
        // UICollectionView is smart and lays out items like they would have been placed on a full row
        // So we need to calculate the "usedItemCount" with using the last item as a reference size.
        // This allows us to correctly justify-place the items in the grid.
        NSUInteger usedItemCount = 0;
        NSInteger itemIndex = 0;
        BOOL canFitMoreItems = itemIndex < self.itemCount;
        while (itemIndex < self.itemCount || canFitMoreItems) {
            if (!self.fixedItemSize) {
                PSTGridLayoutItem *item = self.items[MIN(itemIndex, self.itemCount-1)];
                leftOverSpace -= isHorizontal ? item.itemFrame.size.height : item.itemFrame.size.width;
                canFitMoreItems = isHorizontal ? leftOverSpace > item.itemFrame.size.height : leftOverSpace > item.itemFrame.size.width;
            }else {
                leftOverSpace -= isHorizontal ? self.section.itemSize.height : self.section.itemSize.width;
                canFitMoreItems = isHorizontal ? leftOverSpace > self.section.itemSize.height : leftOverSpace > self.section.itemSize.width;
            }
            // separator starts after first item
            if (itemIndex > 0) {
                leftOverSpace -= isHorizontal ? self.section.verticalInterstice : self.section.horizontalInterstice;
            }
            itemIndex++;
            usedItemCount = itemIndex;
        }

        CGPoint itemOffset = CGPointZero;
        if (horizontalAlignment == PSTFlowLayoutHorizontalAlignmentRight) {
            itemOffset.x += leftOverSpace;
        }else if(horizontalAlignment == PSTFlowLayoutHorizontalAlignmentCentered) {
            itemOffset.x += leftOverSpace/2;
        }

        // calculate row frame as union of all items
        CGRect frame = CGRectZero;
        CGRect itemFrame = (CGRect){.size=self.section.itemSize};
        for (itemIndex = 0; itemIndex < self.itemCount; itemIndex++) {
            PSTGridLayoutItem *item = nil;
            if (!self.fixedItemSize) {
                item = self.items[itemIndex];
                itemFrame = [item itemFrame];
            }
            if (isHorizontal) {
                itemFrame.origin.y = itemOffset.y;
                itemOffset.y += itemFrame.size.height + self.section.verticalInterstice;
                if (horizontalAlignment == PSTFlowLayoutHorizontalAlignmentJustify) {
                    itemOffset.y += leftOverSpace/(CGFloat)(usedItemCount-1);
                }
            }else {
                itemFrame.origin.x = itemOffset.x;
                itemOffset.x += itemFrame.size.width + self.section.horizontalInterstice;
                if (horizontalAlignment == PSTFlowLayoutHorizontalAlignmentJustify) {
                    itemOffset.x += leftOverSpace/(CGFloat)(usedItemCount-1);
                }
            }
            item.itemFrame = CGRectIntegral(itemFrame); // might call nil; don't care
            [rects addObject:[NSValue valueWithCGRect:CGRectIntegral(itemFrame)]];
            frame = CGRectUnion(frame, itemFrame);
        }
        _rowSize = frame.size;
        //        _rowFrame = frame; // set externally
        _isValid = YES;
    }
    return rects;
}

- (void)addItem:(PSTGridLayoutItem *)item {
    [_items addObject:item];
    item.rowObject = self;
    [self invalidate];
}

- (PSTGridLayoutRow *)snapshot {
    PSTGridLayoutRow *snapshotRow = [[self class] new];
    snapshotRow.section = self.section;
    snapshotRow.items = self.items;
    snapshotRow.rowSize = self.rowSize;
    snapshotRow.rowFrame = self.rowFrame;
    snapshotRow.index = self.index;
    snapshotRow.complete = self.complete;
    snapshotRow.fixedItemSize = self.fixedItemSize;
    snapshotRow.itemCount = self.itemCount;
    return snapshotRow;
}

- (PSTGridLayoutRow *)copyFromSection:(PSTGridLayoutSection *)section {
    return nil; // ???
}

- (NSInteger)itemCount {
    if(self.fixedItemSize) {
        return _itemCount;
    }else {
        return [self.items count];
    }
}

@end


/*
 // _UIGridLayoutItem
 #import <objc/runtime.h>
 #import <objc/message.h>
 __attribute__((constructor)) static void PSHackUIGridLayoutItem(void) {
 @autoreleasepool {
 SEL itemFrameSetter = @selector(ps_dealloc);
 IMP customImageViewDescIMP = imp_implementationWithBlock(PSBlockImplCast(^(__unsafe_unretained id _self)) {
 //            NSLog(@"deallocating %@", _self);
 objc_msgSend(_self, itemFrameSetter);
 });
 PSPDFReplaceMethod(NSClassFromString(@"UICollectionViewLayoutAttributes"), NSSelectorFromString(@"dealloc"), itemFrameSetter, customImageViewDescIMP);
 }
 }

 __attribute__((constructor)) static void PSHackUIGridLayoutSection(void) {
 @autoreleasepool {
 SEL itemFrameSetter = @selector(ps_addRow);
 IMP customImageViewDescIMP = imp_implementationWithBlock(^(id _self) {
 objc_msgSend(_self, itemFrameSetter);
 });
 PSPDFReplaceMethod(NSClassFromString(@"_UIGridLayoutSection"), @selector(addRow), itemFrameSetter, customImageViewDescIMP);
 }
 }

 __attribute__((constructor)) static void PSHackUICollectionViewLayoutAttributes(void) {
 @autoreleasepool {
 SEL itemFrameSetter = @selector(ps_initWithCollectionView:layout:);
 IMP customImageViewDescIMP = imp_implementationWithBlock(^(id _self, id c, id l) {
 return objc_msgSend(_self, itemFrameSetter, c, l);
 });
 PSPDFReplaceMethod(NSClassFromString(@"UICollectionViewData"), @selector(initWithCollectionView:layout:), itemFrameSetter, customImageViewDescIMP);
 }
 }
 */
