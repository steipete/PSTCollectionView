//
//  PSCollectionViewItemKey.h
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PSCollectionViewLayoutAttributes;

typedef NS_ENUM(NSUInteger, PSCollectionViewItemType) {
    PSCollectionViewItemTypeCell,
    PSCollectionViewItemTypeDecorationView,
    PSCollectionViewItemTypeSupplementaryView
};

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
