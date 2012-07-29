//
//  PSGridLayoutItem.h
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PSGridLayoutSection, PSGridLayoutRow;

// _UIGridLayoutItem
@interface PSGridLayoutItem : NSObject

@property (nonatomic, unsafe_unretained) PSGridLayoutSection *section;
@property (nonatomic, unsafe_unretained) PSGridLayoutRow *rowObject;
@property (nonatomic, assign) CGRect itemFrame;

@end
