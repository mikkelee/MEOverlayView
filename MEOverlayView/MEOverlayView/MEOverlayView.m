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
    __weak id __ME_overlayDelegate;
    __weak id __ME_overlayDataSource;
    
    MEState __ME_state;
    CALayer *__ME_topLayer;
    
    //properties
    CGColorRef __ME_overlayFillColor;
    CGColorRef __ME_overlayBorderColor;
    CGColorRef __ME_overlaySelectionFillColor;
    CGColorRef __ME_overlaySelectionBorderColor;
    CGFloat __ME_overlayBorderWidth;
    
    __weak id __ME_target;
    SEL __ME_action;
    SEL __ME_doubleAction;
    SEL __ME_rightAction;
    
    BOOL __ME_allowsCreatingOverlays;
    BOOL __ME_allowsModifyingOverlays;
    BOOL __ME_allowsDeletingOverlays;
    BOOL __ME_allowsOverlappingOverlays;
    
    BOOL __ME_allowsOverlaySelection;
    BOOL __ME_allowsEmptyOverlaySelection;
    BOOL __ME_allowsMultipleOverlaySelection;
    
    //internal helper ivars
    CGFloat __ME_handleWidth;
    CGFloat __ME_handleOffset;
    NSCursor *__ME_northWestSouthEastResizeCursor;
    NSCursor *__ME_northEastSouthWestResizeCursor;
    
    //events
    NSPoint __ME_mouseDownPoint;
    
    //temp vals
    CAShapeLayer *__ME_activeLayer;
    MECorner __ME_activeCorner;
    NSPoint __ME_activeOrigin;
    NSSize __ME_activeSize;
    CGFloat __ME_xOffset;
    CGFloat __ME_yOffset;
    NSInvocation *__ME_singleClickInvocation;
    
    //cache
    NSMutableArray *__ME_overlayCache;
    NSMutableArray *__ME_selectedOverlays;
    NSInteger __ME_clickedOverlay;
}

#pragma mark Initialization

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    
    if (self) {
        DLog(@"init");
        __ME_state = MEIdleState;
        
        //default property values:
        __ME_overlayFillColor = CGColorCreateGenericRGB(0.0f, 0.0f, 1.0f, 0.5f);
        __ME_overlayBorderColor = CGColorCreateGenericRGB(0.0f, 0.0f, 1.0f, 1.0f);
        __ME_overlaySelectionFillColor = CGColorCreateGenericRGB(0.0f, 1.0f, 0.0f, 0.5f);
        __ME_overlaySelectionBorderColor = CGColorCreateGenericRGB(0.0f, 1.0f, 0.0f, 1.0f);
        __ME_overlayBorderWidth = 3.0f;
        
        __ME_allowsCreatingOverlays = YES;
        __ME_allowsModifyingOverlays = YES;
        __ME_allowsDeletingOverlays = YES;
        __ME_allowsOverlappingOverlays = NO;
        
        __ME_allowsOverlaySelection = YES;
        __ME_allowsEmptyOverlaySelection = YES;
        __ME_allowsMultipleOverlaySelection = YES;
        
        __ME_handleWidth = __ME_overlayBorderWidth * 2.0f;
        __ME_handleOffset = (__ME_overlayBorderWidth / 2.0f) + 1.0f;
        
        __ME_overlayCache = [NSMutableArray arrayWithCapacity:0];
        __ME_selectedOverlays = [NSMutableArray arrayWithCapacity:0];
        __ME_clickedOverlay = -1;
    }
    
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    DLog(@"overlayDelegate: %@", __ME_overlayDelegate);

    [self performSelector:@selector(initialSetup) withObject:nil afterDelay:0.0f];
}

- (void)initialSetup
{
    __ME_topLayer = [CALayer layer];
    
    [__ME_topLayer setFrame:NSMakeRect(0.0f, 0.0f, [self imageSize].width, [self imageSize].height)];
    [__ME_topLayer setName:@"topLayer"];
    
    [self reloadData];
    
    NSTrackingArea *fullArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect 
                                                            options:(NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect) 
                                                              owner:self 
                                                           userInfo:[NSDictionary dictionaryWithObject:__ME_topLayer forKey:@"layer"]];
    [self addTrackingArea:fullArea];
    
    [self setOverlay:__ME_topLayer forType:IKOverlayTypeImage];
}

