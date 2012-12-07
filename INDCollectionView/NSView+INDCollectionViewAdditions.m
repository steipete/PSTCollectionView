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

+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(void))completion
{
    if (completion == nil) completion = ^{};
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = duration;
        context.allowsImplicitAnimation = YES;
        if (animations) animations();
    } completionHandler:^{
        completion();
    }];
}
@end
