
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
#import "SCBlockDateUtilities.h"

@interface TimerWindowController ()

@property(nonatomic, readonly) AppController* appController;

@end

@implementation TimerWindowController

- (TimerWindowController*) init {
	if(self = [super init]) {
        settings_ = [SCSettings currentUserSettings];
        
		// We need a block to prevent us from running multiple copies of the "Add to Block"
		// sheet.
		modifyBlockLock = [[NSLock alloc] init];

        self.extendBlockHoursValue = 0;
        self.extendBlockMinutesValue = 15;
	
        numStrikes = 0;
	}

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

	killBlockButton_.hidden = YES;
	addToBlockButton_.hidden = NO;

    blockEndingDate_ = [SCBlockDateUtilities blockEndDateInDictionary: settings_.dictionaryRepresentation];

	[self updateTimerDisplay: nil];

	timerUpdater_ = [NSTimer timerWithTimeInterval: 1.0
											target: self
										  selector: @selector(updateTimerDisplay:)
										  userInfo: nil
										   repeats: YES];

	//If the dialog isn't focused, instead of getting a NSTimer, we get null.
	//Scheduling the timer from the main thread seems to work.
	[self performSelectorOnMainThread: @selector(hackAroundMainThreadtimer:) withObject: timerUpdater_ waitUntilDone: YES];
}



