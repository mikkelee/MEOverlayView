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

@protocol MEOverlayViewDelegate <NSObject>

@required
- (NSUInteger)numberOfOverlays;
- (NSRect)rectForOverlay:(NSUInteger)num;

@optional

//Will default to blue, with an alpha of 0.5 for the background & 1.0 for the border, which is 3 pts wide.
- (CGColorRef)overlayBackgroundColor;
- (CGColorRef)overlayBorderColor;
- (CGFloat)overlayBorderWidth;

- (BOOL)allowsCreatingOverlays;
- (BOOL)allowsModifyingOverlays;
- (BOOL)allowsDeletingOverlays;
- (BOOL)allowsOverlappingOverlays; //note: A bit finicky, if the mouse moves "fast", it stops well before overlapping.

- (void)didCreateOverlay:(NSRect)rect;
- (void)didModifyOverlay:(NSUInteger)num newRect:(NSRect)rect;
- (void)didDeleteOverlay:(NSUInteger)num;

// TODO: should probably have better names:
- (BOOL)wantsEventsForOverlays;
- (void)overlay:(NSUInteger)num receivedEvent:(NSEvent *)event;


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

- (void)setupOverlays; //TMP

@property (weak) IBOutlet id<MEOverlayViewDelegate> overlayDelegate;

@end
