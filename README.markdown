# README #

**Note**: A work in progress. Selectors may change name / appear / disappear.

A subclass of IKImageView that allows you to set an overlayDataSource and an overlayDelegate. 

The data source supplies objects (that respond to -rect or -rectValue) which the overlay will draw on top of the image it's currently displaying.

The delegate is in turn told when an overlay was created/modified/deleted, depending on what allowances have been set up. Additionally, mouseclicks (single / double) can be supplied to the delegate. The delegate can then call back with -reloadData if things have changed.

I've attempted to make it as generic & reusable as possible, modelling the method names & flow after NSTableView. Hopefully it should be possible to "jump right in" if you're familiar with Cocoa conventions.

To use in your own app, you only need the MEOverlayView.h/.m files (and to link to the Quartz.framework). Set the overlayDataSource and optionally the overlayDelegate and implement the selectors from the informal protocols (see docs).

Build & run MEOverlayView.app for an example of the functionality. In the example, the data source and delegate are the same object, but that is not necessary; as long as they have access to the same set of objects, all should work fine. Try changing the delegate setup in MEOverlayController's awakeFromNib to see different behaviors.

All coordinates are in the image's coordinate system (except those in the NSEvents, you must handle those yourself if you need to).

## Documentation ##

[AppleDoc documentation available here](http://mikkelee.github.com/MEOverlayView/).

# TODO #

## Features to add ##

* Clearer separatation of delegate/data source.

* More notifications.

* Easier access of selected objects; not just indexes.

## Misc ##

* Docs for MEOverlayState and notifications when AppleDoc supports it.

* Go through docs with a fine comb and make sure that described behavior is correct.

# Bugs #

## Major ##

* Keyboard selection: In some cases, objects can't be reached.

## Ugliness/hacks ##

* Creating & modifying overlays is somewhat finicky ("fast" mouse movements can make the overlay appear stuck if they're too close to the edge or, when allowsOverlappingOverlays == NO, another overlay).

* Tracking Areas/cursorRects: I can't rely entirely on -cursorUpdate: as it's not issued when moving the mouse from a sublayer back out onto the topLayer. Thus I've had to check for -mouseExited: on the sublayers. It works, but at the expense of extra event handling.

* Note that the DLog() statements in the code are only active in a DEBUG build. Look at the top of MEOverlayView.m if the log spam is annoying.

-----------------------------------------------------------------------------------------------

Pic of cabbage is from http://www.freestockimages.org/wp-content/uploads/2009/06/royalty-free-food-image-cabbage.jpg
