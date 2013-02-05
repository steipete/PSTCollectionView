//
//  NSIndexPath+PSTCollectionViewAdditions.h
//  PSTCollectionView
//
//  Copyright (c) 2013 Peter Steinberger. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface NSIndexPath (PSTCollectionViewAdditions)

+ (NSIndexPath *)indexPathForItem:(NSInteger)item inSection:(NSInteger)section;

- (NSInteger)item;

@end
