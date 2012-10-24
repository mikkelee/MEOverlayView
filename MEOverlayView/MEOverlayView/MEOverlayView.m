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

#pragma mark -
#pragma mark Implementation

@implementation MEOverlayView {
    __weak id _overlayDelegate;
    __weak id _overlayDataSource;
    
    MEState _state;
    CALayer *_topLayer;
    
    //properties
    CGColorRef _overlayFillColor;
    CGColorRef _overlayBorderColor;
    CGColorRef _overlaySelectionFillColor;
    CGColorRef _overlaySelectionBorderColor;
    CGFloat _overlayBorderWidth;
    
    __weak id _target;
    SEL _action;
    SEL _doubleAction;
    SEL _rightAction;
    
    BOOL _allowsCreatingOverlays;
    BOOL _allowsModifyingOverlays;
    BOOL _allowsDeletingOverlays;
    BOOL _allowsOverlappingOverlays;
    
    BOOL _allowsOverlaySelection;
    BOOL _allowsEmptyOverlaySelection;
    BOOL _allowsMultipleOverlaySelection;
    
    //internal helper ivars
    CGFloat _handleWidth;
    CGFloat _handleOffset;
    NSCursor *_northWestSouthEastResizeCursor;
    NSCursor *_northEastSouthWestResizeCursor;
    
    //events
    NSPoint _mouseDownPoint;
    
    //temp vals
    CAShapeLayer *_activeLayer;
    MECorner _activeCorner;
    NSPoint _activeOrigin;
    NSSize _activeSize;
    CGFloat _xOffset;
    CGFloat _yOffset;
    
    //cache
    NSMutableArray *_overlayCache;
    NSMutableArray *_selectedOverlays;
    NSInteger _clickedOverlay;
}

#pragma mark Initialization

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    
    if (self) {
        DLog(@"init");
        _state = MEIdleState;
        
        //default property values:
        _overlayFillColor = CGColorCreateGenericRGB(0.0f, 0.0f, 1.0f, 0.5f);
        _overlayBorderColor = CGColorCreateGenericRGB(0.0f, 0.0f, 1.0f, 1.0f);
        _overlaySelectionFillColor = CGColorCreateGenericRGB(0.0f, 1.0f, 0.0f, 0.5f);
        _overlaySelectionBorderColor = CGColorCreateGenericRGB(0.0f, 1.0f, 0.0f, 1.0f);
        _overlayBorderWidth = 3.0f;
        
        _allowsCreatingOverlays = YES;
        _allowsModifyingOverlays = YES;
        _allowsDeletingOverlays = YES;
        _allowsOverlappingOverlays = NO;
        
        _allowsOverlaySelection = YES;
        _allowsEmptyOverlaySelection = YES;
        _allowsMultipleOverlaySelection = YES;
        
        _handleWidth = _overlayBorderWidth * 2.0f;
        _handleOffset = (_overlayBorderWidth / 2.0f) + 1.0f;
        
        _overlayCache = [NSMutableArray arrayWithCapacity:0];
        _selectedOverlays = [NSMutableArray arrayWithCapacity:0];
        _clickedOverlay = -1;
        
        _activeCorner = MENoCorner;
    }
    
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    DLog(@"overlayDelegate: %@", _overlayDelegate);
    DLog(@"overlayDataSource: %@", _overlayDataSource);

    [self performSelector:@selector(_initialSetup) withObject:nil afterDelay:0.0f];
}

- (void)_initialSetup
{
    _topLayer = [CALayer layer];
    
    [_topLayer setFrame:NSMakeRect(0.0f, 0.0f, [self imageSize].width, [self imageSize].height)];
    [_topLayer setName:@"topLayer"];
    
    [self reloadData];
    
    NSTrackingArea *fullArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect 
                                                            options:(NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect) 
                                                              owner:self 
                                                           userInfo:[NSDictionary dictionaryWithObject:_topLayer forKey:@"layer"]];
    [self addTrackingArea:fullArea];
    
    [self setOverlay:_topLayer forType:IKOverlayTypeImage];
}

