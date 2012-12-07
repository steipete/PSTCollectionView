//
//  NSView+INDCollectionViewAdditions.m
//  BasicExample
//
//  Created by Indragie Karunaratne on 2012-12-07.
//  Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import "NSView+INDCollectionViewAdditions.h"

@implementation NSView (INDCollectionViewAdditions)
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
{
    [self animateWithDuration:duration animations:animations completion:nil];
}

+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(void))block
{
    [NSAnimationContext beginGrouping];
    NSAnimationContext *ctx = [NSAnimationContext currentContext];
    [ctx setDuration:duration];
    [ctx setCompletionHandler:block];
    [ctx setAllowsImplicitAnimation:YES];
    if (animations) animations();
    [NSAnimationContext endGrouping];
}
@end
