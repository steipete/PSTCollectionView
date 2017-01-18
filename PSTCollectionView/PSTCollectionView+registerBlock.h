//
//  PSTCollectionView+registerBlocks.h
//
//  Copyright (c) 2012 Florian Agsteiner. All rights reserved.
//

#import <Foundation/NSObject.h>

/**
 *  Adds support to register blocks as a factory for cells and supplementary views
 *
 *  Example:
 *
 * [self.collectionView registerBlock:^id(NSString *identifier) {
 *      Cell* cell = [[Cell alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
 *      return cell;
 *    } forCellWithReuseIdentifier:@"MY_CELL"]
 *
 * Note: Referencing any object not retained by the collection view is safe because the deallocation of the view
 *       will unregister the blocks. But when you use a reference to the collectionView itself inside the block,
 *       it will result in an retaincycle. You can break the cycle by calling registerBlock with nil.
 */
@interface PSTCollectionView(registerBlock)

- (void)registerBlock:(id(^)(NSString* identifier))block forCellWithReuseIdentifier:(NSString *)identifier;
- (void)registerBlock:(id(^)(NSString* identifier))block forSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier;

@end
