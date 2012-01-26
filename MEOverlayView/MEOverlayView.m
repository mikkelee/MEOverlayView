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
- (void)refreshOverlays;

//helpers
- (NSPoint)convertWindowPointToImagePoint:(NSPoint)windowPoint;
- (CALayer *)layerWithRect:(NSRect)rect;
- (CALayer *)layerAtPoint:(NSPoint)point;
- (BOOL)layer:(CALayer *)_layer willGetValidRect:(NSRect)rect;
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
    
    [self refreshOverlays];
    
    [self setOverlay:topLayer forType:IKOverlayTypeImage];
}

- (void)refreshOverlays //TODO should be put into the view's normal lifetime
{
    DLog(@"Setting up overlays from overlayDelegate: %@", __delegate);
    
    [topLayer setSublayers:[NSArray array]];
    
    DLog(@"Number of overlays to create: %lu", [__delegate numberOfOverlaysInOverlayView:self]);
    
    //create new layers for each rect in the delegate:
    for (NSUInteger i = 0; i < [__delegate numberOfOverlaysInOverlayView:self]; i++) {
        DLog(@"Creating layer #%lu", i);
        
        id overlayObject = [__delegate overlayView:self overlayObjectAtIndex:i];
        
        NSRect rect;
        if ([overlayObject respondsToSelector:@selector(rectValue)]) {
            rect = [overlayObject rectValue];
        } else if ([overlayObject respondsToSelector:@selector(rect)]) {
            rect = [overlayObject rect];
        } else {
            @throw [NSException exceptionWithName:@"MEOverlayObjectHasNoRect"
                                           reason:@"Objects given to MEOverlayView must respond to -(NSRect)rectValue or -(NSRect)rect"
                                         userInfo:nil];
        }
        
        CALayer *layer = [self layerWithRect:rect];
        
        [layer setValue:[NSNumber numberWithInteger:i] forKey:@"MEOverlayNumber"];
        [layer setValue:overlayObject forKey:@"MEOverlayObject"];
        
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

- (void)viewWillDraw
{
    [self refreshOverlays];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
}

#pragma mark Mouse events

- (void)mouseDown:(NSEvent *)theEvent
{
    mouseDownPoint = [self convertWindowPointToImagePoint:[theEvent locationInWindow]];
    
    [super mouseDown:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint mouseUpPoint = [self convertWindowPointToImagePoint:[theEvent locationInWindow]];
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
    NSPoint mouseUpPoint = [self convertWindowPointToImagePoint:[theEvent locationInWindow]];
    CGFloat epsilonSquared = 0.025;
    
    CGFloat dx = mouseDownPoint.x - mouseUpPoint.x, dy = mouseDownPoint.y - mouseUpPoint.y;
    BOOL pointsAreEqual = (dx * dx + dy * dy) < epsilonSquared;
    
    CALayer *hitLayer = [self layerAtPoint:mouseUpPoint];
    
    if (state == MEDeletingState && [__delegate allowsDeletingOverlays] && [hitLayer valueForKey:@"MEOverlayObject"]) {
        [__delegate didDeleteOverlay:[hitLayer valueForKey:@"MEOverlayObject"]];
        [self refreshOverlays];
    } else if (state == MEIdleState && [__delegate wantsOverlayActions] && [hitLayer valueForKey:@"MEOverlayObject"]) {
        if ([theEvent clickCount] == 1) {
            [__delegate overlay:[hitLayer valueForKey:@"MEOverlayObject"] singleClicked:theEvent];
        } else if ([theEvent clickCount] == 2) {
            [__delegate overlay:[hitLayer valueForKey:@"MEOverlayObject"] doubleClicked:theEvent];
        } else {
            [super mouseUp:theEvent];
        }
    } else if ((state == MECreatingState || state == MEModifyingState) && !pointsAreEqual) {
        [self draggedFrom:mouseDownPoint to:mouseUpPoint done:YES];
    } else {
        [super mouseUp:theEvent];
    }
}

- (void)cursorUpdate:(NSEvent *)theEvent
{
    NSPoint mousePoint = [self convertWindowPointToImagePoint:[theEvent locationInWindow]];
    
    if (state == MECreatingState && [self layerAtPoint:mousePoint] == topLayer) {
        [[NSCursor crosshairCursor] set];
    } else if (state == MEModifyingState) {
        [[NSCursor openHandCursor] set];
    } else if (state == MEDeletingState) {
        [[NSCursor disappearingItemCursor] set];
    }
}

#pragma mark Helpers

- (NSPoint)convertWindowPointToImagePoint:(NSPoint)windowPoint
{
    DLog(@"windowPoint: %@", NSStringFromPoint(windowPoint));
    NSPoint imagePoint = [self convertViewPointToImagePoint:[self convertPoint:windowPoint fromView:[[self window] contentView]]];
    DLog(@"imagePoint: %@", NSStringFromPoint(imagePoint));
    return imagePoint;
}

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
    CALayer *hitLayer = [rootLayer hitTest:[self convertImagePointToViewPoint:point]];
    
    DLog(@"hitLayer for obj %@: %@", [hitLayer valueForKey:@"MEOverlayObject"], hitLayer);
    
    return hitLayer;
}

- (BOOL)layer:(CALayer *)_layer willGetValidRect:(NSRect)rect
{
    if (rect.origin.x < 0.0f) {
        return NO;
    } else if (rect.origin.y < 0.0f) {
        return NO;
    } else if (rect.origin.x + rect.size.width > [self imageSize].width) {
        return NO;
    } else if (rect.origin.y + rect.size.height > [self imageSize].height) {
        return NO;
    }
    
    if (![__delegate allowsOverlappingOverlays]) {
        for (CALayer *layer in [topLayer sublayers]) {
            if (layer == _layer) {
                continue; //don't compare against oneself
            }
            NSRect frameRect = [layer frame];
            if (NSIntersectsRect(rect, frameRect)) {
                DLog(@"%@ intersects layer #%lu %@: %@", NSStringFromRect(rect), [[layer valueForKey:@"MEOverlayNumber"] integerValue], layer, NSStringFromRect(rect));
                return NO;
            }
        }
    }
    
    return YES;
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
        NSRect imageRect = NSMakeRect(origin.x, origin.y, size.width, size.height);
        
        BOOL validLocation = [self layer:creatingLayer willGetValidRect:imageRect];
        
        if (validLocation) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.0f];
            [creatingLayer setFrame:imageRect];
            [CATransaction commit];
        }
        
        if (done) {
            DLog(@"done creating: %@", NSStringFromRect([creatingLayer frame]));
            [__delegate didCreateOverlay:[creatingLayer frame]];
            [creatingLayer removeFromSuperlayer];
            creatingLayer = nil;
            [self refreshOverlays];
        }
    } else if (state == MEModifyingState && [__delegate allowsModifyingOverlays]) {
        DLog(@"modifying");
        if (draggingLayer == nil) {
            CALayer *hitLayer = [self layerAtPoint:mouseDownPoint];
            if (hitLayer == topLayer || [hitLayer valueForKey:@"MEOverlayObject"] == nil) {
                return;
            }
            draggingLayer = hitLayer;
            xOffset = [draggingLayer position].x - endPoint.x;
            yOffset = [draggingLayer position].y - endPoint.y;
            
            DLog(@"xOffset: %f yOffset: %f", xOffset, yOffset);
        }
        [[NSCursor closedHandCursor] set];
        
        NSPoint pos = [draggingLayer position];
        
        DLog(@"old position: %@", NSStringFromPoint(pos));
        
        pos.x = endPoint.x + xOffset;
        pos.y = endPoint.y + yOffset;
        
        DLog(@"new position: %@", NSStringFromPoint(pos));
        
        NSRect bounds = [draggingLayer bounds];
        NSRect newRect = NSMakeRect(pos.x - (bounds.size.width * 0.5f), 
                                    pos.y - (bounds.size.height * 0.5f), 
                                    bounds.size.width, 
                                    bounds.size.height);
        BOOL validLocation = [self layer:draggingLayer willGetValidRect:newRect];
        
        if (validLocation) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.0f];
            [draggingLayer setPosition:pos];
            [CATransaction commit];
        }
        
        if (done) {
            DLog(@"done modifying %@: %@", [draggingLayer valueForKey:@"MEOverlayObject"], NSStringFromRect([draggingLayer frame]));
            [__delegate didModifyOverlay:[draggingLayer valueForKey:@"MEOverlayObject"] newRect:[draggingLayer frame]];
            draggingLayer = nil;
            [self refreshOverlays];
            [[NSCursor openHandCursor] set];
        }
    }
}

#pragma mark Properties

@synthesize overlayDelegate = __delegate;

@end
