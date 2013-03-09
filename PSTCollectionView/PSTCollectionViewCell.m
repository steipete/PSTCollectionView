//
//  PSTCollectionViewCell.m
//  PSPDFKit
//
//  Copyright (c) 2012-2013 Peter Steinberger. All rights reserved.
//

#import "PSTCollectionView.h"
#import "PSTCollectionViewCell.h"
#import "PSTCollectionViewLayout.h"

@interface PSTCollectionReusableView() {
    PSTCollectionViewLayoutAttributes *_layoutAttributes;
    NSString *_reuseIdentifier;
    __unsafe_unretained PSTCollectionView *_collectionView;
    struct {
        unsigned int inUpdateAnimation : 1;
    } _reusableViewFlags;
}
@property (nonatomic, copy) NSString *reuseIdentifier;
@property (nonatomic, unsafe_unretained) PSTCollectionView *collectionView;
@property (nonatomic, strong) PSTCollectionViewLayoutAttributes *layoutAttributes;
@end

@implementation PSTCollectionReusableView

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if((self = [super initWithCoder:aDecoder])) {
    }
    return self;
}

- (void)awakeFromNib {
    self.reuseIdentifier = [self valueForKeyPath:@"reuseIdentifier"];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)prepareForReuse {
    self.layoutAttributes = nil;
}

- (void)applyLayoutAttributes:(PSTCollectionViewLayoutAttributes *)layoutAttributes {
    if (layoutAttributes != _layoutAttributes) {
        _layoutAttributes = layoutAttributes;

        self.frame = CGRectApplyAffineTransform(layoutAttributes.frame, CATransform3DGetAffineTransform(layoutAttributes.transform3D));
        self.center = layoutAttributes.center;

        self.hidden = layoutAttributes.isHidden;
        self.layer.transform = layoutAttributes.transform3D;
        self.layer.zPosition = layoutAttributes.zIndex;
        self.layer.opacity = layoutAttributes.alpha;
        // TODO more attributes
    }
}

- (void)willTransitionFromLayout:(PSTCollectionViewLayout *)oldLayout toLayout:(PSTCollectionViewLayout *)newLayout {
    _reusableViewFlags.inUpdateAnimation = YES;
}

- (void)didTransitionFromLayout:(PSTCollectionViewLayout *)oldLayout toLayout:(PSTCollectionViewLayout *)newLayout {
    _reusableViewFlags.inUpdateAnimation = NO;
}

- (BOOL)isInUpdateAnimation {
    return _reusableViewFlags.inUpdateAnimation;
}

- (void)setInUpdateAnimation:(BOOL)inUpdateAnimation {
    _reusableViewFlags.inUpdateAnimation = inUpdateAnimation;
}

@end


@implementation PSTCollectionViewCell {
    UIView *_contentView;
    UIView *_backgroundView;
    UIView *_selectedBackgroundView;
    UILongPressGestureRecognizer *_menuGesture;
    id _selectionSegueTemplate;
    id _highlightingSupport;
    struct {
        unsigned int selected : 1;
        unsigned int highlighted : 1;
        unsigned int showingMenu : 1;
        unsigned int clearSelectionWhenMenuDisappears : 1;
        unsigned int waitingForSelectionAnimationHalfwayPoint : 1;
    } _collectionCellFlags;
    BOOL _selected;
    BOOL _highlighted;
}

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

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        if ([[self subviews] count] > 0) {
            _contentView = [self subviews][0];
        } else {
            _contentView = [[UIView alloc] initWithFrame:self.bounds];
            _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self addSubview:_contentView];
        }
        
        _backgroundView = [[UIView alloc] initWithFrame:self.bounds];
        _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self insertSubview:_backgroundView belowSubview:_contentView];
        
        _menuGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(menuGesture:)];
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)prepareForReuse {
    self.layoutAttributes = nil;
    self.selected = NO;
    self.highlighted = NO;
}

// Selection highlights underlying contents
- (void)setSelected:(BOOL)selected {
    _collectionCellFlags.selected = selected;
    [self updateBackgroundView:selected];
}

// Cell highlighting only highlights the cell itself
- (void)setHighlighted:(BOOL)highlighted {
    _collectionCellFlags.highlighted = highlighted;
    [self updateBackgroundView:highlighted];
}

- (void)updateBackgroundView:(BOOL)highlight
{
    _selectedBackgroundView.alpha = highlight ? 1.0f : 0.0f;
    [self setHighlighted:highlight forViews:self.contentView.subviews];
}

- (void)setHighlighted:(BOOL)highlighted forViews:(id)subviews {
    for (id view in subviews) {
        // Ignore the events if view wants to
        if (!((UIView *)view).isUserInteractionEnabled &&
            [view respondsToSelector:@selector(setHighlighted:)] &&
            ![view isKindOfClass:[UIButton class]]) {
            [view setHighlighted:highlighted];
            
        }
        [self setHighlighted:highlighted forViews:[view subviews]];
    }
}

- (void)menuGesture:(UILongPressGestureRecognizer *)recognizer {
    NSLog(@"Not yet implemented: %@", NSStringFromSelector(_cmd));
}

- (void)setBackgroundView:(UIView *)backgroundView {
    if (_backgroundView != backgroundView) {
        [_backgroundView removeFromSuperview];
        _backgroundView = backgroundView;
        _backgroundView.frame = self.bounds;
        _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
        [self insertSubview:_backgroundView atIndex:0];
    }
}

- (void)setSelectedBackgroundView:(UIView *)selectedBackgroundView {
    if (_selectedBackgroundView != selectedBackgroundView) {
        [_selectedBackgroundView removeFromSuperview];
        _selectedBackgroundView = selectedBackgroundView;
        _selectedBackgroundView.frame = self.bounds;
        _selectedBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _selectedBackgroundView.alpha = self.selected ? 1.0f : 0.0f;
        if (_backgroundView) {
            [self insertSubview:_selectedBackgroundView aboveSubview:_backgroundView];
        }
        else {
            [self insertSubview:_selectedBackgroundView atIndex:0];
        }
    }
}

- (BOOL)isSelected {
    return _collectionCellFlags.selected;
}

- (BOOL)isHighlighted {
    return _collectionCellFlags.highlighted;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSTCollection/UICollection interoperability

#ifdef kPSUIInteroperabilityEnabled
#import <objc/runtime.h>
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
#endif

@end
