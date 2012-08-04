//
//  PSCollectionViewController.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSCollectionViewController.h"
#import "PSCollectionView.h"

@interface PSCollectionViewController () {
    struct {
        unsigned int clearsSelectionOnViewWillAppear:1;
    } _collectionViewControllerFlags;
}
@property (nonatomic, strong) PSCollectionViewLayout* layout;
@property (nonatomic, assign) BOOL appearsFirstTime;
@end

@implementation PSCollectionViewController

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithCollectionViewLayout:(PSCollectionViewLayout *)layout {
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
    self.collectionView = [[PSCollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:self.layout];
    [self.view addSubview:self.collectionView];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (_appearsFirstTime) {
        [_collectionView reloadData];
        self.appearsFirstTime = NO;
    }
    
    if (_collectionViewControllerFlags.clearsSelectionOnViewWillAppear) {
        for (NSIndexPath* aIndexPath in [_collectionView indexPathsForSelectedItems]) {
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
#pragma mark - PSCollectionViewDataSource

- (NSInteger)collectionView:(PSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return 0;
}

- (PSCollectionViewCell *)collectionView:(PSCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

@end
