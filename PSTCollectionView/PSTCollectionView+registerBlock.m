//
//  PSTCollectionView+registerBlocks.m
//
//  Copyright (c) 2012 Florian Agsteiner. All rights reserved.
//

#import "PSTCollectionView.h"

#import <objc/runtime.h>

/**
 *  The block class host will create a runtime class, that will call the block instead of the initializer.
 *  This method and allows to intercept the object creation of registerClass and use your own initialisation.
 */
@interface BlockClassHost : NSObject{
@private
    /**
     *  The dynamically created class (it will be disposed together with the class host)
     */
    Class _clazz;

    /**
     *  The block to be executed when a object is requested
     */
    id(^_block)(NSString* identifier);

    /**
     *  The reuseIdentifier used
     */
    NSString* _identifier;
}

+ (BlockClassHost*) blockClassHostForBlock:(id(^)(NSString* identifier))block objectClass:(Class)objectClass identifier:(id)identifier;

/**
 *  The dynamically created class (it will be disposed together with the class host)
 */
@property(nonatomic, weak, readonly) Class clazz;

/**
 *  The block to be executed when a object is requested
 */
@property(nonatomic, copy, readonly) id (^ block )(NSString* identifier);

/**
 *  The reuseIdentifier used
 */
@property(nonatomic, copy, readonly) NSString * identifier;

@end

@implementation BlockClassHost

- (id) initWithClass:(Class)clazz block:(id(^)(NSString* identifier))block identifier:(id)identifier{
    self = [super init];
    if (self) {
        self->_clazz = clazz;
        self->_block = [block copy];
        self->_identifier = [identifier copy];
    }
    return self;
}

/**
 *  We will add this init method to our custom class to intercept the initialisation
 */
id functionInit(id self, SEL _cmd);

id functionInit(id self, SEL _cmd){
    BlockClassHost* classHost = objc_getAssociatedObject([self class], @selector(BlockClassHost));
    id result = nil;

    if (classHost.block != nil) {
        result = classHost.block(classHost.identifier);
        if (result == nil) {
            @throw [NSException exceptionWithName:@"Object was not created"
                                           reason:[NSString stringWithFormat:@"Block for reuseIdentifier '%@' did not return an instance!",classHost.identifier]
                                         userInfo:nil];
        }

        CFBridgingRetain(result);
        // Keep ClassHost retained until each object is released
        objc_setAssociatedObject(result, @selector(BlockClassHost), classHost, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    CFBridgingRelease((__bridge CFTypeRef)(self));

    return result;
}

/**
 *  We will add this initWithFrame method to our custom class to intercept the initialisation
 */
id functionInitWithFrame(id self, SEL _cmd, CGRect frame);

id functionInitWithFrame(id self, SEL _cmd, CGRect frame){
    return functionInit(self, _cmd);
}

+ (BlockClassHost*) blockClassHostForBlock:(id(^)(NSString* identifier))block objectClass:(Class)objectClass identifier:(id)identifier{
    if (identifier == nil) {
        identifier = NSStringFromClass(objectClass);
    }

    static NSUInteger classNumber = 0;

    // Create a unique classname each time
    NSString* className = [NSString stringWithFormat:@"%@%@%d", identifier, NSStringFromClass([self class]),classNumber];
    classNumber ++;

    Class clazz = NSClassFromString(className);

    if (clazz == nil) {
        // Create custom class and add init methods
        clazz = objc_allocateClassPair(objectClass, [className UTF8String], 0);

        class_addMethod(clazz, @selector(init), (IMP)functionInit, "v@:");
        class_addMethod(clazz, @selector(initWithFrame:), (IMP)functionInitWithFrame, "v@:");

        objc_registerClassPair(clazz);
    }
    else{
        @throw [NSException exceptionWithName:@"Block cound not be registered"
                                       reason:[NSString stringWithFormat:@"Classname already in use '%@', this should never happen",className]
                                     userInfo:nil];
    }

    BlockClassHost* classHost = [[BlockClassHost alloc] initWithClass:clazz block:block identifier:identifier];
    // Only assign to avoid retain cycle
    objc_setAssociatedObject(clazz, @selector(BlockClassHost), classHost, OBJC_ASSOCIATION_ASSIGN);

    return classHost;
}

- (void) dealloc {
    objc_disposeClassPair(self->_clazz);

    self->_identifier = nil;
    self->_block = nil;

    self->_clazz = nil;
}

- (NSString*) identifier {
    return self->_identifier;
}

- (Class) clazz {
    return self->_clazz;
}

- (id (^)(NSString* identifier)) block {
    return self->_block;
}

@end

@implementation PSTCollectionView (registerBlock)

- (void)registerBlock:(id(^)(NSString* identifier))block forCellWithReuseIdentifier:(NSString *)identifier{
    BlockClassHost* blockClassHost = nil;

    if (identifier != nil) {
        blockClassHost = [BlockClassHost blockClassHostForBlock:block objectClass:[PSTCollectionReusableView class] identifier:identifier];
    }

    [self registerClass:blockClassHost.clazz forCellWithReuseIdentifier:identifier];

    // Set or remove
    objc_setAssociatedObject(self, NSSelectorFromString(identifier), blockClassHost, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)registerBlock:(id(^)(NSString* identifier))block forSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier{
    BlockClassHost* blockClassHost = nil;

    if (identifier != nil) {
        blockClassHost = [BlockClassHost blockClassHostForBlock:block objectClass:[PSTCollectionReusableView class] identifier:identifier];
    }

    [self registerClass:blockClassHost.clazz forSupplementaryViewOfKind:elementKind withReuseIdentifier:identifier];

    // Set or remove
    objc_setAssociatedObject(self, NSSelectorFromString(identifier), blockClassHost, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
