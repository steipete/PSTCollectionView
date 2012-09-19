PSTCollectionView
=================

Open Source, 100% API compatible replacement of UICollectionView for iOS4.3+

**You want to use UICollectionView, but still need to support iOS4/5? Then you'll gonna love this project.**
I've originally written it for [PSPDFKit](http://PSPDFKit.com), my iOS PDF framework that supports text selection and annotations, but this project seemed way to useful for others to to keep it for myself :) Plus, I would love the influx of new gridviews to stop. Better just write layout managers and build on a great codebase.

The goal is to use PSTCollectionView on iOS 4/5 as a fallback and switch to UICollectionView on iOS6. We even use certain runtime tricks to create UICollectionView at runtime for older versions of iOS. Ideally, **you just link the files and everything works on older systems.**
Practically, it's not that easy, and especially when you're using subclasses of UICollectionView-classes, since they can't be replaced at runtime.

PSTCollectionView is also internally designed very closesly to UICollectionView and thus a great study if you're wondering how UICollectionView works. See [HowTo](/steipete/PSTCollectionView/blob/master/HowTo.md) for helpful details.

## Current State

Most basic features work, including the flow layout with fixed or dynamic cell sizes. If you're not doing something fancy, it should just work.

Currently there are still some problems with interoperability, but that's anyway not encouraged right now. (e.g. when you're using a UICollectionViewCell in the PSTCollectionView grid) [See Issue #1](/steipete/PSTCollectionView/issues/1)

You can control if PSTCollectionView should relay to UICollectionView with the global define `kPSTCollectionViewRelayToUICollectionViewIfAvailable` in [PSTCollectionView.h](/steipete/PSTCollectionView/blob/master/PSTCollectionView/PSTCollectionView.h). (Note that this will break your subclasses since a different class is returned)

## How can I help?

The best way is if you're already using UICollectionView somewhere. Add PSTCollectionView and try it on iOS4/5. Check if everything works, fix bugs until the result is 1:1 the one of iOS6. You can also just pick an issue fron the Issue Tracker and start working there.

Or start playing around with one of the WWDC examples and try to make them work with PSTCollectionView. Most of them already do, but just not as perfect.

You could also write a Pintrest-style layout manager. Can't be that hard.

## Animations

Animations are not yet supported at all. We're currently looking for a great iOS engineer that want to tackle animations, I can connect you with a potential sponsor.

## ARC

PSTCollectionView works with Xcode 4.4+ and ARC.

## Interoperability

Another goal (at least super useful for debugging) is interoperability between UI/PS classes:

``` objective-c
UICollectionViewFlowLayout *flowLayout = [UICollectionViewFlowLayout new];
PSTCollectionView *collectionView = [PSTCollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:(PSTCollectionViewFlowLayout *)flowLayout];
```

(*) Note that for some methods we can't use the _ underscore variants or we risk to get a false-positive on private API use. I've added some runtime hacks to dynamcially add block forwarders for those cases (mainly for UI/PST interoperability)

## Creator

[Peter Steinberger](http://github.com/steipete), [@steipete](https://twitter.com/steipete)
and lots of others! See [Contributors](https://github.com/steipete/PSTCollectionView/graphs/contributors) for a graph. Thanks everyone!

## License

PSTCollectionView is available under the MIT license. See the LICENSE file for more info.