- (void)reloadData
{
    DLog(@"start");
    if (_overlayDataSource) {
        DLog(@"Setting up overlays from overlayDataSouce: %@", _overlayDataSource);
        
        NSUInteger count = [_overlayDataSource numberOfOverlaysInOverlayView:self];
        
        DLog(@"Number of overlays to create: %lu", count);
        
        _overlayCache = [NSMutableArray arrayWithCapacity:count];
        for (NSUInteger i = 0; i < count; i++) {
            [_overlayCache addObject:[_overlayDataSource overlayView:self overlayObjectAtIndex:i]];
        }
    }
    
    [self _drawOverlays];
}

- (void)_drawOverlays
{
    DLog(@"start");
    if (![self allowsEmptyOverlaySelection] && [_selectedOverlays count] == 0 && [_overlayCache count] > 0) {
        _selectedOverlays = [NSMutableArray arrayWithObject:[_overlayCache lastObject]];
    }
    
    [_topLayer setSublayers:[NSArray array]];
    
    __weak MEOverlayView *weakSelf = self;
    [_overlayCache enumerateObjectsUsingBlock:^(id overlayObject, NSUInteger i, BOOL *stop){
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
        
        CALayer *layer = [strongSelf _layerWithRect:rect 
                                           handles:(_state == MEModifyingState)
                                          selected:[_selectedOverlays containsObject:overlayObject]];
        
        [layer setValue:[NSNumber numberWithInteger:i] forKey:@"MEOverlayNumber"];
        [layer setValue:overlayObject forKey:@"MEOverlayObject"];
        
        DLog(@"Created layer: %@", layer);
        
        NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:[strongSelf convertImageRectToViewRect:rect] 
                                                            options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow) 
                                                              owner:self 
                                                           userInfo:[NSDictionary dictionaryWithObject:layer forKey:@"layer"]];
        [self addTrackingArea:area];
        [layer setValue:area forKey:@"MEOverlayTrackingArea"];
        
        [_topLayer addSublayer:layer];
    }];
}

#pragma mark Deallocation

- (void)dealloc
{
    self.overlayDelegate = nil;
    self.overlayDataSource = nil;
    
    CFRelease(_overlayFillColor);
    CFRelease(_overlayBorderColor);
    CFRelease(_overlaySelectionFillColor);
    CFRelease(_overlaySelectionBorderColor);
}

#pragma mark Selection

- (void)selectOverlayIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend
{
    if ([indexes count] == 0) {
        return;
    }
    if (extend) {
        [_selectedOverlays addObjectsFromArray:[_overlayCache objectsAtIndexes:indexes]];
    } else {
        _selectedOverlays = [[_overlayCache objectsAtIndexes:indexes] mutableCopy];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:MEOverlayViewSelectionDidChangeNotification object:self];
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
    return [_overlayCache indexesOfObjectsPassingTest:^(id overlayObject, NSUInteger i, BOOL *stop){
        return [_selectedOverlays containsObject:overlayObject];
    }];
}

- (NSArray *)selectedOverlays
{
    return _selectedOverlays;
}

- (void)deselectOverlay:(NSInteger)overlayIndex
{
    [_selectedOverlays removeObject:[_overlayCache objectAtIndex:overlayIndex]];
    [[NSNotificationCenter defaultCenter] postNotificationName:MEOverlayViewSelectionDidChangeNotification object:self];
}

- (NSInteger)numberOfSelectedOverlays
{
    return [_selectedOverlays count];
}

- (BOOL)isOverlaySelected:(NSInteger)overlayIndex
{
    return [_selectedOverlays containsObject:[_overlayCache objectAtIndex:overlayIndex]];
}

- (IBAction)selectAllOverlays:(id)sender
{
    _selectedOverlays = [_overlayCache mutableCopy];
    [[NSNotificationCenter defaultCenter] postNotificationName:MEOverlayViewSelectionDidChangeNotification object:self];
}

