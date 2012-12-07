//
//  INDGridLayoutRow.h
//
//  Original Source: Copyright (c) 2012 Peter Steinberger. All rights reserved.
//  AppKit Port: Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//
#import <Foundation/Foundation.h>

@class INDGridLayoutSection, INDGridLayoutItem;

@interface INDGridLayoutRow : NSObject

@property (nonatomic, unsafe_unretained) INDGridLayoutSection *section;
@property (nonatomic, strong, readonly) NSArray *items;
@property (nonatomic, assign) CGSize rowSize;
@property (nonatomic, assign) CGRect rowFrame;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) BOOL complete;
@property (nonatomic, assign) BOOL fixedItemSize;

// @steipete addition for row-fastPath
@property (nonatomic, assign) NSInteger itemCount;

//- (INDGridLayoutRow *)copyFromSection:(INDGridLayoutSection *)section; // ???

// Add new item to items array.
- (void)addItem:(INDGridLayoutItem *)item;

// Layout current row (if invalid)
- (void)layoutRow;

// @steipete: Helper to save code in INDCollectionViewFlowLayout.
// Returns the item rects when fixedItemSize is enabled.
- (NSArray *)itemRects;

//  Set current row frame invalid.
- (void)invalidate;

// Copy a snapshot of the current row data
- (INDGridLayoutRow *)snapshot;

@end
