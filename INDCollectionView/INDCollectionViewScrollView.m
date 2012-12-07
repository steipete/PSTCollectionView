//
//  INDCollectionViewScrollView.m
//  BasicExample
//
//  Created by Indragie Karunaratne on 2012-12-07.
//  Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import "INDCollectionViewScrollView.h"

@implementation INDCollectionViewScrollView

- (void)tile
{
    [super tile];
    CGRect contentViewFrame = self.contentView.frame;
    contentViewFrame.origin = self.contentOffset;
    contentViewFrame.size.width -= self.contentOffset.x;
    contentViewFrame.size.height -= self.contentOffset.y;
    self.contentView.frame = contentViewFrame;
}

- (void)setContentOffset:(CGPoint)contentOffset
{
    if (!CGPointEqualToPoint(_contentOffset, contentOffset)) {
        _contentOffset = contentOffset;
        [self tile];
    }
}
@end
