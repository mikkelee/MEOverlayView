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

#define MEDistance(A,B) sqrtf(powf(fabs(A.x - B.x), 2.0f) + powf(fabs(A.y - B.y), 2.0f))

#import "MEOverlayView.h"

#pragma mark -
#pragma mark Helper class extension

enum {
    MENoCorner = -1,
    MENorthEastCorner,
    MENorthWestCorner,
    MESouthEastCorner,
    MESouthWestCorner
};
typedef NSUInteger MECorner;

@interface MEOverlayView ()

//initialization
- (void)initialSetup;

//helpers
- (void)setMouseForPoint:(NSPoint)point;
- (CGPathRef)newRectPathWithSize:(NSSize)size handles:(BOOL)handles;
- (id)layerAtPoint:(NSPoint)point;
- (MECorner)cornerOfLayer:(CALayer *)layer atPoint:(NSPoint)point;
- (BOOL)isRect:(NSRect)rect validForLayer:(CALayer *)layer;
- (void)draggedFrom:(NSPoint)startPoint to:(NSPoint)endPoint done:(BOOL)done;

//maybe these should be put in categories on their respective objects?
//NSCursor:
- (NSCursor *)northWestSouthEastResizeCursor;
- (NSCursor *)northEastSouthWestResizeCursor;
//IKImageView:
- (NSPoint)convertWindowPointToImagePoint:(NSPoint)windowPoint;
//CAShapeLayer:
- (CAShapeLayer *)layerWithRect:(NSRect)rect handles:(BOOL)handles;

@end

#pragma mark -
#pragma mark Implementation

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
    BOOL __wantsOverlaySingleClickActions;
    BOOL __wantsOverlayDoubleClickActions;
    
    //internal helper ivars
    CGFloat handleWidth;
    CGFloat handleOffset;
    NSCursor *__northWestSouthEastResizeCursor;
    NSCursor *__northEastSouthWestResizeCursor;
    
    //events
    NSPoint mouseDownPoint;
    
    //temp vals
    CAShapeLayer *activeLayer;
    MECorner activeCorner;
    NSPoint activeOrigin;
    NSSize activeSize;
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
    __wantsOverlaySingleClickActions = YES;
    __wantsOverlayDoubleClickActions = YES;
    
    handleWidth = __borderWidth * 2.0f;
    handleOffset = (__borderWidth / 2.0f) + 1.0f;
    
    [self performSelector:@selector(initialSetup) withObject:nil afterDelay:0.0f];
}

- (void)initialSetup
{
    topLayer = [CALayer layer];
    
    [topLayer setFrame:NSMakeRect(0, 0, [self imageSize].width, [self imageSize].height)];
    [topLayer setName:@"topLayer"];
    
    [self reloadData];
    
    NSTrackingArea *fullArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect 
                                                            options:(NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect) 
                                                              owner:self 
                                                           userInfo:[NSDictionary dictionaryWithObject:topLayer forKey:@"layer"]];
    [self addTrackingArea:fullArea];
    
    [self setOverlay:topLayer forType:IKOverlayTypeImage];
}

- (void)reloadData //TODO should be put into the view's normal lifetime
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
        
        CALayer *layer = [self layerWithRect:rect handles:(state == MEModifyingState)];
        
        [layer setValue:[NSNumber numberWithInteger:i] forKey:@"MEOverlayNumber"];
        [layer setValue:overlayObject forKey:@"MEOverlayObject"];
        
        DLog(@"Created layer: %@", layer);
        
        [topLayer addSublayer:layer];
        
        NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:[self convertImageRectToViewRect:rect] 
                                                            options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow) 
                                                              owner:self 
                                                           userInfo:[NSDictionary dictionaryWithObject:layer forKey:@"layer"]];
        [self addTrackingArea:area];
    }
}

#pragma mark Deallocation

