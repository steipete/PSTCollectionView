//
//  PSTCollectionViewItemKey.m
//  PSPDFKit
//
//  Copyright (c) 2012-2013 Peter Steinberger. All rights reserved.
//

#import "PSTCollectionViewItemKey.h"
#import "PSTCollectionViewLayout.h"

NSString *const PSTCollectionElementKindCell = @"UICollectionElementKindCell";
NSString *const PSTCollectionElementKindDecorationView = @"PSTCollectionElementKindDecorationView";

@implementation PSTCollectionViewItemKey

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Static

+ (id)collectionItemKeyForCellWithIndexPath:(NSIndexPath *)indexPath {
    PSTCollectionViewItemKey *key = [[self class] new];
    key.indexPath = indexPath;
    key.type = PSTCollectionViewItemTypeCell;
    key.identifier = PSTCollectionElementKindCell;
    return key;
}

+ (id)collectionItemKeyForLayoutAttributes:(PSTCollectionViewLayoutAttributes *)layoutAttributes {
    PSTCollectionViewItemKey *key = [[self class] new];
    key.indexPath = layoutAttributes.indexPath;
    key.type = layoutAttributes.representedElementCategory;
    key.identifier = layoutAttributes.representedElementKind;
    return key;
}

// elementKind or reuseIdentifier?
+ (id)collectionItemKeyForDecorationViewOfKind:(NSString *)elementKind andIndexPath:(NSIndexPath *)indexPath {
    PSTCollectionViewItemKey *key = [[self class] new];
    key.indexPath = indexPath;
    key.type = PSTCollectionViewItemTypeDecorationView;
    key.identifier = elementKind;
    return key;
}

+ (id)collectionItemKeyForSupplementaryViewOfKind:(NSString *)elementKind andIndexPath:(NSIndexPath *)indexPath {
    PSTCollectionViewItemKey *key = [[self class] new];
    key.indexPath = indexPath;
    key.identifier = elementKind;
    key.type = PSTCollectionViewItemTypeSupplementaryView;
    return key;
}

NSString *PSTCollectionViewItemTypeToString(PSTCollectionViewItemType type) {
    switch (type) {
        case PSTCollectionViewItemTypeCell: return @"Cell";
        case PSTCollectionViewItemTypeDecorationView: return @"Decoration";
        case PSTCollectionViewItemTypeSupplementaryView: return @"Supplementary";
        default: return @"<INVALID>";
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p Type = %@ Identifier=%@ IndexPath = %@>", NSStringFromClass([self class]),
            self, PSTCollectionViewItemTypeToString(self.type), _identifier, self.indexPath];
}

- (NSUInteger)hash {
    return (([_indexPath hash] + _type) * 31) + [_identifier hash];
}

- (BOOL)isEqual:(id)other {
    if ([other isKindOfClass:[self class]]) {
        PSTCollectionViewItemKey *otherKeyItem = (PSTCollectionViewItemKey *)other;
        // identifier might be nil?
        if (_type == otherKeyItem.type && [_indexPath isEqual:otherKeyItem.indexPath] && ([_identifier isEqualToString:otherKeyItem.identifier] || _identifier == otherKeyItem.identifier)) {
            return YES;
            }
        }
    return NO;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PSTCollectionViewItemKey *itemKey = [[self class] new];
    itemKey.indexPath = self.indexPath;
    itemKey.type = self.type;
    itemKey.identifier = self.identifier;
    return itemKey;
}

@end
