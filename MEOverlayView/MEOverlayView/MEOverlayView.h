//
//  MEOverlayView.h
//  MEOverlayView
//
//  Created by Mikkel Eide Eriksen on 25/01/12.
//  Copyright (c) 2012 Mikkel Eide Eriksen. All rights reserved.
//

#import <Quartz/Quartz.h>

@class MEOverlayView;

#pragma mark -
#pragma mark Overlay Data Source

/** An informal protocol.
 
 TODO
 */
@interface NSObject (MEOverlayViewDataSource)

/// ---------------------------------
/// @name Required
/// ---------------------------------

/** Returns the number of overlays managed for anOverlayView by the data source object.
 
 An instance of MEOverlayView uses this method to determine how many overlays it should create 
 and display. Your numberOfOverlaysInOverlayView: implementation can be called very frequently, 
 so it must be efficient.
  
 @param anOverlayView The overlay view that sent the message.
 @return The number of overlays in anOverlayView.
 */
- (NSUInteger)numberOfOverlaysInOverlayView:(MEOverlayView *)anOverlayView;


/** Invoked by the overlay view to return the data object associated with the specified index.
 
 overlayView:overlayObjectAtIndex: is called ..., so it must be efficient.
 
 @param anOverlayView The overlay view that sent the message.
 @param num The overlay view that sent the message.
 @return An item in the data source at the specified index of the view. Must respond to -(NSRect)rect
 or -(NSRect)rectValue.
 */
- (id)overlayView:(MEOverlayView *)anOverlayView overlayObjectAtIndex:(NSUInteger)num; 

@end 

#pragma mark -
#pragma mark Overlay Delegate

/** An informal protocol.
 
 TODO
 */
@interface NSObject (MEOverlayViewDelegate)

/// ---------------------------------
/// @name Changing Overlays
/// ---------------------------------

/** Invoked by the overlay view when the user has created a new overlay.
 
 The delegate should create an object and expect to return it to the overlay when
 asked.
 
 @param anOverlayView The overlay view that sent the message.
 @param rect The frame for the new overlay, expressed in the coordinate system of the image.
 */
- (void)overlayView:(MEOverlayView *)anOverlayView didCreateOverlay:(NSRect)rect;

/** Invoked by the overlay view when the user has modified an overlay.
 
 The delegate should change the frame of the rect. Alternately, the new frame can be 
 discarded if the frame is not satisfactory.
 
 @param anOverlayView The overlay view that sent the message.
 @param overlayObject The object that was modified.
 @param rect The new frame for the overlay, expressed in the coordinate system of the image.
 */
- (void)overlayView:(MEOverlayView *)anOverlayView didModifyOverlay:(id)overlayObject newRect:(NSRect)rect;

/** Invoked by the overlay view when the user has deleted an overlay.
 
 The delegate should delete...
 
 @param anOverlayView The overlay view that sent the message.
 @param overlayObject The object that was deleted.
 */
- (void)overlayView:(MEOverlayView *)anOverlayView didDeleteOverlay:(id)overlayObject;


/// ---------------------------------
/// @name Events
/// ---------------------------------

/** Invoked by the overlay view when the user has single-clicked an overlay.
 
 @param anOverlayView The overlay view that sent the message.
 @param overlayObject The object that was deleted.
 @param event The NSEvent that caused the action. Note that coordinates in the event are not in the image's
 coordinate system.
 */
- (void)overlayView:(MEOverlayView *)anOverlayView overlay:(id)overlayObject singleClicked:(NSEvent *)event;

/** Invoked by the overlay view when the user has double-clicked an overlay.
 
 @param anOverlayView The overlay view that sent the message.
 @param overlayObject The object that was deleted.
 @param event The NSEvent that caused the action. Note that coordinates in the event are not in the image's
 coordinate system.
 */
- (void)overlayView:(MEOverlayView *)anOverlayView overlay:(id)overlayObject doubleClicked:(NSEvent *)event;

/** Invoked by the overlay view when the user has right-clicked an overlay.
 
 @param anOverlayView The overlay view that sent the message.
 @param overlayObject The object that was deleted.
 @param event The NSEvent that caused the action. Note that coordinates in the event are not in the image's
 coordinate system.
 */
- (void)overlayView:(MEOverlayView *)anOverlayView overlay:(id)overlayObject rightClicked:(NSEvent *)event;

@end

#pragma mark -
#pragma mark Overlay View

/** MEState
 TODO
 */
enum {
    MEIdleState,
    MECreatingState,
    MEModifyingState,
    MEDeletingState
};
typedef NSUInteger MEState;

/** The overlay view.
 
 TODO
 */
@interface MEOverlayView : IKImageView


/// ---------------------------------
/// @name Setting the Overlay Data Source
/// ---------------------------------
/** Sets the receiver’s data source to a given object.
 
 In a managed memory environment, the receiver maintains a weak reference to the 
 data source.
 
 Setting the delegate will implicitly reload the overlay view.
 
 */
@property (weak) IBOutlet id overlayDataSource;

/// ---------------------------------
/// @name Setting the Overlay Delegate
/// ---------------------------------
/** Sets the receiver’s overlay delegate to a given object.
 
 In a managed memory environment, the receiver maintains a weak reference to the 
 delegate.
 
 Setting the delegate will implicitly reload the overlay view.
 
 */