- (IBAction)deselectAllOverlays:(id)sender
{
    _selectedOverlays = [NSMutableArray arrayWithCapacity:2];
    [[NSNotificationCenter defaultCenter] postNotificationName:MEOverlayViewSelectionDidChangeNotification object:self];
}

#pragma mark Mouse events

- (void)mouseDown:(NSEvent *)theEvent
{
    _mouseDownPoint = [self _convertWindowPointToImagePoint:[theEvent locationInWindow]];
    
    [super mouseDown:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint mouseUpPoint = [self _convertWindowPointToImagePoint:[theEvent locationInWindow]];
    CGFloat epsilonSquared = 0.025;
    
    CGFloat dx = _mouseDownPoint.x - mouseUpPoint.x, dy = _mouseDownPoint.y - mouseUpPoint.y;
    BOOL pointsAreEqual = (dx * dx + dy * dy) < epsilonSquared;
    
    if ((_state == MECreatingState || _state == MEModifyingState) && !pointsAreEqual) {
        [self _draggedFrom:_mouseDownPoint to:mouseUpPoint done:NO];
    } else {
        [super mouseDragged:theEvent];
    }
}

- (void)mouseUp:(NSEvent *)theEvent
{
    NSPoint mouseUpPoint = [self _convertWindowPointToImagePoint:[theEvent locationInWindow]];
    CGFloat epsilonSquared = 0.025;
    
    CGFloat dx = _mouseDownPoint.x - mouseUpPoint.x, dy = _mouseDownPoint.y - mouseUpPoint.y;
    BOOL pointsAreEqual = (dx * dx + dy * dy) < epsilonSquared;
    
    CALayer *hitLayer = [self _layerAtPoint:mouseUpPoint];
    
    if (_state == MEDeletingState && [self allowsDeletingOverlays] && [hitLayer valueForKey:@"MEOverlayObject"]) {
        id overlayObject = [hitLayer valueForKey:@"MEOverlayObject"];
        [_overlayDelegate overlayView:self didDeleteOverlay:overlayObject];
        [_selectedOverlays removeObject:overlayObject];
        [self removeTrackingArea:[hitLayer valueForKey:@"MEOverlayTrackingArea"]];
    } else if (_state == MEIdleState && [hitLayer valueForKey:@"MEOverlayObject"]) {
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
            DLog(@"current selection: %@", _selectedOverlays);
            [self _drawOverlays];
        }
        if (_action || _doubleAction) {
            _clickedOverlay = [_overlayCache indexOfObject:[hitLayer valueForKey:@"MEOverlayObject"]];
            DLog(@"click!");
            DLog(@"_action: %@", NSStringFromSelector(_action));
            DLog(@"_doubleAction: %@", NSStringFromSelector(_doubleAction));
            if ([theEvent clickCount] == 1 && _action) {
                [_target performSelector:_action withObject:nil afterDelay:[NSEvent doubleClickInterval]];
            } else if ([theEvent clickCount] == 2 && _doubleAction) {
                [NSRunLoop cancelPreviousPerformRequestsWithTarget:_target];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [_target performSelector:_doubleAction];
#pragma clang diagnostic pop
            } else {
                [super mouseUp:theEvent];
            }
        }
    } else if ((_state == MECreatingState || _state == MEModifyingState) && !pointsAreEqual) {
        [self _draggedFrom:_mouseDownPoint to:mouseUpPoint done:YES];
    } else {
        [super mouseUp:theEvent];
    }
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
    NSPoint mouseUpPoint = [self _convertWindowPointToImagePoint:[theEvent locationInWindow]];
    
    CALayer *hitLayer = [self _layerAtPoint:mouseUpPoint];
    
    if (_state == MEIdleState && [hitLayer valueForKey:@"MEOverlayObject"] && _rightAction) {
        _clickedOverlay = [_overlayCache indexOfObject:[hitLayer valueForKey:@"MEOverlayObject"]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [_target performSelector:_rightAction];
#pragma clang diagnostic pop
    } else {
        [super mouseUp:theEvent];
    }
}

- (void)cursorUpdate:(NSEvent *)theEvent
{
    [self _setMouseForPoint:[self _convertWindowPointToImagePoint:[theEvent locationInWindow]]];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    [self _setMouseForPoint:[self _convertWindowPointToImagePoint:[theEvent locationInWindow]]];
}

- (void)mouseExited:(NSEvent *)theEvent
{
    [self _setMouseForPoint:[self _convertWindowPointToImagePoint:[theEvent locationInWindow]]];
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
    id selection = [_selectedOverlays lastObject];
    DLog(@"selection: %@", selection);
    if (selection == nil) {
        return;
    }
    
    CGPoint center = NSMakePoint(NSMidX([selection rectValue]), NSMidY([selection rectValue]));
    
    id bestCandidate = nil;
    CGFloat bestDistance = MAXFLOAT;
    
    for (CALayer *sublayer in [_topLayer sublayers]) {
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
        _selectedOverlays = [NSMutableArray arrayWithObject:[bestCandidate valueForKey:@"MEOverlayObject"]];
        [self _drawOverlays];
    }
    
    [super keyUp:theEvent];
}

#pragma mark Other events

- (void)selectAll:(id)sender
{
    [self selectAllOverlays:sender];
    [self _drawOverlays];
}

#pragma mark Helpers

//Weird that NSCursor doesn't provide these types of cursor...
- (NSCursor *)_northWestSouthEastResizeCursor
{
    if (_northWestSouthEastResizeCursor == nil) {
        _northWestSouthEastResizeCursor = [[NSCursor alloc] initWithImage:[[NSImage alloc] initWithContentsOfFile:@"/System/Library/Frameworks/WebKit.framework/Versions/A/Frameworks/WebCore.framework/Versions/A/Resources/northWestSouthEastResizeCursor.png"] hotSpot:NSMakePoint(8.0f, 8.0f)];
    }
    return _northWestSouthEastResizeCursor;
}

- (NSCursor *)_northEastSouthWestResizeCursor
{
    if (_northEastSouthWestResizeCursor == nil) {
        _northEastSouthWestResizeCursor = [[NSCursor alloc] initWithImage:[[NSImage alloc] initWithContentsOfFile:@"/System/Library/Frameworks/WebKit.framework/Versions/A/Frameworks/WebCore.framework/Versions/A/Resources/northEastSouthWestResizeCursor.png"] hotSpot:NSMakePoint(8.0f, 8.0f)];
    }
    return _northEastSouthWestResizeCursor;
}

- (void)_setMouseForPoint:(NSPoint)point
{
    //Unfortunately necessary to do it this way since I don't get -cursorUpdate: messages when the mouse leaves a layer and goes back to the topLayer.
    
    CALayer *layer = [self _layerAtPoint:point];
    
    if (_state == MECreatingState && layer == _topLayer) {
        DLog(@"layer %@ topLayer %@", layer, _topLayer);
        [[NSCursor crosshairCursor] set];
    } else if (_state == MEModifyingState && layer != _topLayer) {
        MECorner corner = [self _cornerOfLayer:layer atPoint:point];
        if (corner == MENorthEastCorner || corner == MESouthWestCorner) {
            [[self _northEastSouthWestResizeCursor] set];
        } else if (corner == MENorthWestCorner || corner == MESouthEastCorner) {
            [[self _northWestSouthEastResizeCursor] set];
        } else { //MENoCorner
            [[NSCursor openHandCursor] set];
        }
    } else if (_state == MEDeletingState && layer != _topLayer) {
        [[NSCursor disappearingItemCursor] set];
    } else {
        [[NSCursor arrowCursor] set];
    }
}

- (NSPoint)_convertWindowPointToImagePoint:(NSPoint)windowPoint
{
    DLog(@"windowPoint: %@", NSStringFromPoint(windowPoint));
    NSPoint imagePoint = [self convertViewPointToImagePoint:[self convertPoint:windowPoint fromView:[[self window] contentView]]];
    DLog(@"imagePoint: %@", NSStringFromPoint(imagePoint));
    return imagePoint;
}

- (CGPathRef)_newRectPathWithSize:(NSSize)size handles:(BOOL)handles
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, NSMakeRect(0.0f, 0.0f, size.width, size.height));
    
    if (handles) {
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(-_handleOffset, -_handleOffset, _handleWidth, _handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(-_handleOffset, size.height - _handleOffset, _handleWidth, _handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(size.width - _handleOffset, -_handleOffset, _handleWidth, _handleWidth));
        CGPathAddEllipseInRect(path, NULL, NSMakeRect(size.width - _handleOffset, size.height - _handleOffset, _handleWidth, _handleWidth));
    }
    
    return path;
}

