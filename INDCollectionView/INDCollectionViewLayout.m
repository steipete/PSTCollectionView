//
//  INDCollectionViewLayout.m
//
//  Original Source: Copyright (c) 2012 Peter Steinberger. All rights reserved.
//  AppKit Port: Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import "INDCollectionView.h"
#import "INDCollectionViewLayout.h"
#import "INDCollectionViewItemKey.h"
#import "INDCollectionViewData.h"
#import "INDCollectionViewUpdateItem.h"

@interface INDCollectionView()
- (id)currentUpdate;
- (NSDictionary *)visibleViewsDict;
- (INDCollectionViewData *)collectionViewData;
- (CGRect)visibleBoundRects; // visibleBounds is flagged as private API (wtf)
@end

@interface INDCollectionReusableView()
- (void)setIndexPath:(NSIndexPath *)indexPath;
@end

@interface INDCollectionViewUpdateItem()
- (BOOL)isSectionOperation;
@end

@interface INDCollectionViewLayoutAttributes() {
    struct {
        unsigned int isCellKind:1;
        unsigned int isDecorationView:1;
        unsigned int isHidden:1;
    } _layoutFlags;
}
@property (nonatomic, copy) NSString *elementKind;
@property (nonatomic, copy) NSString *reuseIdentifier;
@end

@interface INDCollectionViewUpdateItem()
-(NSIndexPath*) indexPath;
@end

@implementation INDCollectionViewLayoutAttributes

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Static

+ (instancetype)layoutAttributesForCellWithIndexPath:(NSIndexPath *)indexPath {
    INDCollectionViewLayoutAttributes *attributes = [self new];
    attributes.elementKind = INDCollectionElementKindCell;
    attributes.indexPath = indexPath;
    return attributes;
}

+ (instancetype)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind withIndexPath:(NSIndexPath *)indexPath {
    INDCollectionViewLayoutAttributes *attributes = [self new];
    attributes.elementKind = elementKind;
    attributes.indexPath = indexPath;
    return attributes;
}

+ (instancetype)layoutAttributesForDecorationViewWithReuseIdentifier:(NSString *)reuseIdentifier withIndexPath:(NSIndexPath *)indexPath {
    INDCollectionViewLayoutAttributes *attributes = [self new];
    attributes.elementKind = INDCollectionElementKindDecorationView;
    attributes.reuseIdentifier = reuseIdentifier;
    attributes.indexPath = indexPath;
    return attributes;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)init {
    if((self = [super init])) {
        _alpha = 1.f;
        _transform3D = CATransform3DIdentity;
    }
    return self;
}

- (NSUInteger)hash {
    return ([_elementKind hash] * 31) + [_indexPath hash];
}

