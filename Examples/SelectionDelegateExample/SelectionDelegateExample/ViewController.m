//
//  ViewController.m
//  SelectionDelegateExample
//
//  Created by orta therox on 06/11/2012.
//  Copyright (c) 2012 orta therox. All rights reserved.
//

#import "ViewController.h"
#import "ImageGridCell.h"

CGSize CollectionViewCellSize = { .height = 140, .width = 180 };
NSString *CollectionViewCellIdentifier = @"SelectionDelegateExample";

@interface ViewController (){
    PSUICollectionView *_gridView;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self createGridView];

    UIBarButtonItem *toggleMultiSelectButton = [[UIBarButtonItem alloc] initWithTitle:@"Multi-Select" style:UIBarButtonItemStylePlain target:self action:@selector(toggleAllowsMultipleSelection:)];
    [self.navigationItem setRightBarButtonItem:toggleMultiSelectButton];
}

- (void)createGridView {
    PSUICollectionViewFlowLayout *layout = [[PSUICollectionViewFlowLayout alloc] init];
    _gridView = [[PSUICollectionView alloc] initWithFrame:[self.view bounds] collectionViewLayout:layout];
    _gridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _gridView.delegate = self;
    _gridView.dataSource = self;
    _gridView.backgroundColor = [UIColor colorWithRed:0.135 green:0.341 blue:0.000 alpha:1.000];
    [_gridView registerClass:[ImageGridCell class] forCellWithReuseIdentifier:CollectionViewCellIdentifier];

    [self.view addSubview:_gridView];
}

- (void)toggleAllowsMultipleSelection:(UIBarButtonItem *)item {
    _gridView.allowsMultipleSelection = !_gridView.allowsMultipleSelection;
    item.title = _gridView.allowsMultipleSelection ? @"Single-Select" : @"Multi-Select";
}

#pragma mark -
#pragma mark Collection View Data Source

- (PSUICollectionViewCell *)collectionView:(PSUICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ImageGridCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CollectionViewCellIdentifier forIndexPath:indexPath];
    cell.label.text = [NSString stringWithFormat:@"{%ld,%ld}", (long)indexPath.row, (long)indexPath.section];

    // load the image for this cell
    NSString *imageToLoad = [NSString stringWithFormat:@"%d.JPG", indexPath.row];
    cell.image.image = [UIImage imageNamed:imageToLoad];
    return cell;
}

- (CGSize)collectionView:(PSUICollectionView *)collectionView layout:(PSUICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CollectionViewCellSize;
}

- (NSInteger)collectionView:(PSUICollectionView *)view numberOfItemsInSection:(NSInteger)section {
    return 32;
}

#pragma mark -
#pragma mark Collection View Delegate

- (void)collectionView:(PSUICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"%@ - %@", NSStringFromSelector(_cmd), indexPath);
}

- (void)collectionView:(PSUICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"%@ - %@", NSStringFromSelector(_cmd), indexPath);
}

#pragma mark -
#pragma mark Collection View Menu Support

// These aren't yet supported in PSTCollectionView

- (BOOL)collectionView:(PSUICollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"%@ - %@", NSStringFromSelector(_cmd), indexPath);
    return YES;
}

- (BOOL)collectionView:(PSUICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    NSLog(@"%@ - %@", NSStringFromSelector(_cmd), NSStringFromSelector(action));
    return YES;
}

- (void)collectionView:(PSUICollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    NSLog(@"%@ - %@", NSStringFromSelector(_cmd), NSStringFromSelector(action));    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end