- (void)reloadData
{
    DLog(@"Setting up overlays from overlayDelegate: %@", __ME_overlayDelegate);
    
    NSUInteger count = [__ME_overlayDataSource numberOfOverlaysInOverlayView:self];
    
    DLog(@"Number of overlays to create: %lu", count);
    
    __ME_overlayCache = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        [__ME_overlayCache addObject:[__ME_overlayDataSource overlayView:self overlayObjectAtIndex:i]];
    }
    
    [self drawOverlays];
}

- (void)drawOverlays
{
    DLog(@"start");
    if (![self allowsEmptyOverlaySelection] && [__ME_selectedOverlays count] == 0 && [__ME_overlayCache count] > 0) {
        __ME_selectedOverlays = [NSMutableArray arrayWithObject:[__ME_overlayCache lastObject]];
    }
    
    [__ME_topLayer setSublayers:[NSArray array]];
    
    __weak MEOverlayView *weakSelf = self;
    [__ME_overlayCache enumerateObjectsUsingBlock:^(id overlayObject, NSUInteger i, BOOL *stop){
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
                                           handles:(__ME_state == MEModifyingState)
                                          selected:[__ME_selectedOverlays containsObject:overlayObject]];
        
        [layer setValue:[NSNumber numberWithInteger:i] forKey:@"MEOverlayNumber"];
        [layer setValue:overlayObject forKey:@"MEOverlayObject"];
        
        DLog(@"Created layer: %@", layer);
        
        NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:[strongSelf convertImageRectToViewRect:rect] 
                                                            options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow) 
                                                              owner:self 
                                                           userInfo:[NSDictionary dictionaryWithObject:layer forKey:@"layer"]];
        [self addTrackingArea:area];
        [layer setValue:area forKey:@"MEOverlayTrackingArea"];
        
        [__ME_topLayer addSublayer:layer];
    }];
}

#pragma mark Deallocation

- (void)dealloc
{
    [self setOverlayDelegate:nil];
    [self setOverlayDataSource:nil];
    
    CFRelease(__ME_overlayFillColor);
    CFRelease(__ME_overlayBorderColor);
}

#pragma mark State

- (BOOL)enterState:(MEState)_state
{
    //check for allowances
    if (_state == MECreatingState && !__ME_allowsCreatingOverlays) {
        return NO;
    } else if (_state == MEModifyingState && !__ME_allowsModifyingOverlays) {
        return NO;
    } else if (_state == MEDeletingState && !__ME_allowsDeletingOverlays) {
        return NO;
    } else {
        DLog(@"%lu => %lu", __ME_state, _state);
        __ME_state = _state;
        [self setNeedsDisplay:YES];
        return YES;
    }
}

#pragma mark Selection

- (void)selectOverlayIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend
{
    if (extend) {
        [__ME_selectedOverlays addObjectsFromArray:[__ME_overlayCache objectsAtIndexes:indexes]];
    } else {
        __ME_selectedOverlays = [[__ME_overlayCache objectsAtIndexes:indexes] mutableCopy];
    }
}

- (NSInteger)selectedOverlayIndex
{
    NSIndexSet *selected = [self selectedOverlayIndexes];
    if ([selected count] >= 1) {
        return [selected lastIndex];
    } else {
        return -1;
    }
}

- (NSIndexSet *)selectedOverlayIndexes
{
    return [__ME_overlayCache indexesOfObjectsPassingTest:^(id overlayObject, NSUInteger i, BOOL *stop){
        return [__ME_selectedOverlays containsObject:overlayObject];
    }];
}

- (void)deselectOverlay:(NSInteger)overlayIndex
{
    [__ME_selectedOverlays removeObject:[__ME_overlayCache objectAtIndex:overlayIndex]];
}

- (NSInteger)numberOfSelectedOverlays
{
    return [__ME_selectedOverlays count];
}

- (BOOL)isOverlaySelected:(NSInteger)overlayIndex
{
    return [__ME_selectedOverlays containsObject:[__ME_overlayCache objectAtIndex:overlayIndex]];
}

- (IBAction)selectAllOverlays:(id)sender
{
    __ME_selectedOverlays = [__ME_overlayCache mutableCopy];
}

- (IBAction)deselectAllOverlays:(id)sender
{
    __ME_selectedOverlays = [NSMutableArray arrayWithCapacity:2];
}

#pragma mark Mouse events

