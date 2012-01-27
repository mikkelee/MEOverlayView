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
- (void)drawOverlays;

//helpers
- (void)setMouseForPoint:(NSPoint)point;
- (CGPathRef)newRectPathWithSize:(NSSize)size handles:(BOOL)handles;
- (id)layerAtPoint:(NSPoint)point;
- (MECorner)cornerOfLayer:(CALayer *)layer atPoint:(NSPoint)point;
- (BOOL)rect:(NSRect)rect isValidForLayer:(CALayer *)layer;
- (void)draggedFrom:(NSPoint)startPoint to:(NSPoint)endPoint done:(BOOL)done;

//maybe these should be put in categories on their respective objects?
//NSCursor:
- (NSCursor *)northWestSouthEastResizeCursor;
- (NSCursor *)northEastSouthWestResizeCursor;
//IKImageView:
- (NSPoint)convertWindowPointToImagePoint:(NSPoint)windowPoint;
//CAShapeLayer:
- (CAShapeLayer *)layerWithRect:(NSRect)rect handles:(BOOL)handles selected:(BOOL)selected;

@end

#pragma mark -
#pragma mark Implementation

@implementation MEOverlayView {
    __weak id __delegate;
    id __dataSource;
    
    MEState __state;
    CALayer *__topLayer;
    
    //properties
    CGColorRef __overlayBackgroundColor;
    CGColorRef __overlayBorderColor;
    CGColorRef __overlaySelectionBackgroundColor;
    CGColorRef __overlaySelectionBorderColor;
    CGFloat __overlayBorderWidth;
    
    BOOL __allowsCreatingOverlays;
    BOOL __allowsModifyingOverlays;
    BOOL __allowsDeletingOverlays;
    BOOL __allowsOverlappingOverlays;
    
    BOOL __wantsOverlaySingleClickActions;
    BOOL __wantsOverlayDoubleClickActions;
    BOOL __wantsOverlayRightClickActions;
    
    BOOL __allowsSelection;
    BOOL __allowsEmptySelection;
    BOOL __allowsMultipleSelection;
    
    //internal helper ivars
    CGFloat __handleWidth;
    CGFloat __handleOffset;
    NSCursor *__northWestSouthEastResizeCursor;
    NSCursor *__northEastSouthWestResizeCursor;
    
    //events
    NSPoint __mouseDownPoint;
    
    //temp vals
    CAShapeLayer *__activeLayer;
    MECorner __activeCorner;
    NSPoint __activeOrigin;
    NSSize __activeSize;
    CGFloat __xOffset;
    CGFloat __yOffset;
    NSInvocation *__singleClickInvocation;
    
    //cache
    NSMutableArray *__overlayCache;
    NSMutableArray *__selectedOverlays;
}

#pragma mark Initialization

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    
    if (self) {
        DLog(@"init");
        __state = MEIdleState;
        
        //default property values:
        __overlayBackgroundColor = CGColorCreateGenericRGB(0.0f, 0.0f, 1.0f, 0.5f);
        __overlayBorderColor = CGColorCreateGenericRGB(0.0f, 0.0f, 1.0f, 1.0f);
        __overlaySelectionBackgroundColor = CGColorCreateGenericRGB(0.0f, 1.0f, 0.0f, 0.5f);
        __overlaySelectionBorderColor = CGColorCreateGenericRGB(0.0f, 1.0f, 0.0f, 1.0f);
        __overlayBorderWidth = 3.0f;
        
        __allowsCreatingOverlays = YES;
        __allowsModifyingOverlays = YES;
        __allowsDeletingOverlays = YES;
        __allowsOverlappingOverlays = NO;
        
        __wantsOverlaySingleClickActions = YES;
        __wantsOverlayDoubleClickActions = YES;
        __wantsOverlayRightClickActions = YES;
        
        __allowsSelection = YES;
        __allowsEmptySelection = YES;
        __allowsMultipleSelection = YES;
        
        __handleWidth = __overlayBorderWidth * 2.0f;
        __handleOffset = (__overlayBorderWidth / 2.0f) + 1.0f;
        
        __overlayCache = [NSMutableArray arrayWithCapacity:0];
        __selectedOverlays = [NSMutableArray arrayWithCapacity:0];
    }
    
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    DLog(@"overlayDelegate: %@", __delegate);

    [self performSelector:@selector(initialSetup) withObject:nil afterDelay:0.0f];
}

