//
//  NFIFrame.h
//  iLife Window
//
//  Created by Sean Patrick O'Brien on 9/15/06.
//  Copyright 2006 Sean Patrick O'Brien. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "NSGrayFrame.h"

@class NSGrayFrame;

@interface NFIFrame : NSGrayFrame {
	float mTitleBarHeight;
    float mBottomBarHeight;
    float mMidBarHeight;
    float mMidBarOriginY;
	
	id mInnerGradient;
	id mOuterGradient;
}

+ (NSBezierPath*)_clippingPathForFrame:(NSRect)frame;
+ (float)cornerRadius;

- (void)_drawTitleBar:(NSRect)rect;
- (void)_drawMidBar:(NSRect)rect;
- (void)_drawBottomBar:(NSRect)rect;
- (void)_drawTitle:(NSRect)rect;

- (id)backgroundColor;
- (id)gradientStartColor;
- (id)gradientEndColor;
- (id)gradient2StartColor;
- (id)gradient2EndColor;
- (id)edgeColor;
- (id)bottomEdgeColor;
- (id)topWindowEdgeColor;
- (id)bottomWindowEdgeColor;
- (id)titleColor;

- (float)titleBarHeight;
- (void)setTitleBarHeight:(float)height;
- (float)bottomBarHeight;
- (void)setBottomBarHeight:(float)height;
- (float)midBarHeight;
- (float)midBarOriginY;
- (void)setMidBarHeight:(float)height origin:(float)origin;

@end
