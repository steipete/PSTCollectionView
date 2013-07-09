//
//  CollectionViewLayout.m
//  PSCollectionViewExample
//
//  Created by Scott Talbot on 7/03/13.
//

#import "CollectionViewLayout.h"
#import "DecorationViewLayoutAttributes.h"
#import "DecorationView.h"

@implementation CollectionViewLayout

- (id)init {
	if ((self = [super init])) {
		[self registerClass:[DecorationView class] forDecorationViewOfKind:@"DecorationView1"];
		[self registerClass:[DecorationView class] forDecorationViewOfKind:@"DecorationView2"];
	}
	return self;
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
	NSMutableArray *layoutAttributes = [NSMutableArray arrayWithArray:[super layoutAttributesForElementsInRect:rect]];

	CGSize const collectionViewContentSize = self.collectionViewContentSize;

	{
		DecorationViewLayoutAttributes *attributes = [DecorationViewLayoutAttributes layoutAttributesForDecorationViewOfKind:@"DecorationView1" withIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
		attributes.frame = (CGRect){
			.size.width = collectionViewContentSize.width / 2.,
			.size.height = collectionViewContentSize.height
		};
		attributes.backgroundColor = [UIColor redColor];
		[layoutAttributes addObject:attributes];
	}
	{
		DecorationViewLayoutAttributes *attributes = [DecorationViewLayoutAttributes layoutAttributesForDecorationViewOfKind:@"DecorationView2" withIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
		attributes.frame = (CGRect){
			.origin.x = collectionViewContentSize.width / 2.,
			.size.width = collectionViewContentSize.width / 2.,
			.size.height = collectionViewContentSize.height
		};
		attributes.backgroundColor = [UIColor blueColor];
		[layoutAttributes addObject:attributes];
	}

	return layoutAttributes;
}

- (PSTCollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
	CGSize const collectionViewContentSize = self.collectionViewContentSize;

	if ([@"DecorationView1" isEqualToString:kind]) {
		DecorationViewLayoutAttributes *attributes = [DecorationViewLayoutAttributes layoutAttributesForDecorationViewOfKind:kind withIndexPath:indexPath];
		attributes.frame = (CGRect){
			.size.width = collectionViewContentSize.width / 2.,
			.size.height = collectionViewContentSize.height
		};
		attributes.backgroundColor = [UIColor redColor];
		return attributes;
	}

	if ([@"DecorationView2" isEqualToString:kind]) {
		DecorationViewLayoutAttributes *attributes = [DecorationViewLayoutAttributes layoutAttributesForDecorationViewOfKind:kind withIndexPath:indexPath];
		attributes.frame = (CGRect){
			.origin.x = collectionViewContentSize.width / 2.,
			.size.width = collectionViewContentSize.width / 2.,
			.size.height = collectionViewContentSize.height
		};
		attributes.backgroundColor = [UIColor redColor];
		return attributes;
	}

	return nil;
}

@end
