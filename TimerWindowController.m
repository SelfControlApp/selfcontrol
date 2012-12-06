 
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
  [super init];
  unsigned int major, minor, bugfix;
  
  [SelfControlUtilities getSystemVersionMajor: &major minor: &minor bugFix: &bugfix];
  
  if(major <= 10 && minor < 5)
    isLeopard = NO;
  else
    isLeopard = YES;
        
  // We need a block to prevent us from running multiple copies of the "Add to Block"
  // sheet.
  addToBlockLock = [[NSLock alloc] init];
      
  numStrikes = 0;
  
  return self;
}

- (void)awakeFromNib {
  [[self window] center];
  [[self window] makeKeyAndOrderFront: self];
  
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  
  NSWindow* window = [self window];
        
  [window center];
  
  if([defaults boolForKey:@"TimerWindowFloats"])
    [window setLevel: NSFloatingWindowLevel];
  else
    [window setLevel: NSNormalWindowLevel];
  
  [window setHidesOnDeactivate: NO];
  
  [window makeKeyAndOrderFront: self];
  
  NSDictionary* lockDict = [NSDictionary dictionaryWithContentsOfFile: SelfControlLockFilePath];
      
  NSDate* beginDate = [lockDict objectForKey:@"BlockStartedDate"];
  NSTimeInterval blockDuration = [[lockDict objectForKey:@"BlockDuration"] intValue] * 60;
  
  if(beginDate == nil || [beginDate isEqualToDate: [NSDate distantFuture]]
     || blockDuration < 1) {
    beginDate = [defaults objectForKey:@"BlockStartedDate"];
    blockDuration = [defaults integerForKey:@"BlockDuration"] * 60;
  }
  
  // It is KEY to retain the block ending date , if you forget to retain it
  // you'll end up with a nasty program crash.
  if(blockDuration)
    blockEndingDate_ = [[beginDate addTimeInterval: blockDuration] retain];
  else
    // If the block duration is 0, the ending date is... now!
    blockEndingDate_ = [[NSDate date] retain];
  [self updateTimerDisplay: nil];
  timerUpdater_ = [NSTimer scheduledTimerWithTimeInterval: 1.0
                                                   target: self
                                                 selector: @selector(updateTimerDisplay:)
                                                 userInfo: nil
                                                  repeats: YES];
}

- (void)blockEnded {
  if(![[NSApp delegate] selfControlLaunchDaemonIsLoaded]) {
    [timerUpdater_ invalidate];
    timerUpdater_ = nil;
    
    [timerLabel_ setStringValue: NSLocalizedString(@"Block not active", @"block not active string")];
    [timerLabel_ setFont: [[NSFontManager sharedFontManager]
                           convertFont: [timerLabel_ font]
                           toSize: 37]
     ];
    
    [timerLabel_ sizeToFit];
    
    [self resetStrikes];
  }
}

- (void)updateTimerDisplay:(NSTimer*)timer {  
  int numSeconds = (int) [blockEndingDate_ timeIntervalSinceNow];
  int numHours;
  int numMinutes;
  
  if(numSeconds < 0) {
    if(isLeopard)
      [[NSApp dockTile] setBadgeLabel: nil];    
        
    // This increments the strike counter.  After four strikes of the timer being
    // at or less than 0 seconds, SelfControl will assume something's wrong and run
    // scheckup.
    numStrikes++;
        
    if(numStrikes == 4) {
      NSLog(@"WARNING: Block should have ended four seconds ago, starting scheckup");
      [self runCheckup];
    } else if(numStrikes == 15) {
        // OK, so apparently scheckup couldn't remove the block either
        // The user needs some help, let's open the FAQ for them.
        NSLog(@"WARNING: Block should have ended fifteen seconds ago! Probable permablock.");
        [[NSApp delegate] openFAQ: self];
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
  [self resetStrikes];
  
  if(isLeopard && [[NSUserDefaults standardUserDefaults] boolForKey: @"BadgeApplicationIcon"]) {
    // We want to round up the minutes--standard when we aren't displaying seconds.
    if(numSeconds > 0 && numMinutes != 59)
      numMinutes++;
    NSString* badgeString = [NSString stringWithFormat: @"%0.2d:%0.2d",
                                                        numHours,
                                                        numMinutes];
    [[NSApp dockTile] setBadgeLabel: badgeString];
  } else if(isLeopard) {
    // If we're on Leopard but aren't using badging, set the badge string to be
    // empty to remove any badge if there is one.
    [[NSApp dockTile] setBadgeLabel: nil];
  }
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
  
  [NSApp beginSheet: addSheet_
     modalForWindow: [self window]
      modalDelegate: self
     didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
        contextInfo: nil];
  
  [addToBlockLock unlock];  
}

- (IBAction) closeAddSheet:(id)sender {
  [NSApp endSheet: addSheet_];
}

- (IBAction) performAdd:(id)sender {
  NSString* addToBlockTextFieldContents = [addToBlockTextField_ stringValue];
  [[NSApp delegate] addToBlockList: addToBlockTextFieldContents lock: addToBlockLock];
  [NSApp endSheet: addSheet_];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
  [sheet orderOut:self];  
}

// see updateTimerDisplay: for an explanation
- (void)resetStrikes {
  numStrikes = 0;
}

- (void)runCheckup {
  [NSTask launchedTaskWithLaunchPath: @"/Library/PrivilegedHelperTools/scheckup" arguments: [NSArray array]];
}

- (void)dealloc {
  [addToBlockLock release];
  [timerUpdater_ invalidate];
  timerUpdater_ = nil;
  [super dealloc];
}

@end