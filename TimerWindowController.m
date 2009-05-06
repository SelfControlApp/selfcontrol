 
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

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.


#import "TimerWindowController.h"

@implementation TimerWindowController

- (TimerWindowController*) init {
  NSLog(@"TimerWindowController: init");
  unsigned int major, minor, bugfix;
  
  [SelfControlUtilities getSystemVersionMajor: &major minor: &minor bugFix: &bugfix];
  
  if(major <= 10 && minor < 5)
    [super initWithWindowNibName:@"TigerTimerWindow"];
  else
    [super initWithWindowNibName:@"TimerWindow"];
      
  // We need a block to prevent us from running multiple copies of the "Add to Block"
  // sheet.
  addToBlockLock = [[NSLock alloc] init];
  
  return self;
}

- (void)awakeFromNib {
  NSLog(@"TimerWindowController: awakeFromNib");
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
  
  NSDictionary* lockDict = [NSDictionary dictionaryWithContentsOfFile: kSelfControlLockFilePath];
  
  /* if([[lockDict objectForKey: @"BlockAsWhitelist"] boolValue])
    [addToBlockButton_ setEnabled: NO];
  else
    [addToBlockButton_ setEnabled: YES]; */
  
  NSLog(@"TimerWindowController: Passed where BlockAsWhitelist check was");
  
  NSDate* beginDate = [lockDict objectForKey:@"BlockStartedDate"];
  NSTimeInterval blockDuration = [[lockDict objectForKey:@"BlockDuration"] intValue] * 60;
  
  if(beginDate == nil || [beginDate isEqualToDate: [NSDate distantFuture]]
     || blockDuration <= 0) {
    beginDate = [defaults objectForKey:@"BlockStartedDate"];
    blockDuration = [defaults integerForKey:@"BlockDuration"] * 60;
  } else {
    [defaults setObject: beginDate forKey: @"BlockStartedDate"];
    [defaults setObject: [NSNumber numberWithFloat: (blockDuration / 60)] forKey: @"BlockDuration"];
  }
  
  // It is KEY to retain the block ending date , if you forget to retain it
  // you'll end up with a nasty program crash.
  if(blockDuration)
    blockEndingDate_ = [[beginDate addTimeInterval: blockDuration] retain];
  else
    // If the block duration is 0, the ending date is... now!
    blockEndingDate_ = [[NSDate date] retain];
  [self updateTimerDisplay: nil];
  timerUpdater_ = [[NSTimer scheduledTimerWithTimeInterval: 1.0
                                                   target: self
                                                 selector: @selector(updateTimerDisplay:)
                                                 userInfo: nil
                                                  repeats: YES] retain];
  NSLog(@"TimerWindowController: Scheduled timer, timerUpdater_ is now %@", timerUpdater_);
}

- (void)reloadTimer {
  NSLog(@"TimerWindowController: reloadTimer");
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

  NSDictionary* lockDict = [NSDictionary dictionaryWithContentsOfFile: kSelfControlLockFilePath];
  
  NSDate* beginDate = [lockDict objectForKey:@"BlockStartedDate"];
  NSTimeInterval blockDuration = [[lockDict objectForKey:@"BlockDuration"] intValue] * 60;
  
  if(beginDate == nil || [beginDate isEqualToDate: [NSDate distantFuture]]
     || blockDuration <= 0) {
    beginDate = [defaults objectForKey:@"BlockStartedDate"];
    blockDuration = [defaults integerForKey:@"BlockDuration"] * 60;
  } else {
    [defaults setObject: beginDate forKey: @"BlockStartedDate"];
    [defaults setObject: [NSNumber numberWithFloat: (blockDuration / 60)] forKey: @"BlockDuration"];
  }
  
  [blockEndingDate_ release];
  if(blockDuration)
    blockEndingDate_ = [[beginDate addTimeInterval: blockDuration] retain];
  else
    blockEndingDate_ = [[NSDate date] retain];
  
  if([timerUpdater_ isValid])
    [timerUpdater_ invalidate];
  [timerUpdater_ release];
  timerUpdater_ = nil;

  timerUpdater_ = [[NSTimer scheduledTimerWithTimeInterval: 1.0
                                                   target: self
                                                 selector: @selector(updateTimerDisplay:)
                                                 userInfo: nil
                                                  repeats: YES] retain];
  
  NSLog(@"TimerWindowController: Scheduled timer (reloaded), timerUpdater_ is now %@", timerUpdater_);
  
  [self updateTimerDisplay: nil];
}

- (void)updateTimerDisplay:(NSTimer*)timer {
  NSLog(@"TimerWindowController: updateTimerDisplay:%@", timer);
  int numSeconds = (int) [blockEndingDate_ timeIntervalSinceNow];
  int numHours;
  int numMinutes;
  
  if(numSeconds < 0) {
    if(![[NSApp delegate] selfControlLaunchDaemonIsLoaded]) {
      if([timer isValid])
        [timer invalidate];
      timer = nil;
      if([timerUpdater_ isValid])
        [timerUpdater_ invalidate];
      [timerUpdater_ release];
      timerUpdater_ = nil;
      
      [timerLabel_ setStringValue: @"Block not active"];
      [timerLabel_ setFont: [[NSFontManager sharedFontManager]
                            convertFont: [timerLabel_ font]
                            toSize: 37]
       ];
      
      [timerLabel_ sizeToFit];
      
      // Also reload the contents of the domain list in case it was changed while
      // the block was ongoing.  We do this by simply clearing the
      // AppController's domainListWindowController variable.  It will initialize
      // a new object when it is needed, which will have new data.
      [[NSApp delegate] setDomainListWindowController: nil];
      
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
  
  NSLog(@"TimerWindowController: updateTimerDisplay: set string value to %@", timeString);
}

- (void)windowShouldClose:(NSNotification *)notification {
  // Hack to make the application terminate after the last window is closed, but
  // INCLUDE the HUD-style timer window.
  if(![[[NSApp delegate] initialWindow] isVisible]) {
    [NSApp terminate: self];
  }
}

- (IBAction) addToBlock:(id)sender {  
  // Check if there's already a thread trying to add a host.  If so, don't make
  // another.
  if(![addToBlockLock tryLock])
    return;
  
  // At first I tried loading the nib only if it wasn't loaded, but for some reason
  // it didn't work right and sometimes the nib would seem to be loaded even though
  // it obviously wasn't loaded properly.
  [NSBundle loadNibNamed: @"AddToBlock" owner: self];
    
  [NSApp beginSheet: addSheet_
     modalForWindow: [self window]
      modalDelegate: self
     didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
        contextInfo: nil];
}

- (IBAction) closeAddSheet:(id)sender {
  [NSApp endSheet: addSheet_];
  // Unlock the lock so that we can add another host to the list
  [addToBlockLock unlock];
}

- (IBAction) performAdd:(id)sender {
  NSString* addToBlockTextFieldContents = [addToBlockTextField_ stringValue];
  [[NSApp delegate] addToBlockList: addToBlockTextFieldContents];
  [NSApp endSheet: addSheet_];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
  [sheet orderOut:self];  
}

- (void)dealloc {
  NSLog(@"TimerWindowController: dealloc");
  if([timerUpdater_ isValid])
    [timerUpdater_ invalidate];
  [timerUpdater_ release];
  timerUpdater_ = nil;
  [super dealloc];
}

@end