- (CAShapeLayer *)_layerWithRect:(NSRect)rect handles:(BOOL)handles selected:(BOOL)selected
{
    CAShapeLayer *layer = [CAShapeLayer layer];
    
    [layer setFrame:rect];
    CGPathRef path = [self _newRectPathWithSize:rect.size handles:handles];
    [layer setPath:path];
    CFRelease(path);
    
    if (selected) {
        DLog(@"drawing selected");
        [layer setFillColor:_overlaySelectionFillColor];
        [layer setStrokeColor:_overlaySelectionBorderColor];
    } else {
        [layer setFillColor:_overlayFillColor];
        [layer setStrokeColor:_overlayBorderColor];
    }
    [layer setLineWidth:_overlayBorderWidth];
    [layer setNeedsDisplayOnBoundsChange:YES];
    
    return layer;
}

- (id)_layerAtPoint:(NSPoint)point
{
    CALayer *rootLayer = [self overlayForType:IKOverlayTypeImage];
    CALayer *hitLayer = [rootLayer hitTest:[self convertImagePointToViewPoint:point]];
    
    if (hitLayer != _topLayer) {
        DLog(@"hitLayer for obj %@: %@", [hitLayer valueForKey:@"MEOverlayObject"], hitLayer);
    }
    
    return hitLayer;
}

