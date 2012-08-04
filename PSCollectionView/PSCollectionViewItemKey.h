//
//  PSCollectionViewItemKey.h
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSCollectionViewCommon.h"
#import "PSCollectionViewLayout.h"

@class PSCollectionViewLayoutAttributes;

NSString *PSCollectionViewItemTypeToString(PSCollectionViewItemType type); // debug helper

// Used in NSDictionaries
@interface PSCollectionViewItemKey : NSObject <NSCopying>

+ (id)collectionItemKeyForLayoutAttributes:(PSCollectionViewLayoutAttributes *)layoutAttributes;
+ (id)collectionItemKeyForDecorationViewOfKind:(NSString *)elementKind andIndexPath:(NSIndexPath *)indexPath;
+ (id)collectionItemKeyForSupplementaryViewOfKind:(NSString *)elementKind andIndexPath:(NSIndexPath *)indexPath;
+ (id)collectionItemKeyForCellWithIndexPath:(NSIndexPath *)indexPath;

@property(nonatomic, assign) PSCollectionViewItemType type;
@property(nonatomic, strong) NSIndexPath *indexPath;
@property(nonatomic, strong) NSString *identifier;

@end
