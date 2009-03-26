
//
//  TimerWindowController.m
//  SelfControl
//
//  Created by Charlie Stigler on 2/15/09.
//  Copyright 2009 Eyebeam.  

// This file is part of SelfControl.
// 
// SelfControl is free software:  you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "TimerWindowController.h"

#import "AppController.h"

@implementation TimerWindowController

- (TimerWindowController*) init {
  [super initWithWindowNibName:@"TimerWindow"];
    
  return self;
}

- (void)awakeFromNib {
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  
  NSWindow* window = [self window];
  
  if([defaults boolForKey:@"TimerWindowFloats"]) {
    [window setLevel: NSFloatingWindowLevel];
    [window setHidesOnDeactivate: NO];
  }
  else {
    [window setLevel: NSNormalWindowLevel];
    [window setHidesOnDeactivate: NO];
  }
  
  NSDate* beginDate = [defaults objectForKey:@"BlockStartedDate"];
  NSTimeInterval blockDuration = [defaults integerForKey:@"BlockDuration"] * 60;
  // It is KEY to retain the block ending date , if you forget to retain it
  // you'll end up with a nasty program crash.
  if(blockDuration)
    blockEndingDate_ = [[beginDate addTimeInterval: blockDuration] retain];
  else
    // If the block duration is 0, the ending date is... now!
    blockEndingDate_ = [[NSDate date] retain];
  [self updateTimerDisplay];
  timerUpdater_ = [NSTimer scheduledTimerWithTimeInterval: 1.0
                                                   target: self
                                                 selector: @selector(updateTimerDisplay)
                                                 userInfo: nil
                                                  repeats: YES];
}

- (void)reloadTimer {
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSDate* beginDate = [defaults objectForKey:@"BlockStartedDate"];
  NSTimeInterval blockDuration = [defaults integerForKey:@"BlockDuration"] * 60;
  [blockEndingDate_ release];
  if(blockDuration)
    blockEndingDate_ = [[beginDate addTimeInterval: blockDuration] retain];
  else
    blockEndingDate_ = [[NSDate date] retain];
  if([timerUpdater_ isValid]) {
    [timerUpdater_ invalidate];
    timerUpdater_ = nil;
  }
  timerUpdater_ = [NSTimer scheduledTimerWithTimeInterval: 1.0
                                                   target: self
                                                 selector: @selector(updateTimerDisplay)
                                                 userInfo: nil
                                                  repeats: YES];
  [self updateTimerDisplay];
}

- (void)updateTimerDisplay {
  int numSeconds = (int) [blockEndingDate_ timeIntervalSinceNow];
  int numHours;
  int numMinutes;
  
  if(numSeconds < 0) {
    if(![[NSApp delegate] selfControlLaunchDaemonIsLoaded]) {
      if([timerUpdater_ isValid]) {
        [timerUpdater_ invalidate];
        timerUpdater_ = nil;
      }
      
      [timerLabel_ setStringValue: @"Block not active"];
      [timerLabel_ setFont: [[NSFontManager sharedFontManager]
                            convertFont: [timerLabel_ font]
                            toSize: 37]
       ];
      
      [timerLabel_ sizeToFit];
      
      [[NSApp delegate] refreshUserInterface];
    }
    
    return;
  }
  
  numHours = (numSeconds / 3600);
  numSeconds %= 3600;
  numMinutes = (numSeconds / 60);
  numSeconds %= 60;
  
  NSString* timeString = [NSString stringWithFormat: @"%0.2d:%0.2d:%0.2d",
                                                    numHours,
                                                    numMinutes,
                                                    numSeconds];
  
  [timerLabel_ setStringValue: timeString];
  [timerLabel_ setFont: [[NSFontManager sharedFontManager]
                        convertFont: [timerLabel_ font]
                        toSize: 42]
   ];
  
  [timerLabel_ sizeToFit];
}

- (void)windowShouldClose:(NSNotification *)notification {
  // Hack to make the application terminate after the last window is closed, but
  // INCLUDE the HUD-style timer window.
  if(![[[NSApp delegate] initialWindow] isVisible]) {
    [NSApp terminate: self];
  }
}

@end