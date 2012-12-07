//
//  INDGridLayoutItem.h
//
//  Original Source: Copyright (c) 2012 Peter Steinberger. All rights reserved.
//  AppKit Port: Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import <Foundation/Foundation.h>

@class INDGridLayoutSection, INDGridLayoutRow;

// Represents a single grid item; only created for non-uniform-sized grids.
@interface INDGridLayoutItem : NSObject

@property (nonatomic, unsafe_unretained) INDGridLayoutSection *section;
@property (nonatomic, unsafe_unretained) INDGridLayoutRow *rowObject;
@property (nonatomic, assign) CGRect itemFrame;

@end
