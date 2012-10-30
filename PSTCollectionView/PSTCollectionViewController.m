//
//  PSTCollectionViewController.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSTCollectionViewController.h"
#import "PSTCollectionView.h"

@interface PSTCollectionViewController () {
    PSTCollectionViewLayout *_layout;
    PSTCollectionView *_collectionView;
    struct {
        unsigned int clearsSelectionOnViewWillAppear : 1;
        unsigned int appearsFirstTime : 1; // PST exension!
    } _collectionViewControllerFlags;
}
@property (nonatomic, strong) PSTCollectionViewLayout* layout;
@end

@implementation PSTCollectionViewController

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
		self.layout = [PSUICollectionViewFlowLayout new];
        self.clearsSelectionOnViewWillAppear = YES;
        _collectionViewControllerFlags.appearsFirstTime = YES;
    }
    return self;
}

- (id)initWithCollectionViewLayout:(PSTCollectionViewLayout *)layout {
    if((self = [super init])) {
        self.layout = layout;
        self.clearsSelectionOnViewWillAppear = YES;
        _collectionViewControllerFlags.appearsFirstTime = YES;
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIViewController

- (void)loadView {
    [super loadView];

    // if this is restored from IB, we don't have plain main view.
    if ([self.view isKindOfClass:[PSTCollectionView class]]) {
        _collectionView = (PSTCollectionView *)self.view;
    }
	
	if (_collectionView.delegate == nil) _collectionView.delegate = self;
    if (_collectionView.dataSource == nil) _collectionView.dataSource = self;

    // only create the collection view if it is not already created (by IB)
    if (!_collectionView) {
        self.collectionView = [[PSTCollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:self.layout];
        self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:self.collectionView];
        self.collectionView.delegate = self;
        self.collectionView.dataSource = self;
    }
    // on low memory event, just re-attach the view.
    else if (self.view != self.collectionView) {
        [self.view addSubview:self.collectionView];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (_collectionViewControllerFlags.appearsFirstTime) {
        [_collectionView reloadData];
        _collectionViewControllerFlags.appearsFirstTime = NO;
    }
    
    if (_collectionViewControllerFlags.clearsSelectionOnViewWillAppear) {
        for (NSIndexPath* aIndexPath in [[_collectionView indexPathsForSelectedItems] copy]) {
            [_collectionView deselectItemAtIndexPath:aIndexPath animated:animated];
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Properties

- (void)setClearsSelectionOnViewWillAppear:(BOOL)clearsSelectionOnViewWillAppear {
    _collectionViewControllerFlags.clearsSelectionOnViewWillAppear = clearsSelectionOnViewWillAppear;
}

- (BOOL)clearsSelectionOnViewWillAppear {
    return _collectionViewControllerFlags.clearsSelectionOnViewWillAppear;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSTCollectionViewDataSource

- (NSInteger)collectionView:(PSTCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return 0;
}

- (PSTCollectionViewCell *)collectionView:(PSTCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

@end
