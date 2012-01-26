# README #

*Note*: A work in progress. Selectors may change name / appear / disappear.

A subclass of IKImageView that allows you to set an an overlayDataSource and an overlayDelegate. 

The data source supplies objects (that respond to -rect or -rectValue) which the overlay will draw on top of the image it's currently displaying.

The delegate is in turn told when an overlay was created/modified/deleted, depending on what allowances have been set up. Additionally, mouseclicks (single / double) can be supplied to the delegate.

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

* get a clearer idea of when it's a good idea to -refreshOverlays (ie. when should a view poll its data source?)

* rework the action sending code (doubleClick sends a singleClick first; possibly add more types)

* get better trackingareas (better delete cursor - arrow with little minus)

* make creating/modifying less finicky (when allowsOverlappingOverlays == NO, "fast" mouse movements can make the overlay appear stuck if it's too close to the edge/another overlay)

* resizing with corner handles 

-----------------------------------------------------------------------------------------------

Pic of cabbage is from:
* http://www.freestockimages.org/wp-content/uploads/2009/06/royalty-free-food-image-cabbage.jpg
