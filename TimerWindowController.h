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

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import <Cocoa/Cocoa.h>
#import "AppController.h"
#import "SelfControlCommon.h"

// A subclass of NSWindowController created to manage the floating timer window
// which tells the user how much time remains in the block.
@interface TimerWindowController : NSWindowController {
	IBOutlet NSTextField* timerLabel_;
	NSTimer* timerUpdater_;
	NSDate* blockEndingDate_;
	NSLock* modifyBlockLock;
	int numStrikes;
	IBOutlet NSButton* addToBlockButton_;
	IBOutlet NSButton* killBlockButton_;

	IBOutlet NSPanel* addSheet_;
	IBOutlet NSTextField* addToBlockTextField_;
    
    IBOutlet NSPanel* extendBlockTimeSheet_;
}

@property (nonatomic, readwrite) int extendBlockHoursValue;
@property (nonatomic, readwrite) int extendBlockMinutesValue;

// Updates the window's timer display to the correct time remaining until the
// block expires.  If the block has expired and been removed, it invalidates
// timerUpdater, closes the timer window, and opens the initial window.
- (void)updateTimerDisplay:(NSTimer*)timer;

// Closes the "Add to Block" sheet.
- (IBAction) closeAddSheet:(id)sender;

// Closes the "Extend Block Time" sheet.
- (IBAction) closeExtendSheet:(id)sender;

// Called when the "Add to Block" button is clicked, instantiates and runs a sheet
// to take input for the host to block.
- (IBAction) addToBlock:(id)sender;

// Called after the block end date has been successfully changed
- (void) blockEndDateUpdated;

// Called by the "Add to Block" sheet if the user clicks the add button, to destroy
// the sheet and try to add the host to the block.
- (IBAction) performAddSite:(id)sender;

// Delegate method for the sheet.  Just closes the sheet.
- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

// Run specialized SelfControl checkup program to make sure timer should still be on,
// and remove it if it isn't supposed to be on.
- (void)runCheckup;

- (IBAction)killBlock:(id)sender;

- (void)resetStrikes;

- (void)blockEnded;

@end
