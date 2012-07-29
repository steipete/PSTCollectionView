PSCollectionView
================

Open Source Clone of UICollectionView for iOS4+

This project has the goal to be a 100% API compatible replacement for UICollectionView.
The goal is to use it for fallback on iOS4/iOS5 and use "the real thing" on iOS6.

Since iSO6 is not yet released, this repository needs to be private to not break the NDA :/

TODO:
- Margins
- Bugs with disappearing first cells
- Performance (less recalculations)
- Call more delegates, selection, highlighting
- ...

As cell animations are another super-tricky thing, my goal for now is to just don't animate.
(But feel free to change that!)


Should work with Xcode 4.4+ and ARC.

Feel free to hack around and improve it.


Another goal (at least super useful for debugging) is interoperability between UI/PS classes:

            flowLayout = (UICollectionViewFlowLayout *)[UICollectionViewFlowLayout new];
            collectionView = (UICollectionView *)[[PSCollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:(PSCollectionViewFlowLayout *)flowLayout];


License will be MIT.