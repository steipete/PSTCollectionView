//
//  ViewController.m
//  CollectionExample
//
//  Created by Barry Haanstra on 19-10-12.
//  Copyright (c) 2012 Haanstra. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController {
    NSArray *data;
}

static NSString *cellIdentifier = @"TestCell";
static NSString *headerViewIdentifier = @"Test Header View";
static NSString *footerViewIdentifier = @"Test Footer View";


#pragma mark -
#pragma mark Rotation stuff

- (BOOL)shouldAutorotate {
    return YES;
}


- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}


- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationLandscapeLeft;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    if ((orientation == UIInterfaceOrientationLandscapeRight) || (orientation == UIInterfaceOrientationLandscapeLeft)) {
        return YES;
    }
    
    return NO;
}


#pragma mark -
#pragma mark Setup

- (void)viewDidLoad {
    [super viewDidLoad];

    data = @[
        @[@"One", @"Two", @"Three"],
        @[@"Four", @"Five", @"Six"],
		@[],
		@[@"Seven"],
    ];
}


#pragma mark -
#pragma mark PSUICollectionView stuff

- (NSInteger)numberOfSectionsInCollectionView:(PSUICollectionView *)collectionView {
    return [data count];
}


- (NSInteger)collectionView:(PSUICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [[data objectAtIndex:section] count];
}


- (PSUICollectionViewCell *)collectionView:(PSUICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PSUICollectionViewCell *cell = (PSUICollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    
    UILabel *label = (UILabel *)[cell viewWithTag:123];
    label.text  = [[data objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    return cell;
}

- (PSUICollectionReusableView *)collectionView:(PSUICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
	NSString *identifier = nil;
	
	if ([kind isEqualToString:PSTCollectionElementKindSectionHeader]) {
		identifier = headerViewIdentifier;
	} else if ([kind isEqualToString:PSTCollectionElementKindSectionFooter]) {
		identifier = footerViewIdentifier;
	}
    PSUICollectionReusableView *supplementaryView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:identifier forIndexPath:indexPath];

    // TODO Setup view

    return supplementaryView;
}

@end
