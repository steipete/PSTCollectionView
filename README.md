PSCollectionView
================

Open Source, 100% API compatible replacement of UICollectionView for iOS4+

The goal is to make UICollectionView instantly usable to anyone, using "the real thing" on iOS6 and PSCollectionView as a fallback for iOS4/5.
We even use certain runtime tricks to create UICollectionView at runtime for older versions of iOS. Ideally, you just link the files and everything works on older systems.
PSCollectionView is also internally designed very closesly to UICollectionView and thus a great study if you're wondering how UICollectionView works. See [HowTo](PSCollectionView/blob/master/HowTo.md) for helpful details.

Currently there are still some problems, e.g. the cell that's either a subclass of PSCollectionViewCell or UICollectionViewCell, and there are problems for interoperabilty. [See Issue #1](https://github.com/steipete/PSCollectionView/issues/1)
You can control if PSCollectionView should relay to UICollectionView with the global define `kPSCollectionViewRelayToUICollectionViewIfAvailable` in PSCollectionView.h.

*Important: Since iSO6 is not yet released, this repository needs to be private to not break the NDA.*

The current goal is to make layouts and all common features workable.
Animations are a whole different problem, we might tackle them at a later date. (But feel free to start!)


PSCollectionView works with Xcode 4.4+ and ARC.
Feel free to hack around and improve it.


Another goal (at least super useful for debugging) is interoperability between UI/PS classes:

``` objective-c
            UICollectionViewFlowLayout *flowLayout = [UICollectionViewFlowLayout new];
            PSCollectionView *collectionView = [PSCollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:(PSCollectionViewFlowLayout *)flowLayout];
```

(*) Note that for some methods we can't use the _ underscore variants or we risk to get a false-positive on private API use. I've added some runtime hacks to dynamcially add block forwarders for those cases (mainly for UI/PS interoperability)

### Creator

[Peter Steinberger](http://github.com/steipete), [@steipete](https://twitter.com/steipete)
and lots of others! See [Contributors](https://github.com/steipete/PSCollectionView/graphs/contributors) for a graph. Thanks everyone!

## License

PSCollectionView is available under the MIT license. See the LICENSE file for more info.