//
//  PSCollectionViewCell.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSCollectionView.h"
#import "PSCollectionViewCell.h"
#import "PSCollectionViewLayout.h"

@interface PSCollectionReusableView() {
    struct {
        unsigned int inUpdateAnimation:1;
    } _reusableViewFlags;
}
@property (nonatomic, copy) NSString *reuseIdentifier;
@property (nonatomic, unsafe_unretained) PSCollectionView *collectionView;
@property (nonatomic, strong) PSCollectionViewLayoutAttributes *layoutAttributes;
@end

@implementation PSCollectionReusableView

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)prepareForReuse {
    self.layoutAttributes = nil;
}

- (void)applyLayoutAttributes:(PSCollectionViewLayoutAttributes *)layoutAttributes {
    if (layoutAttributes != _layoutAttributes) {
        _layoutAttributes = layoutAttributes;
        self.frame = layoutAttributes.frame;
        self.hidden = layoutAttributes.isHidden;
        self.layer.transform = layoutAttributes.transform3D;
        self.layer.zPosition = layoutAttributes.zIndex;
        // TODO more attributes
    }
}

- (void)willTransitionFromLayout:(PSCollectionViewLayout *)oldLayout toLayout:(PSCollectionViewLayout *)newLayout {
    _reusableViewFlags.inUpdateAnimation = YES;
}
- (void)didTransitionFromLayout:(PSCollectionViewLayout *)oldLayout toLayout:(PSCollectionViewLayout *)newLayout {
    _reusableViewFlags.inUpdateAnimation = NO;
}

- (BOOL)isInUpdateAnimation {
    return _reusableViewFlags.inUpdateAnimation;
}

- (void)setInUpdateAnimation:(BOOL)inUpdateAnimation {
    _reusableViewFlags.inUpdateAnimation = inUpdateAnimation;
}

@end


@implementation PSCollectionViewCell

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _backgroundView = [[UIView alloc] initWithFrame:self.bounds];
        _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_backgroundView];

        _contentView = [[UIView alloc] initWithFrame:self.bounds];
        _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_contentView];

        _menuGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(menuGesture:)];
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)setSelected:(BOOL)selected {
    if (_collectionCellFlags.selected != selected) {
        _collectionCellFlags.selected = selected;
        _selectedBackgroundView.alpha = selected ? 1.0f : 0.0f;
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    if (_collectionCellFlags.highlighted != highlighted) {
        _collectionCellFlags.highlighted = highlighted;
    }
}

- (void)menuGesture:(UILongPressGestureRecognizer *)recognizer {
    NSLog(@"Not yet implemented: %@", NSStringFromSelector(_cmd));
}

- (void)setBackgroundView:(UIView *)backgroundView
{
    if (_backgroundView != backgroundView) {
        [_backgroundView removeFromSuperview];
        _backgroundView = backgroundView;
        [self addSubview:_backgroundView];
        [self sendSubviewToBack:_backgroundView];
    }
}

- (void)setSelectedBackgroundView:(UIView *)selectedBackgroundView
{
    if (_selectedBackgroundView != selectedBackgroundView) {
        [_selectedBackgroundView removeFromSuperview];
        _selectedBackgroundView = selectedBackgroundView;
        _selectedBackgroundView.frame = self.bounds;
        _selectedBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _selectedBackgroundView.alpha = self.selected ? 1.0f : 0.0f;
        [self insertSubview:_selectedBackgroundView aboveSubview:_backgroundView];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSCollection/UICollection interoperability

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
            inv.selector = cleanedSelector;
            [inv invokeWithTarget:self];
        }
    }else {
        [super forwardInvocation:inv];
    }
}

@end