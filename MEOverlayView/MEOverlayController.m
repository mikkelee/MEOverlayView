//
//  MEOverlayController.m
//  MEOverlayView
//
//  Created by Mikkel Eide Eriksen on 25/01/12.
//  Copyright (c) 2012 Mikkel Eide Eriksen. All rights reserved.
//

#import "MEOverlayController.h"
#import "MEOverlayView.h"

@implementation MEOverlayController {
    NSMutableArray *overlays;
}

#pragma mark Initialization

- (id) init
{
    self = [super init];
    
    if (self) {
        NSUInteger overlayCount = 5;
        
        overlays = [NSMutableArray arrayWithCapacity:overlayCount];
        for (NSUInteger i = 0; i < overlayCount; i++) {
            NSRect rect = NSMakeRect(20.0f + (i * 110.0f), 100.0f + (i * 10.0f), 100.0f, 100.0f + (i * 20.0f));
            
            [overlays addObject:[NSValue valueWithRect:rect]];
        }
        
        NSLog(@"Created rects: %@", overlays);
    }
    
    return self;
}

- (void)awakeFromNib
{
    //some examples -- try changing them to see how they work.
    
    [overlayView setOverlayBackgroundColor:CGColorCreateGenericRGB(0.0f, 0.0f, 1.0f, 0.5f)];
    [overlayView setOverlayBorderColor:CGColorCreateGenericRGB(0.0f, 0.0f, 1.0f, 1.0f)];
    [overlayView setOverlaySelectionBackgroundColor:CGColorCreateGenericRGB(1.0f, 0.0f, 0.0f, 0.5f)];
    [overlayView setOverlaySelectionBorderColor:CGColorCreateGenericRGB(1.0f, 0.0f, 0.0f, 1.0f)];
    [overlayView setOverlayBorderWidth:3.0f];
    
    [overlayView setAllowsCreatingOverlays:YES];
    [overlayView setAllowsModifyingOverlays:YES];
    [overlayView setAllowsDeletingOverlays:YES];
    [overlayView setAllowsOverlappingOverlays:NO];
    
    [overlayView setWantsOverlaySingleClickActions:YES];
    [overlayView setWantsOverlayDoubleClickActions:NO];
    
    [overlayView setAllowsSelection:YES];
    [overlayView setAllowsEmptySelection:NO];
    [overlayView setAllowsMultipleSelection:YES];
}

#pragma mark MEOverlayViewDataSource

- (NSUInteger)numberOfOverlaysInOverlayView:(MEOverlayView *)anOverlayView
{
    return [overlays count];
}

- (id)overlayView:(MEOverlayView *)anOverlayView overlayObjectAtIndex:(NSUInteger)num
{
    return [overlays objectAtIndex:num];
}

#pragma mark MEOverlayViewDelegate

- (void)overlayView:(MEOverlayView *)anOverlayView didCreateOverlay:(NSRect)rect
{
    NSLog(@"overlay created: %@", NSStringFromRect(rect));
    [overlays addObject:[NSValue valueWithRect:rect]];
    
    /*
     Do whatever else you feel like here... 
     */
    [overlayView reloadData];
}

- (void)overlayView:(MEOverlayView *)anOverlayView didModifyOverlay:(id)overlayObject newRect:(NSRect)rect
{
    NSLog(@"overlay %@ got new rectangle %@", overlayObject, NSStringFromRect(rect));
    [overlays removeObject:overlayObject];
    [overlays addObject:[NSValue valueWithRect:rect]];
    
    /*
     Do whatever else you feel like here... 
     In reality you wouldn't delete/replace, but modify the actual object you're given. 
     I'm just doing it like this here because I'm using NSValues in the example.
     This also causes the object to lose its selection if modified, since it is no longer the same object.
     */
    [overlayView reloadData];
}

- (void)overlayView:(MEOverlayView *)anOverlayView didDeleteOverlay:(id)overlayObject
{
    NSLog(@"overlay %@ deleted", overlayObject);
    [overlays removeObject:overlayObject];
    
    /*
     Do whatever else you feel like here... 
     Naturally you can run some extra logic and decide not to delete the object if you want/need to.
     */
    [overlayView reloadData];
}

- (void)overlayView:(MEOverlayView *)anOverlayView overlay:(id)overlayObject singleClicked:(NSEvent *)event
{
    NSLog(@"overlay %@ singleClicked: %@", overlayObject, event);
    /*
     Do whatever else you feel like here... 
     */
    [overlayView reloadData];
}

- (void)overlayView:(MEOverlayView *)anOverlayView overlay:(id)overlayObject doubleClicked:(NSEvent *)event
{
    NSLog(@"overlay %@ doubleClicked: %@", overlayObject, event);
    /*
     Do whatever else you feel like here... 
     */
    [overlayView reloadData];
}

#pragma mark User interface

- (IBAction)logCurrentOverlays:(id)sender
{
    NSLog(@"overlays: %@", overlays);
}

- (IBAction)changeState:(id)sender
{
    [overlayView enterState:[sender selectedSegment]];
}

@end
