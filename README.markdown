# README #

*Note*: A work in progress. Selectors may change name / appear / disappear.

A subclass of IKImageView that allows you to set an an overlayDataSource and an overlayDelegate. 

The data source supplies objects (that respond to -rect or -rectValue) which the overlay will draw on top of the image it's currently displaying.

The delegate is in turn told when an overlay was created/modified/deleted, depending on what allowances have been set up. Additionally, mouseclicks (single / double) can be supplied to the delegate. The delegate can then call back with -reloadData if things have changed.

I've attempted to make it as generic as possible, hopefully someone else can use it. To use in your own app, you only need the MEOverlayView.h/.m files (and to link to the Quartz.framework). Set the overlayDataSource and optionally the overlayDelegate and implement the selectors from the informal protocols (see below).

Build & run MEOverlayView.app for an example of the functionality. In the example, the data source and delegate are the same object, but that is not necessary, as long as they have access to the same set of objects, all should work fine.

All coordinates are in the image's coordinate system.

## Informal protocols ##

The protocols as of Jan. 26, 2012:

    @interface NSObject (MEOverlayViewDataSource)
    
    - (NSUInteger)numberOfOverlaysInOverlayView:(MEOverlayView *)anOverlayView;
    - (id)overlayView:(MEOverlayView *)anOverlayView overlayObjectAtIndex:(NSUInteger)num; 
    //overlayObjects can be anything, but must respond to -(NSRect)rectValue or -(NSRect)rect
    
    @end
    
    @interface NSObject (MEOverlayViewDelegate)
    
    - (void)overlayView:(MEOverlayView *)anOverlayView didCreateOverlay:(NSRect)rect;
    - (void)overlayView:(MEOverlayView *)anOverlayView didModifyOverlay:(id)overlayObject newRect:(NSRect)rect;
    - (void)overlayView:(MEOverlayView *)anOverlayView didDeleteOverlay:(id)overlayObject;
    
    - (void)overlayView:(MEOverlayView *)anOverlayView overlay:(id)overlayObject singleClicked:(NSEvent *)event;
    - (void)overlayView:(MEOverlayView *)anOverlayView overlay:(id)overlayObject doubleClicked:(NSEvent *)event;
    
    @end

All methods are optional, but obviously nothing will happen unless you at least implement the data source.

# TODO #

## Features to add ##

* None at the moment :o

## Bugs/uncleanliness ##

* Resizing corners are somewhat wonky to catch with the mouse.

* Tracking Areas: Can't rely entirely on -cursorUpdate: as it's not issued when moving the mouse from a sublayer back out onto the topLayer. Thus I've had to check for -mouseExited: on the sublayers.

* Make creating/modifying less finicky ("fast" mouse movements can make the overlay appear stuck if they're too close to the edge, or when allowsOverlappingOverlays == NO, another overlay)

* Rework the action sending code (doubleClick sends a singleClick first; possibly add more types)

-----------------------------------------------------------------------------------------------

Pic of cabbage is from:
* http://www.freestockimages.org/wp-content/uploads/2009/06/royalty-free-food-image-cabbage.jpg
