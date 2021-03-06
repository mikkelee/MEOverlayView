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
    NSMutableArray *_overlays;
}

#pragma mark Initialization

- (id) init
{
    self = [super init];
    
    if (self) {
        NSUInteger overlayCount = 5;
        
        _overlays = [NSMutableArray arrayWithCapacity:overlayCount];
        for (NSUInteger i = 0; i < overlayCount; i++) {
            NSRect rect = NSMakeRect(20.0f + (i * 110.0f), 100.0f + (i * 10.0f), 100.0f, 100.0f + (i * 20.0f));
            
            [_overlays addObject:[NSValue valueWithRect:rect]];
        }
        
        NSLog(@"Created rects: %@", _overlays);
    }
    
    return self;
}

- (void)awakeFromNib
{
    //some examples -- try changing them to see how they work.
    NSString *imgURL = [[NSBundle mainBundle] pathForImageResource:@"royalty-free-food-image-cabbage.jpg"];
    [overlayView setImageWithURL:[NSURL fileURLWithPath:imgURL]];
    
    CGColorRef ofColor = CGColorCreateGenericRGB(0.0f, 0.0f, 1.0f, 0.5f);
    [overlayView setOverlayFillColor:ofColor];
    CGColorRelease(ofColor);
    
    CGColorRef obColor = CGColorCreateGenericRGB(0.0f, 0.0f, 1.0f, 1.0f);
    [overlayView setOverlayBorderColor:obColor];
    CGColorRelease(obColor);
    
    CGColorRef osfColor = CGColorCreateGenericRGB(1.0f, 0.0f, 0.0f, 0.5f);
    [overlayView setOverlaySelectionFillColor:osfColor];
    CGColorRelease(osfColor);
    
    CGColorRef osbColor = CGColorCreateGenericRGB(1.0f, 0.0f, 0.0f, 1.0f);
    [overlayView setOverlaySelectionBorderColor:osbColor];
    CGColorRelease(osbColor);
    
    [overlayView setOverlayBorderWidth:3.0f];
    
    [overlayView setAllowsCreatingOverlays:YES];
    [overlayView setAllowsModifyingOverlays:YES];
    [overlayView setAllowsDeletingOverlays:YES];
    [overlayView setAllowsOverlappingOverlays:NO];
    
    [overlayView setTarget:self];
    [overlayView setAction:@selector(singleClick)];
    [overlayView setDoubleAction:@selector(doubleClick)];
    [overlayView setRightAction:@selector(rightClick)];
    
    [overlayView setAllowsOverlaySelection:YES];
    [overlayView setAllowsEmptyOverlaySelection:NO];
    [overlayView setAllowsMultipleOverlaySelection:YES];
    
    [overlayView bind:@"contents" toObject:self withKeyPath:@"overlays" options:nil];
}

#pragma mark MEOverlayViewDataSource

- (NSUInteger)numberOfOverlaysInOverlayView:(MEOverlayView *)anOverlayView
{
    return [_overlays count];
}

- (id)overlayView:(MEOverlayView *)anOverlayView overlayObjectAtIndex:(NSUInteger)num
{
    return [_overlays objectAtIndex:num];
}

#pragma mark MEOverlayViewDelegate

- (void)overlayView:(MEOverlayView *)anOverlayView didCreateOverlay:(NSRect)rect
{
    NSLog(@"overlay created: %@", NSStringFromRect(rect));
    [_overlays addObject:[NSValue valueWithRect:rect]];
    
    /*
     Do whatever else you feel like here... 
     */
    [overlayView reloadData];
}

- (void)overlayView:(MEOverlayView *)anOverlayView didModifyOverlay:(id)overlayObject newRect:(NSRect)rect
{
    NSLog(@"overlay %@ got new rectangle %@", overlayObject, NSStringFromRect(rect));
    [_overlays removeObject:overlayObject];
    [_overlays addObject:[NSValue valueWithRect:rect]];
    
    /*
     Do whatever else you feel like here... 
     In reality you wouldn't delete/replace, but modify the actual object you're given. 
     I'm just doing it like this here because I'm using NSValues in the example.
     In this case it also causes the overlay to lose its selection if modified, since it is no longer the same object.
     */
    [overlayView reloadData];
}

- (void)overlayView:(MEOverlayView *)anOverlayView didDeleteOverlay:(id)overlayObject
{
    NSLog(@"overlay %@ deleted", overlayObject);
    [_overlays removeObject:overlayObject];
    
    /*
     Do whatever else you feel like here... 
     Naturally you can run some extra logic and decide not to delete the object if you want/need to.
     */
    [overlayView reloadData];
}

- (void)overlaySelectionDidChange:(NSNotification *)aNotification
{
    NSLog(@"notification: %@", aNotification);
}

- (void)singleClick
{
    NSLog(@"singleClick: %ld", [overlayView clickedOverlay]);
}

- (void)doubleClick
{
    NSLog(@"doubleClick: %ld", [overlayView clickedOverlay]);
}

- (void)rightClick
{
    NSLog(@"rightClick: %ld", [overlayView clickedOverlay]);
}

#pragma mark User interface

- (IBAction)logCurrentOverlays:(id)sender
{
    NSLog(@"overlays: %@", _overlays);
}

- (IBAction)changeState:(id)sender
{
    overlayView.state = [sender selectedSegment];
}

@synthesize overlays = _overlays;

@end
