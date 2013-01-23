//
//  UILabel+Highlight.m
//  SelectionDelegateExample
//
//  Created by Eric Chen on 1/21/13.
//  Copyright (c) 2013 orta therox. All rights reserved.
//

#import "UILabel+Highlight.h"

@implementation UILabel (Highlight)

- (void)setHighlighted:(BOOL)highlighted
{
    NSLog(@"Label %@ highlight: %@", self.text, highlighted ? @"ON" : @"OFF");
}

@end
