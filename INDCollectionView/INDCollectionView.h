//
//  INDCollectionView.h
//
//  Original Source: Copyright (c) 2012 Peter Steinberger. All rights reserved.
//  AppKit Port: Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import "INDCollectionViewLayout.h"
#import "INDCollectionViewFlowLayout.h"
#import "INDCollectionViewCell.h"
#import "INDCollectionViewController.h"
#import "INDCollectionViewUpdateItem.h"

@class INDCollectionViewController;

typedef NS_OPTIONS(NSUInteger, INDCollectionViewScrollPosition) {
    INDCollectionViewScrollPositionNone                 = 0,

    // The vertical positions are mutually exclusive to each other, but are bitwise or-able with the horizontal scroll positions.
    // Combining positions from the same grouping (horizontal or vertical) will result in an NSInvalidArgumentException.
    INDCollectionViewScrollPositionTop                  = 1 << 0,
    INDCollectionViewScrollPositionCenteredVertically   = 1 << 1,
    INDCollectionViewScrollPositionBottom               = 1 << 2,

    // Likewise, the horizontal positions are mutually exclusive to each other.
    INDCollectionViewScrollPositionLeft                 = 1 << 3,
    INDCollectionViewScrollPositionCenteredHorizontally = 1 << 4,
    INDCollectionViewScrollPositionRight                = 1 << 5
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

/**
 Replacement for UICollectionView for iOS4/5.
 Only supports a subset of the features of UICollectionView.
 e.g. animations won't be handled.
 */
@interface INDCollectionView : UIScrollView

- (id)initWithFrame:(CGRect)frame collectionViewLayout:(INDCollectionViewLayout *)layout; // the designated initializer

@property (nonatomic, strong) INDCollectionViewLayout *collectionViewLayout;
@property (nonatomic, assign) IBOutlet id <INDCollectionViewDelegate> delegate;
@property (nonatomic, assign) IBOutlet id <INDCollectionViewDataSource> dataSource;
@property (nonatomic, strong) UIView *backgroundView; // will be automatically resized to track the size of the collection view and placed behind all cells and supplementary views.

// For each reuse identifier that the collection view will use, register either a class or a nib from which to instantiate a cell.
// If a nib is registered, it must contain exactly 1 top level object which is a INDCollectionViewCell.
// If a class is registered, it will be instantiated via alloc/initWithFrame:
- (void)registerClass:(Class)cellClass forCellWithReuseIdentifier:(NSString *)identifier;
- (void)registerClass:(Class)viewClass forSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(UINib *)nib forCellWithReuseIdentifier:(NSString *)identifier;

// TODO: implement!
- (void)registerNib:(UINib *)nib forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)identifier;

- (id)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath;
- (id)dequeueReusableSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath;

// These properties control whether items can be selected, and if so, whether multiple items can be simultaneously selected.
@property (nonatomic) BOOL allowsSelection; // default is YES
@property (nonatomic) BOOL allowsMultipleSelection; // default is NO

- (NSArray *)indexPathsForSelectedItems; // returns nil or an array of selected index paths
- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(INDCollectionViewScrollPosition)scrollPosition;
- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;

- (void)reloadData; // discard the dataSource and delegate data and requery as necessary

- (void)setCollectionViewLayout:(INDCollectionViewLayout *)layout animated:(BOOL)animated; // transition from one layout to another

// Information about the current state of the collection view.

- (NSInteger)numberOfSections;
- (NSInteger)numberOfItemsInSection:(NSInteger)section;

- (INDCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath;
- (INDCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

- (NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point;
- (NSIndexPath *)indexPathForCell:(INDCollectionViewCell *)cell;

- (INDCollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath;
- (NSArray *)visibleCells;
- (NSArray *)indexPathsForVisibleItems;

// Interacting with the collection view.

- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(INDCollectionViewScrollPosition)scrollPosition animated:(BOOL)animated;

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

// To dynamically switch between INDCollectionView and UICollectionView, use the PSUICollectionView* classes.
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
#define PSUICollectionView PSUICollectionView_
#define PSUICollectionViewCell PSUICollectionViewCell_
#define PSUICollectionReusableView PSUICollectionReusableView_
#define PSUICollectionViewDelegate INDCollectionViewDelegate
#define PSUICollectionViewDataSource INDCollectionViewDataSource
#define PSUICollectionViewLayout PSUICollectionViewLayout_
#define PSUICollectionViewFlowLayout PSUICollectionViewFlowLayout_
#define PSUICollectionViewDelegateFlowLayout INDCollectionViewDelegateFlowLayout
#define PSUICollectionViewLayoutAttributes PSUICollectionViewLayoutAttributes_
#define PSUICollectionViewController PSUICollectionViewController_

@interface PSUICollectionView_ : INDCollectionView @end
@interface PSUICollectionViewCell_ : INDCollectionViewCell @end
@interface PSUICollectionReusableView_ : INDCollectionReusableView @end
@interface PSUICollectionViewLayout_ : INDCollectionViewLayout @end
@interface PSUICollectionViewFlowLayout_ : INDCollectionViewFlowLayout @end
@protocol PSUICollectionViewDelegateFlowLayout_ <INDCollectionViewDelegateFlowLayout> @end
@interface PSUICollectionViewLayoutAttributes_ : INDCollectionViewLayoutAttributes @end
@interface PSUICollectionViewController_ : INDCollectionViewController <PSUICollectionViewDelegate, PSUICollectionViewDataSource> @end

#else
#define PSUICollectionView UICollectionView
#define PSUICollectionViewCell UICollectionViewCell
#define PSUICollectionReusableView UICollectionReusableView
#define PSUICollectionViewDelegate UICollectionViewDelegate
#define PSUICollectionViewDataSource UICollectionViewDataSource
#define PSUICollectionViewLayout UICollectionViewLayout
#define PSUICollectionViewFlowLayout UICollectionViewFlowLayout
#define PSUICollectionViewDelegateFlowLayout UICollectionViewDelegateFlowLayout
#define PSUICollectionViewLayoutAttributes UICollectionViewLayoutAttributes
#define PSUICollectionViewController UICollectionViewController
#endif