- (void)initialSetup
{
    __topLayer = [CALayer layer];
    
    [__topLayer setFrame:NSMakeRect(0.0f, 0.0f, [self imageSize].width, [self imageSize].height)];
    [__topLayer setName:@"topLayer"];
    
    [self reloadData];
    
    NSTrackingArea *fullArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect 
                                                            options:(NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect) 
                                                              owner:self 
                                                           userInfo:[NSDictionary dictionaryWithObject:__topLayer forKey:@"layer"]];
    [self addTrackingArea:fullArea];
    
    [self setOverlay:__topLayer forType:IKOverlayTypeImage];
}

- (void)reloadData
{
    DLog(@"Setting up overlays from overlayDelegate: %@", __delegate);
    
    NSUInteger count = [__dataSource numberOfOverlaysInOverlayView:self];
    
    DLog(@"Number of overlays to create: %lu", count);
    
    __overlayCache = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        [__overlayCache addObject:[__dataSource overlayView:self overlayObjectAtIndex:i]];
    }
    
    [self drawOverlays];
}

- (void)drawOverlays
{
    DLog(@"start");
    [__topLayer setSublayers:[NSArray array]];
    
    if (![self allowsEmptySelection] && [__selectedOverlays count] == 0 && [__overlayCache count] > 0) {
        __selectedOverlays = [NSMutableArray arrayWithObject:[__overlayCache lastObject]];
    }
    
    __weak MEOverlayView *weakSelf = self;
    [__overlayCache enumerateObjectsUsingBlock:^(id overlayObject, NSUInteger i, BOOL *stop){
        MEOverlayView *strongSelf = weakSelf;
        DLog(@"Creating layer #%lu", i);
        
        NSRect rect = NSZeroRect;
        if ([overlayObject respondsToSelector:@selector(rectValue)]) {
            rect = [overlayObject rectValue];
        } else if ([overlayObject respondsToSelector:@selector(rect)]) {
            rect = [overlayObject rect];
        } else {
            @throw [NSException exceptionWithName:@"MEOverlayObjectHasNoRect"
                                           reason:@"Objects given to MEOverlayView must respond to -(NSRect)rectValue or -(NSRect)rect"
                                         userInfo:nil];
        }
        
        CALayer *layer = [strongSelf layerWithRect:rect 
                                           handles:(__state == MEModifyingState)
                                          selected:[__selectedOverlays containsObject:overlayObject]];
        
        [layer setValue:[NSNumber numberWithInteger:i] forKey:@"MEOverlayNumber"];
        [layer setValue:overlayObject forKey:@"MEOverlayObject"];
        
        DLog(@"Created layer: %@", layer);
        
        [__topLayer addSublayer:layer];
        
        NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:[strongSelf convertImageRectToViewRect:rect] 
                                                            options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow) 
                                                              owner:self 
                                                           userInfo:[NSDictionary dictionaryWithObject:layer forKey:@"layer"]];
        [self addTrackingArea:area];
    }];
}

#pragma mark Deallocation

- (void)dealloc
{
    [self setOverlayDelegate:nil];
    [self setOverlayDataSource:nil];
    
    CFRelease(__overlayBackgroundColor);
    CFRelease(__overlayBorderColor);
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
        DLog(@"%lu => %lu", __state, _state);
        __state = _state;
        [self setNeedsDisplay:YES];
        return YES;
    }
}

#pragma mark Selection

