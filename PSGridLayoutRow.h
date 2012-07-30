//
//  PSGridLayoutRow.h
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PSGridLayoutSection, PSGridLayoutItem;

@interface PSGridLayoutRow : NSObject

@property (nonatomic, unsafe_unretained) PSGridLayoutSection *section;
@property (nonatomic, strong, readonly) NSArray *items;
@property (nonatomic, assign) CGSize rowSize;
@property (nonatomic, assign) CGRect rowFrame;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) BOOL complete;
@property (nonatomic, assign) BOOL fixedItemSize;

// @steipete addition for row-fastPath
@property (nonatomic, assign) NSInteger itemCount;

//- (PSGridLayoutRow *)copyFromSection:(PSGridLayoutSection *)section; // ???

// Add new item to items array.
- (void)addItem:(PSGridLayoutItem *)item;

// Layout current row (if invalid)
- (void)layoutRow;

//  Set current row frame invalid.
- (void)invalidate;

// Copy a snapshot of the current row data
- (PSGridLayoutRow *)snapshot;

@end