- (void)mouseDown:(NSEvent *)theEvent
{
    __ME_mouseDownPoint = [self convertWindowPointToImagePoint:[theEvent locationInWindow]];
    
    [super mouseDown:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint mouseUpPoint = [self convertWindowPointToImagePoint:[theEvent locationInWindow]];
    CGFloat epsilonSquared = 0.025;
    
    CGFloat dx = __ME_mouseDownPoint.x - mouseUpPoint.x, dy = __ME_mouseDownPoint.y - mouseUpPoint.y;
    BOOL pointsAreEqual = (dx * dx + dy * dy) < epsilonSquared;
    
    if ((__ME_state == MECreatingState || __ME_state == MEModifyingState) && !pointsAreEqual) {
        [self draggedFrom:__ME_mouseDownPoint to:mouseUpPoint done:NO];
    } else {
        [super mouseDragged:theEvent];
    }
}

- (void)mouseUp:(NSEvent *)theEvent
{
    NSPoint mouseUpPoint = [self convertWindowPointToImagePoint:[theEvent locationInWindow]];
    CGFloat epsilonSquared = 0.025;
    
    CGFloat dx = __ME_mouseDownPoint.x - mouseUpPoint.x, dy = __ME_mouseDownPoint.y - mouseUpPoint.y;
    BOOL pointsAreEqual = (dx * dx + dy * dy) < epsilonSquared;
    
    CALayer *hitLayer = [self layerAtPoint:mouseUpPoint];
    
    if (__ME_state == MEDeletingState && [self allowsDeletingOverlays] && [hitLayer valueForKey:@"MEOverlayObject"]) {
        id overlayObject = [hitLayer valueForKey:@"MEOverlayObject"];
        [__ME_overlayDelegate overlayView:self didDeleteOverlay:overlayObject];
        [__ME_selectedOverlays removeObject:overlayObject];
        [self removeTrackingArea:[hitLayer valueForKey:@"MEOverlayTrackingArea"]];
    } else if (__ME_state == MEIdleState && [hitLayer valueForKey:@"MEOverlayObject"]) {
        if ([self allowsOverlaySelection]) {
            NSUInteger layerNumber = [[hitLayer valueForKey:@"MEOverlayNumber"] integerValue];
            DLog(@"checking select with %lu", layerNumber);
            BOOL multiAttempt = ([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSShiftKeyMask || ([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSCommandKeyMask;
            if ([self isOverlaySelected:layerNumber]) {
                if (multiAttempt && ([self numberOfSelectedOverlays] > 1 || [self allowsEmptyOverlaySelection])) {
                    DLog(@"deselected");
                    [self deselectOverlay:layerNumber];
                    [[NSNotificationCenter defaultCenter] postNotificationName:MEOverlayViewSelectionDidChangeNotification object:self];
                }
            } else {
                [self selectOverlayIndexes:[NSIndexSet indexSetWithIndex:layerNumber] 
                      byExtendingSelection:(multiAttempt && [self allowsMultipleOverlaySelection])];
                [[NSNotificationCenter defaultCenter] postNotificationName:MEOverlayViewSelectionDidChangeNotification object:self];
            }
            DLog(@"current selection: %@", __ME_selectedOverlays);
            [self drawOverlays];
        }
        if (__ME_action || __ME_doubleAction) {
            __ME_clickedOverlay = [__ME_overlayCache indexOfObject:[hitLayer valueForKey:@"MEOverlayObject"]];
            DLog(@"click!");
            DLog(@"__ME_action: %@", NSStringFromSelector(__ME_action));
            DLog(@"__ME_doubleAction: %@", NSStringFromSelector(__ME_doubleAction));
            if ([theEvent clickCount] == 1 && __ME_action) {
                [__ME_target performSelector:__ME_action withObject:nil afterDelay:[NSEvent doubleClickInterval]];
            } else if ([theEvent clickCount] == 2 && __ME_doubleAction) {
                DLog(@"Cancelling single click: %@", __ME_singleClickInvocation);
                [NSRunLoop cancelPreviousPerformRequestsWithTarget:__ME_target];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [__ME_target performSelector:__ME_doubleAction];
#pragma clang diagnostic pop
            } else {
                [super mouseUp:theEvent];
            }
        }
    } else if ((__ME_state == MECreatingState || __ME_state == MEModifyingState) && !pointsAreEqual) {
        [self draggedFrom:__ME_mouseDownPoint to:mouseUpPoint done:YES];
    } else {
        [super mouseUp:theEvent];
    }
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
    NSPoint mouseUpPoint = [self convertWindowPointToImagePoint:[theEvent locationInWindow]];
    
    CALayer *hitLayer = [self layerAtPoint:mouseUpPoint];
    
    if (__ME_state == MEIdleState && [hitLayer valueForKey:@"MEOverlayObject"] && __ME_rightAction) {
        __ME_clickedOverlay = [__ME_overlayCache indexOfObject:[hitLayer valueForKey:@"MEOverlayObject"]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [__ME_target performSelector:__ME_rightAction];
#pragma clang diagnostic pop
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
    id selection = [__ME_selectedOverlays lastObject];
    DLog(@"selection: %@", selection);
    if (selection == nil) {
        return;
    }
    
    CGPoint center = NSMakePoint(NSMidX([selection rectValue]), NSMidY([selection rectValue]));
    
    id bestCandidate = nil;
    CGFloat bestDistance = MAXFLOAT;
    
    for (CALayer *sublayer in [__ME_topLayer sublayers]) {
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
        __ME_selectedOverlays = [NSMutableArray arrayWithObject:[bestCandidate valueForKey:@"MEOverlayObject"]];
        [self drawOverlays];
    }
    
    [super keyUp:theEvent];
}

#pragma mark Other events

- (void)selectAll:(id)sender
{
    [self selectAllOverlays:sender];
    [self drawOverlays];
}

#pragma mark Helpers

//Weird that NSCursor doesn't provide these types of cursor...
- (NSCursor *)northWestSouthEastResizeCursor
{
    if (__ME_northWestSouthEastResizeCursor == nil) {
        __ME_northWestSouthEastResizeCursor = [[NSCursor alloc] initWithImage:[[NSImage alloc] initWithContentsOfFile:@"/System/Library/Frameworks/WebKit.framework/Versions/A/Frameworks/WebCore.framework/Versions/A/Resources/northWestSouthEastResizeCursor.png"] hotSpot:NSMakePoint(8.0f, 8.0f)];
    }
    return __ME_northWestSouthEastResizeCursor;
}

- (NSCursor *)northEastSouthWestResizeCursor
{
    if (__ME_northEastSouthWestResizeCursor == nil) {
        __ME_northEastSouthWestResizeCursor = [[NSCursor alloc] initWithImage:[[NSImage alloc] initWithContentsOfFile:@"/System/Library/Frameworks/WebKit.framework/Versions/A/Frameworks/WebCore.framework/Versions/A/Resources/northEastSouthWestResizeCursor.png"] hotSpot:NSMakePoint(8.0f, 8.0f)];
    }
    return __ME_northEastSouthWestResizeCursor;
}

- (void)setMouseForPoint:(NSPoint)point
{
    //Unfortunately necessary to do it this way since I don't get -cursorUpdate: messages when the mouse leaves a layer and goes back to the topLayer.
    
    CALayer *layer = [self layerAtPoint:point];
    
    if (__ME_state == MECreatingState && layer == __ME_topLayer) {
        DLog(@"layer %@ topLayer %@", layer, __ME_topLayer);
        [[NSCursor crosshairCursor] set];
    } else if (__ME_state == MEModifyingState && layer != __ME_topLayer) {
        MECorner corner = [self cornerOfLayer:layer atPoint:point];
        if (corner == MENorthEastCorner || corner == MESouthWestCorner) {
            [[self northEastSouthWestResizeCursor] set];
        } else if (corner == MENorthWestCorner || corner == MESouthEastCorner) {
            [[self northWestSouthEastResizeCursor] set];
        } else { //MENoCorner
            [[NSCursor openHandCursor] set];
        }
    } else if (__ME_state == MEDeletingState && layer != __ME_topLayer) {
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
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(-__ME_handleOffset, -__ME_handleOffset, __ME_handleWidth, __ME_handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(-__ME_handleOffset, size.height - __ME_handleOffset, __ME_handleWidth, __ME_handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(size.width - __ME_handleOffset, -__ME_handleOffset, __ME_handleWidth, __ME_handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(size.width - __ME_handleOffset, size.height - __ME_handleOffset, __ME_handleWidth, __ME_handleWidth));
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
        [layer setFillColor:__ME_overlaySelectionFillColor];
        [layer setStrokeColor:__ME_overlaySelectionBorderColor];
    } else {
        [layer setFillColor:__ME_overlayFillColor];
        [layer setStrokeColor:__ME_overlayBorderColor];
    }
    [layer setLineWidth:__ME_overlayBorderWidth];
    [layer setNeedsDisplayOnBoundsChange:YES];
    
    return layer;
}

- (id)layerAtPoint:(NSPoint)point
{
    CALayer *rootLayer = [self overlayForType:IKOverlayTypeImage];
    CALayer *hitLayer = [rootLayer hitTest:[self convertImagePointToViewPoint:point]];
    
    if (hitLayer != __ME_topLayer) {
        DLog(@"hitLayer for obj %@: %@", [hitLayer valueForKey:@"MEOverlayObject"], hitLayer);
    }
    
    return hitLayer;
}

- (MECorner)cornerOfLayer:(CALayer *)layer atPoint:(NSPoint)point
{
    NSRect frame = [layer frame];
    
    CGFloat tolerance = __ME_handleWidth * 3.0f;
    
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
        for (CALayer *sublayer in [__ME_topLayer sublayers]) {
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
    
    if (__ME_state == MECreatingState && [self allowsCreatingOverlays]) {
        DLog(@"creating");
        if (__ME_activeLayer == nil) {
            __ME_activeLayer = [self layerWithRect:NSZeroRect handles:YES selected:YES];
            
            [__ME_topLayer addSublayer:__ME_activeLayer];
        }
        
        NSPoint origin = NSMakePoint(fmin(startPoint.x, endPoint.x), fmin(startPoint.y, endPoint.y));
        NSPoint end = NSMakePoint(fmax(startPoint.x, endPoint.x), fmax(startPoint.y, endPoint.y));
        NSSize size = NSMakeSize(end.x - origin.x, end.y - origin.y);
        NSRect newRect = NSMakeRect(origin.x, origin.y, size.width, size.height);
        
        BOOL validLocation = [self rect:newRect isValidForLayer:__ME_activeLayer];
        
        if (validLocation) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.0f];
            [__ME_activeLayer setFrame:newRect];
            CGPathRef path = [self newRectPathWithSize:newRect.size handles:YES];
            [__ME_activeLayer setPath:path];
            CFRelease(path);
            [CATransaction commit];
        }
        
        if (done) {
            DLog(@"done creating: %@", NSStringFromRect([__ME_activeLayer frame]));
            [__ME_overlayDelegate overlayView:self didCreateOverlay:[__ME_activeLayer frame]];
            [__ME_activeLayer removeFromSuperlayer];
            __ME_activeLayer = nil;
        }
    } else if (__ME_state == MEModifyingState && [self allowsModifyingOverlays]) {
        DLog(@"modifying");
        
        if (__ME_activeLayer == nil) {
            CAShapeLayer *hitLayer = [self layerAtPoint:startPoint];
            if (hitLayer == __ME_topLayer || [hitLayer valueForKey:@"MEOverlayObject"] == nil) {
                return;
            }
            __ME_activeLayer = hitLayer;
            __ME_activeCorner = [self cornerOfLayer:__ME_activeLayer atPoint:startPoint];
            
            __ME_xOffset = [__ME_activeLayer position].x - endPoint.x;
            __ME_yOffset = [__ME_activeLayer position].y - endPoint.y;
            
            __ME_activeOrigin = [__ME_activeLayer frame].origin;
            __ME_activeSize = [__ME_activeLayer frame].size;
            
            DLog(@"xOffset: %f yOffset: %f", __ME_xOffset, __ME_yOffset);
        }
        [[NSCursor closedHandCursor] set];
        
        NSRect newRect = NSZeroRect;
        
        CGFloat xDelta = endPoint.x - startPoint.x;
        CGFloat yDelta = endPoint.y - startPoint.y;
        
        if (__ME_activeCorner == MENorthEastCorner) {
            newRect = NSMakeRect(__ME_activeOrigin.x, 
                                 __ME_activeOrigin.y, 
                                 __ME_activeSize.width + xDelta, 
                                 __ME_activeSize.height + yDelta);
        } else if (__ME_activeCorner == MENorthWestCorner) {
            newRect = NSMakeRect(__ME_activeOrigin.x + xDelta, 
                                 __ME_activeOrigin.y, 
                                 __ME_activeSize.width - xDelta, 
                                 __ME_activeSize.height + yDelta);
        } else if (__ME_activeCorner == MESouthEastCorner) {
            newRect = NSMakeRect(__ME_activeOrigin.x, 
                                 __ME_activeOrigin.y + yDelta, 
                                 __ME_activeSize.width + xDelta, 
                                 __ME_activeSize.height - yDelta);
        } else if (__ME_activeCorner == MESouthWestCorner) {
            newRect = NSMakeRect(__ME_activeOrigin.x + xDelta, 
                                 __ME_activeOrigin.y + yDelta, 
                                 __ME_activeSize.width - xDelta, 
                                 __ME_activeSize.height - yDelta);
        } else { //MENoCorner
            newRect = NSMakeRect(endPoint.x + __ME_xOffset - (__ME_activeSize.width * 0.5f), 
                                 endPoint.y + __ME_yOffset - (__ME_activeSize.height * 0.5f), 
                                 __ME_activeSize.width, 
                                 __ME_activeSize.height);
        }
        
        /*
         TODO:
         for smoother operation, something like:
         
         do {
            newrect = ...
            
            delta = delta - (delta/abs(delta)) // make delta 1 closer to zero each iteration
         } while (!isvalid);
         
         */
        
        DLog(@"corner: %lu : %@", __ME_activeCorner, NSStringFromRect(newRect));
        
        BOOL validLocation = [self rect:newRect isValidForLayer:__ME_activeLayer];
        
        if (validLocation) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.0f];
            [__ME_activeLayer setFrame:newRect];
            CGPathRef path = [self newRectPathWithSize:newRect.size handles:YES];
            [__ME_activeLayer setPath:path];
            CFRelease(path);
            [CATransaction commit];
        }
        
        if (done) {
            DLog(@"done modifying %@: %@", [__ME_activeLayer valueForKey:@"MEOverlayObject"], NSStringFromRect([__ME_activeLayer frame]));
            [__ME_overlayDelegate overlayView:self didModifyOverlay:[__ME_activeLayer valueForKey:@"MEOverlayObject"] newRect:[__ME_activeLayer frame]];
            __ME_activeLayer = nil;
            [[NSCursor openHandCursor] set];
        }
    }
}



#pragma mark Properties

- (id)overlayDataSource
{
    return __ME_overlayDataSource;
}

- (void)setOverlayDataSource:(id)overlayDataSource
{
    __ME_overlayDataSource = overlayDataSource;
    
    [self reloadData];
}

- (id)overlayDelegate
{
    return __ME_overlayDelegate;
}

- (void)setOverlayDelegate:(id)overlayDelegate
{
    [[NSNotificationCenter defaultCenter] removeObserver:__ME_overlayDelegate
                                                    name:MEOverlayViewSelectionDidChangeNotification
                                                  object:self];
    
    __ME_overlayDelegate = overlayDelegate;
    
    [[NSNotificationCenter defaultCenter] addObserver:__ME_overlayDelegate 
                                             selector:@selector(overlaySelectionDidChange:) 
                                                 name:MEOverlayViewSelectionDidChangeNotification 
                                               object:self];

    
    [self reloadData];
}

@synthesize overlayFillColor = __ME_overlayFillColor;
@synthesize overlayBorderColor = __ME_overlayBorderColor;
@synthesize overlaySelectionFillColor = __ME_overlaySelectionFillColor;
@synthesize overlaySelectionBorderColor = __ME_overlaySelectionBorderColor;
@synthesize overlayBorderWidth = __ME_overlayBorderWidth;

@synthesize allowsCreatingOverlays = __ME_allowsCreatingOverlays;
@synthesize allowsModifyingOverlays = __ME_allowsModifyingOverlays;
@synthesize allowsDeletingOverlays = __ME_allowsDeletingOverlays;
@synthesize allowsOverlappingOverlays = __ME_allowsOverlappingOverlays;

@synthesize allowsOverlaySelection = __ME_allowsOverlaySelection;
@synthesize allowsEmptyOverlaySelection = __ME_allowsEmptyOverlaySelection;
@synthesize allowsMultipleOverlaySelection = __ME_allowsMultipleOverlaySelection;

@synthesize target = __ME_target;
@synthesize action = __ME_action;
@synthesize doubleAction = __ME_doubleAction;
@synthesize rightAction = __ME_rightAction;
@synthesize clickedOverlay = __ME_clickedOverlay;

@end

#pragma mark Notifications

NSString *MEOverlayViewSelectionDidChangeNotification = @"MEOverlayViewSelectionDidChangeNotification";
