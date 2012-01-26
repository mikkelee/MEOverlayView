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
- (CAShapeLayer *)layerWithRect:(NSRect)rect withHandles:(BOOL)handles;
- (CALayer *)layerAtPoint:(NSPoint)point;
- (BOOL)isRect:(NSRect)rect validForLayer:(CALayer *)_layer;
- (void)draggedFrom:(NSPoint)startPoint to:(NSPoint)endPoint done:(BOOL)done;

@end

@implementation MEOverlayView {
    __weak id __delegate;
    id __dataSource;
    
    MEState state;
    CALayer *topLayer;
    
    //properties
    CGColorRef __backgroundColor;
    CGColorRef __borderColor;
    CGFloat __borderWidth;
    BOOL __allowsCreatingOverlays;
    BOOL __allowsModifyingOverlays;
    BOOL __allowsDeletingOverlays;
    BOOL __allowsOverlappingOverlays;
    BOOL __wantsOverlayActions;
    
    //events
    NSPoint mouseDownPoint;
    
    //temp vals
    CAShapeLayer *creatingLayer;
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
    
    //default property values:
    __backgroundColor = CGColorCreateGenericRGB(0, 0, 1, 0.5);
    __borderColor = CGColorCreateGenericRGB(0, 0, 1, 1);
    __borderWidth = 3.0f;
    __allowsCreatingOverlays = YES;
    __allowsModifyingOverlays = YES;
    __allowsDeletingOverlays = YES;
    __allowsOverlappingOverlays = NO;
    __wantsOverlayActions = YES;
    
    [self performSelector:@selector(initialSetup) withObject:nil afterDelay:0.0f];
    
    NSTrackingArea *fullArea = [[NSTrackingArea alloc] initWithRect:NSMakeRect(0, 0, 0, 0) options:(NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect) owner:self userInfo:nil];
    [self addTrackingArea:fullArea];
}

- (void)initialSetup
{
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
    
    DLog(@"Number of overlays to create: %lu", [__dataSource numberOfOverlaysInOverlayView:self]);
    
    //create new layers for each rect in the delegate:
    for (NSUInteger i = 0; i < [__dataSource numberOfOverlaysInOverlayView:self]; i++) {
        DLog(@"Creating layer #%lu", i);
        
        id overlayObject = [__dataSource overlayView:self overlayObjectAtIndex:i];
        
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
        
        CALayer *layer = [self layerWithRect:rect withHandles:(state == MEModifyingState)];
        
        [layer setValue:[NSNumber numberWithInteger:i] forKey:@"MEOverlayNumber"];
        [layer setValue:overlayObject forKey:@"MEOverlayObject"];
        
        DLog(@"Created layer: %@", layer);
        
        [topLayer addSublayer:layer];
    }
}

#pragma mark State