- (void)selectOverlayIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend
{
    if (extend) {
        [__selectedOverlays addObjectsFromArray:[__overlayCache objectsAtIndexes:indexes]];
    } else {
        __selectedOverlays = [[__overlayCache objectsAtIndexes:indexes] mutableCopy];
    }
}

- (NSInteger)selectedOverlay
{
    return [__selectedOverlays count]-1;
}

- (NSIndexSet *)selectedOverlayIndexes
{
    return [__overlayCache indexesOfObjectsPassingTest:^(id overlayObject, NSUInteger i, BOOL *stop){
        return [__selectedOverlays containsObject:overlayObject];
    }];
}

- (void)deselectOverlay:(NSInteger)overlayIndex
{
    [__selectedOverlays removeObject:[__overlayCache objectAtIndex:overlayIndex]];
}

- (NSInteger)numberOfSelectedOverlays
{
    return [__selectedOverlays count];
}

- (BOOL)isOverlaySelected:(NSInteger)overlayIndex
{
    return [__selectedOverlays containsObject:[__overlayCache objectAtIndex:overlayIndex]];
}

- (void)selectAll:(id)sender
{
    __selectedOverlays = [__overlayCache mutableCopy];
}

- (void)deselectAll:(id)sender
{
    __selectedOverlays = [NSMutableArray arrayWithCapacity:2];
}

#pragma mark Drawing

- (void)viewWillDraw
{
    DLog(@"viewWillDraw");
    [self drawOverlays];
}

#pragma mark Mouse events