@property (weak) IBOutlet id overlayDelegate;

/// ---------------------------------
/// @name Loading Data
/// ---------------------------------
/** Marks the receiver as needing redisplay, so it will reload the data for 
 visible cells and draw the new values.
 
 This method forces redraw of all the visible cells in the receiver. 
 */
- (void)reloadData;

/// ---------------------------------
/// @name Managing State
/// ---------------------------------
/** Attempt to enter new state.
 
 Discussion about allowances here.
 
 @param theState The state that should be entered.
 @return `YES` if the state could be changed; otherwise `NO`.
 */
- (BOOL)enterState:(MEState)theState;

/// ---------------------------------
/// @name Selecting Overlays
/// ---------------------------------
/** Sets the overlay selection using _indexes_ possibly extending the selection.
 
 @param indexes The indexes to select.
 @param extend `YES` if the selection should be extended, `NO` if the current selection should be changed.
 */
- (void)selectOverlayIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend;

/** Returns the index of the last overlay selected or added to the selection.
 
 @return The index of the last overlay selected or added to the selection, or –1 if no overlay is selected.
 */
- (NSInteger)selectedOverlay;

/** Returns an index set containing the indexes of the selected overlays.
 
 @return An index set containing the indexes of the selected overlays.
 */
- (NSIndexSet *)selectedOverlayIndexes;

/** Deselects the overlay at overlayIndex if it’s selected, regardless of whether empty selection 
 is allowed.
  
 If the indicated overlay was the last overlay selected by the user, the overlay selected
 prior to this one effectively becomes the last selected overlay.
 
 This method doesn’t check with the delegate before changing the selection.
 
 @param overlayIndex The index of the overlay to deselect.
 */
- (void)deselectOverlay:(NSInteger)overlayIndex;

/** Returns the number of selected overlays.
 
 @return The number of selected overlays.
 */
- (NSInteger)numberOfSelectedOverlays;

/** Returns a Boolean value that indicates whether the overlay at a given index is selected.
 
 @param overlayIndex The index of the overlay to test.
 @return `YES` if the overlay at overlayIndex is selected, otherwise `NO`.
 */
- (BOOL)isOverlaySelected:(NSInteger)overlayIndex;

/** Select all overlays.

 @param sender Typically the object that sent the message.
 */
- (IBAction)selectAllOverlays:(id)sender;

/** Deselect all overlays.
 
 @param sender Typically the object that sent the message.
 */
- (IBAction)deselectAllOverlays:(id)sender;

/// ---------------------------------
/// @name Setting Display Attributes
/// ---------------------------------

/** The color used to fill an overlay.
 
 Defaults to transparent blue`.
 */
@property (assign) CGColorRef overlayFillColor; //default: blue, alpha 0.5

/** The color used for the border of an overlay.
 
 Defaults to opaque blue.
 */
@property (assign) CGColorRef overlayBorderColor; //default: blue, alpha 1.0

/** The color used to fill a selected overlay.
 
 Defaults to transparent green.
 */
@property (assign) CGColorRef overlaySelectionFillColor; //default: green, alpha 0.5

/** The color used for the border of a selected overlay.
 
 Defaults to opaque green.
 */
@property (assign) CGColorRef overlaySelectionBorderColor; //default: green, alpha 1.0

/** Specifies the border width of an overlay.
 
 Defaults to 3 points.
 */
@property (assign) CGFloat overlayBorderWidth; //default 3.0f

/// ---------------------------------
/// @name Configuring Behavior
/// ---------------------------------

/** Specifies whether receiver should allow creating overlays.
 
 Defaults to `YES`.
 */
@property BOOL allowsCreatingOverlays;

/** Specifies whether receiver should allow modifying overlays.
 
 Defaults to `YES`.
 */
@property BOOL allowsModifyingOverlays;

/** Specifies whether receiver should allow deleting overlays.
 
 Defaults to `YES`.
 */
@property BOOL allowsDeletingOverlays;

/** Specifies whether receiver should allow overlapping overlays.
 
 Defaults to `NO`.
 */
@property BOOL allowsOverlappingOverlays;

/** Specifies whether receiver should send single-clicks to its overlay delegate.
 
 Defaults to `YES`.
 */
@property BOOL wantsOverlaySingleClickActions;

/** Specifies whether receiver should send double-clicks to its overlay delegate.
 
 Defaults to `YES`.
 */
@property BOOL wantsOverlayDoubleClickActions;

/** Specifies whether receiver should send right-clicks to its overlay delegate.
 
 Defaults to `YES`.
 */
@property BOOL wantsOverlayRightClickActions;


/** Specifies whether receiver should allow overlay selection.
 
 Defaults to `YES`.
 */
@property BOOL allowsOverlaySelection;

/** Specifies whether receiver should allow empty overlay selections.
 
 Defaults to `YES`.
 */
@property BOOL allowsEmptyOverlaySelection;

/** Specifies whether receiver should allow multiple overlay selection.
 
 Defaults to `YES`.
 */
@property BOOL allowsMultipleOverlaySelection;

@end
