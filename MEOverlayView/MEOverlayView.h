//
//  MEOverlayView.h
//  MEOverlayView
//
//  Created by Mikkel Eide Eriksen on 25/01/12.
//  Copyright (c) 2012 Mikkel Eide Eriksen. All rights reserved.
//

#import <Quartz/Quartz.h>

/*
 
 All NSRects are in the image's coordinate system.
 
 */

@class MEOverlayView;

@interface NSObject (MEOverlayViewDataSource)

- (NSUInteger)numberOfOverlaysInOverlayView:(MEOverlayView *)anOverlayView;
- (id)overlayView:(MEOverlayView *)anOverlayView overlayObjectAtIndex:(NSUInteger)num; 
//overlayObjects can be anything, but must respond to -(NSRect)rectValue or -(NSRect)rect

@end

@interface NSObject (MEOverlayViewDelegate)

//Will default to blue, with an alpha of 0.5 for the background & 1.0 for the border, which is 3 pts wide.
- (CGColorRef)overlayBackgroundColor;
- (CGColorRef)overlayBorderColor;
- (CGFloat)overlayBorderWidth;

- (BOOL)allowsCreatingOverlays;
- (BOOL)allowsModifyingOverlays;
- (BOOL)allowsDeletingOverlays;
- (BOOL)allowsOverlappingOverlays; //note: A bit finicky, if the mouse moves "fast", it stops well before overlapping.

- (void)didCreateOverlay:(NSRect)rect;
- (void)didModifyOverlay:(id)overlayObject newRect:(NSRect)rect;
- (void)didDeleteOverlay:(id)overlayObject;

- (BOOL)wantsOverlayActions;
- (void)overlay:(id)overlayObject singleClicked:(NSEvent *)event;
- (void)overlay:(id)overlayObject doubleClicked:(NSEvent *)event;


@end

enum {
    MEIdleState,
    MECreatingState,
    MEModifyingState,
    MEDeletingState
};
typedef NSUInteger MEState;

@interface MEOverlayView :IKImageView

- (void)enterState:(MEState)_state;

@property (weak) IBOutlet id overlayDelegate;

@end
