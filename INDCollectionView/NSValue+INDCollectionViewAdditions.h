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
+ (NSValue *)ind_valueWithCGRect:(CGRect)rect;
+ (NSValue *)ind_valueWithCGSize:(CGSize)size;
+ (NSValue *)ind_valueWithCGPoint:(CGPoint)point;
- (CGRect)ind_CGRectValue;
- (CGSize)ind_CGSizeValue;
- (CGPoint)ind_CGPointValue;
@end
