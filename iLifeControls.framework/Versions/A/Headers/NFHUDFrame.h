//
//  NFHUDFrame.h
//  iLife HUD Window
//
//  Created by Sean Patrick O'Brien on 9/23/06.
//  Copyright 2006 Sean Patrick O'Brien. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NSGrayFrame.h"

@interface NFHUDFrame : NSGrayFrame {

}

+ (NSBezierPath*)_clippingPathForFrame:(NSRect)aRect;

- (void)_drawTitle:(NSRect)rect;
- (void)_drawTitleBar:(NSRect)rect;
- (void)drawRect:(NSRect)rect;

-(float)titleBarHeight;

@end
