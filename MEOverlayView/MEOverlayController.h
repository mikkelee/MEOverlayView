//
//  MEOverlayController.h
//  MEOverlayView
//
//  Created by Mikkel Eide Eriksen on 25/01/12.
//  Copyright (c) 2012 Mikkel Eide Eriksen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MEOverlayView.h"

@interface MEOverlayController : NSObject <MEOverlayViewDelegate> {
    IBOutlet MEOverlayView *overlayView;
}

- (IBAction)update:(id)sender;
- (IBAction)changeState:(id)sender;

@end
