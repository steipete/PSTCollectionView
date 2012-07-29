//
//  PSGridLayoutRow.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSGridLayoutRow.h"
#import "PSGridLayoutSection.h"
#import "PSGridLayoutItem.h"
#import "PSGridLayoutInfo.h"

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

- (void)layoutRow {
    if (!_isValid) {

        // calculate row frame as union of all items
        CGRect frame = CGRectZero;
        CGRect itemFrame = (CGRect){.size=self.section.itemSize};
        CGPoint itemOffset = CGPointZero;
        for (NSUInteger itemIndex = 0; itemIndex < self.itemCount; itemIndex++) {
            PSGridLayoutItem *item = nil;
            if (!self.fixedItemSize) {
                item = self.items[itemIndex];
                itemFrame = [item itemFrame];
            }
            if (self.section.layoutInfo.horizontal) {
                itemFrame.origin.y = itemOffset.y;
                itemOffset.y += itemFrame.size.height + self.section.verticalInterstice;
            }else {
                itemFrame.origin.x = itemOffset.x;
                itemOffset.x += itemFrame.size.width + self.section.horizontalInterstice;
            }
            item.itemFrame = itemFrame; // might call nil; don't care

            frame = CGRectUnion(frame, itemFrame);
        }
        _rowSize = frame.size;
//        _rowFrame = frame; // set externally
        _isValid = YES;
    }
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



// _UIGridLayoutItem
#import "PSPDFPatches.h"
#import <objc/runtime.h>
#import <objc/message.h>
__attribute__((constructor)) static void PSHackUIGridLayoutItem(void) {
    @autoreleasepool {
        SEL itemFrameSetter = @selector(ps_setItemFrame:);
        IMP customImageViewDescIMP = imp_implementationWithBlock(^(id _self, CGRect itemFrame) {
            objc_msgSend(_self, itemFrameSetter, itemFrame);
        });
        PSPDFReplaceMethod(NSClassFromString(@"_UIGridLayoutItem"), @selector(setItemFrame:), itemFrameSetter, customImageViewDescIMP);
    }
}

/*
__attribute__((constructor)) static void PSHackUIGridLayoutSection(void) {
    @autoreleasepool {
        SEL itemFrameSetter = @selector(ps_addRow);
        IMP customImageViewDescIMP = imp_implementationWithBlock(^(id _self) {
            objc_msgSend(_self, itemFrameSetter);
        });
        PSPDFReplaceMethod(NSClassFromString(@"_UIGridLayoutSection"), @selector(addRow), itemFrameSetter, customImageViewDescIMP);
    }
}*/


__attribute__((constructor)) static void PSHackUICollectionViewLayoutAttributes(void) {
    @autoreleasepool {
        SEL itemFrameSetter = @selector(ps_initWithCollectionView:layout:);
        IMP customImageViewDescIMP = imp_implementationWithBlock(^(id _self, id c, id l) {
            return objc_msgSend(_self, itemFrameSetter, c, l);
        });
        PSPDFReplaceMethod(NSClassFromString(@"UICollectionViewData"), @selector(initWithCollectionView:layout:), itemFrameSetter, customImageViewDescIMP);
    }
}
