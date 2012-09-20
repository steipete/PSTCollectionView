//
//  ViewController.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "ViewController.h"
#import "Cell.h"

@implementation ViewController

- (void)viewDidLoad {
    //UIPinchGestureRecognizer* pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    //[self.collectionView addGestureRecognizer:pinchRecognizer];
    [self.collectionView registerClass:[Cell class] forCellWithReuseIdentifier:@"MY_CELL"];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSTCollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {
    return 63;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSTCollectionViewDelegate

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    Cell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"MY_CELL" forIndexPath:indexPath];
    return (UICollectionViewCell *)cell;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSTCollectionViewDelegateFlowLayout

- (CGSize)collectionView:(PSTCollectionView *)collectionView layout:(PSTCollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(200, 200);
}

- (CGFloat)collectionView:(PSTCollectionView *)collectionView layout:(PSTCollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

- (CGFloat)collectionView:(PSTCollectionView *)collectionView layout:(PSTCollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 50;
}

@end