- (MECorner)_cornerOfLayer:(CALayer *)layer atPoint:(NSPoint)point
{
    NSRect frame = [layer frame];
    
    CGFloat tolerance = _handleWidth * 3.0f;
    
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

- (BOOL)_rect:(NSRect)rect isValidForLayer:(CALayer *)layer
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
        for (CALayer *sublayer in [_topLayer sublayers]) {
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

- (void)_draggedFrom:(NSPoint)startPoint to:(NSPoint)endPoint done:(BOOL)done
{
    DLog(@"from %@ to %@", NSStringFromPoint(startPoint), NSStringFromPoint(endPoint));
    
    if (_state == MECreatingState && [self allowsCreatingOverlays]) {
        DLog(@"creating");
        if (_activeLayer == nil) {
            _activeLayer = [self _layerWithRect:NSZeroRect handles:YES selected:YES];
            
            [_topLayer addSublayer:_activeLayer];
        }
        
        NSPoint origin = NSMakePoint(fmin(startPoint.x, endPoint.x), fmin(startPoint.y, endPoint.y));
        NSPoint end = NSMakePoint(fmax(startPoint.x, endPoint.x), fmax(startPoint.y, endPoint.y));
        NSSize size = NSMakeSize(end.x - origin.x, end.y - origin.y);
        NSRect newRect = NSMakeRect(origin.x, origin.y, size.width, size.height);
        
        BOOL validLocation = [self _rect:newRect isValidForLayer:_activeLayer];
        
        if (validLocation) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.0f];
            [_activeLayer setFrame:newRect];
            CGPathRef path = [self _newRectPathWithSize:newRect.size handles:YES];
            [_activeLayer setPath:path];
            CFRelease(path);
            [CATransaction commit];
        }
        
        if (done) {
            DLog(@"done creating: %@", NSStringFromRect([_activeLayer frame]));
            [_overlayDelegate overlayView:self didCreateOverlay:[_activeLayer frame]];
            [_activeLayer removeFromSuperlayer];
            _activeLayer = nil;
        }
    } else if (_state == MEModifyingState && [self allowsModifyingOverlays]) {
        DLog(@"modifying");
        
        if (_activeLayer == nil) {
            CAShapeLayer *hitLayer = [self _layerAtPoint:startPoint];
            if (hitLayer == _topLayer || [hitLayer valueForKey:@"MEOverlayObject"] == nil) {
                return;
            }
            _activeLayer = hitLayer;
            _activeCorner = [self _cornerOfLayer:_activeLayer atPoint:startPoint];
            
            _xOffset = [_activeLayer position].x - endPoint.x;
            _yOffset = [_activeLayer position].y - endPoint.y;
            
            _activeOrigin = [_activeLayer frame].origin;
            _activeSize = [_activeLayer frame].size;
            
            DLog(@"xOffset: %f yOffset: %f", _xOffset, _yOffset);
        }
        [[NSCursor closedHandCursor] set];
        
        NSRect newRect = NSZeroRect;
        
        CGFloat xDelta = endPoint.x - startPoint.x;
        CGFloat yDelta = endPoint.y - startPoint.y;
        
        if (_activeCorner == MENorthEastCorner) {
            newRect = NSMakeRect(_activeOrigin.x, 
                                 _activeOrigin.y, 
                                 _activeSize.width + xDelta, 
                                 _activeSize.height + yDelta);
        } else if (_activeCorner == MENorthWestCorner) {
            newRect = NSMakeRect(_activeOrigin.x + xDelta, 
                                 _activeOrigin.y, 
                                 _activeSize.width - xDelta, 
                                 _activeSize.height + yDelta);
        } else if (_activeCorner == MESouthEastCorner) {
            newRect = NSMakeRect(_activeOrigin.x, 
                                 _activeOrigin.y + yDelta, 
                                 _activeSize.width + xDelta, 
                                 _activeSize.height - yDelta);
        } else if (_activeCorner == MESouthWestCorner) {
            newRect = NSMakeRect(_activeOrigin.x + xDelta, 
                                 _activeOrigin.y + yDelta, 
                                 _activeSize.width - xDelta, 
                                 _activeSize.height - yDelta);
        } else { //MENoCorner
            newRect = NSMakeRect(endPoint.x + _xOffset - (_activeSize.width * 0.5f), 
                                 endPoint.y + _yOffset - (_activeSize.height * 0.5f), 
                                 _activeSize.width, 
                                 _activeSize.height);
        }
        
        /*
         TODO:
         for smoother operation, something like:
         
         do {
            newrect = ...
            
            delta = delta - (delta/abs(delta)) // make delta 1 closer to zero each iteration
         } while (!isvalid);
         
         */
        
        DLog(@"corner: %lu : %@", _activeCorner, NSStringFromRect(newRect));
        
        BOOL validLocation = [self _rect:newRect isValidForLayer:_activeLayer];
        
        if (validLocation) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.0f];
            [_activeLayer setFrame:newRect];
            CGPathRef path = [self _newRectPathWithSize:newRect.size handles:YES];
            [_activeLayer setPath:path];
            CFRelease(path);
            [CATransaction commit];
        }
        
        if (done) {
            DLog(@"done modifying %@: %@", [_activeLayer valueForKey:@"MEOverlayObject"], NSStringFromRect([_activeLayer frame]));
            [_overlayDelegate overlayView:self didModifyOverlay:[_activeLayer valueForKey:@"MEOverlayObject"] newRect:[_activeLayer frame]];
            _activeLayer = nil;
            [[NSCursor openHandCursor] set];
        }
    }
}