- (void)blockEnded {
	if(![self.appController selfControlLaunchDaemonIsLoaded]) {
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


- (void)hackAroundMainThreadtimer:(NSTimer*)timer{
	[[NSRunLoop currentRunLoop] addTimer: timer forMode: NSDefaultRunLoopMode];
}

- (void)updateTimerDisplay:(NSTimer*)timer {
	// update UI for the whole app, in case the block is done with
    [self.appController performSelectorOnMainThread:@selector(refreshUserInterface)
                                         withObject:nil
                                      waitUntilDone:NO];

    NSString* finishingString = NSLocalizedString(@"Finishing", @"String shown when waiting for finished block to clear");
	int numSeconds = (int) [blockEndingDate_ timeIntervalSinceNow];
	int numHours;
	int numMinutes;

    // if we're already showing "Finishing", but the block timer isn't clearing,
    // keep track of that, so we can take drastic measures if necessary.
	if(numSeconds < 0 && [timerLabel_.stringValue isEqualToString: finishingString]) {
		[[NSApp dockTile] setBadgeLabel: nil];

		// This increments the strike counter.  After four strikes of the timer being
		// at or less than 0 seconds, SelfControl will assume something's wrong and run
		// scheckup.
		numStrikes++;

		if(numStrikes == 2) {
			NSLog(@"WARNING: Block should have ended two seconds ago, starting scheckup");
			[self runCheckup];
		} else if(numStrikes > 10) {
			// OK, so apparently scheckup couldn't remove the block either. Enable manual block removal.
			if (numStrikes == 10) NSLog(@"WARNING: Block should have ended a minute ago! Probable permablock.");
			addToBlockButton_.hidden = YES;
			killBlockButton_.hidden = NO;
		}

		return;
	}

	numHours = (numSeconds / 3600);
	numSeconds %= 3600;
	numMinutes = (numSeconds / 60);
	numSeconds %= 60;

    NSString* timeString;
    if (numHours > 0 || numMinutes > 0 || numSeconds > 0) {
        timeString = [NSString stringWithFormat: @"%0.2d:%0.2d:%0.2d",
                      numHours,
                      numMinutes,
                      numSeconds];
    } else {
        // It usually takes 5-15 seconds after a block finishes for it to turn off
        // so show "Finishing" instead of "00:00:00" to avoid user worry and confusion!
        timeString = finishingString;
    }

	[timerLabel_ setStringValue: timeString];
	[timerLabel_ setFont: [[NSFontManager sharedFontManager]
						   convertFont: [timerLabel_ font]
						   toSize: 42]
	 ];

	[timerLabel_ sizeToFit];
	[timerLabel_ setFrame:NSRectFromCGRect(CGRectMake(0, timerLabel_.frame.origin.y, self.window.frame.size.width, timerLabel_.frame.size.height))];
	[self resetStrikes];

	if([[NSUserDefaults standardUserDefaults] boolForKey: @"BadgeApplicationIcon"]) {
		// We want to round up the minutes--standard when we aren't displaying seconds.
		if(numSeconds > 0 && numMinutes != 59) {
			numMinutes++;
		}

		NSString* badgeString = [NSString stringWithFormat: @"%0.2d:%0.2d",
								 numHours,
								 numMinutes];
		[[NSApp dockTile] setBadgeLabel: badgeString];
	} else {
		// If we aren't using badging, set the badge string to be
		// empty to remove any badge if there is one.
		[[NSApp dockTile] setBadgeLabel: nil];
	}
}

- (void)windowShouldClose:(NSNotification *)notification {
	// Hack to make the application terminate after the last window is closed, but
	// INCLUDE the HUD-style timer window.
	if(![[self.appController initialWindow] isVisible]) {
		[NSApp terminate: self];
	}
}

- (IBAction) addToBlock:(id)sender {
	// Check if there's already a thread trying to modify the block.  If so, don't make
	// another.
	if(![modifyBlockLock tryLock]) {
		return;
	}

	[NSApp beginSheet: addSheet_
	   modalForWindow: [self window]
		modalDelegate: self
	   didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
		  contextInfo: nil];

	[modifyBlockLock unlock];
}

- (IBAction) extendBlockTime:(id)sender {
    // Check if there's already a thread trying to modify the block.  If so, don't make
    // another.
    if(![modifyBlockLock tryLock]) {
        return;
    }
    
    [NSApp beginSheet: extendBlockTimeSheet_
       modalForWindow: [self window]
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
    
    [modifyBlockLock unlock];
}

- (IBAction) closeAddSheet:(id)sender {
	[NSApp endSheet: addSheet_];
}
- (IBAction) closeExtendSheet:(id)sender {
    [NSApp endSheet: extendBlockTimeSheet_];
}

- (IBAction) performAddSite:(id)sender {
	NSString* addToBlockTextFieldContents = [addToBlockTextField_ stringValue];
	[self.appController addToBlockList: addToBlockTextFieldContents lock: modifyBlockLock];
	[NSApp endSheet: addSheet_];
}

- (IBAction) performExtendBlock:(id)sender {
    NSInteger extendBlockMinutes = (self.extendBlockHoursValue * 60) + self.extendBlockMinutesValue;
        
    [self.appController extendBlockTime: extendBlockMinutes lock: modifyBlockLock];
    [NSApp endSheet: extendBlockTimeSheet_];
}

- (void) blockEndDateUpdated {
    blockEndingDate_ = [SCBlockDateUtilities blockEndDateInDictionary: settings_.dictionaryRepresentation];
    
    [self updateTimerDisplay: nil];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	[sheet orderOut:self];
}

// see updateTimerDisplay: for an explanation
- (void)resetStrikes {
	numStrikes = 0;
}

- (void)runCheckup {
	@try {
		[NSTask launchedTaskWithLaunchPath: @"/Library/PrivilegedHelperTools/scheckup" arguments: @[]];
	}
	@catch (NSException* exception) {
		NSLog(@"ERROR: exception %@ caught while trying to launch scheckup", exception);
	}
}

- (IBAction)killBlock:(id)sender {
	AuthorizationRef authorizationRef;
	char* helperToolPath = [self selfControlKillerHelperToolPathUTF8String];
	NSUInteger helperToolPathSize = strlen(helperToolPath);
	AuthorizationItem right = {
		kAuthorizationRightExecute,
		helperToolPathSize,
		helperToolPath,
		0
	};
	AuthorizationRights authRights = {
		1,
		&right
	};
	AuthorizationFlags myFlags = kAuthorizationFlagDefaults |
	kAuthorizationFlagExtendRights |
	kAuthorizationFlagInteractionAllowed;
	OSStatus status;

	status = AuthorizationCreate (&authRights,
								  kAuthorizationEmptyEnvironment,
								  myFlags,
								  &authorizationRef);

	if(status) {
		NSLog(@"ERROR: Failed to authorize block kill.");
		return;
	}
    
    // we're about to launch a helper tool which will read settings, so make sure the ones on disk are valid
    [settings_ synchronizeSettings];

	char uidString[10];
	snprintf(uidString, sizeof(uidString), "%d", getuid());

	char* args[] = { uidString, NULL };

	status = AuthorizationExecuteWithPrivileges(authorizationRef,
												helperToolPath,
												kAuthorizationFlagDefaults,
												args,
												NULL);
	if(status) {
		NSLog(@"WARNING: Authorized execution of helper tool returned failure status code %d", status);

		NSError* err = [NSError errorWithDomain: @"org.eyebeam.SelfControl-Killer" code: status userInfo: @{NSLocalizedDescriptionKey: @"Error executing privileged helper tool."}];

		[NSApp presentError: err];

		return;
	} else {
        // Now that the current block is over, we can go ahead and remove the legacy block info
        // and migrate them to the new SCSettings system
        [[SCSettings currentUserSettings] clearLegacySettings];
        
		NSAlert* alert = [[NSAlert alloc] init];
		[alert setMessageText: @"Success!"];
		[alert setInformativeText:@"The block was cleared successfully.  You can find the log file, named SelfControl-Killer.log, in your Documents folder. If you're still having issues, please check out the SelfControl FAQ on GitHub."];
		[alert addButtonWithTitle: @"OK"];
		[alert runModal];
	}
}

- (NSString*)selfControlKillerHelperToolPath {
	static NSString* path;

	// Cache the path so it doesn't have to be searched for again.
	if(!path) {
		NSBundle* thisBundle = [NSBundle mainBundle];
		path = [thisBundle pathForAuxiliaryExecutable: @"SCKillerHelper"];
	}

	return path;
}
- (char*)selfControlKillerHelperToolPathUTF8String {
	static char* path;

	// Cache the converted path so it doesn't have to be converted again
	if(!path) {
		path = malloc(512);
		[[self selfControlKillerHelperToolPath] getCString: path
												 maxLength: 512
												  encoding: NSUTF8StringEncoding];
	}

	return path;
}

- (void)dealloc {
	[timerUpdater_ invalidate];
}

#pragma mark - Properties

- (AppController *)appController
{
    AppController* controller = (AppController *)[NSApp delegate];
    return controller;
}

@end
