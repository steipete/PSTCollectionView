//
//  PSTCollectionViewController.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSTCollectionViewController.h"
#import "PSTCollectionView.h"

@interface PSTCollectionViewController () {
    struct {
        unsigned int clearsSelectionOnViewWillAppear:1;
    } _collectionViewControllerFlags;
}
@property (nonatomic, strong) PSTCollectionViewLayout* layout;
@property (nonatomic, assign) BOOL appearsFirstTime;
@end

@implementation PSTCollectionViewController

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithCollectionViewLayout:(PSTCollectionViewLayout *)layout {
    if((self = [super init])) {
        self.layout = layout;
        self.clearsSelectionOnViewWillAppear = YES;
        self.appearsFirstTime = YES;
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIViewController

- (void)awakeFromNib {
    [super awakeFromNib];
    if (_collectionView.delegate == nil) _collectionView.delegate = self;
    if (_collectionView.dataSource == nil) _collectionView.dataSource = self;
}

- (void)loadView {
    [super loadView];

    // if this is restored from IB, we don't have plain main view.
    if ([self.view isKindOfClass:[PSTCollectionView class]]) {
        _collectionView = (PSTCollectionView *)self.view;
    }

    // only create the collection view if it is not already created (by IB)
    if (!_collectionView) {
        self.collectionView = [[PSTCollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:self.layout];
        self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:self.collectionView];
        self.collectionView.delegate = self;
        self.collectionView.dataSource = self;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (_appearsFirstTime) {
        [_collectionView reloadData];
        self.appearsFirstTime = NO;
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
