//
//  NFIWindow.h
//  iLife Window
//
//  Created by Sean Patrick O'Brien on 9/15/06.
//  Copyright 2006 Sean Patrick O'Brien. All rights reserved.
//
#import <Cocoa/Cocoa.h>

@interface NFIWindow : NSWindow
{
}

- (float)titleBarHeight;
- (void)setTitleBarHeight:(float)height;
- (float)bottomBarHeight;
- (void)setBottomBarHeight:(float)height;
- (float)midBarHeight;
- (float)midBarOriginY;
- (void)setMidBarHeight:(float)height origin:(float)origin;

@end