- (BOOL)isEqual:(id)other {
    if ([other isKindOfClass:[self class]]) {
        INDCollectionViewLayoutAttributes *otherLayoutAttributes = (INDCollectionViewLayoutAttributes *)other;
        if ([_elementKind isEqual:otherLayoutAttributes.elementKind] && [_indexPath isEqual:otherLayoutAttributes.indexPath]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p frame:%@ indexPath:%@ elementKind:%@>", NSStringFromClass([self class]), self, NSStringFromCGRect(self.frame), self.indexPath, self.elementKind];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (INDCollectionViewItemType)representedElementCategory {
    if ([self.elementKind isEqualToString:INDCollectionElementKindCell]) {
        return INDCollectionViewItemTypeCell;
    }else if([self.elementKind isEqualToString:INDCollectionElementKindDecorationView]) {
        return INDCollectionViewItemTypeDecorationView;
    }else {
        return INDCollectionViewItemTypeSupplementaryView;
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (NSString *)representedElementKind {
    return self.elementKind;
}

- (BOOL)isDecorationView {
    return self.representedElementCategory == INDCollectionViewItemTypeDecorationView;
}

- (BOOL)isSupplementaryView {
    return self.representedElementCategory == INDCollectionViewItemTypeSupplementaryView;
}

- (BOOL)isCell {
    return self.representedElementCategory == INDCollectionViewItemTypeCell;
}

- (void)setSize:(CGSize)size {
    _size = size;
    _frame = (CGRect){_frame.origin, _size};
}

- (void)setCenter:(CGPoint)center {
    _center = center;
    _frame = (CGRect){{_center.x - _frame.size.width / 2, _center.y - _frame.size.height / 2}, _frame.size};
}

- (void)setFrame:(CGRect)frame {
    _frame = frame;
    _size = _frame.size;
    _center = (CGPoint){CGRectGetMidX(_frame), CGRectGetMidY(_frame)};
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    INDCollectionViewLayoutAttributes *layoutAttributes = [[self class] new];
    layoutAttributes.indexPath = self.indexPath;
    layoutAttributes.elementKind = self.elementKind;
    layoutAttributes.reuseIdentifier = self.reuseIdentifier;
    layoutAttributes.frame = self.frame;
    layoutAttributes.center = self.center;
    layoutAttributes.size = self.size;
    layoutAttributes.transform3D = self.transform3D;
    layoutAttributes.alpha = self.alpha;
    layoutAttributes.zIndex = self.zIndex;
    layoutAttributes.hidden = self.isHidden;
    return layoutAttributes;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - INDCollection/UICollection interoperability

#import <objc/runtime.h>
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = [super methodSignatureForSelector:selector];
    if(!signature) {
        NSString *selString = NSStringFromSelector(selector);
        if ([selString hasPrefix:@"_"]) {
            SEL cleanedSelector = NSSelectorFromString([selString substringFromIndex:1]);
            signature = [super methodSignatureForSelector:cleanedSelector];
        }
    }
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSString *selString = NSStringFromSelector([invocation selector]);
    if ([selString hasPrefix:@"_"]) {
        SEL cleanedSelector = NSSelectorFromString([selString substringFromIndex:1]);
        if ([self respondsToSelector:cleanedSelector]) {
            invocation.selector = cleanedSelector;
            [invocation invokeWithTarget:self];
        }
    }else {
        [super forwardInvocation:invocation];
    }
}

@end


@interface INDCollectionViewLayout() {
    __unsafe_unretained INDCollectionView *_collectionView;
    CGSize _collectionViewBoundsSize;
    NSMutableDictionary *_initialAnimationLayoutAttributesDict;
    NSMutableDictionary *_finalAnimationLayoutAttributesDict;
    NSMutableIndexSet *_deletedSectionsSet;
    NSMutableIndexSet *_insertedSectionsSet;
    NSMutableDictionary *_decorationViewClassDict;
    NSMutableDictionary *_decorationViewNibDict;
    NSMutableDictionary *_decorationViewExternalObjectsTables;
}
@property (nonatomic, unsafe_unretained) INDCollectionView *collectionView;
@end

NSString *const INDCollectionViewLayoutAwokeFromNib = @"INDCollectionViewLayoutAwokeFromNib";

@implementation INDCollectionViewLayout

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)init {
    if((self = [super init])) {
        _decorationViewClassDict = [NSMutableDictionary new];
        _decorationViewNibDict = [NSMutableDictionary new];
        _decorationViewExternalObjectsTables = [NSMutableDictionary new];
        _initialAnimationLayoutAttributesDict = [NSMutableDictionary new];
        _finalAnimationLayoutAttributesDict = [NSMutableDictionary new];
        _insertedSectionsSet = [NSMutableIndexSet new];
        _deletedSectionsSet = [NSMutableIndexSet new];

        [[NSNotificationCenter defaultCenter] postNotificationName:INDCollectionViewLayoutAwokeFromNib object:self];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
}

- (void)setCollectionView:(INDCollectionView *)collectionView {
    if (collectionView != _collectionView) {
        _collectionView = collectionView;
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Invalidating the Layout

- (void)invalidateLayout {
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return NO; // return YES to requery the layout for geometry information
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Providing Layout Attributes

- (void)prepareLayout {
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    return nil;
}

- (INDCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (INDCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (INDCollectionViewLayoutAttributes *)layoutAttributesForDecorationViewWithReuseIdentifier:(NSString*)identifier atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

// return a point at which to rest after scrolling - for layouts that want snap-to-point scrolling behavior
- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset withScrollingVelocity:(CGPoint)velocity {
    return proposedContentOffset;
}

- (CGSize)collectionViewContentSize {
    return CGSizeZero;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Responding to Collection View Updates

- (void)prepareForCollectionViewUpdates:(NSArray *)updateItems {
    NSDictionary* update = [_collectionView currentUpdate];

    for (INDCollectionReusableView *view in [[_collectionView visibleViewsDict] objectEnumerator]) {
        INDCollectionViewLayoutAttributes *attr = [view.layoutAttributes copy];

        INDCollectionViewData* oldModel = update[@"oldModel"];
        NSInteger index = [oldModel globalIndexForItemAtIndexPath:[attr indexPath]];

        if(index != NSNotFound) {
            index = [update[@"oldToNewIndexMap"][index] intValue];
            if(index != NSNotFound) {
                [attr setIndexPath:[update[@"newModel"] indexPathForItemAtGlobalIndex:index]];
                [_initialAnimationLayoutAttributesDict setObject:attr
                                                          forKey:[INDCollectionViewItemKey collectionItemKeyForLayoutAttributes:attr]];
            }
        }
    }

    INDCollectionViewData* collectionViewData = [_collectionView collectionViewData];

    CGRect bounds = [_collectionView visibleBoundRects];

    for (INDCollectionViewLayoutAttributes* attr in [collectionViewData layoutAttributesForElementsInRect:bounds]) {
        NSInteger index = [collectionViewData globalIndexForItemAtIndexPath:attr.indexPath];

        index = [update[@"newToOldIndexMap"][index] intValue];
        if(index != NSNotFound) {
            INDCollectionViewLayoutAttributes* finalAttrs = [attr copy];
            [finalAttrs setIndexPath:[update[@"oldModel"] indexPathForItemAtGlobalIndex:index]];
            [finalAttrs setAlpha:0];
            [_finalAnimationLayoutAttributesDict setObject:finalAttrs
                                                    forKey:[INDCollectionViewItemKey collectionItemKeyForLayoutAttributes:finalAttrs]];
        }
    }

    for(INDCollectionViewUpdateItem* updateItem in updateItems) {
        INDCollectionUpdateAction action = updateItem.updateAction;

        if([updateItem isSectionOperation]) {
            if(action == INDCollectionUpdateActionReload) {
                [_deletedSectionsSet addIndex:[[updateItem indexPathBeforeUpdate] section]];
                [_insertedSectionsSet addIndex:[updateItem indexPathAfterUpdate].section];
            }
            else {
                NSMutableIndexSet *indexSet = action == INDCollectionUpdateActionInsert ? _insertedSectionsSet : _deletedSectionsSet;
                [indexSet addIndex:[updateItem indexPath].section];
            }
        }
        else {
            if(action == INDCollectionUpdateActionDelete) {
                INDCollectionViewItemKey *key = [INDCollectionViewItemKey collectionItemKeyForCellWithIndexPath:
                                                 [updateItem indexPathBeforeUpdate]];

                INDCollectionViewLayoutAttributes *attrs = [[_finalAnimationLayoutAttributesDict objectForKey:key]copy];

                if(attrs) {
                    [attrs setAlpha:0];
                    [_finalAnimationLayoutAttributesDict setObject:attrs
                                                            forKey:key];
                }
            }
            else if(action == INDCollectionUpdateActionReload || action == INDCollectionUpdateActionInsert) {
                INDCollectionViewItemKey *key = [INDCollectionViewItemKey collectionItemKeyForCellWithIndexPath:
                                                 [updateItem indexPathAfterUpdate]];
                INDCollectionViewLayoutAttributes *attrs = [[_initialAnimationLayoutAttributesDict objectForKey:key] copy];

                if(attrs) {
                    [attrs setAlpha:0];
                    [_initialAnimationLayoutAttributesDict setObject:attrs forKey:key];
                }
            }
        }
    }
}

- (INDCollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath*)itemIndexPath {
    INDCollectionViewLayoutAttributes* attrs = [_initialAnimationLayoutAttributesDict objectForKey:
                                                [INDCollectionViewItemKey collectionItemKeyForCellWithIndexPath:itemIndexPath]];

    if([_insertedSectionsSet containsIndex:[itemIndexPath section]]) {
        attrs = [attrs copy];
        [attrs setAlpha:0];
    }
    return attrs;
}

- (INDCollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)itemIndexPath {
    INDCollectionViewLayoutAttributes* attrs = [_finalAnimationLayoutAttributesDict objectForKey:
                                                [INDCollectionViewItemKey collectionItemKeyForCellWithIndexPath:itemIndexPath]];

    if([_deletedSectionsSet containsIndex:[itemIndexPath section]]) {
        attrs = [attrs copy];
        [attrs setAlpha:0];
    }
    return attrs;

}

- (INDCollectionViewLayoutAttributes *)initialLayoutAttributesForInsertedSupplementaryElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)elementIndexPath {
    return nil;
}

- (INDCollectionViewLayoutAttributes *)finalLayoutAttributesForDeletedSupplementaryElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)elementIndexPath {
    return nil;
}

- (void)finalizeCollectionViewUpdates {
    [_initialAnimationLayoutAttributesDict removeAllObjects];
    [_finalAnimationLayoutAttributesDict removeAllObjects];
    [_deletedSectionsSet removeAllIndexes];
    [_insertedSectionsSet removeAllIndexes];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Registering Decoration Views

- (void)registerClass:(Class)viewClass forDecorationViewWithReuseIdentifier:(NSString *)identifier {
}

- (void)registerNib:(UINib *)nib forDecorationViewWithReuseIdentifier:(NSString *)identifier {
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (void)setCollectionViewBoundsSize:(CGSize)size {
    _collectionViewBoundsSize = size;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    if((self = [self init])) {
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - INDCollection/UICollection interoperability

#ifdef kPSUIInteroperabilityEnabled
#import <objc/runtime.h>
#import <objc/message.h>
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *sig = [super methodSignatureForSelector:selector];
    if(!sig) {
        NSString *selString = NSStringFromSelector(selector);
        if ([selString hasPrefix:@"_"]) {
            SEL cleanedSelector = NSSelectorFromString([selString substringFromIndex:1]);
            sig = [super methodSignatureForSelector:cleanedSelector];
        }
    }
    return sig;
}

- (void)forwardInvocation:(NSInvocation *)inv {
    NSString *selString = NSStringFromSelector([inv selector]);
    if ([selString hasPrefix:@"_"]) {
        SEL cleanedSelector = NSSelectorFromString([selString substringFromIndex:1]);
        if ([self respondsToSelector:cleanedSelector]) {
            // dynamically add method for faster resolving
            Method newMethod = class_getInstanceMethod([self class], [inv selector]);
            IMP underscoreIMP = imp_implementationWithBlock(PSBlockImplCast(^(id _self) {
                return objc_msgSend(_self, cleanedSelector);
            }));
            class_addMethod([self class], [inv selector], underscoreIMP, method_getTypeEncoding(newMethod));
            // invoke now
            inv.selector = cleanedSelector;
            [inv invokeWithTarget:self];
        }
    }else {
        [super forwardInvocation:inv];
    }
}
#endif

@end
