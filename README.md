PSCollectionView
================

IMPORTANT: DO NOT FORK THIS REPO, OR YOU WILL SEND HUNDRETHS OF EMAILS AS EVERY SINGLE DEVELOPER ADDED HERE WILL GET ACCESS TO YOUR REPO. USE BRANCHES.

Open Source, 100% API compatible replacement of UICollectionView for iOS4+

I've originally started this to replace the thumbnail grid in my iOS PDF Framework/SDK [PSPDFKit](http://pspdfkit.com), but seemed way too useful for others to keep it for myself.

**The goal is to make UICollectionView instantly usable to anyone**, using "the real thing" on iOS6 and PSCollectionView as a fallback for iOS4/5.
We even use certain runtime tricks to create UICollectionView at runtime for older versions of iOS. Ideally, **you just link the files and everything works on older systems.**

PSCollectionView is also internally designed very closesly to UICollectionView and thus a great study if you're wondering how UICollectionView works. See [HowTo](/steipete/PSCollectionView/blob/master/HowTo.md) for helpful details.


*Important: Since iSO6 is not yet released, this repository needs to be private to not break the NDA.*

## Current State

Most basic features work, including the flow layout with fixed or dynamic cell sizes.

Currently there are still some problems, e.g. the cell that's either a subclass of PSCollectionViewCell or UICollectionViewCell, and there are problems for interoperabilty. [See Issue #1](/steipete/PSCollectionView/issues/1)

You can control if PSCollectionView should relay to UICollectionView with the global define `kPSCollectionViewRelayToUICollectionViewIfAvailable` in [PSCollectionView.h](/steipete/PSCollectionView/blob/master/PSCollectionView.h).

The current goal is to make layouts and all common features workable.
Animations are a whole different problem, we might tackle them at a later date. (But feel free to start!)

## How can I help?

The best way is if you're already using UICollectionView somewhere. Add PSCollectionView and try it on iOS5. Check if everything works, fix bugs until the result is 1:1 the one of iOS6.
You can also just pick an Issue fron the Issue Tracker and start working there.

Or start playing around with one of the WWDC examples and try to make them work with PSCollectionView. There sure will be problems/bugs/missing features with more difficult layouts.

## ARC

PSCollectionView works with Xcode 4.4+ and ARC.
Feel free to hack around and improve it.

## Interoperability

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