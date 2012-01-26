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

- (void)didCreateOverlay:(NSRect)rect;
- (void)didModifyOverlay:(id)overlayObject newRect:(NSRect)rect;
- (void)didDeleteOverlay:(id)overlayObject;

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

@property CGColorRef overlayBackgroundColor; //default: blue, alpha 0.5
@property CGColorRef overlayBorderColor; //default: blue, alpha 1.0
@property CGFloat overlayBorderWidth; //default 3.0f

@property BOOL allowsCreatingOverlays;
@property BOOL allowsModifyingOverlays;
@property BOOL allowsDeletingOverlays;
@property BOOL allowsOverlappingOverlays; //note: A bit finicky, if the mouse moves "fast", it stops well before overlapping.
@property BOOL wantsOverlayActions;

@end