- (void)dealloc
{
    [self setOverlayDelegate:nil];
    [self setOverlayDataSource:nil];
    
    CFRelease(__backgroundColor);
    CFRelease(__borderColor);
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
    [self reloadData];
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
    } else if (state == MEIdleState && ([self wantsOverlaySingleClickActions] || [self wantsOverlayDoubleClickActions]) && [hitLayer valueForKey:@"MEOverlayObject"]) {
        if ([theEvent clickCount] == 1 && [self wantsOverlaySingleClickActions]) {
            [__delegate overlayView:self overlay:[hitLayer valueForKey:@"MEOverlayObject"] singleClicked:theEvent];
        } else if ([theEvent clickCount] == 2 && [self wantsOverlayDoubleClickActions]) {
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
    [self setMouseForPoint:[self convertWindowPointToImagePoint:[theEvent locationInWindow]]];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    [self setMouseForPoint:[self convertWindowPointToImagePoint:[theEvent locationInWindow]]];
}

- (void)mouseExited:(NSEvent *)theEvent
{
    [self setMouseForPoint:[self convertWindowPointToImagePoint:[theEvent locationInWindow]]];
}

#pragma mark Helpers

//Weird that NSCursor doesn't provide these types of cursor...
- (NSCursor *)northWestSouthEastResizeCursor
{
    if (__northWestSouthEastResizeCursor == nil) {
        __northWestSouthEastResizeCursor = [[NSCursor alloc] initWithImage:[[NSImage alloc] initWithContentsOfFile:@"/System/Library/Frameworks/WebKit.framework/Versions/A/Frameworks/WebCore.framework/Versions/A/Resources/northWestSouthEastResizeCursor.png"] hotSpot:NSZeroPoint];
    }
    return __northWestSouthEastResizeCursor;
}

- (NSCursor *)northEastSouthWestResizeCursor
{
    if (__northEastSouthWestResizeCursor == nil) {
        __northEastSouthWestResizeCursor = [[NSCursor alloc] initWithImage:[[NSImage alloc] initWithContentsOfFile:@"/System/Library/Frameworks/WebKit.framework/Versions/A/Frameworks/WebCore.framework/Versions/A/Resources/northEastSouthWestResizeCursor.png"] hotSpot:NSZeroPoint];
    }
    return __northEastSouthWestResizeCursor;
}

- (void)setMouseForPoint:(NSPoint)point
{
    //Unfortunately necessary to do it this way since I don't get -cursorUpdate: messages when the mouse leaves a layer and goes back to the topLayer.
    
    CALayer *layer = [self layerAtPoint:point];
    
    if (state == MECreatingState && layer == topLayer) {
        DLog(@"layer %@ topLayer %@", layer, topLayer);
        [[NSCursor crosshairCursor] set];
    } else if (state == MEModifyingState && layer != topLayer) {
        MECorner corner = [self cornerOfLayer:layer atPoint:point];
        if (corner == MENorthEastCorner || corner == MESouthWestCorner) {
            [[self northEastSouthWestResizeCursor] set];
        } else if (corner == MENorthWestCorner || corner == MESouthEastCorner) {
            [[self northWestSouthEastResizeCursor] set];
        } else { //MENoCorner
            [[NSCursor openHandCursor] set];
        }
    } else if (state == MEDeletingState && layer != topLayer) {
        [[NSCursor disappearingItemCursor] set];
    } else {
        [[NSCursor arrowCursor] set];
    }
}

- (NSPoint)convertWindowPointToImagePoint:(NSPoint)windowPoint
{
    DLog(@"windowPoint: %@", NSStringFromPoint(windowPoint));
    NSPoint imagePoint = [self convertViewPointToImagePoint:[self convertPoint:windowPoint fromView:[[self window] contentView]]];
    DLog(@"imagePoint: %@", NSStringFromPoint(imagePoint));
    return imagePoint;
}

- (CGPathRef)newRectPathWithSize:(NSSize)size handles:(BOOL)handles
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, NSMakeRect(0.0, 0.0, size.width, size.height));
    
    if (handles) {
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(-handleOffset, -handleOffset, handleWidth, handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(-handleOffset, size.height - handleOffset, handleWidth, handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(size.width - handleOffset, -handleOffset, handleWidth, handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(size.width - handleOffset, size.height - handleOffset, handleWidth, handleWidth));
    }
    
    return path;
}

- (CAShapeLayer *)layerWithRect:(NSRect)rect handles:(BOOL)handles
{
    CAShapeLayer *layer = [CAShapeLayer layer];
    
    [layer setFrame:rect];
    CGPathRef path = [self newRectPathWithSize:rect.size handles:handles];
    [layer setPath:path];
    CFRelease(path);
    
    [layer setFillColor:__backgroundColor];
    [layer setLineWidth:__borderWidth];
    [layer setStrokeColor:__borderColor];
    [layer setNeedsDisplayOnBoundsChange:YES];
    
    return layer;
}

- (id)layerAtPoint:(NSPoint)point
{
    CALayer *rootLayer = [self overlayForType:IKOverlayTypeImage];
    CALayer *hitLayer = [rootLayer hitTest:[self convertImagePointToViewPoint:point]];
    
    DLog(@"hitLayer for obj %@: %@", [hitLayer valueForKey:@"MEOverlayObject"], hitLayer);
    
    return hitLayer;
}

- (MECorner)cornerOfLayer:(CALayer *)layer atPoint:(NSPoint)point
{
    NSRect frame = [layer frame];
    
    CGFloat tolerance = handleWidth * 2.0f;
    
    NSPoint swPoint = NSMakePoint(frame.origin.x, 
                                  frame.origin.y);
    
    NSPoint nwPoint = NSMakePoint(frame.origin.x, 
                                  frame.origin.y + frame.size.height - (tolerance / 2.0f));
    
    NSPoint nePoint = NSMakePoint(frame.origin.x + frame.size.width - (tolerance / 2.0f), 
                                  frame.origin.y + frame.size.height - (tolerance / 2.0f));
    
    NSPoint sePoint = NSMakePoint(frame.origin.x + frame.size.width - (tolerance / 2.0f), 
                                  frame.origin.y);
    
    if (MEDistance(point, nePoint) <= tolerance) {
        return MENorthEastCorner;
    } else if (MEDistance(point, nwPoint) <= tolerance) {
        return MENorthWestCorner;
    } else if (MEDistance(point, sePoint) <= tolerance) {
        return MESouthEastCorner;
    } else if (MEDistance(point, swPoint) <= tolerance) {
        return MESouthWestCorner;
    } else {
        return MENoCorner;
    }
}

- (BOOL)isRect:(NSRect)rect validForLayer:(CALayer *)layer
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
        for (CALayer *sublayer in [topLayer sublayers]) {
            if (layer == sublayer) {
                continue; //don't compare against oneself
            }
            NSRect frameRect = [sublayer frame];
            if (NSIntersectsRect(rect, frameRect)) {
                DLog(@"layer %@ (rect %@) would intersect layer #%lu %@: %@", layer, NSStringFromRect(rect), [[sublayer valueForKey:@"MEOverlayNumber"] integerValue], sublayer, NSStringFromRect(rect));
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
        if (activeLayer == nil) {
            activeLayer = [self layerWithRect:NSZeroRect handles:YES];
            
            [topLayer addSublayer:activeLayer];
        }
        
        NSPoint origin = NSMakePoint(fmin(startPoint.x, endPoint.x), fmin(startPoint.y, endPoint.y));
        NSPoint end = NSMakePoint(fmax(startPoint.x, endPoint.x), fmax(startPoint.y, endPoint.y));
        NSSize size = NSMakeSize(end.x - origin.x, end.y - origin.y);
        NSRect newRect = NSMakeRect(origin.x, origin.y, size.width, size.height);
        
        BOOL validLocation = [self isRect:newRect validForLayer:activeLayer];
        
        if (validLocation) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.0f];
            [activeLayer setFrame:newRect];
            CGPathRef path = [self newRectPathWithSize:newRect.size handles:YES];
            [activeLayer setPath:path];
            CFRelease(path);
            [CATransaction commit];
        }
        
        if (done) {
            DLog(@"done creating: %@", NSStringFromRect([activeLayer frame]));
            [__delegate overlayView:self didCreateOverlay:[activeLayer frame]];
            [activeLayer removeFromSuperlayer];
            activeLayer = nil;
        }
    } else if (state == MEModifyingState && [self allowsModifyingOverlays]) {
        DLog(@"modifying");
        
        if (activeLayer == nil) {
            CAShapeLayer *hitLayer = [self layerAtPoint:startPoint];
            if (hitLayer == topLayer || [hitLayer valueForKey:@"MEOverlayObject"] == nil) {
                return;
            }
            activeLayer = hitLayer;
            activeCorner = [self cornerOfLayer:activeLayer atPoint:startPoint];
            
            xOffset = [activeLayer position].x - endPoint.x;
            yOffset = [activeLayer position].y - endPoint.y;
            
            activeOrigin = [activeLayer frame].origin;
            activeSize = [activeLayer frame].size;
            
            DLog(@"xOffset: %f yOffset: %f", xOffset, yOffset);
        }
        [[NSCursor closedHandCursor] set];
        
        NSRect newRect = NSZeroRect;
        
        CGFloat xDelta = endPoint.x - startPoint.x;
        CGFloat yDelta = endPoint.y - startPoint.y;
        
        if (activeCorner == MENorthEastCorner) {
            newRect = NSMakeRect(activeOrigin.x, 
                                 activeOrigin.y, 
                                 activeSize.width + xDelta, 
                                 activeSize.height + yDelta);
        } else if (activeCorner == MENorthWestCorner) {
            newRect = NSMakeRect(activeOrigin.x + xDelta, 
                                 activeOrigin.y, 
                                 activeSize.width - xDelta, 
                                 activeSize.height + yDelta);
        } else if (activeCorner == MESouthEastCorner) {
            newRect = NSMakeRect(activeOrigin.x, 
                                 activeOrigin.y + yDelta, 
                                 activeSize.width + xDelta, 
                                 activeSize.height - yDelta);
        } else if (activeCorner == MESouthWestCorner) {
            newRect = NSMakeRect(activeOrigin.x + xDelta, 
                                 activeOrigin.y + yDelta, 
                                 activeSize.width - xDelta, 
                                 activeSize.height - yDelta);
        } else { //MENoCorner
            newRect = NSMakeRect(endPoint.x + xOffset - (activeSize.width * 0.5f), 
                                 endPoint.y + yOffset - (activeSize.height * 0.5f), 
                                 activeSize.width, 
                                 activeSize.height);
        }
        
        DLog(@"corner: %lu : %@", activeCorner, NSStringFromRect(newRect));
        
        BOOL validLocation = [self isRect:newRect validForLayer:activeLayer];
        
        if (validLocation) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.0f];
            [activeLayer setFrame:newRect];
            CGPathRef path = [self newRectPathWithSize:newRect.size handles:YES];
            [activeLayer setPath:path];
            CFRelease(path);
            [CATransaction commit];
        }
        
        if (done) {
            DLog(@"done modifying %@: %@", [activeLayer valueForKey:@"MEOverlayObject"], NSStringFromRect([activeLayer frame]));
            [__delegate overlayView:self didModifyOverlay:[activeLayer valueForKey:@"MEOverlayObject"] newRect:[activeLayer frame]];
            activeLayer = nil;
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
@synthesize wantsOverlaySingleClickActions = __wantsOverlaySingleClickActions;
@synthesize wantsOverlayDoubleClickActions = __wantsOverlayDoubleClickActions;

@end
