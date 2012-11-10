//
//  PSTCollectionViewUpdateItem.h
//  PSCollectionViewExample
//
//  Created by Sergey Gavrilyuk on 12-10-28.
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
{
    NSIndexPath *_initialIndexPath;
    NSIndexPath *_finalIndexPath;
    PSTCollectionUpdateAction _updateAction;
    id _gap;
}

@property(readonly) NSIndexPath * indexPathBeforeUpdate;
@property(readonly) NSIndexPath * indexPathAfterUpdate;
@property(readonly) PSTCollectionUpdateAction updateAction;


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
