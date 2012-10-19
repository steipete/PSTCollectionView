//
//  ViewController.h
//  CollectionExample
//
//  Created by Barry Haanstra on 19-10-12.
//  Copyright (c) 2012 Haanstra. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PSTCollectionView.h"

@interface ViewController : UIViewController <PSUICollectionViewDataSource, PSUICollectionViewDelegate>

@property (weak, nonatomic) IBOutlet PSUICollectionView *collectionView;

@end
