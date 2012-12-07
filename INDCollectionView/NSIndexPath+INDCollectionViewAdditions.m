//
//  NSIndexPath+INDCollectionViewAdditions.m
//
//  Created by Indragie Karunaratne on 2012-12-07.
//  Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import "NSIndexPath+INDCollectionViewAdditions.h"

@implementation NSIndexPath (INDCollectionViewAdditions)
+ (NSIndexPath *)indexPathForItem:(NSInteger)item inSection:(NSInteger)section
{
    NSUInteger indexes[2] = {section, item};
    return [NSIndexPath indexPathWithIndexes:indexes length:2];
}

- (NSInteger)item
{
    return [self indexAtPosition:1];
}

- (NSInteger)section
{
    return [self indexAtPosition:0];
}
@end
