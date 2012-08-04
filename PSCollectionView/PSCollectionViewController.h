//
//  PSCollectionViewController.h
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSCollectionViewCommon.h"
#import "PSCollectionView.h"

@class PSCollectionViewLayout, PSCollectionViewController;

@interface PSCollectionViewController : UIViewController <PSCollectionViewDelegate, PSCollectionViewDataSource>

- (id)initWithCollectionViewLayout:(PSCollectionViewLayout *)layout;

@property (nonatomic, strong) PSCollectionView *collectionView;

@property (nonatomic, assign) BOOL clearsSelectionOnViewWillAppear; // defaults to YES, and if YES, any selection is cleared in viewWillAppear:

@end
