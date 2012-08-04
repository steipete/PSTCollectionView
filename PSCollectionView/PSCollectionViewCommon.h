//
//  PSCollectionViewCommon.h
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class PSCollectionView;
@protocol PSCollectionViewDataSource, PSCollectionViewDelegate;

// Newer runtimes defines this, here's a fallback for the iOS5 SDK.
#ifndef NS_ENUM
#define NS_ENUM(_type, _name) _type _name; enum
#define NS_OPTIONS(_type, _name) _type _name; enum
#endif

// Category exists in iOS6.
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
@interface NSIndexPath (PSCollectionViewAdditions)
+ (NSIndexPath *)indexPathForItem:(NSInteger)item inSection:(NSInteger)section;
@property (nonatomic, readonly) NSInteger item;
@end
#endif

// compatibility
#ifndef kCFCoreFoundationVersionNumber_iOS_6_0
#define kCFCoreFoundationVersionNumber_iOS_6_0 788.0
#endif

// imp_implementationWithBlock changed it's type in iOS6.
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 60000
#define PSBlockImplCast (__bridge void *)
@interface NSObject (PSSubscriptingSupport)
- (id)objectAtIndexedSubscript:(NSUInteger)idx;
- (void)setObject:(id)obj atIndexedSubscript:(NSUInteger)idx;
- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key;
- (id)objectForKeyedSubscript:(id)key;
@end
#else
#define PSBlockImplCast
#endif
