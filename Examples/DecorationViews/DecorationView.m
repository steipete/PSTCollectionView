//
//  DecorationView.m
//  PSCollectionViewExample
//
//  Created by Scott Talbot on 7/03/13.
//

#import "DecorationView.h"
#import "DecorationViewLayoutAttributes.h"


@implementation DecorationView

- (void)applyLayoutAttributes:(PSTCollectionViewLayoutAttributes *)layoutAttributes {
	DecorationViewLayoutAttributes *decorationAttributes = nil;
	if ([layoutAttributes isKindOfClass:[DecorationViewLayoutAttributes class]]) {
		decorationAttributes = (DecorationViewLayoutAttributes *)layoutAttributes;
	}

	UIColor * const backgroundColor = decorationAttributes.backgroundColor ?: [UIColor orangeColor];
	self.backgroundColor = [backgroundColor colorWithAlphaComponent:.5];
}

@end