#pragma mark Properties

- (id)overlayDelegate
{
    return _overlayDelegate;
}

- (void)setOverlayDelegate:(id)overlayDelegate
{
    if (_overlayDelegate != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:_overlayDelegate
                                                        name:MEOverlayViewSelectionDidChangeNotification
                                                      object:self];
        [[NSNotificationCenter defaultCenter] removeObserver:_overlayDelegate
                                                        name:MEOverlayViewOverlayDidMoveNotification
                                                      object:self];
        [[NSNotificationCenter defaultCenter] removeObserver:_overlayDelegate
                                                        name:MEOverlayViewOverlayDidResizeNotification
                                                      object:self];
        [[NSNotificationCenter defaultCenter] removeObserver:_overlayDelegate
                                                        name:MEOverlayViewOverlayDidDeleteNotification
                                                      object:self];
    }
    
    _overlayDelegate = overlayDelegate;
    
    [[NSNotificationCenter defaultCenter] addObserver:_overlayDelegate 
                                             selector:@selector(overlaySelectionDidChange:) 
                                                 name:MEOverlayViewSelectionDidChangeNotification 
                                               object:self];

    
    [self reloadData];
}

- (id)overlayDataSource
{
    return _overlayDataSource;
}

- (void)setOverlayDataSource:(id)overlayDataSource
{
    _overlayDataSource = overlayDataSource;
    
    [self reloadData];
}

