//
//  INDCollectionViewUpdateItem.h
//
//  Original Source: Copyright (c) 2012 Peter Steinberger. All rights reserved.
//  AppKit Port: Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, INDCollectionUpdateAction) {
    INDCollectionUpdateActionInsert,
    INDCollectionUpdateActionDelete,
    INDCollectionUpdateActionReload,
    INDCollectionUpdateActionMove,
    INDCollectionUpdateActionNone
};

@interface INDCollectionViewUpdateItem : NSObject

@property (nonatomic, readonly, strong) NSIndexPath *indexPathBeforeUpdate; // nil for INDCollectionUpdateActionInsert
@property (nonatomic, readonly, strong) NSIndexPath *indexPathAfterUpdate;  // nil for INDCollectionUpdateActionDelete
@property (nonatomic, readonly, assign) INDCollectionUpdateAction updateAction;


- (id)initWithInitialIndexPath:(NSIndexPath*)arg1
                finalIndexPath:(NSIndexPath*)arg2
                  updateAction:(INDCollectionUpdateAction)arg3;

- (id)initWithAction:(INDCollectionUpdateAction)arg1
        forIndexPath:(NSIndexPath*)indexPath;

- (id)initWithOldIndexPath:(NSIndexPath*)arg1 newIndexPath:(NSIndexPath*)arg2;

- (INDCollectionUpdateAction)updateAction;

- (NSComparisonResult)compareIndexPaths:(INDCollectionViewUpdateItem*) otherItem;
- (NSComparisonResult)inverseCompareIndexPaths:(INDCollectionViewUpdateItem*) otherItem;

@end
