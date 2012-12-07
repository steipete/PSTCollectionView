//
//  NSValue+INDCollectionViewAdditions.h
//  BasicExample
//
//  Created by Indragie Karunaratne on 2012-12-07.
//  Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import <Foundation/Foundation.h>

// Additions to support boxing CG data types in NSValue
@interface NSValue (INDCollectionViewAdditions)
+ (NSValue *)valueWithCGRect:(CGRect)rect;
+ (NSValue *)valueWithCGSize:(CGSize)size;
+ (NSValue *)valueWithCGPoint:(CGPoint)point;
- (CGRect)CGRectValue;
- (CGSize)CGSizeValue;
- (CGPoint)CGPointValue;
@end
