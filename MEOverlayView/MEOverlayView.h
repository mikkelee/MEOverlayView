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

@interface NSObject (MEOverlayViewDataSource)

- (NSUInteger)numberOfOverlaysInOverlayView:(MEOverlayView *)anOverlayView;
- (id)overlayView:(MEOverlayView *)anOverlayView overlayObjectAtIndex:(NSUInteger)num; 
//overlayObjects can be anything, but must respond to -(NSRect)rectValue or -(NSRect)rect

@end

#pragma mark -
#pragma mark Overlay Delegate

@interface NSObject (MEOverlayViewDelegate)

- (void)overlayView:(MEOverlayView *)anOverlayView didCreateOverlay:(NSRect)rect;
- (void)overlayView:(MEOverlayView *)anOverlayView didModifyOverlay:(id)overlayObject newRect:(NSRect)rect;
- (void)overlayView:(MEOverlayView *)anOverlayView didDeleteOverlay:(id)overlayObject;

- (void)overlayView:(MEOverlayView *)anOverlayView overlay:(id)overlayObject singleClicked:(NSEvent *)event;
- (void)overlayView:(MEOverlayView *)anOverlayView overlay:(id)overlayObject doubleClicked:(NSEvent *)event;

@end

#pragma mark -
#pragma mark Overlay View

enum {
    MEIdleState,
    MECreatingState,
    MEModifyingState,
    MEDeletingState
};
typedef NSUInteger MEState;

@interface MEOverlayView :IKImageView

- (BOOL)enterState:(MEState)_state; //returns success of state change (depending on allowance properties)

@property (weak) IBOutlet id overlayDelegate;
@property (strong) IBOutlet id overlayDataSource;

@property CGColorRef overlayBackgroundColor; //default: blue, alpha 0.5
@property CGColorRef overlayBorderColor; //default: blue, alpha 1.0
@property CGFloat overlayBorderWidth; //default 3.0f

@property BOOL allowsCreatingOverlays; //default YES
@property BOOL allowsModifyingOverlays; //default YES
@property BOOL allowsDeletingOverlays; //default YES
@property BOOL allowsOverlappingOverlays; //default NO (note: somewhat finicky when mouse is moving "fast")
@property BOOL wantsOverlayActions; //default YES

@end
