//
//  PSTCollectionViewUpdateItem.h
//
//  Original Source: Copyright (c) 2012 Peter Steinberger. All rights reserved.
//  AppKit Port: Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PSTCollectionUpdateAction) {
    PSTCollectionUpdateActionInsert,
    PSTCollectionUpdateActionDelete,
    PSTCollectionUpdateActionReload,
    PSTCollectionUpdateActionMove,
    PSTCollectionUpdateActionNone
};

@interface PSTCollectionViewUpdateItem : NSObject

@property (nonatomic, readonly, strong) NSIndexPath *indexPathBeforeUpdate; // nil for PSTCollectionUpdateActionInsert
@property (nonatomic, readonly, strong) NSIndexPath *indexPathAfterUpdate;  // nil for PSTCollectionUpdateActionDelete
@property (nonatomic, readonly, assign) PSTCollectionUpdateAction updateAction;


- (id)initWithInitialIndexPath:(NSIndexPath*)arg1
                finalIndexPath:(NSIndexPath*)arg2
                  updateAction:(PSTCollectionUpdateAction)arg3;

- (id)initWithAction:(PSTCollectionUpdateAction)arg1
        forIndexPath:(NSIndexPath*)indexPath;

- (id)initWithOldIndexPath:(NSIndexPath*)arg1 newIndexPath:(NSIndexPath*)arg2;

- (PSTCollectionUpdateAction)updateAction;

- (NSComparisonResult)compareIndexPaths:(PSTCollectionViewUpdateItem*) otherItem;
- (NSComparisonResult)inverseCompareIndexPaths:(PSTCollectionViewUpdateItem*) otherItem;

@end
