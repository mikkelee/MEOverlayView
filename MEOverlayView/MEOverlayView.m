//
//  MEOverlayView.m
//  MEOverlayView
//
//  Created by Mikkel Eide Eriksen on 25/01/12.
//  Copyright (c) 2012 Mikkel Eide Eriksen. All rights reserved.
//

#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

#import "MEOverlayView.h"

@interface MEOverlayView ()

//initialization
- (void)initialSetup;
- (void)setupOverlays;

//helpers
- (CALayer *)layerWithRect:(NSRect)rect;
- (CALayer *)layerAtPoint:(NSPoint)point;
- (void)draggedFrom:(NSPoint)startPoint to:(NSPoint)endPoint done:(BOOL)done;

@end

@implementation MEOverlayView {
    __weak id<MEOverlayViewDelegate> __delegate;
    
    MEState state;
    CALayer *topLayer;
    
    //defaults
    CGColorRef backgroundColor;
    CGColorRef borderColor;
    CGFloat borderWidth;
    
    //events
    NSPoint mouseDownPoint;
    
    //temp vals
    CALayer *creatingLayer;
    CALayer *draggingLayer;
    CGFloat xOffset;
    CGFloat yOffset;
}

#pragma mark Initialization

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    DLog(@"overlayDelegate: %@", __delegate);

    state = MEIdleState;
    
    [self performSelector:@selector(initialSetup) withObject:nil afterDelay:0.0f];
    
    NSTrackingArea *fullArea = [[NSTrackingArea alloc] initWithRect:NSMakeRect(0, 0, 0, 0) options:(NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect) owner:self userInfo:nil];
    [self addTrackingArea:fullArea];
}

- (void)initialSetup
{
    if ([__delegate respondsToSelector:@selector(overlayBackgroundColor)]) {
        backgroundColor = [__delegate overlayBackgroundColor];
    } else {
        backgroundColor = CGColorCreateGenericRGB(0, 0, 1, 0.5);
    }
    
    if ([__delegate respondsToSelector:@selector(overlayBorderColor)]) {
        borderColor = [__delegate overlayBorderColor];
    } else {
        borderColor = CGColorCreateGenericRGB(0, 0, 1, 1);
    }
    
    if ([__delegate respondsToSelector:@selector(overlayBorderWidth)]) {
        borderWidth = [__delegate overlayBorderWidth];
    } else {
        borderWidth = 3.0f;
    }
    
    topLayer = [CALayer layer];
    
    [topLayer setFrame:NSMakeRect(0, 0, [self imageSize].width, [self imageSize].height)];
    [topLayer setName:@"topLayer"];
    
    [self setupOverlays];
    
    [self setOverlay:topLayer forType:IKOverlayTypeImage];
}

- (void)setupOverlays //TODO should be put into the view's normal lifetime
{
    DLog(@"Setting up overlays from overlayDelegate: %@", __delegate);
    
    [topLayer setSublayers:[NSArray array]];
    
    DLog(@"Number of overlays to create: %lu", [__delegate numberOfOverlays]);
    
    //create new layers for each rect in the delegate:
    for (NSUInteger i = 0; i < [__delegate numberOfOverlays]; i++) {
        DLog(@"Creating layer #%lu", i);
        
        CALayer *layer = [self layerWithRect:[__delegate rectForOverlay:i]];
        
        [layer setValue:[NSNumber numberWithInteger:i] forKey:@"MEOverlayNumber"];
        
        DLog(@"Created layer: %@", layer);
        
        [topLayer addSublayer:layer];
    }
}

#pragma mark State

- (void)enterState:(MEState)_state
{
    DLog(@"%lu => %lu", state, _state);
    state = _state;
}

#pragma mark Drawing

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
}

#pragma mark Mouse events

