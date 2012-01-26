//
//  MEOverlayController.m
//  MEOverlayView
//
//  Created by Mikkel Eide Eriksen on 25/01/12.
//  Copyright (c) 2012 Mikkel Eide Eriksen. All rights reserved.
//

#import "MEOverlayController.h"

@implementation MEOverlayController {
    NSMutableArray *rects;
}

- (id) init
{
    self = [super init];
    
    if (self) {
        NSUInteger overlayCount = 5;
        
        rects = [NSMutableArray arrayWithCapacity:overlayCount];
        for (NSUInteger i = 0; i < overlayCount; i++) {
            NSRect rect = NSMakeRect(20.0f + (i * 110.0f), 100.0f + (i * 10.0f), 100.0f, 100.0f + (i * 20.0f));
            
            [rects addObject:[NSValue valueWithRect:rect]];
        }
        
        NSLog(@"Created rects: %@", rects);
    }
    
    //to check if viewWillDraw refreshes the overlays properly:
    [rects performSelector:@selector(addObject:) 
                withObject:[NSValue valueWithRect:NSMakeRect(20.0f, 20.0f, 540.0f, 20.0f)] 
                afterDelay:10.0f];
    
    return self;
}

- (NSUInteger)numberOfOverlays
{
    return [rects count];
}

- (NSRect)rectForOverlay:(NSUInteger)num
{
    return [[rects objectAtIndex:num] rectValue];
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
    [rects addObject:[NSValue valueWithRect:rect]];
    
    //do whatever else you feel like here...
}

- (void)didModifyOverlay:(NSUInteger)num newRect:(NSRect)rect
{
    NSLog(@"overlay #%lu replaced with %@", num, NSStringFromRect(rect));
    [rects replaceObjectAtIndex:num withObject:[NSValue valueWithRect:rect]];
    
    //do whatever else you feel like here...
}

- (void)didDeleteOverlay:(NSUInteger)num
{
    NSLog(@"overlay #%lu deleted", num);
    [rects removeObjectAtIndex:num];
    
    //do whatever else you feel like here...
}

- (BOOL)wantsEventsForOverlays
{
    return YES;
}

- (void)overlay:(NSUInteger)num receivedEvent:(NSEvent *)event
{
    NSLog(@"overlay #%lu received %@", num, event);
}

- (IBAction)logCurrentOverlays:(id)sender
{
    NSLog(@"overlays: %@", rects);
}

- (IBAction)changeState:(id)sender
{
    [overlayView enterState:[sender selectedSegment]];
}

@end
