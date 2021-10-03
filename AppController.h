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
#import "SCSettings.h"
#import "SCDurationSlider.h"

// The main controller for the SelfControl app, which includes several methods
// to handle command flow and acts as delegate for the initial window.
@interface AppController : NSObject <NSApplicationDelegate> {
	IBOutlet SCDurationSlider* blockDurationSlider_;
	IBOutlet NSTextField* blockSliderTimeDisplayLabel_;
    IBOutlet NSTextField* blocklistTeaserLabel_;
	IBOutlet NSButton* submitButton_;
	IBOutlet NSWindow* initialWindow_;

	IBOutlet NSMenuItem* domainListMenuItem_;
    IBOutlet NSMenuItem* editBlocklistMenuItem_;
    
	IBOutlet NSButton* editBlocklistButton_;
	IBOutlet DomainListWindowController* domainListWindowController_;
	IBOutlet TimerWindowController* timerWindowController_;
	NSWindowController* preferencesWindowController_;
	NSUserDefaults* defaults_;
    SCSettings* settings_;
	NSLock* refreshUILock_;
	BOOL blockIsOn;
	BOOL addingBlock;
}

@property (assign) BOOL addingBlock;

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

// Called when the "Edit blocklist" button is clicked or the menu item is
// selected.  Allocates a new DomainListWindowController if necessary and opens
// the domain blocklist window.  Spawns an alert box if a block is in progress.
- (IBAction)showDomainList:(id)sender;

// Allocates a new TimerWindowController if necessary and opens the timer window.
- (void)showTimerWindow;

// Calls the close method of our TimerWindowController
- (void)closeTimerWindow;

// Calls the close method of our DomainListWindowController
- (void)closeDomainList;

// Called by timerWindowController_ after its sheet returns, to add a specified
// host to the blocklist (and refresh the block to use the new blocklist).  Launches
// a new thread with addToBlocklist:
- (void)addToBlockList:(NSString*)host lock:(NSLock*)lock;

// Called by timerWindowController_ after its sheet returns, to add a specified
// number of minutes to the black timer.
- (void)extendBlockTime:(NSInteger)minutes lock:(NSLock*)lock;

// Gets authorization for and then immediately adds the block by calling
// SelfControl's helper tool with the appropriate arguments.  Meant to be called
// as a separate thread.
- (void)installBlock;

// Gets authorization for and then immediately refreshes the block by calling
// SelfControl's helper tool with the appropriate arguments.  Meant to be called
// as a separate thread.
- (void)updateActiveBlocklist:(NSLock*)lockToUse;

// open preferences panel
- (IBAction)openPreferences:(id)sender;

- (IBAction)showGetStartedWindow:(id)sender;

// Opens a save panel and saves the blocklist.
- (IBAction)save:(id)sender;

// Opens an open panel and imports a blocklist, clearing the current one.
- (IBAction)open:(id)sender;

// Property allows initialWindow to be accessed from TimerWindowController
// @property (retain, nonatomic, readonly) id initialWindow;

// Changed property to manual accessor for pre-Leopard compatibility
@property (nonatomic, readonly, strong) id initialWindow;

// opens the SelfControl FAQ in the default browser
- (IBAction)openFAQ:(id)sender;

// opens the SelfControl Support Hub in the default browser
- (IBAction)openSupportHub:(id)sender;

@end
