//
//  PSCollectionView.h
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSCollectionViewLayout.h"
#import "PSCollectionViewFlowLayout.h"
#import "PSCollectionViewCell.h"

@class PSCollectionViewController;

// Define this to automatically return UICollection* variants on init if they are available.
//#define kPSCollectionViewRelayToUICollectionViewIfAvailable

// Allows code to just use UICollectionView as if it would be avaiable on iOS SDK 5.
// http://developer.apple.com/legacy/mac/library/#documentation/DeveloperTools/gcc-3.3/gcc/compatibility_005falias.html
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 60000
@compatibility_alias UICollectionViewController PSCollectionViewController;
@compatibility_alias UICollectionView PSCollectionView;
@compatibility_alias UICollectionReusableView PSCollectionReusableView;
@compatibility_alias UICollectionViewCell PSCollectionViewCell;
@compatibility_alias UICollectionViewLayout PSCollectionViewLayout;
@compatibility_alias UICollectionViewFlowLayout PSCollectionViewFlowLayout;
@compatibility_alias UICollectionViewLayoutAttributes PSCollectionViewLayoutAttributes;
@protocol UICollectionViewDataSource <PSCollectionViewDataSource> @end
@protocol UICollectionViewDelegate <PSCollectionViewDelegate> @end
#endif

@protocol PSCollectionViewDataSource <NSObject>
@required

