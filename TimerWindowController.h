//
//  TimerWindowController.h
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

#import <Cocoa/Cocoa.h>

// A subclass of NSWindowController created to manage the floating timer window
// which tells the user how much time remains in the block.
@interface TimerWindowController : NSWindowController {
  IBOutlet id timerLabel_;
  NSTimer* timerUpdater_;
  NSDate* blockEndingDate_;
}

// Updates the window's timer display to the correct time remaining until the
// block expires.  If the block has expired and been removed, it invalidates
// timerUpdater, closes the timer window, and opens the initial window. 
- (void)updateTimerDisplay;

// Invalidates timerUpdater if it's still valid, then restarts the timer and
// sets the end time to the scheduled end of the block, or the current time if
// no block is scheduled.
- (void)reloadTimer;

@end