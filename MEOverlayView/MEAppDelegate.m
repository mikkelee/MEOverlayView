//
//  MEAppDelegate.m
//  MEOverlayView
//
//  Created by Mikkel Eide Eriksen on 25/01/12.
//  Copyright (c) 2012 Mikkel Eide Eriksen. All rights reserved.
//

#import "MEAppDelegate.h"

@implementation MEAppDelegate 

@synthesize window = _window;
@synthesize overlayView;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSString *imgURL = [[NSBundle mainBundle] pathForImageResource:@"royalty-free-food-image-cabbage.jpg"];
    [overlayView setImageWithURL:[NSURL fileURLWithPath:imgURL]];
}


@end
