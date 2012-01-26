NOTE: A work in progress. Selectors may change name / appear / disappear.

A subclass of IKImageView that allows you to set an overlayDelegate. The delegate can supply rects that will be overlaid the view, and the view can in turn create/modify/delete overlays depending on what the delegate allows. It can also send NSEvents back to the delegate in case it wants to take action, for instance when an overlay is clicked or double clicked.

I've attempted to make it as generic as possible, hopefully someone else can use it. To use in your own app, you only need the MEOverlayView.h/.m files (and to link to the Quartz.framework). Set the overlayDelegate and implement the selectors from the protocol (see the .h file).

Build & run MEOverlayView.app for an example of the functionality.

All coordinates are in the image's coordinates.

TODO:
- most important: figure out a good place to put -setupOverlays and don't call it so much, have it be part of the normal life of the view.
- rework the event sending code (only send actions -- doubleClick, singleClick?)
- when modifying, prevent moving off-image
- get better trackingareas (ie only show hand when over an overlay?)
- make moving less finicky when allowsOverlappingOverlays == NO
- resizing with corner handles 


Pic of cabbage is from:

http://www.freestockimages.org/wp-content/uploads/2009/06/royalty-free-food-image-cabbage.jpg
