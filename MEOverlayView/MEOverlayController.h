//
//  MEOverlayController.h
//  MEOverlayView
//
//  Created by Mikkel Eide Eriksen on 25/01/12.
//  Copyright (c) 2012 Mikkel Eide Eriksen. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MEOverlayView;

@interface MEOverlayController : NSObject {
    IBOutlet MEOverlayView *overlayView;
}

- (IBAction)logCurrentOverlays:(id)sender;
- (IBAction)changeState:(id)sender;

@property (strong) NSMutableArray *overlays;

@end
