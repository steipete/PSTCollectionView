//
//  AppDelegate.m
//  BasicExample
//
//  Created by Indragie Karunaratne and Jonathan Willing on 2012-12-06.
//  Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import "AppDelegate.h"
#import "CollectionViewCell.h"

@interface AppDelegate()
@property (strong, nonatomic) INDCollectionView *collectionView;
@property (strong, nonatomic) NSArray *data;
@end

@implementation AppDelegate

static NSString *cellIdentifier = @"TestCell";
static NSString *headerViewIdentifier = @"Test Header View";
static NSString *footerViewIdentifier = @"Test Footer View";

- (void)awakeFromNib {	
	INDCollectionViewFlowLayout *collectionViewFlowLayout = [[INDCollectionViewFlowLayout alloc] init];
	
	[collectionViewFlowLayout setScrollDirection:INDCollectionViewScrollDirectionVertical];
	[collectionViewFlowLayout setItemSize:CGSizeMake(245, 250)];
	[collectionViewFlowLayout setHeaderReferenceSize:CGSizeMake(500, 30)];
	[collectionViewFlowLayout setFooterReferenceSize:CGSizeMake(500, 50)];
	[collectionViewFlowLayout setMinimumInteritemSpacing:10];
	[collectionViewFlowLayout setMinimumLineSpacing:10];
	//[collectionViewFlowLayout setSectionInset:UIEdgeInsetsMake(10, 0, 20, 0)];
	
	NSView *view = [self.window contentView];
	_collectionView = [[INDCollectionView alloc] initWithFrame:CGRectMake(floorf((CGRectGetWidth(view.bounds)-500)/2), 0, 500, CGRectGetHeight(view.bounds)) collectionViewLayout:collectionViewFlowLayout];
	[_collectionView setDataSource:self];
	[_collectionView setDelegate:self];
	//[_collectionView setAutoresizingMask:INDViewAutoresizingFlexibleHeight | INDViewAutoresizingFlexibleLeftMargin | INDViewAutoresizingFlexibleRightMargin];
	//[_collectionView setBackgroundColor:[NSColor redColor]];
	
	[_collectionView registerClass:[CollectionViewCell class] forCellWithReuseIdentifier:cellIdentifier];
	//[_collectionView registerClass:[HeaderView class] forSupplementaryViewOfKind:PSTCollectionElementKindSectionHeader withReuseIdentifier:headerViewIdentifier];
	//[_collectionView registerClass:[FooterView class] forSupplementaryViewOfKind:PSTCollectionElementKindSectionFooter withReuseIdentifier:footerViewIdentifier];
	
	[view addSubview:_collectionView];
	
	self.data = @[ @[@"One", @"Two", @"Three"], @[@"Four", @"Five", @"Six"], @[], @[@"Seven"], ];
}

- (NSInteger)numberOfSectionsInCollectionView:(INDCollectionView *)collectionView {
    return [self.data count];
}


- (NSInteger)collectionView:(INDCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [[self.data objectAtIndex:section] count];
}


- (INDCollectionViewCell *)collectionView:(INDCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    INDCollectionViewCell *cell = (INDCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    
    //UILabel *label = (UILabel *)[cell viewWithTag:123];
    //label.text  = [[self.data objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    return cell;
}

- (INDCollectionReusableView *)collectionView:(INDCollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
	NSString *identifier = nil;
	
	if ([kind isEqualToString:INDCollectionElementKindSectionHeader]) {
		identifier = headerViewIdentifier;
	} else if ([kind isEqualToString:INDCollectionElementKindSectionFooter]) {
		identifier = footerViewIdentifier;
	}
    INDCollectionReusableView *supplementaryView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:identifier forIndexPath:indexPath];
	
    // TODO Setup view
	
    return supplementaryView;
}

@end
