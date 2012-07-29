PSCollectionView
================

Open Source Clone of UICollectionView for iOS4+

This project has the goal to be a 100% API compatible replacement for UICollectionView.
My goal is to use it for fallback on iOS4/iOS5 and use "the real thing" on iOS6.

Since iSO6 is not yet released, this repository needs to be private to not break the NDA.

TODO:
- Margins
- Bugs with first items
- Performance (less recalculations)
- Call more delegates, selection, highlighting
- ...

As cell animations are another super-tricky theme, my goal for now is to just don't animate.

Should work with Xcode 4.4+ and ARC.