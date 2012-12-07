//
//  INDGeometryAdditions.h
//  BasicExample
//
//  Created by Indragie Karunaratne on 2012-12-07.
//  Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import <Foundation/Foundation.h>

// Reimplementation of UIEdgeInsets

typedef struct {
    CGFloat top, left, bottom, right;
} INDEdgeInsets;

#define INDEdgeInsetsZero (INDEdgeInsets){0, 0, 0, 0}

NS_INLINE INDEdgeInsets INDEdgeInsetsMake(CGFloat top, CGFloat left, CGFloat bottom, CGFloat right) {
    return (INDEdgeInsets){top, left, bottom, right};
}

// NSString <-> Data type conversions

NS_INLINE NSString* INDNSStringFromCGRect(CGRect rect) {
    return NSStringFromRect(NSRectFromCGRect(rect));
}

NS_INLINE NSString* INDNSStringFromCGSize(CGSize size) {
    return NSStringFromSize(NSSizeFromCGSize(size));
}