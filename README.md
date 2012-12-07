INDCollectionView
=================

This is an in-progress port of [Peter Steinberger's](https://github.com/steipete) [PSTCollectionView](https://github.com/steipete/PSTCollectionView) to AppKit. 

## Goals:

* Minimal changes to existing PSTCollectionView code in order to maintain the ability to easily merge in future changes
* Removal of iOS specific code and addition of methods to make this a first class citizen on OS X, with support for drag and drop and other desktop specific paradigms
* 10.8+ only in order to take advantage of all the new Core Animation goodies that will hopefully make this a performant class, even on AppKit

## License

This fork is licensed under the same MIT license as the original. See the LICENSE file for more info.