- (BOOL)enterState:(MEState)_state
{
    //check for allowances
    if (_state == MECreatingState && !__allowsCreatingOverlays) {
        return NO;
    } else if (_state == MEModifyingState && !__allowsModifyingOverlays) {
        return NO;
    } else if (_state == MEDeletingState && !__allowsDeletingOverlays) {
        return NO;
    } else {
        DLog(@"%lu => %lu", state, _state);
        state = _state;
        [self setNeedsDisplay:YES];
        return YES;
    }
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
    
    if (state == MEDeletingState && [self allowsDeletingOverlays] && [hitLayer valueForKey:@"MEOverlayObject"]) {
        [__delegate overlayView:self didDeleteOverlay:[hitLayer valueForKey:@"MEOverlayObject"]];
        [self refreshOverlays];
    } else if (state == MEIdleState && [self wantsOverlayActions] && [hitLayer valueForKey:@"MEOverlayObject"]) {
        if ([theEvent clickCount] == 1) {
            [__delegate overlayView:self overlay:[hitLayer valueForKey:@"MEOverlayObject"] singleClicked:theEvent];
        } else if ([theEvent clickCount] == 2) {
            [__delegate overlayView:self overlay:[hitLayer valueForKey:@"MEOverlayObject"] doubleClicked:theEvent];
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

- (CGPathRef)rectPathWithSize:(NSSize)size handles:(BOOL)handles
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, NSMakeRect(0.0, 0.0, size.width, size.height));
    
    if (handles) {
        CGFloat handleWidth = __borderWidth * 2.0f;
        CGFloat handleOffset = (__borderWidth / 2.0f) + 1.0f;
        
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(-handleOffset, -handleOffset, handleWidth, handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(-handleOffset, size.height - handleOffset, handleWidth, handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(size.width - handleOffset, -handleOffset, handleWidth, handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(size.width - handleOffset, size.height - handleOffset, handleWidth, handleWidth));
    }
    
    return path;
}

- (CAShapeLayer *)layerWithRect:(NSRect)rect withHandles:(BOOL)handles
{
    CAShapeLayer *layer = [CAShapeLayer layer];
    
    [layer setFrame:rect];
    [layer setPath:[self rectPathWithSize:rect.size handles:handles]];
    
    [layer setFillColor:__backgroundColor];
    [layer setLineWidth:__borderWidth];
    [layer setStrokeColor:__borderColor];
    
    return layer;
}

- (CALayer *)layerAtPoint:(NSPoint)point
{
    CALayer *rootLayer = [self overlayForType:IKOverlayTypeImage];
    CALayer *hitLayer = [rootLayer hitTest:[self convertImagePointToViewPoint:point]];
    
    DLog(@"hitLayer for obj %@: %@", [hitLayer valueForKey:@"MEOverlayObject"], hitLayer);
    
    return hitLayer;
}

- (BOOL)isRect:(NSRect)rect validForLayer:(CALayer *)_layer
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
    
    if (![self allowsOverlappingOverlays]) {
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
    
    if (state == MECreatingState && [self allowsCreatingOverlays]) {
        DLog(@"creating");
        if (creatingLayer == nil) {
            creatingLayer = [self layerWithRect:NSMakeRect(0.0f, 0.0f, 0.0f, 0.0f) withHandles:YES];
            
            [topLayer addSublayer:creatingLayer];
        }
        
        //make rect
        NSPoint origin = NSMakePoint(fmin(startPoint.x, endPoint.x), fmin(startPoint.y, endPoint.y));
        NSPoint end = NSMakePoint(fmax(startPoint.x, endPoint.x), fmax(startPoint.y, endPoint.y));
        NSSize size = NSMakeSize(end.x - origin.x, end.y - origin.y);
        NSRect imageRect = NSMakeRect(origin.x, origin.y, size.width, size.height);
        
        BOOL validLocation = [self isRect:imageRect validForLayer:creatingLayer];
        
        if (validLocation) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.0f];
            [creatingLayer setFrame:imageRect];
            [creatingLayer setPath:[self rectPathWithSize:imageRect.size handles:YES]];
            [CATransaction commit];
        }
        
        if (done) {
            DLog(@"done creating: %@", NSStringFromRect([creatingLayer frame]));
            [__delegate overlayView:self didCreateOverlay:[creatingLayer frame]];
            [creatingLayer removeFromSuperlayer];
            creatingLayer = nil;
            [self refreshOverlays];
        }
    } else if (state == MEModifyingState && [self allowsModifyingOverlays]) {
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
        BOOL validLocation = [self isRect:newRect validForLayer:draggingLayer];
        
        if (validLocation) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.0f];
            [draggingLayer setPosition:pos];
            [CATransaction commit];
        }
        
        if (done) {
            DLog(@"done modifying %@: %@", [draggingLayer valueForKey:@"MEOverlayObject"], NSStringFromRect([draggingLayer frame]));
            [__delegate overlayView:self didModifyOverlay:[draggingLayer valueForKey:@"MEOverlayObject"] newRect:[draggingLayer frame]];
            draggingLayer = nil;
            [self refreshOverlays];
            [[NSCursor openHandCursor] set];
        }
    }
}

#pragma mark Properties

@synthesize overlayDelegate = __delegate;
@synthesize overlayDataSource = __dataSource;

@synthesize overlayBackgroundColor;
@synthesize overlayBorderColor;
@synthesize overlayBorderWidth;

@synthesize allowsCreatingOverlays = __allowsCreatingOverlays;
@synthesize allowsModifyingOverlays = __allowsModifyingOverlays;
@synthesize allowsDeletingOverlays = __allowsDeletingOverlays;
@synthesize allowsOverlappingOverlays = __allowsOverlappingOverlays;
@synthesize wantsOverlayActions = __wantsOverlayActions;

@end