- (NSInteger)collectionView:(PSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section;

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (PSCollectionViewCell *)collectionView:(PSCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath;

@optional

- (NSInteger)numberOfSectionsInCollectionView:(PSCollectionView *)collectionView;

// The view that is returned must be retrieved from a call to -dequeueReusableSupplementaryViewOfKind:withReuseIdentifier:forIndexPath:
- (PSCollectionReusableView *)collectionView:(PSCollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

@end

@protocol PSCollectionViewDelegate <UIScrollViewDelegate>
@optional

// Methods for notification of selection/deselection and highlight/unhighlight events.
// The sequence of calls leading to selection from a user touch is:
//
// (when the touch begins)
// 1. -collectionView:shouldHighlightItemAtIndexPath:
// 2. -collectionView:didHighlightItemAtIndexPath:
//
// (when the touch lifts)
// 3. -collectionView:shouldSelectItemAtIndexPath: or -collectionView:shouldDeselectItemAtIndexPath:
// 4. -collectionView:didSelectItemAtIndexPath: or -collectionView:didDeselectItemAtIndexPath:
// 5. -collectionView:didUnhighlightItemAtIndexPath:
- (BOOL)collectionView:(PSCollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(PSCollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(PSCollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)collectionView:(PSCollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)collectionView:(PSCollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath; // called when the user taps on an already-selected item in multi-select mode
- (void)collectionView:(PSCollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(PSCollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath;

- (void)collectionView:(PSCollectionView *)collectionView didEndDisplayingCell:(PSCollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(PSCollectionView *)collectionView didEndDisplayingSupplementaryView:(PSCollectionReusableView *)view forElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath;

// These methods provide support for copy/paste actions on cells.
// All three should be implemented if any are.
- (BOOL)collectionView:(PSCollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)collectionView:(PSCollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender;
- (void)collectionView:(PSCollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender;

@end

typedef NS_OPTIONS(NSUInteger, PSCollectionViewScrollPosition) {
    PSCollectionViewScrollPositionNone                 = 0,

    // The vertical positions are mutually exclusive to each other, but are bitwise or-able with the horizontal scroll positions.
    // Combining positions from the same grouping (horizontal or vertical) will result in an NSInvalidArgumentException.
    PSCollectionViewScrollPositionTop                  = 1 << 0,
    PSCollectionViewScrollPositionCenteredVertically   = 1 << 1,
    PSCollectionViewScrollPositionBottom               = 1 << 2,

    // Likewise, the horizontal positions are mutually exclusive to each other.
    PSCollectionViewScrollPositionLeft                 = 1 << 3,
    PSCollectionViewScrollPositionCenteredHorizontally = 1 << 4,
    PSCollectionViewScrollPositionRight                = 1 << 5
};

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 60000
typedef NS_OPTIONS(NSUInteger, UICollectionViewScrollPosition) {
    UICollectionViewScrollPositionNone                 = 0,

    // The vertical positions are mutually exclusive to each other, but are bitwise or-able with the horizontal scroll positions.
    // Combining positions from the same grouping (horizontal or vertical) will result in an NSInvalidArgumentException.
    UICollectionViewScrollPositionTop                  = 1 << 0,
    UICollectionViewScrollPositionCenteredVertically   = 1 << 1,
    UICollectionViewScrollPositionBottom               = 1 << 2,

    // Likewise, the horizontal positions are mutually exclusive to each other.
    UICollectionViewScrollPositionLeft                 = 1 << 3,
    UICollectionViewScrollPositionCenteredHorizontally = 1 << 4,
    UICollectionViewScrollPositionRight                = 1 << 5
};
#endif

#import "PSCollectionViewController.h"

/**
    Replacement for UICollectionView for iOS4/5.
    Only supports a subset of the features of UICollectionView.
    e.g. animations won't be handled.
 */
@interface PSCollectionView : UIScrollView

- (id)initWithFrame:(CGRect)frame collectionViewLayout:(PSCollectionViewLayout *)layout; // the designated initializer

@property (nonatomic, retain) PSCollectionViewLayout *collectionViewLayout;
@property (nonatomic, assign) id <PSCollectionViewDelegate> delegate;
@property (nonatomic, assign) id <PSCollectionViewDataSource> dataSource;
@property (nonatomic, retain) UIView *backgroundView; // will be automatically resized to track the size of the collection view and placed behind all cells and supplementary views.

// For each reuse identifier that the collection view will use, register either a class or a nib from which to instantiate a cell.
// If a nib is registered, it must contain exactly 1 top level object which is a PSCollectionViewCell.
// If a class is registered, it will be instantiated via alloc/initWithFrame:
- (void)registerClass:(Class)cellClass forCellWithReuseIdentifier:(NSString *)identifier;
- (void)registerClass:(Class)viewClass forSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(UINib *)nib forCellWithReuseIdentifier:(NSString *)identifier;

/*
- (void)registerNib:(UINib *)nib forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)identifier;
 */

- (id)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath;
- (id)dequeueReusableSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath;
// These properties control whether items can be selected, and if so, whether multiple items can be simultaneously selected.
@property (nonatomic) BOOL allowsSelection; // default is YES
@property (nonatomic) BOOL allowsMultipleSelection; // default is NO

- (NSArray *)indexPathsForSelectedItems; // returns nil or an array of selected index paths
- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(PSCollectionViewScrollPosition)scrollPosition;
- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;

- (void)reloadData; // discard the dataSource and delegate data and requery as necessary

- (void)setCollectionViewLayout:(PSCollectionViewLayout *)layout animated:(BOOL)animated; // transition from one layout to another

// Information about the current state of the collection view.

- (NSInteger)numberOfSections;
- (NSInteger)numberOfItemsInSection:(NSInteger)section;

- (PSCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath;
- (PSCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

- (NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point;
- (NSIndexPath *)indexPathForCell:(PSCollectionViewCell *)cell;

- (PSCollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath;
- (NSArray *)visibleCells;
- (NSArray *)indexPathsForVisibleItems;

// Interacting with the collection view.

- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(PSCollectionViewScrollPosition)scrollPosition animated:(BOOL)animated;

// These methods allow dynamic modification of the current set of items in the collection view
- (void)insertSections:(NSIndexSet *)sections;
- (void)deleteSections:(NSIndexSet *)sections;
- (void)reloadSections:(NSIndexSet *)sections;
- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection;

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths;
- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths;
- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths;
- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath;

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion; // allows multiple insert/delete/reload/move calls to be animated simultaneously. Nestable.

@end
