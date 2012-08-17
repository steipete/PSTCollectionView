//
//  PSGridLayoutRow.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSCollectionView.h"
#import "PSGridLayoutRow.h"
#import "PSGridLayoutSection.h"
#import "PSGridLayoutItem.h"
#import "PSGridLayoutInfo.h"
#import "PSCollectionViewFlowLayout.h"

@interface PSGridLayoutRow() {
    NSMutableArray *_items;
    BOOL _isValid;
    int _verticalAlignement;
    int _horizontalAlignement;
}
@property (nonatomic, strong) NSArray *items;
@end

@implementation PSGridLayoutRow

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
        PSFlowLayoutHorizontalAlignment horizontalAlignment = [self.section.rowAlignmentOptions[isLastRow ? PSFlowLayoutLastRowHorizontalAlignmentKey : PSFlowLayoutCommonRowHorizontalAlignmentKey] integerValue];

        // calculate space that's left over if we would align it from left to right.
        CGFloat leftOverSpace = self.section.layoutInfo.dimension;
        if (isHorizontal) {
            leftOverSpace -= self.section.sectionMargins.top + self.section.sectionMargins.bottom;
        }else {
            leftOverSpace -= self.section.sectionMargins.left + self.section.sectionMargins.right;
        }

        for (NSInteger itemIndex = 0; itemIndex < self.itemCount; itemIndex++) {
            if (!self.fixedItemSize) {
                PSGridLayoutItem *item = self.items[itemIndex];
                leftOverSpace -= isHorizontal ? item.itemFrame.size.height : item.itemFrame.size.width;
            }else {
                leftOverSpace -= isHorizontal ? self.section.itemSize.height : self.section.itemSize.width;
            }
            // separator starts after first item
            if (itemIndex > 0) {
                leftOverSpace -= isHorizontal ? self.section.verticalInterstice : self.section.horizontalInterstice;
            }
        }
        CGPoint itemOffset = CGPointZero;
        if (horizontalAlignment == PSFlowLayoutHorizontalAlignmentRight) {
            itemOffset.x += leftOverSpace;
        }else if(horizontalAlignment == PSFlowLayoutHorizontalAlignmentCentered) {
            itemOffset.x += leftOverSpace/2;
        }

        // calculate row frame as union of all items
        CGRect frame = CGRectZero;
        CGRect itemFrame = (CGRect){.size=self.section.itemSize};
        for (NSInteger itemIndex = 0; itemIndex < self.itemCount; itemIndex++) {
            PSGridLayoutItem *item = nil;
            if (!self.fixedItemSize) {
                item = self.items[itemIndex];
                itemFrame = [item itemFrame];
            }
            if (isHorizontal) {
                itemFrame.origin.y = itemOffset.y;
                itemOffset.y += itemFrame.size.height + self.section.verticalInterstice;
                if (horizontalAlignment == PSFlowLayoutHorizontalAlignmentJustify) {
                    itemOffset.y += leftOverSpace/(CGFloat)(self.itemCount-1);
                }
            }else {
                itemFrame.origin.x = itemOffset.x;
                itemOffset.x += itemFrame.size.width + self.section.horizontalInterstice;
                if (horizontalAlignment == PSFlowLayoutHorizontalAlignmentJustify) {
                    itemOffset.x += leftOverSpace/(CGFloat)(self.itemCount-1);
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

- (void)addItem:(PSGridLayoutItem *)item {
    [_items addObject:item];
    item.rowObject = self;
    [self invalidate];
}

- (PSGridLayoutRow *)snapshot {
    PSGridLayoutRow *snapshotRow = [[self class] new];
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

- (PSGridLayoutRow *)copyFromSection:(PSGridLayoutSection *)section {
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
