//
//  ColorView.m
//  BasicExample
//
//  Created by Jonathan Willing on 12/7/12.
//  Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import "ColorView.h"

@implementation ColorView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
		self.layer.backgroundColor = [NSColor blueColor].CGColor;
    }
    
    return self;
}

//- (void)drawRect:(NSRect)dirtyRect
//{
//    // Drawing code here.
//}

@end
