//
//  NSValue+INDCollectionViewAdditions.m
//  BasicExample
//
//  Created by Indragie Karunaratne on 2012-12-07.
//  Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import "NSValue+INDCollectionViewAdditions.h"

@implementation NSValue (INDCollectionViewAdditions)
+ (NSValue *)ind_valueWithCGRect:(CGRect)rect
{
    return [self valueWithRect:NSRectFromCGRect(rect)];
}

- (CGRect)ind_CGRectValue
{
    return NSRectToCGRect([self rectValue]);
}

+ (NSValue *)ind_valueWithCGSize:(CGSize)size
{
    return [self valueWithSize:NSSizeFromCGSize(size)];
}

+ (NSValue *)ind_valueWithCGPoint:(CGPoint)point
{
    return [self valueWithPoint:NSPointFromCGPoint(point)];
}

- (CGSize)ind_CGSizeValue
{
    return NSSizeToCGSize([self sizeValue]);
}

- (CGPoint)ind_CGPointValue
{
    return NSPointToCGPoint([self pointValue]);
}
@end