- (void)mouseDown:(NSEvent *)theEvent
{
    mouseDownPoint = [self convertViewPointToImagePoint:[theEvent locationInWindow]];
    
    [super mouseDown:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint mouseUpPoint = [self convertViewPointToImagePoint:[theEvent locationInWindow]];
    CGFloat epsilonSquared = 0.025;
    
    CGFloat dx = mouseDownPoint.x - mouseUpPoint.x, dy = mouseDownPoint.y - mouseUpPoint.y;
    BOOL pointsAreEqual = (dx * dx + dy * dy) < epsilonSquared;
    
    if ((state == MECreatingState || state == MEModifyingState) && !pointsAreEqual) {
        [self draggedFrom:mouseDownPoint to:mouseUpPoint done:NO];
    } else {
        [super mouseDragged:theEvent];
    }
}

- (void)mouseUp:(NSEvent *)theEvent
{
    NSPoint mouseUpPoint = [self convertViewPointToImagePoint:[theEvent locationInWindow]];
    CGFloat epsilonSquared = 0.025;
    
    CGFloat dx = mouseDownPoint.x - mouseUpPoint.x, dy = mouseDownPoint.y - mouseUpPoint.y;
    BOOL pointsAreEqual = (dx * dx + dy * dy) < epsilonSquared;
    
    CALayer *hitLayer = [self layerAtPoint:mouseUpPoint];
    NSUInteger overlayNum = [[hitLayer valueForKey:@"MEOverlayNumber"] integerValue];
    
    if (state == MEDeletingState && [__delegate allowsDeletingOverlays]) {
        [__delegate didDeleteOverlay:overlayNum];
        [self setupOverlays];
    } else if (state == MEIdleState && [__delegate wantsEventsForOverlays]) {
        [__delegate overlay:overlayNum receivedEvent:theEvent];
    } else if ((state == MECreatingState || state == MEModifyingState) && !pointsAreEqual) {
        [self draggedFrom:mouseDownPoint to:mouseUpPoint done:YES];
    } else {
        [super mouseUp:theEvent];
    }
}

- (void)cursorUpdate:(NSEvent *)theEvent
{
    NSPoint mousePoint = [self convertViewPointToImagePoint:[theEvent locationInWindow]];
    
    if (state == MECreatingState && [self layerAtPoint:mousePoint] == topLayer) {
        [[NSCursor crosshairCursor] set];
    } else if (state == MEModifyingState) {
        [[NSCursor openHandCursor] set];
    } else if (state == MEDeletingState) {
        [[NSCursor pointingHandCursor] set];
    }
}

#pragma mark Helpers

- (CALayer *)layerWithRect:(NSRect)rect
{
    CALayer *layer = [CALayer layer];
    
    [layer setFrame:rect];
    //[layer setAnchorPoint:CGPointMake(0.0f, 0.0f)];
    
    [layer setBackgroundColor:backgroundColor];
    [layer setBorderWidth:borderWidth];
    [layer setBorderColor:borderColor];
    
    return layer;
}

- (CALayer *)layerAtPoint:(NSPoint)point
{
    CALayer *rootLayer = [self overlayForType:IKOverlayTypeImage];
    CALayer *hitLayer = [rootLayer hitTest:[self convertPoint:point fromView:nil]];
    
    DLog(@"hitLayer #%lu: %@", [[hitLayer valueForKey:@"MEOverlayNumber"] integerValue], hitLayer);
    
    return hitLayer;
}

- (void)draggedFrom:(NSPoint)startPoint to:(NSPoint)endPoint done:(BOOL)done
{
    DLog(@"from %@ to %@", NSStringFromPoint(startPoint), NSStringFromPoint(endPoint));
    
    
    if (state == MECreatingState && [__delegate allowsCreatingOverlays]) {
        DLog(@"creating");
        if (creatingLayer == nil) {
            creatingLayer = [self layerWithRect:NSMakeRect(0.0f, 0.0f, 0.0f, 0.0f)];
            
            [topLayer addSublayer:creatingLayer];
        }
        
        //make rect
        NSPoint origin = NSMakePoint(fmin(startPoint.x, endPoint.x), fmin(startPoint.y, endPoint.y));
        NSPoint end = NSMakePoint(fmax(startPoint.x, endPoint.x), fmax(startPoint.y, endPoint.y));
        NSSize size = NSMakeSize(end.x - origin.x, end.y - origin.y);
        NSRect windowRect = NSMakeRect(origin.x, origin.y, size.width, size.height);
        
        //translate to image coordinates:
        NSRect viewRect = [self convertRect:windowRect fromView:[[self window] contentView]];
        NSRect imageRect = [self convertViewRectToImageRect:viewRect];
        
        if (![__delegate allowsOverlappingOverlays]) {
            for (CALayer *layer in [topLayer sublayers]) {
                if (layer == creatingLayer) {
                    continue; //don't compare against oneself
                }
                NSRect frameRect = [layer frame];
                if (NSIntersectsRect(imageRect, frameRect)) {
                    DLog(@"%@ intersects layer #%lu %@: %@", NSStringFromRect(imageRect), [[layer valueForKey:@"MEOverlayNumber"] integerValue], layer, NSStringFromRect(frameRect));
                    return;
                }
            }
        }
        
        [CATransaction begin];
        [CATransaction setAnimationDuration:0.0f];
        [creatingLayer setFrame:imageRect];
        [CATransaction commit];
        
        if (done) {
            DLog(@"done creating: %@", NSStringFromRect([creatingLayer frame]));
            [__delegate didCreateOverlay:[creatingLayer frame]];
            [creatingLayer removeFromSuperlayer];
            creatingLayer = nil;
            [self setupOverlays];
        }
    } else if (state == MEModifyingState && [__delegate allowsModifyingOverlays]) {
        DLog(@"modifying");
        if (draggingLayer == nil) {
            CALayer *hitLayer = [self layerAtPoint:mouseDownPoint];
            if (hitLayer == topLayer) {
                return;
            }
            draggingLayer = hitLayer;
            xOffset = [draggingLayer position].x - endPoint.x;
            yOffset = [draggingLayer position].y - endPoint.y;
            
            DLog(@"xOffset: %f yOffset: %f", xOffset, yOffset);
        }
        [[NSCursor closedHandCursor] set];
        NSUInteger overlayNum = [[draggingLayer valueForKey:@"MEOverlayNumber"] integerValue];
        
        NSPoint pos = [draggingLayer position];
        
        DLog(@"old position: %@", NSStringFromPoint(pos));
        
        pos.x = endPoint.x + xOffset;
        pos.y = endPoint.y + yOffset;
        
        DLog(@"new position: %@", NSStringFromPoint(pos));
        
        if (![__delegate allowsOverlappingOverlays]) {
            for (CALayer *layer in [topLayer sublayers]) {
                if (layer == draggingLayer) {
                    continue; //don't compare against oneself
                }
                NSRect frameRect = [layer frame];
                NSRect bounds = [draggingLayer bounds];
                NSRect imageRect = NSMakeRect(pos.x - (bounds.size.width * 0.5f), 
                                              pos.y - (bounds.size.height * 0.5f), 
                                              bounds.size.width, 
                                              bounds.size.height);
                if (NSIntersectsRect(imageRect, frameRect)) {
                    DLog(@"%@ intersects layer #%lu %@: %@", NSStringFromRect(imageRect), [[layer valueForKey:@"MEOverlayNumber"] integerValue], layer, NSStringFromRect(frameRect));
                    return;
                }
            }
        }
        
        [CATransaction begin];
        [CATransaction setAnimationDuration:0.0f];
        [draggingLayer setPosition:pos];
        [CATransaction commit];
        
        if (done) {
            DLog(@"done modifying #%lu: %@", overlayNum, NSStringFromRect([draggingLayer frame]));
            [__delegate didModifyOverlay:overlayNum newRect:[draggingLayer frame]];
            draggingLayer = nil;
            [self setupOverlays];
            [[NSCursor openHandCursor] set];
        }
    }
}

#pragma mark Properties

@synthesize overlayDelegate = __delegate;

@end
