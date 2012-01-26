//
//  MEOverlayController.m
//  MEOverlayView
//
//  Created by Mikkel Eide Eriksen on 25/01/12.
//  Copyright (c) 2012 Mikkel Eide Eriksen. All rights reserved.
//

#import "MEOverlayController.h"

@implementation MEOverlayController {
    NSMutableArray *overlays;
}

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
    
    //to check if viewWillDraw refreshes the overlays properly:
    [overlays performSelector:@selector(addObject:) 
                withObject:[NSValue valueWithRect:NSMakeRect(20.0f, 20.0f, 540.0f, 20.0f)] 
                afterDelay:10.0f];
    
    return self;
}

- (NSUInteger)numberOfOverlaysInOverlayView:(MEOverlayView *)anOverlayView
{
    return [overlays count];
}

- (id)overlayView:(MEOverlayView *)anOverlayView overlayObjectAtIndex:(NSUInteger)num
{
    return [overlays objectAtIndex:num];
}

- (CGColorRef)overlayBackgroundColor
{
    return CGColorCreateGenericRGB(0, 0, 1, 0.5);
}
- (CGColorRef)overlayBorderColor
{
    return CGColorCreateGenericRGB(0, 0, 1, 1);
}
- (CGFloat)overlayBorderWidth
{
    return 3.0f;
}

- (BOOL)allowsCreatingOverlays
{
    return YES;
}

- (BOOL)allowsModifyingOverlays
{
    return YES;
}

- (BOOL)allowsDeletingOverlays
{
    return YES;
}

- (BOOL)allowsOverlappingOverlays
{
    return NO;
}

- (void)didCreateOverlay:(NSRect)rect
{
    NSLog(@"overlay created: %@", NSStringFromRect(rect));
    [overlays addObject:[NSValue valueWithRect:rect]];
    
    /*
     Do whatever else you feel like here... 
     */
}

- (void)didModifyOverlay:(id)overlayObject newRect:(NSRect)rect
{
    NSLog(@"overlay %@ got new rectangle %@", overlayObject, NSStringFromRect(rect));
    [overlays removeObject:overlayObject];
    [overlays addObject:[NSValue valueWithRect:rect]];
    
    /*
     Do whatever else you feel like here... 
     In reality you wouldn't delete/replace, but modify the actual object you're given. 
     I'm just doing it like this here because I'm using NSValues in the example.
     */
}

- (void)didDeleteOverlay:(id)overlayObject
{
    NSLog(@"overlay %@ deleted", overlayObject);
    [overlays removeObject:overlayObject];
    
    /*
     Do whatever else you feel like here... 
     Naturally you can run some extra logic and decide not to delete the object if you want/need to.
     */
}

- (BOOL)wantsOverlayActions
{
    return YES;
}

- (void)overlay:(id)overlayObject singleClicked:(NSEvent *)event
{
    NSLog(@"overlay %@ received %@", overlayObject, event);
}

- (void)overlay:(id)overlayObject doubleClicked:(NSEvent *)event
{
    NSLog(@"overlay %@ received %@", overlayObject, event);
}

- (IBAction)logCurrentOverlays:(id)sender
{
    NSLog(@"overlays: %@", overlays);
}

- (IBAction)changeState:(id)sender
{
    [overlayView enterState:[sender selectedSegment]];
}

@end
