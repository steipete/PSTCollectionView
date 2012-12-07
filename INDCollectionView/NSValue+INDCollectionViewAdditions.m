//
//  NSValue+INDCollectionViewAdditions.m
//  BasicExample
//
//  Created by Indragie Karunaratne on 2012-12-07.
//  Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import "NSValue+INDCollectionViewAdditions.h"

@implementation NSValue (INDCollectionViewAdditions)
+ (NSValue *)valueWithCGRect:(CGRect)rect
{
    return [self valueWithRect:NSRectFromCGRect(rect)];
}

- (CGRect)CGRectValue
{
    return NSRectToCGRect([self rectValue]);
}

+ (NSValue *)valueWithCGSize:(CGSize)size
{
    return [self valueWithSize:NSSizeFromCGSize(size)];
}

+ (NSValue *)valueWithCGPoint:(CGPoint)point
{
    return [self valueWithPoint:NSPointFromCGPoint(point)];
}

- (CGSize)CGSizeValue
{
    return NSSizeToCGSize([self sizeValue]);
}

- (CGPoint)CGPointValue
{
    return NSPointToCGPoint([self pointValue]);
}
@end
