//
//  AppController.h
//  SelfControl
//
//  Created by Charlie Stigler on 1/29/09.
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

// Forward declaration to avoid compiler weirdness
@class TimerWindowController;

#import <Cocoa/Cocoa.h>
#import "DomainListWindowController.h"
#import "TimerWindowController.h"
#import <Security/Security.h>
#import <SystemConfiguration/SCNetwork.h>
#import <unistd.h>
#import "SelfControlCommon.h"

// The main controller for the SelfControl app, which includes several methods
// to handle command flow and acts as delegate for the initial window.
@interface AppController : NSObject {
  IBOutlet id blockDurationSlider_;
  IBOutlet id blockSliderTimeDisplayLabel_;
  IBOutlet id submitButton_;
  IBOutlet id initialWindow_;
  IBOutlet id domainListMenuItem_;
  IBOutlet id editBlacklistButton_;
  IBOutlet DomainListWindowController* domainListWindowController_;
  IBOutlet TimerWindowController* timerWindowController_;
  NSUserDefaults* defaults_;
  NSLock* refreshUILock_;
  BOOL blockIsOn;
  BOOL addingBlock;
}

@property (assign) BOOL addingBlock;

// Returns an autoreleased instance of the path to the helper tool inside
// SelfControl's bundle
- (NSString*)selfControlHelperToolPath;

// Returns as a UTF-8 encoded C-string the path to the helper tool inside
// SelfControl's bundle
- (char*)selfControlHelperToolPathUTF8String;

// Called when the block duration slider is moved.  Updates the label that gives
// the block duration in words (hours and minutes).
- (IBAction)updateTimeSliderDisplay:(id)sender;

/* // Gets authorization for and then immediately removes the block by calling
// SelfControl's helper tool with the appropriate arguments.  This can be used
// for testing, but should not be called at all during normal execution of the
// program.
- (void)removeBlock; */

// Called when the main Start button is clicked.  Launchs installBlock in another
// thread after some checking and syncing.
- (IBAction)addBlock:(id)sender;

// Checks whether the SelfControl block is active and accordingly changes the
// user interface.  Called very often by several parts of the program.
- (void)refreshUserInterface;

// Called when the "Edit blacklist" button is clicked or the menu item is
// selected.  Allocates a new DomainListWindowController if necessary and opens
// the domain blacklist window.  Spawns an alert box if a block is in progress.
- (IBAction)showDomainList:(id)sender;

// Returns YES if, according to a flag set in the user defaults system, the
// SelfControl launchd daemon (and therefore the block) is loaded.  Returns NO
// if it is not.
- (BOOL)selfControlLaunchDaemonIsLoaded;

// Allocates a new TimerWindowController if necessary and opens the timer window.
// Also calls TimerWindowController's reloadTimer method to begin the timer's
// countdown.
- (void)showTimerWindow;

// Calls the close method of our TimerWindowController
- (void)closeTimerWindow;

// Calls the close method of our DomainListWindowController
- (void)closeDomainList;

// Checks whether a network connection is available by checking the reachabilty
// of google.com  This method may not be correct if the network configuration
// was just changed a few seconds ago.
- (BOOL)networkConnectionIsAvailable;

// Called whenever the selection of sound to play in the Preferences menu changes.
// Plays the sound so that the user can "sample" them.
- (IBAction)soundSelectionChanged:(id)sender;

// Called by timerWindowController_ after its sheet returns, to add a specified
// host to the blacklist (and refresh the block to use the new blacklist).  Launches
// a new thread with refreshBlock:
- (void)addToBlockList:(NSString*)host lock:(NSLock*)lock;

// Converts a failure exit code from a helper tool invocation into an NSError,
// ready to be presented to the user.
- (NSError*)errorFromHelperToolStatusCode:(int)status;

// Gets authorization for and then immediately adds the block by calling
// SelfControl's helper tool with the appropriate arguments.  Meant to be called
// as a separate thread.
- (void)installBlock;

// Gets authorization for and then immediately refreshes the block by calling
// SelfControl's helper tool with the appropriate arguments.  Meant to be called
// as a separate thread.
- (void)refreshBlock:(NSLock*)lockToUse;

// Opens a save panel and saves the blocklist.
- (IBAction)save:(id)sender;

// Opens an open panel and imports a blocklist, clearing the current one.
- (IBAction)open:(id)sender;

// Property allows initialWindow to be accessed from TimerWindowController
// @property (retain, nonatomic, readonly) id initialWindow;

// Changed property to manual accessor for pre-Leopard compatibility
- (id)initialWindow;

- (int)blockLength;

- (void)setBlockLength:(int)blockLength;

- (IBAction)openFAQ:(id)sender;

- (void)switchedToWhitelist:(id)sender;

@end