- (void)setState:(MEState)state
{
    //check for allowances
    if (state == MECreatingState && !_allowsCreatingOverlays) {
        return;
    } else if (state == MEModifyingState && !_allowsModifyingOverlays) {
        return;
    } else if (state == MEDeletingState && !_allowsDeletingOverlays) {
        return;
    } else {
        DLog(@"%lu => %lu", _state, state);
        _state = state;
        [self setNeedsDisplay:YES];
    }
}

- (MEState)state
{
    return _state;
}

- (void)setOverlayFillColor:(CGColorRef)overlayFillColor
{
    CGColorRelease(_overlayFillColor);
    _overlayFillColor = overlayFillColor;
    CGColorRetain(_overlayFillColor);
}

- (CGColorRef)overlayFillColor
{
    return _overlayFillColor;
}

- (void)setOverlayBorderColor:(CGColorRef)overlayBorderColor
{
    CGColorRelease(_overlayBorderColor);
    _overlayBorderColor = overlayBorderColor;
    CGColorRetain(_overlayBorderColor);
}

- (CGColorRef)overlayBorderColor
{
    return _overlayBorderColor;
}

- (void)setOverlaySelectionFillColor:(CGColorRef)overlaySelectionFillColor
{
    CGColorRelease(_overlaySelectionFillColor);
    _overlaySelectionFillColor = overlaySelectionFillColor;
    CGColorRetain(_overlaySelectionFillColor);
}

- (CGColorRef)overlaySelectionFillColor
{
    return _overlaySelectionFillColor;
}

- (void)setOverlaySelectionBorderColor:(CGColorRef)overlaySelectionBorderColor
{
    CGColorRelease(_overlaySelectionBorderColor);
    _overlaySelectionBorderColor = overlaySelectionBorderColor;
    CGColorRetain(_overlaySelectionBorderColor);
}

- (CGColorRef)overlaySelectionBorderColor
{
    return _overlaySelectionBorderColor;
}

@end

#pragma mark Notifications

NSString *MEOverlayViewSelectionDidChangeNotification = @"MEOverlayViewSelectionDidChangeNotification";
NSString *MEOverlayViewOverlayDidMoveNotification = @"MEOverlayViewOverlayDidMoveNotification";
NSString *MEOverlayViewOverlayDidResizeNotification = @"MEOverlayViewOverlayDidResizeNotification";
NSString *MEOverlayViewOverlayDidDeleteNotification = @"MEOverlayViewOverlayDidDeleteNotification";