- (void)mouseDown:(NSEvent *)theEvent
{
    __mouseDownPoint = [self convertWindowPointToImagePoint:[theEvent locationInWindow]];
    
    [super mouseDown:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint mouseUpPoint = [self convertWindowPointToImagePoint:[theEvent locationInWindow]];
    CGFloat epsilonSquared = 0.025;
    
    CGFloat dx = __mouseDownPoint.x - mouseUpPoint.x, dy = __mouseDownPoint.y - mouseUpPoint.y;
    BOOL pointsAreEqual = (dx * dx + dy * dy) < epsilonSquared;
    
    if ((__state == MECreatingState || __state == MEModifyingState) && !pointsAreEqual) {
        [self draggedFrom:__mouseDownPoint to:mouseUpPoint done:NO];
    } else {
        [super mouseDragged:theEvent];
    }
}

- (void)mouseUp:(NSEvent *)theEvent
{
    NSPoint mouseUpPoint = [self convertWindowPointToImagePoint:[theEvent locationInWindow]];
    CGFloat epsilonSquared = 0.025;
    
    CGFloat dx = __mouseDownPoint.x - mouseUpPoint.x, dy = __mouseDownPoint.y - mouseUpPoint.y;
    BOOL pointsAreEqual = (dx * dx + dy * dy) < epsilonSquared;
    
    CALayer *hitLayer = [self layerAtPoint:mouseUpPoint];
    
    if (__state == MEDeletingState && [self allowsDeletingOverlays] && [hitLayer valueForKey:@"MEOverlayObject"]) {
        id overlayObject = [hitLayer valueForKey:@"MEOverlayObject"];
        [__delegate overlayView:self didDeleteOverlay:overlayObject];
        [__selectedOverlays removeObject:overlayObject];
    } else if (__state == MEIdleState && [hitLayer valueForKey:@"MEOverlayObject"]) {
        if ([self allowsSelection]) {
            NSUInteger layerNumber = [[hitLayer valueForKey:@"MEOverlayNumber"] integerValue];
            DLog(@"checking select with %lu", layerNumber);
            if ([self isOverlaySelected:layerNumber]) {
                if ([self numberOfSelectedOverlays] > 1 || [self allowsEmptySelection]) {
                    DLog(@"deselected");
                    [self deselectOverlay:layerNumber];
                }
            } else {
                [self selectOverlayIndexes:[NSIndexSet indexSetWithIndex:layerNumber] 
                      byExtendingSelection:[self allowsMultipleSelection]];
            }
            DLog(@"current selection: %@", __selectedOverlays);
            [self drawOverlays];
        }
        if ([self wantsOverlaySingleClickActions] || [self wantsOverlayDoubleClickActions]) {
            DLog(@"click!");
            DLog(@"[self wantsOverlaySingleClickActions]: %d", [self wantsOverlaySingleClickActions]);
            DLog(@"[self wantsOverlayDoubleClickActions]: %d", [self wantsOverlayDoubleClickActions]);
            if ([theEvent clickCount] == 1 && [self wantsOverlaySingleClickActions]) {
                SEL theSelector = @selector(overlayView:overlay:singleClicked:);
                __singleClickInvocation = [NSInvocation invocationWithMethodSignature:[[__delegate class] instanceMethodSignatureForSelector:theSelector]];
                
                [__singleClickInvocation setSelector:theSelector];
                [__singleClickInvocation setTarget:__delegate];
                MEOverlayView *selfRef = self;
                id overlayObject = [hitLayer valueForKey:@"MEOverlayObject"];
                [__singleClickInvocation setArgument:&selfRef atIndex:2];
                [__singleClickInvocation setArgument:&overlayObject atIndex:3];
                [__singleClickInvocation setArgument:&theEvent atIndex:4];
                [__singleClickInvocation retainArguments]; 
               
                [__singleClickInvocation performSelector:@selector(invoke) withObject:nil afterDelay:[NSEvent doubleClickInterval]];
                //[__delegate overlayView:self overlay:[hitLayer valueForKey:@"MEOverlayObject"] singleClicked:theEvent];
            } else if ([theEvent clickCount] == 2 && [self wantsOverlayDoubleClickActions]) {
                DLog(@"Cancelling single click: %@", __singleClickInvocation);
                [NSRunLoop cancelPreviousPerformRequestsWithTarget:__singleClickInvocation];
                [__delegate overlayView:self overlay:[hitLayer valueForKey:@"MEOverlayObject"] doubleClicked:theEvent];
            } else {
                [super mouseUp:theEvent];
            }
        }
    } else if ((__state == MECreatingState || __state == MEModifyingState) && !pointsAreEqual) {
        [self draggedFrom:__mouseDownPoint to:mouseUpPoint done:YES];
    } else {
        [super mouseUp:theEvent];
    }
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
    NSPoint mouseUpPoint = [self convertWindowPointToImagePoint:[theEvent locationInWindow]];
    
    CALayer *hitLayer = [self layerAtPoint:mouseUpPoint];
    
    if (__state == MEIdleState && [hitLayer valueForKey:@"MEOverlayObject"] && [self wantsOverlayRightClickActions]) {
        [__delegate overlayView:self overlay:[hitLayer valueForKey:@"MEOverlayObject"] rightClicked:theEvent];
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

#pragma mark Key events

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
    //prevents "beep" on button click.
    [super keyDown:theEvent];
}

- (void)keyUp:(NSEvent *)theEvent
{
    id selection = [__selectedOverlays lastObject];
    DLog(@"selection: %@", selection);
    if (selection == nil) {
        return;
    }
    
    CGPoint center = NSMakePoint(NSMidX([selection rectValue]), NSMidY([selection rectValue]));
    
    id bestCandidate = nil;
    CGFloat bestDistance = MAXFLOAT;
    
    for (CALayer *sublayer in [__topLayer sublayers]) {
        if (selection == sublayer) {
            continue; //don't compare against oneself
        }
        CGFloat dist = MEDistance(center, NSMakePoint(NSMidX([sublayer frame]), NSMidY([sublayer frame])));
        switch ([theEvent keyCode]) {
            case 0x7B: { //left arrow
                if (dist < bestDistance && NSMidX([sublayer frame]) < center.x) {
                    bestCandidate = sublayer;
                    bestDistance = dist;
                }
            }
                break;
            case 0x7C: { //right arrow
                if (dist < bestDistance && NSMidX([sublayer frame]) > center.x) {
                    bestCandidate = sublayer;
                    bestDistance = dist;
                }
            }
                break;
            case 0x7D: { //down arrow
                if (dist < bestDistance && NSMidY([sublayer frame]) < center.y) {
                    bestCandidate = sublayer;
                    bestDistance = dist;
                }
            }
                break;
            case 0x7E: { //up arrow
                if (dist < bestDistance && NSMidY([sublayer frame]) > center.y) {
                    bestCandidate = sublayer;
                    bestDistance = dist;
                }
            }
                break;
            default:;
                break;
        }
    }
    
    if (bestCandidate) {
        __selectedOverlays = [NSMutableArray arrayWithObject:[bestCandidate valueForKey:@"MEOverlayObject"]];
        [self drawOverlays];
    }
    
    [super keyUp:theEvent];
}

#pragma mark Helpers

//Weird that NSCursor doesn't provide these types of cursor...
- (NSCursor *)northWestSouthEastResizeCursor
{
    if (__northWestSouthEastResizeCursor == nil) {
        __northWestSouthEastResizeCursor = [[NSCursor alloc] initWithImage:[[NSImage alloc] initWithContentsOfFile:@"/System/Library/Frameworks/WebKit.framework/Versions/A/Frameworks/WebCore.framework/Versions/A/Resources/northWestSouthEastResizeCursor.png"] hotSpot:NSMakePoint(8.0f, 8.0f)];
    }
    return __northWestSouthEastResizeCursor;
}

- (NSCursor *)northEastSouthWestResizeCursor
{
    if (__northEastSouthWestResizeCursor == nil) {
        __northEastSouthWestResizeCursor = [[NSCursor alloc] initWithImage:[[NSImage alloc] initWithContentsOfFile:@"/System/Library/Frameworks/WebKit.framework/Versions/A/Frameworks/WebCore.framework/Versions/A/Resources/northEastSouthWestResizeCursor.png"] hotSpot:NSMakePoint(8.0f, 8.0f)];
    }
    return __northEastSouthWestResizeCursor;
}

- (void)setMouseForPoint:(NSPoint)point
{
    //Unfortunately necessary to do it this way since I don't get -cursorUpdate: messages when the mouse leaves a layer and goes back to the topLayer.
    
    CALayer *layer = [self layerAtPoint:point];
    
    if (__state == MECreatingState && layer == __topLayer) {
        DLog(@"layer %@ topLayer %@", layer, __topLayer);
        [[NSCursor crosshairCursor] set];
    } else if (__state == MEModifyingState && layer != __topLayer) {
        MECorner corner = [self cornerOfLayer:layer atPoint:point];
        if (corner == MENorthEastCorner || corner == MESouthWestCorner) {
            [[self northEastSouthWestResizeCursor] set];
        } else if (corner == MENorthWestCorner || corner == MESouthEastCorner) {
            [[self northWestSouthEastResizeCursor] set];
        } else { //MENoCorner
            [[NSCursor openHandCursor] set];
        }
    } else if (__state == MEDeletingState && layer != __topLayer) {
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
    CGPathAddRect(path, NULL, NSMakeRect(0.0f, 0.0f, size.width, size.height));
    
    if (handles) {
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(-__handleOffset, -__handleOffset, __handleWidth, __handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(-__handleOffset, size.height - __handleOffset, __handleWidth, __handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(size.width - __handleOffset, -__handleOffset, __handleWidth, __handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(size.width - __handleOffset, size.height - __handleOffset, __handleWidth, __handleWidth));
    }
    
    return path;
}

- (CAShapeLayer *)layerWithRect:(NSRect)rect handles:(BOOL)handles selected:(BOOL)selected
{
    CAShapeLayer *layer = [CAShapeLayer layer];
    
    [layer setFrame:rect];
    CGPathRef path = [self newRectPathWithSize:rect.size handles:handles];
    [layer setPath:path];
    CFRelease(path);
    
    if (selected) {
        DLog(@"drawing selected");
        [layer setFillColor:__overlaySelectionBackgroundColor];
        [layer setStrokeColor:__overlaySelectionBorderColor];
    } else {
        [layer setFillColor:__overlayBackgroundColor];
        [layer setStrokeColor:__overlayBorderColor];
    }
    [layer setLineWidth:__overlayBorderWidth];
    [layer setNeedsDisplayOnBoundsChange:YES];
    
    return layer;
}

- (id)layerAtPoint:(NSPoint)point
{
    CALayer *rootLayer = [self overlayForType:IKOverlayTypeImage];
    CALayer *hitLayer = [rootLayer hitTest:[self convertImagePointToViewPoint:point]];
    
    if (hitLayer != __topLayer) {
        DLog(@"hitLayer for obj %@: %@", [hitLayer valueForKey:@"MEOverlayObject"], hitLayer);
    }
    
    return hitLayer;
}

- (MECorner)cornerOfLayer:(CALayer *)layer atPoint:(NSPoint)point
{
    NSRect frame = [layer frame];
    
    CGFloat tolerance = __handleWidth * 3.0f;
    
    NSPoint swPoint = NSMakePoint(frame.origin.x, 
                                  frame.origin.y);
    
    NSPoint nwPoint = NSMakePoint(frame.origin.x, 
                                  frame.origin.y + frame.size.height);
    
    NSPoint nePoint = NSMakePoint(frame.origin.x + frame.size.width, 
                                  frame.origin.y + frame.size.height);
    
    NSPoint sePoint = NSMakePoint(frame.origin.x + frame.size.width, 
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

- (BOOL)rect:(NSRect)rect isValidForLayer:(CALayer *)layer
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
        for (CALayer *sublayer in [__topLayer sublayers]) {
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
    
    if (__state == MECreatingState && [self allowsCreatingOverlays]) {
        DLog(@"creating");
        if (__activeLayer == nil) {
            __activeLayer = [self layerWithRect:NSZeroRect handles:YES selected:YES];
            
            [__topLayer addSublayer:__activeLayer];
        }
        
        NSPoint origin = NSMakePoint(fmin(startPoint.x, endPoint.x), fmin(startPoint.y, endPoint.y));
        NSPoint end = NSMakePoint(fmax(startPoint.x, endPoint.x), fmax(startPoint.y, endPoint.y));
        NSSize size = NSMakeSize(end.x - origin.x, end.y - origin.y);
        NSRect newRect = NSMakeRect(origin.x, origin.y, size.width, size.height);
        
        BOOL validLocation = [self rect:newRect isValidForLayer:__activeLayer];
        
        if (validLocation) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.0f];
            [__activeLayer setFrame:newRect];
            CGPathRef path = [self newRectPathWithSize:newRect.size handles:YES];
            [__activeLayer setPath:path];
            CFRelease(path);
            [CATransaction commit];
        }
        
        if (done) {
            DLog(@"done creating: %@", NSStringFromRect([__activeLayer frame]));
            [__delegate overlayView:self didCreateOverlay:[__activeLayer frame]];
            [__activeLayer removeFromSuperlayer];
            __activeLayer = nil;
        }
    } else if (__state == MEModifyingState && [self allowsModifyingOverlays]) {
        DLog(@"modifying");
        
        if (__activeLayer == nil) {
            CAShapeLayer *hitLayer = [self layerAtPoint:startPoint];
            if (hitLayer == __topLayer || [hitLayer valueForKey:@"MEOverlayObject"] == nil) {
                return;
            }
            __activeLayer = hitLayer;
            __activeCorner = [self cornerOfLayer:__activeLayer atPoint:startPoint];
            
            __xOffset = [__activeLayer position].x - endPoint.x;
            __yOffset = [__activeLayer position].y - endPoint.y;
            
            __activeOrigin = [__activeLayer frame].origin;
            __activeSize = [__activeLayer frame].size;
            
            DLog(@"xOffset: %f yOffset: %f", __xOffset, __yOffset);
        }
        [[NSCursor closedHandCursor] set];
        
        NSRect newRect = NSZeroRect;
        
        CGFloat xDelta = endPoint.x - startPoint.x;
        CGFloat yDelta = endPoint.y - startPoint.y;
        
        if (__activeCorner == MENorthEastCorner) {
            newRect = NSMakeRect(__activeOrigin.x, 
                                 __activeOrigin.y, 
                                 __activeSize.width + xDelta, 
                                 __activeSize.height + yDelta);
        } else if (__activeCorner == MENorthWestCorner) {
            newRect = NSMakeRect(__activeOrigin.x + xDelta, 
                                 __activeOrigin.y, 
                                 __activeSize.width - xDelta, 
                                 __activeSize.height + yDelta);
        } else if (__activeCorner == MESouthEastCorner) {
            newRect = NSMakeRect(__activeOrigin.x, 
                                 __activeOrigin.y + yDelta, 
                                 __activeSize.width + xDelta, 
                                 __activeSize.height - yDelta);
        } else if (__activeCorner == MESouthWestCorner) {
            newRect = NSMakeRect(__activeOrigin.x + xDelta, 
                                 __activeOrigin.y + yDelta, 
                                 __activeSize.width - xDelta, 
                                 __activeSize.height - yDelta);
        } else { //MENoCorner
            newRect = NSMakeRect(endPoint.x + __xOffset - (__activeSize.width * 0.5f), 
                                 endPoint.y + __yOffset - (__activeSize.height * 0.5f), 
                                 __activeSize.width, 
                                 __activeSize.height);
        }
        
        /*
         TODO:
         for smoother operation, something like:
         
         do {
            newrect = ...
            
            delta = delta - (delta/abs(delta)) // make delta 1 closer to zero each iteration
         } while (!isvalid);
         
         */
        
        DLog(@"corner: %lu : %@", __activeCorner, NSStringFromRect(newRect));
        
        BOOL validLocation = [self rect:newRect isValidForLayer:__activeLayer];
        
        if (validLocation) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.0f];
            [__activeLayer setFrame:newRect];
            CGPathRef path = [self newRectPathWithSize:newRect.size handles:YES];
            [__activeLayer setPath:path];
            CFRelease(path);
            [CATransaction commit];
        }
        
        if (done) {
            DLog(@"done modifying %@: %@", [__activeLayer valueForKey:@"MEOverlayObject"], NSStringFromRect([__activeLayer frame]));
            [__delegate overlayView:self didModifyOverlay:[__activeLayer valueForKey:@"MEOverlayObject"] newRect:[__activeLayer frame]];
            __activeLayer = nil;
            [[NSCursor openHandCursor] set];
        }
    }
}



#pragma mark Properties

@synthesize overlayDelegate = __delegate;
@synthesize overlayDataSource = __dataSource;

@synthesize overlayBackgroundColor = __overlayBackgroundColor;
@synthesize overlayBorderColor = __overlayBorderColor;
@synthesize overlaySelectionBackgroundColor = __overlaySelectionBackgroundColor;
@synthesize overlaySelectionBorderColor = __overlaySelectionBorderColor;
@synthesize overlayBorderWidth = __overlayBorderWidth;

@synthesize allowsCreatingOverlays = __allowsCreatingOverlays;
@synthesize allowsModifyingOverlays = __allowsModifyingOverlays;
@synthesize allowsDeletingOverlays = __allowsDeletingOverlays;
@synthesize allowsOverlappingOverlays = __allowsOverlappingOverlays;

@synthesize wantsOverlaySingleClickActions = __wantsOverlaySingleClickActions;
@synthesize wantsOverlayDoubleClickActions = __wantsOverlayDoubleClickActions;
@synthesize wantsOverlayRightClickActions = __wantsOverlayRightClickActions;

@synthesize allowsSelection = __allowsSelection;
@synthesize allowsEmptySelection = __allowsEmptySelection;
@synthesize allowsMultipleSelection = __allowsMultipleSelection;

@end
