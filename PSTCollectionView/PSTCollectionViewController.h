//
//  PSTCollectionViewController.h
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSTCollectionViewCommon.h"

@class PSTCollectionViewLayout, PSTCollectionViewController;

@interface PSTCollectionViewController : UIViewController <PSTCollectionViewDelegate, PSTCollectionViewDataSource>

- (id)initWithCollectionViewLayout:(PSTCollectionViewLayout *)layout;

@property (nonatomic, strong) PSTCollectionView *collectionView;

@property (nonatomic, assign) BOOL clearsSelectionOnViewWillAppear; // defaults to YES, and if YES, any selection is cleared in viewWillAppear:

@end
