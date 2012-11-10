//
//              
//  PSCollectionViewExample
//
//  Created by Sergey Gavrilyuk on 12-10-28.
//

#import "PSTCollectionViewUpdateItem.h"

@interface PSTCollectionViewUpdateItem()

- (void)setNewIndexPath:(NSIndexPath*)arg1;
- (void)setGap:(id)arg1;
- (BOOL)isSectionOperation;
- (NSIndexPath*)newIndexPath;
- (id)gap;
- (PSTCollectionUpdateAction)action;
- (NSIndexPath*)indexPath;
@end

@implementation PSTCollectionViewUpdateItem
@synthesize updateAction = _updateAction;
@synthesize indexPathBeforeUpdate = _initialIndexPath;
@synthesize indexPathAfterUpdate = _finalIndexPath;


- (id)initWithInitialIndexPath:(NSIndexPath*)initialIndexPath
                finalIndexPath:(NSIndexPath*)finalIndexPath
                  updateAction:(PSTCollectionUpdateAction)updateAction
{
    self = [super init];
    if(self)
    {
        _initialIndexPath = initialIndexPath;
        _finalIndexPath = finalIndexPath;
        _updateAction = updateAction;
    }
    return self;
}

- (id)initWithAction:(PSTCollectionUpdateAction)updateAction
        forIndexPath:(NSIndexPath*)indexPath
{
    if(updateAction == PSTCollectionUpdateActionInsert)
        return [self initWithInitialIndexPath:nil
                               finalIndexPath:indexPath
                                 updateAction:updateAction];
    else if(updateAction == PSTCollectionUpdateActionDelete)
        return [self initWithInitialIndexPath:indexPath
                               finalIndexPath:nil                                
                                 updateAction:updateAction];
    else if(updateAction == PSTCollectionUpdateActionReload)
        return [self initWithInitialIndexPath:indexPath
                               finalIndexPath:indexPath
                                 updateAction:updateAction];

    
    return nil;
}


- (id)initWithOldIndexPath:(NSIndexPath*)arg1
              newIndexPath:(NSIndexPath*)arg2
{
    return [self initWithInitialIndexPath:arg1
                           finalIndexPath:arg2
                             updateAction:PSTCollectionUpdateActionMove];
}

- (NSString*)description
{
    NSString* action = nil;
    switch (_updateAction)
    {
        case PSTCollectionUpdateActionInsert:
            action = @"insert";
            break;
        case PSTCollectionUpdateActionDelete:
            action = @"delete";
            break;
        case PSTCollectionUpdateActionMove:
            action = @"move";
            break;
        case PSTCollectionUpdateActionReload:
            action = @"reload";
            break;
            
        default:
            break;
    }
    
    return [NSString stringWithFormat:@"index path before update (%@) index path after update (%@) action (%@)",
            _initialIndexPath,
            _finalIndexPath,
            action];
    
}


- (void) setNewIndexPath:(NSIndexPath*)indexPath
{
    _finalIndexPath = indexPath;
}

- (void)setGap:(id)arg1
{
    _gap = arg1;
}

- (BOOL) isSectionOperation
{
    return (_initialIndexPath.item == NSNotFound || _finalIndexPath.item == NSNotFound);
}

- (id) newIndexPath
{
    return _finalIndexPath;
}

- (id) gap
{
    return _gap;
}

- (PSTCollectionUpdateAction) action
{
    return _updateAction;
}

- (id)indexPath
{
//TODO:check this
    return _initialIndexPath;
}

- (NSComparisonResult)compareIndexPaths:(PSTCollectionViewUpdateItem*)otherItem
{
    NSComparisonResult result = NSOrderedSame;
    NSIndexPath* selfIndexPath = nil;
    NSIndexPath* otherIndexPath = nil;
    switch (_updateAction)
    {
        case PSTCollectionUpdateActionInsert:
            selfIndexPath = _finalIndexPath;
            otherIndexPath = [otherItem newIndexPath];
            break;
        case PSTCollectionUpdateActionDelete:
            selfIndexPath = _initialIndexPath;
            otherIndexPath = [otherItem indexPath];
        default:
            break;
    }
    if(self.isSectionOperation)
        result = [[NSNumber numberWithInt:selfIndexPath.section] compare:
                   [NSNumber numberWithInt:otherIndexPath.section]];
    else
        result = [selfIndexPath compare:otherIndexPath];
    return result;
}

- (NSComparisonResult)inverseCompareIndexPaths:(PSTCollectionViewUpdateItem*)otherItem
{
    return (NSComparisonResult) ([self compareIndexPaths:otherItem]*-1);
}

@end
