PSCollectionView
================

Open Source rewrite of UICollectionView for iOS4+

This project has the goal to be a 100% API compatible* replacement for UICollectionView.
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

            UICollectionViewFlowLayout *flowLayout = [UICollectionViewFlowLayout new];
            PSCollectionView *collectionView = [PSCollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:(PSCollectionViewFlowLayout *)flowLayout];


(*) Note that for some methods we can't use the _ underscore variants or we risk to get a false-positive on private API use. I've added  some runtime hacks to dynamcially add block forwarders for those cases (mainly for UI/PS interoperability)

### Creator

[Peter Steinberger](http://github.com/steipete), [@steipete](https://twitter.com/steipete)

and hopefully lots of others! See [HowTo](HowTo.m) for helpful details.

## License

PSCollectionView is available under the MIT license. See the LICENSE file for more info.