//
//  ImageGridCell.m
//  SelectionDelegateExample
//
//  Created by orta therox on 06/11/2012.
//  Copyright (c) 2012 orta therox. All rights reserved.
//

#import "ImageGridCell.h"

static UIEdgeInsets ContentInsets = { .top = 10, .left = 6, .right = 6, .bottom = 0 };
static CGFloat SubTitleLabelHeight = 24;

@implementation ImageGridCell

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        UIView *background = [[UIView alloc] init];
        background.backgroundColor = [UIColor colorWithRed:0.109 green:0.419 blue:0.000 alpha:1.000];
        self.selectedBackgroundView = background;

        _image = [[UIImageView alloc] init];
        _image.contentMode = UIViewContentModeScaleAspectFit;

        _label = [[UILabel alloc] init];
        _label.textColor = [UIColor whiteColor];
        _label.textAlignment = UITextAlignmentCenter;
        _label.backgroundColor = [UIColor clearColor];

        [self.contentView addSubview:_image];
        [self.contentView addSubview:_label];
    }
    return self;
}

- (void)layoutSubviews {
    CGFloat imageHeight = CGRectGetHeight(self.bounds) - ContentInsets.top - SubTitleLabelHeight - ContentInsets.bottom;
    CGFloat imageWidth = CGRectGetWidth(self.bounds) - ContentInsets.left - ContentInsets.right;
    
    _image.frame = CGRectMake(ContentInsets.left, ContentInsets.top, imageWidth, imageHeight);
    _label.frame = CGRectMake(ContentInsets.left, CGRectGetMaxY(_image.frame), imageWidth, SubTitleLabelHeight);
}

- (void)setHighlighted:(BOOL)highlighted {
    NSLog(@"Cell %@ highlight: %@", _label.text, highlighted ? @"ON" : @"OFF");
    if (highlighted) {
        _label.backgroundColor = [UIColor yellowColor];
    }
    else {
        _label.backgroundColor = [UIColor underPageBackgroundColor];
    }
}

@end
