//
//  ViewController.m
//  FlowLayoutNoNIB
//
//  Created by Beau G. Bolle on 2012.10.29.
//
//

#import "ViewController.h"
#import "CollectionViewCell.h"
#import "HeaderView.h"
#import "FooterView.h"

@interface ViewController ()

@property (strong, nonatomic) PSUICollectionView *collectionView;

@end


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

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)loadView {
	[super loadView];
	
	self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
	
	PSUICollectionViewFlowLayout *collectionViewFlowLayout = [[PSUICollectionViewFlowLayout alloc] init];
	
	[collectionViewFlowLayout setScrollDirection:UICollectionViewScrollDirectionVertical];
	[collectionViewFlowLayout setItemSize:CGSizeMake(245, 250)];
	[collectionViewFlowLayout setHeaderReferenceSize:CGSizeMake(500, 30)];
	[collectionViewFlowLayout setFooterReferenceSize:CGSizeMake(500, 50)];
	[collectionViewFlowLayout setMinimumInteritemSpacing:10];
	[collectionViewFlowLayout setMinimumLineSpacing:10];
	[collectionViewFlowLayout setSectionInset:UIEdgeInsetsMake(10, 0, 20, 0)];
	
	_collectionView = [[PSUICollectionView alloc] initWithFrame:CGRectMake(floorf((CGRectGetWidth(self.view.bounds)-500)/2), 0, 500, CGRectGetHeight(self.view.bounds)) collectionViewLayout:collectionViewFlowLayout];
	[_collectionView setDelegate:self];
	[_collectionView setDataSource:self];
	[_collectionView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
	[_collectionView setBackgroundColor:[UIColor redColor]];
	
	[_collectionView registerClass:[CollectionViewCell class] forCellWithReuseIdentifier:cellIdentifier];
	[_collectionView registerClass:[HeaderView class] forSupplementaryViewOfKind:PSTCollectionElementKindSectionHeader withReuseIdentifier:headerViewIdentifier];
	[_collectionView registerClass:[FooterView class] forSupplementaryViewOfKind:PSTCollectionElementKindSectionFooter withReuseIdentifier:footerViewIdentifier];
	
	[self.view addSubview:_collectionView];
}

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
