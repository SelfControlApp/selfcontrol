//
//  AppController.m
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

#import "AppController.h"
#import "MASPreferencesWindowController.h"
#import "PreferencesGeneralViewController.h"
#import "PreferencesAdvancedViewController.h"
#import "SCTimeIntervalFormatter.h"
#import "SCUtilities.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <LetsMove/PFMoveApplication.h>
#import "SCSettings.h"
#import <ServiceManagement/ServiceManagement.h>
#import "SCAppXPC.h"

NSString* const kSelfControlErrorDomain = @"SelfControlErrorDomain";

@interface AppController () {}

@property (atomic, strong, readwrite) SCAppXPC* xpc;

@end

@implementation AppController {
	NSWindowController* getStartedWindowController;
}

@synthesize addingBlock;

- (AppController*) init {
	if(self = [super init]) {

		defaults_ = [NSUserDefaults standardUserDefaults];
        settings_ = [SCSettings currentUserSettings];
        
		NSDictionary* appDefaults = @{
									  @"HighlightInvalidHosts": @YES,
									  @"VerifyInternetConnection": @YES,
									  @"TimerWindowFloats": @NO,
									  @"BadgeApplicationIcon": @YES,
									  @"MaxBlockLength": @1440,
									  @"BlockLengthInterval": @15,
									  @"WhitelistAlertSuppress": @NO,
									  @"GetStartedShown": @NO
                                      };

		[defaults_ registerDefaults:appDefaults];

		self.addingBlock = false;

		// refreshUILock_ is a lock that prevents a race condition by making the refreshUserInterface
		// method alter the blockIsOn variable atomically (will no longer be necessary once we can
		// use properties).
		refreshUILock_ = [[NSLock alloc] init];
	}

	return self;
}

- (NSString*)selfControlHelperToolPath {
	static NSString* path;

	// Cache the path so it doesn't have to be searched for again.
	if(!path) {
		NSBundle* thisBundle = [NSBundle mainBundle];
        path = [thisBundle.bundlePath stringByAppendingString: @"/Contents/Library/LaunchServices/org.eyebeam.selfcontrold"];
    }

	return path;
}

- (char*)selfControlHelperToolPathUTF8String {
	static char* path;

	// Cache the converted path so it doesn't have to be converted again
	if(!path) {
		path = malloc(512);
		[[self selfControlHelperToolPath] getCString: path
										   maxLength: 512
											encoding: NSUTF8StringEncoding];
	}

	return path;
}

- (IBAction)updateTimeSliderDisplay:(id)sender {
    NSInteger numMinutes = [defaults_ integerForKey: @"BlockDuration"];

    // if the duration is larger than we can display on our slider
    // chop it down to our max display value so the user doesn't
    // accidentally start a much longer block than intended
    if (numMinutes > blockDurationSlider_.maxValue) {
        [self setDefaultsBlockDurationOnMainThread: @(floor(blockDurationSlider_.maxValue))];
        numMinutes = [defaults_ integerForKey: @"BlockDuration"];
    }

	// Time-display code cleaned up thanks to the contributions of many users

	NSString* timeString = [self timeSliderDisplayStringFromNumberOfMinutes:numMinutes];

	[blockSliderTimeDisplayLabel_ setStringValue:timeString];
	[submitButton_ setEnabled: (numMinutes > 0) && ([[settings_ valueForKey: @"Blocklist"] count] > 0)];
}

- (NSString *)timeSliderDisplayStringFromNumberOfMinutes:(NSInteger)numberOfMinutes {
    static NSCalendar* gregorian = nil;
    if (gregorian == nil) {
        gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    }

    NSRange secondsRangePerMinute = [gregorian
                                     rangeOfUnit:NSSecondCalendarUnit
                                     inUnit:NSMinuteCalendarUnit
                                     forDate:[NSDate date]];
    NSUInteger numberOfSecondsPerMinute = NSMaxRange(secondsRangePerMinute);

    NSTimeInterval numberOfSecondsSelected = (NSTimeInterval)(numberOfSecondsPerMinute * numberOfMinutes);

    NSString* displayString = [self timeSliderDisplayStringFromTimeInterval:numberOfSecondsSelected];
    return displayString;
}

- (NSString *)timeSliderDisplayStringFromTimeInterval:(NSTimeInterval)numberOfSeconds {
    static SCTimeIntervalFormatter* formatter = nil;
    if (formatter == nil) {
        formatter = [[SCTimeIntervalFormatter alloc] init];
    }

    NSString* formatted = [formatter stringForObjectValue:@(numberOfSeconds)];
    return formatted;
}

- (IBAction)addBlock:(id)sender {
	[defaults_ synchronize];
    if ([self blockIsRunning]) {
		// This method shouldn't be getting called, a block is on so the Start button should be disabled.
		NSError* err = [NSError errorWithDomain:kSelfControlErrorDomain
										   code: -102
									   userInfo: @{NSLocalizedDescriptionKey: @"We can't start a block, because one is currently ongoing."}];
		[NSApp presentError: err];
		return;
	}
	if([[settings_ valueForKey:@"Blocklist"] count] == 0) {
		// Since the Start button should be disabled when the blocklist has no entries,
		// this should definitely not be happening.  Exit.

		NSError* err = [NSError errorWithDomain:kSelfControlErrorDomain
										   code: -102
									   userInfo: @{NSLocalizedDescriptionKey: @"Error -102: Attempting to add block, but no blocklist is set."}];

		[NSApp presentError: err];

		return;
	}

	if([defaults_ boolForKey: @"VerifyInternetConnection"] && ![self networkConnectionIsAvailable]) {
		NSAlert* networkUnavailableAlert = [[NSAlert alloc] init];
		[networkUnavailableAlert setMessageText: NSLocalizedString(@"No network connection detected", "No network connection detected message")];
		[networkUnavailableAlert setInformativeText:NSLocalizedString(@"A block cannot be started without a working network connection.  You can override this setting in Preferences.", @"Message when network connection is unavailable")];
		[networkUnavailableAlert addButtonWithTitle: NSLocalizedString(@"Cancel", "Cancel button")];
		[networkUnavailableAlert addButtonWithTitle: NSLocalizedString(@"Network Diagnostics...", @"Network Diagnostics button")];
		if([networkUnavailableAlert runModal] == NSAlertFirstButtonReturn)
			return;

		// If the user selected Network Diagnostics launch an assisant to help them.
		// apple.com is an arbitrary host chosen to pass to Network Diagnostics.
		CFURLRef url = CFURLCreateWithString(NULL, CFSTR("http://apple.com"), NULL);
		CFNetDiagnosticRef diagRef = CFNetDiagnosticCreateWithURL(kCFAllocatorDefault, url);
		CFNetDiagnosticDiagnoseProblemInteractively(diagRef);
		return;
	}

	[timerWindowController_ resetStrikes];

	[NSThread detachNewThreadSelector: @selector(installBlock) toTarget: self withObject: nil];
}

- (void)refreshUserInterface {
    // UI updates are for the main thread only!
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self refreshUserInterface];
        });
        return;
    }

	if(![refreshUILock_ tryLock]) {
		// already refreshing the UI, no need to wait and do it again
		return;
	}

	BOOL blockWasOn = blockIsOn;
	blockIsOn = [self blockIsRunning];

	if(blockIsOn) { // block is on
		if(!blockWasOn) { // if we just switched states to on...
			[self closeTimerWindow];
			[self showTimerWindow];
			[initialWindow_ close];
			[self closeDomainList];
		}
	} else { // block is off
		if(blockWasOn) { // if we just switched states to off...
            // Now that the current block is over, we can go ahead and remove the legacy block info
            // and migrate them to the new SCSettings system
            [[SCSettings currentUserSettings] clearLegacySettings];

			[timerWindowController_ blockEnded];

			// Makes sure the domain list will refresh when it comes back
			[self closeDomainList];

			NSWindow* mainWindow = [NSApp mainWindow];
			// We don't necessarily want the initial window to be key and front,
			// but no other message seems to show it properly.
			[initialWindow_ makeKeyAndOrderFront: self];
			// So we work around it and make key and front whatever was the main window
			[mainWindow makeKeyAndOrderFront: self];
            
            // make sure the dock badge is cleared
            [[NSApp dockTile] setBadgeLabel: nil];

			[self closeTimerWindow];
		}

		[defaults_ synchronize];

		[self updateTimeSliderDisplay: blockDurationSlider_];

		BOOL addBlockIsOngoing = self.addingBlock;

		if([defaults_ integerForKey: @"BlockDuration"] != 0 && [[settings_ valueForKey: @"Blocklist"] count] != 0 && !addBlockIsOngoing) {
			[submitButton_ setEnabled: YES];
		} else {
			[submitButton_ setEnabled: NO];
		}

		// If we're adding a block, we want buttons disabled.
		if(!addBlockIsOngoing) {
			[blockDurationSlider_ setEnabled: YES];
			[editBlocklistButton_ setEnabled: YES];
			[submitButton_ setTitle: NSLocalizedString(@"Start", @"Start button")];
		} else {
			[blockDurationSlider_ setEnabled: NO];
			[editBlocklistButton_ setEnabled: NO];
			[submitButton_ setTitle: NSLocalizedString(@"Loading", @"Loading button")];
		}

		// if block's off, and we haven't shown it yet, show the first-time modal
		if (![defaults_ boolForKey: @"GetStartedShown"]) {
			[defaults_ setBool: YES forKey: @"GetStartedShown"];
			[defaults_ synchronize];
			[self showGetStartedWindow: self];
		}
	}

    // finally: if the helper tool marked that it detected tampering, make sure
    // we follow through and set the cheater wallpaper (helper tool can't do it itself)
    if ([[settings_ valueForKey: @"TamperingDetected"] boolValue]) {
        NSURL* cheaterBackgroundURL = [[NSBundle mainBundle] URLForResource: @"cheater-background" withExtension: @"png"];
            NSArray<NSScreen *>* screens = [NSScreen screens];
        for (NSScreen* screen in screens) {
            NSError* err;
            [[NSWorkspace sharedWorkspace] setDesktopImageURL: cheaterBackgroundURL
                                                    forScreen: screen
                                                      options: @{}
                                                        error: &err];
        }
        [settings_ setValue: @NO forKey: @"TamperingDetected"];
    }
    
    // Display "blocklist" or "allowlist" as appropriate
    NSString* listType = [[settings_ valueForKey: @"BlockAsWhitelist"] boolValue] ? @"Allowlist" : @"Blocklist";
    NSString* editListString = NSLocalizedString(([NSString stringWithFormat: @"Edit %@", listType]), @"Edit list button / menu item");
    
    editBlocklistButton_.title = editListString;
    editBlocklistMenuItem_.title = editListString;

	[refreshUILock_ unlock];
}

- (void)handleConfigurationChangedNotification {
    // if our configuration changed, we should assume the settings may have changed
    [[SCSettings currentUserSettings] reloadSettings];
    // and our interface may need to change to match!
    [self refreshUserInterface];
}

- (void)showTimerWindow {
	if(timerWindowController_ == nil) {
		[NSBundle loadNibNamed: @"TimerWindow" owner: self];
	} else {
		[[timerWindowController_ window] makeKeyAndOrderFront: self];
		[[timerWindowController_ window] center];
	}
}

- (void)closeTimerWindow {
	[timerWindowController_ close];
	timerWindowController_ = nil;
}

- (IBAction)openPreferences:(id)sender {
	if (preferencesWindowController_ == nil) {
		NSViewController* generalViewController = [[PreferencesGeneralViewController alloc] init];
		NSViewController* advancedViewController = [[PreferencesAdvancedViewController alloc] init];
		NSString* title = NSLocalizedString(@"Preferences", @"Common title for Preferences window");

		preferencesWindowController_ = [[MASPreferencesWindowController alloc] initWithViewControllers: @[generalViewController, advancedViewController] title: title];
	}
	[preferencesWindowController_ showWindow: nil];
}

- (IBAction)showGetStartedWindow:(id)sender {
	if (!getStartedWindowController) {
		getStartedWindowController = [[NSWindowController alloc] initWithWindowNibName: @"FirstTime"];
	}
	[getStartedWindowController.window center];
	[getStartedWindowController.window makeKeyAndOrderFront: nil];
	[getStartedWindowController showWindow: nil];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    // For test runs, we don't want to pop up the dialog to move to the Applications folder, as it breaks the tests
    if (NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"] == nil) {
        PFMoveToApplicationsFolderIfNecessary();
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[NSApplication sharedApplication].delegate = self;
    
    // start up our daemon XPC
    self.xpc = [SCAppXPC new];
    [self.xpc connectToHelperTool];

	// Register observers on both distributed and normal notification centers
	// to receive notifications from the helper tool and the other parts of the
	// main SelfControl app.  Note that they are divided thusly because distributed
	// notifications are very expensive and should be minimized.
	[[NSDistributedNotificationCenter defaultCenter] addObserver: self
														selector: @selector(handleConfigurationChangedNotification)
															name: @"SCConfigurationChangedNotification"
														  object: nil
                                              suspensionBehavior: NSNotificationSuspensionBehaviorDeliverImmediately];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(handleConfigurationChangedNotification)
												 name: @"SCConfigurationChangedNotification"
											   object: nil];

	[initialWindow_ center];

	// We'll set blockIsOn to whatever is NOT right, so that in refreshUserInterface
	// it'll fix it and properly refresh the user interface.
	blockIsOn = ![self blockIsRunning];

	// Change block duration slider for hidden user defaults settings
	long numTickMarks = ([defaults_ integerForKey: @"MaxBlockLength"] / [defaults_ integerForKey: @"BlockLengthInterval"]) + 1;
	[blockDurationSlider_ setMaxValue: [defaults_ integerForKey: @"MaxBlockLength"]];
	[blockDurationSlider_ setNumberOfTickMarks: numTickMarks];

	[blockDurationSlider_ bind: @"value"
					  toObject: [NSUserDefaultsController sharedUserDefaultsController]
				   withKeyPath: @"values.BlockDuration"
					   options: @{
								  NSContinuouslyUpdatesValueBindingOption: @YES
								  }];

	[self refreshUserInterface];

    NSOperatingSystemVersion minRequiredVersion = (NSOperatingSystemVersion){10,8,0}; // Mountain Lion
    NSString* minRequiredVersionString = @"10.8 (Mountain Lion)";
	if (![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion: minRequiredVersion]) {
		NSLog(@"ERROR: Unsupported version for SelfControl");
		NSAlert* unsupportedVersionAlert = [[NSAlert alloc] init];
		[unsupportedVersionAlert setMessageText: NSLocalizedString(@"Unsupported version", nil)];
        [unsupportedVersionAlert setInformativeText: [NSString stringWithFormat: NSLocalizedString(@"This version of SelfControl only supports Mac OS X version %@ or higher. To download a version for older operating systems, please go to www.selfcontrolapp.com", nil), minRequiredVersionString]];
		[unsupportedVersionAlert addButtonWithTitle: NSLocalizedString(@"OK", nil)];
		[unsupportedVersionAlert runModal];
	}
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [settings_ synchronizeSettings];
}

- (BOOL)blockIsRunning {
    return [SCUtilities blockIsRunningWithSettings: settings_ defaults: defaults_];
}

- (IBAction)showDomainList:(id)sender {
    [self.xpc getVersion];
    [self.xpc startBlockWithControllingUID: 501 // TODO: don't hardcode the user ID
                                                 blocklist: [settings_ valueForKey: @"Blocklist"]
                                                   endDate: [settings_ valueForKey: @"BlockEndDate"]
                                             authorization: nil
                                                     reply:^(NSError * _Nonnull error) {
                        NSLog(@"WOO started block with error %@", error);
                    }];
    
	BOOL addBlockIsOngoing = self.addingBlock;
	if([self blockIsRunning] || addBlockIsOngoing) {
		NSAlert* blockInProgressAlert = [[NSAlert alloc] init];
		[blockInProgressAlert setMessageText: NSLocalizedString(@"Block in progress", @"Block in progress error title")];
		[blockInProgressAlert setInformativeText:NSLocalizedString(@"The blocklist cannot be edited while a block is in progress.", @"Block in progress explanation")];
		[blockInProgressAlert addButtonWithTitle: NSLocalizedString(@"OK", @"OK button")];
		[blockInProgressAlert runModal];

		return;
	}

	if(domainListWindowController_ == nil) {
		[NSBundle loadNibNamed: @"DomainList" owner: self];
	}
	[domainListWindowController_ showWindow: self];
}

- (void)closeDomainList {
	[domainListWindowController_ close];
	domainListWindowController_ = nil;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed: (NSApplication*) theApplication {
	// Hack to make the application terminate after the last window is closed, but
	// INCLUDE the HUD-style timer window.
	if([[timerWindowController_ window] isVisible])
		return NO;
    
    if (PFMoveIsInProgress())
        return NO;
    
	return YES;
}

- (BOOL)networkConnectionIsAvailable {
	SCNetworkReachabilityFlags flags;

	// This method goes haywire if Google ever goes down...
	SCNetworkReachabilityRef target = SCNetworkReachabilityCreateWithName (kCFAllocatorDefault, "google.com");

    BOOL reachable = SCNetworkReachabilityGetFlags (target, &flags);
    
	return reachable && (flags & kSCNetworkFlagsReachable) && !(flags & kSCNetworkFlagsConnectionRequired);
}

- (void)addToBlockList:(NSString*)host lock:(NSLock*)lock {
    NSMutableArray* list = [[settings_ valueForKey: @"Blocklist"] mutableCopy];
    NSArray<NSString*>* cleanedEntries = [SCUtilities cleanBlocklistEntry: host];
    
    if (cleanedEntries.count == 0) return;
    
    for (int i = 0; i < cleanedEntries.count; i++) {
       NSString* entry = cleanedEntries[i];
       [list addObject: entry];
    }
       
	[settings_ setValue: list forKey: @"Blocklist"];

	if(![self blockIsRunning]) {
		// This method shouldn't be getting called, a block is not on.
		// so the Start button should be disabled.
		// Maybe the UI didn't get properly refreshed, so try refreshing it again
		// before we return.
		[self refreshUserInterface];

		// Reverse the blocklist change made before we fail
		NSMutableArray* list = [[settings_ valueForKey: @"Blocklist"] mutableCopy];
		[list removeLastObject];
		[settings_ setValue: list forKey: @"Blocklist"];

		NSError* err = [NSError errorWithDomain:kSelfControlErrorDomain
										   code: -103
									   userInfo: @{NSLocalizedDescriptionKey: @"Error -103: Attempting to add host to block, but no block appears to be in progress."}];

		[NSApp presentError: err];

		return;
	}

	if([defaults_ boolForKey: @"VerifyInternetConnection"] && ![self networkConnectionIsAvailable]) {
		NSAlert* networkUnavailableAlert = [[NSAlert alloc] init];
		[networkUnavailableAlert setMessageText: NSLocalizedString(@"No network connection detected", "No network connection detected message")];
		[networkUnavailableAlert setInformativeText:NSLocalizedString(@"A block cannot be started without a working network connection.  You can override this setting in Preferences.", @"Message when network connection is unavailable")];
		[networkUnavailableAlert addButtonWithTitle: NSLocalizedString(@"Cancel", "Cancel button")];
		[networkUnavailableAlert addButtonWithTitle: NSLocalizedString(@"Network Diagnostics...", @"Network Diagnostics button")];
		if([networkUnavailableAlert runModal] == NSAlertFirstButtonReturn) {
			// User clicked cancel
			// Reverse the blocklist change made before we fail
			NSMutableArray* list = [[settings_ valueForKey: @"Blocklist"] mutableCopy];
			[list removeLastObject];
			[settings_ setValue: list forKey: @"Blocklist"];

			return;
		}

		// If the user selected Network Diagnostics, launch an assisant to help them.
		// apple.com is an arbitrary host chosen to pass to Network Diagnostics.
		CFURLRef url = CFURLCreateWithString(NULL, CFSTR("http://apple.com"), NULL);
		CFNetDiagnosticRef diagRef = CFNetDiagnosticCreateWithURL(kCFAllocatorDefault, url);
		CFNetDiagnosticDiagnoseProblemInteractively(diagRef);

		// Reverse the blocklist change made before we fail
		NSMutableArray* list = [[settings_ valueForKey: @"Blocklist"] mutableCopy];
		[list removeLastObject];
		[settings_ setValue: list forKey: @"Blocklist"];

		return;
	}

	[NSThread detachNewThreadSelector: @selector(refreshBlock:) toTarget: self withObject: lock];
}

- (void)extendBlockTime:(NSInteger)minutesToAdd lock:(NSLock*)lock {
    // sanity check: extending a block for 0 minutes is useless; 24 hour should be impossible
    NSInteger MINUTES_IN_DAY = 24 * 60 * 60;
    if(minutesToAdd < 1 || minutesToAdd > MINUTES_IN_DAY)
        return;
    
    // ensure block health before we try to change it
    if(![self blockIsRunning]) {
        // This method shouldn't be getting called, a block is not on.
        // so the Start button should be disabled.
        // Maybe the UI didn't get properly refreshed, so try refreshing it again
        // before we return.
        [self refreshUserInterface];
        
        NSError* err = [NSError errorWithDomain:kSelfControlErrorDomain
                                           code: -103
                                       userInfo: @{NSLocalizedDescriptionKey: @"Error -103: Attempting to extend block time, but no block appears to be in progress."}];
        
        [NSApp presentError: err];
        
        return;
    }
    
    [NSThread detachNewThreadSelector: @selector(extendBlockDuration:)
                             toTarget: self
                           withObject: @{
                                         @"lock": lock,
                                         @"minutesToAdd": @(minutesToAdd)
                                                                                                    }];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self
													name: @"SCConfigurationChangedNotification"
												  object: nil];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver: self
															   name: @"SCConfigurationChangedNotification"
															 object: nil];
}

- (id)initialWindow {
	return initialWindow_;
}

- (id)domainListWindowController {
	return domainListWindowController_;
}

- (void)setDomainListWindowController:(id)newController {
	domainListWindowController_ = newController;
}

- (NSError*)errorFromHelperToolStatusCode:(int)status {
	NSString* domain = kSelfControlErrorDomain;
	NSMutableString* description = [NSMutableString stringWithFormat: @"Error %d: ", status];
	switch(status) {
		case -201:
			[description appendString: @"Helper tool not launched as root."];
			break;
		case -202:
			[description appendString: @"Helper tool launched with insufficient arguments."];
			break;
		case -203:
			[description appendString: @"Host blocklist not set"];
			break;
		case -204:
			[description appendString: @"Could not write launchd plist file to LaunchDaemons folder."];
			break;
		case -205:
			[description appendString: @"Could not create PrivilegedHelperTools directory."];
			break;
		case -206:
			[description appendString: @"Could not change permissions on PrivilegedHelperTools directory."];
			break;
		case -207:
			[description appendString: @"Could not delete old helper binary."];
			break;
		case -208:
			[description appendString: @"Could not copy SelfControl's helper binary to PrivilegedHelperTools directory."];
			break;
		case -209:
			[description appendString: @"Could not change permissions on SelfControl's helper binary."];
			break;
		case -210:
			[description appendString: @"Insufficient block information found."];
			break;
		case -211:
			[description appendString: @"Launch daemon load returned a failure status code."];
			break;
		case -212:
			[description appendString: @"Remove option called."];
			break;
		case -213:
			[description appendString: @"Refreshing domain blocklist, but no block is currently ongoing."];
			break;
		case -214:
			[description appendString: @"Insufficient block information found."];
			break;
		case -215:
			[description appendString: @"Checkup ran but no block found."];
			break;
		case -216:
			[description appendString: @"Could not write lock file."];
			break;
		case -217:
			[description appendString: @"Could not write lock file."];
			break;
		case -218:
			[description appendString: @"Could not remove SelfControl lock file."];
			break;
		case -219:
			[description appendString: @"SelfControl lock file already exists.  Please try your block again."];
			break;

		default:
			[description appendString: [NSString stringWithFormat: @"Helper tool failed with unknown error code: %d", status]];
	}

	return [NSError errorWithDomain: domain code: status userInfo: @{NSLocalizedDescriptionKey: description}];
}

- (void)installBlock {
	@autoreleasepool {
		self.addingBlock = true;
		[self refreshUserInterface];
		AuthorizationRef authorizationRef;
        NSLog(@"helper tool path is %@", [self selfControlHelperToolPath]);
		char* helperToolPath = [self selfControlHelperToolPathUTF8String];
		NSUInteger helperToolPathSize = strlen(helperToolPath);
		AuthorizationItem right = {
			kSMRightBlessPrivilegedHelper,
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
			NSLog(@"ERROR: Failed to authorize block start.");
			self.addingBlock = false;
			[self refreshUserInterface];
			return;
		}

        // for legacy reasons, BlockDuration is in minutes, so convert it to seconds before passing it through]
        NSTimeInterval blockDurationSecs = [[defaults_ valueForKey: @"BlockDuration"] intValue] * 60;
        [SCUtilities startBlockInSettings: settings_ withBlockDuration: blockDurationSecs];
        
        // we're about to launch a helper tool which will read settings, so make sure the ones on disk are valid
        [settings_ synchronizeSettings];

        CFErrorRef cfError;
        BOOL result = (BOOL)SMJobBless(
                                       kSMDomainSystemLaunchd,
                                       CFSTR("org.eyebeam.selfcontrold"),
                                       authorizationRef,
                                       &cfError);
        

		if(!result) {
            NSError* error = CFBridgingRelease(cfError);
            
			NSLog(@"WARNING: Authorized execution of helper tool returned failure status code %d and error %@", (int)status, error);

            // reset settings on failure, and record that on disk ASAP
            [SCUtilities removeBlockFromSettings: settings_];
            [settings_ synchronizeSettings];

			NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain
											   code: status
										   userInfo: @{NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Error %d received from the Security Server.", (int)status]}];

			[NSApp performSelectorOnMainThread: @selector(presentError:)
									withObject: err
								 waitUntilDone: YES];

			self.addingBlock = false;
			[self refreshUserInterface];

			return;
		}

        // ok, the new helper tool is installed! refresh the connection, then it's time to start the block
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.xpc refreshConnection];
            NSLog(@"Refreshed connection!");
//            [self.xpc getVersion];
            [self.xpc startBlockWithControllingUID: 501 // TODO: don't hardcode the user ID
                                         blocklist: [settings_ valueForKey: @"Blocklist"]
                                           endDate: [settings_ valueForKey: @"BlockEndDate"]
                                     authorization: nil
                                             reply:^(NSError * _Nonnull error) {
                NSLog(@"WOO started block with error %@", error);
            }];
        });
        
//		NSFileHandle* helperToolHandle = [[NSFileHandle alloc] initWithFileDescriptor: fileno(commPipe) closeOnDealloc: YES];
//
//		NSData* inData = [helperToolHandle readDataToEndOfFile];
//
//
//		NSString* inDataString = [[NSString alloc] initWithData: inData encoding: NSUTF8StringEncoding];
//
//		if([inDataString isEqualToString: @""]) {
//            // reset settings on failure, and record that on disk ASAP
//            [SCUtilities removeBlockFromSettings: settings_];
//            [settings_ synchronizeSettings];
//
//			NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain
//											   code: -104
//										   userInfo: @{NSLocalizedDescriptionKey: @"Error -104: The helper tool crashed.  This may cause unexpected errors."}];
//
//			[NSApp performSelectorOnMainThread: @selector(presentError:)
//									withObject: err
//								 waitUntilDone: YES];
//		}
//
//		int exitCode = [inDataString intValue];
//
//		if(exitCode) {
//            // reset settings on failure, and record that on disk ASAP
//            [SCUtilities removeBlockFromSettings: settings_];
//            [settings_ synchronizeSettings];
//
//			NSError* err = [self errorFromHelperToolStatusCode: exitCode];
//
//			[NSApp performSelectorOnMainThread: @selector(presentError:)
//									withObject: err
//								 waitUntilDone: YES];
//		}
//
//		self.addingBlock = false;
//		[self refreshUserInterface];
	}
}

- (void)refreshBlock:(NSLock*)lockToUse {
	if(![lockToUse tryLock]) {
		return;
	}

	@autoreleasepool {
		AuthorizationRef authorizationRef;
		char* helperToolPath = [self selfControlHelperToolPathUTF8String];
		long helperToolPathSize = strlen(helperToolPath);
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
			NSLog(@"ERROR: Failed to authorize block refresh.");

			// Reverse the blocklist change made before we fail
			NSMutableArray* list = [[settings_ valueForKey: @"Blocklist"] mutableCopy];
			[list removeLastObject];
			[settings_ setValue: list forKey: @"Blocklist"];

			[lockToUse unlock];

			return;
		}
        
        // we're about to launch a helper tool which will read settings, so make sure the ones on disk are valid
        [settings_ synchronizeSettings];

		// We need to pass our UID to the helper tool.  It needs to know whose defaults
		// it should read in order to properly load the blocklist.
		char uidString[32];
		snprintf(uidString, sizeof(uidString), "%d", getuid());

		FILE* commPipe;

		char* args[] = { uidString, "--refresh", NULL };
		status = AuthorizationExecuteWithPrivileges(authorizationRef,
													helperToolPath,
													kAuthorizationFlagDefaults,
													args,
													&commPipe);

		if(status) {
			NSLog(@"WARNING: Authorized execution of helper tool returned failure status code %d", (int)status);

			NSError* err = [self errorFromHelperToolStatusCode: status];

			[NSApp performSelectorOnMainThread: @selector(presentError:)
									withObject: err
								 waitUntilDone: YES];

			[lockToUse unlock];

			return;
		}

		NSFileHandle* helperToolHandle = [[NSFileHandle alloc] initWithFileDescriptor: fileno(commPipe) closeOnDealloc: YES];

		NSData* inData = [helperToolHandle readDataToEndOfFile];
		NSString* inDataString = [[NSString alloc] initWithData: inData encoding: NSUTF8StringEncoding];

		if([inDataString isEqualToString: @""]) {
			NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain
											   code: -105
										   userInfo: @{NSLocalizedDescriptionKey: @"Error -105: The helper tool crashed.  This may cause unexpected errors."}];

			[NSApp performSelectorOnMainThread: @selector(presentError:)
									withObject: err
								 waitUntilDone: YES];
		}

		int exitCode = [inDataString intValue];

		if(exitCode) {
			NSError* err = [self errorFromHelperToolStatusCode: exitCode];

			[NSApp performSelectorOnMainThread: @selector(presentError:)
									withObject: err
								 waitUntilDone: YES];
		}

        [timerWindowController_ performSelectorOnMainThread:@selector(closeAddSheet:) withObject: self waitUntilDone: YES];
	}
	[lockToUse unlock];
}

// it really sucks, but we can't change any values that are KVO-bound to the UI unless they're on the main thread
// to make that easier, here is a helper that always does it on the main thread
- (void)setDefaultsBlockDurationOnMainThread:(NSNumber*)newBlockDuration {
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread: @selector(setDefaultsBlockDurationOnMainThread:) withObject:newBlockDuration waitUntilDone: YES];
    }

    [defaults_ setInteger: [newBlockDuration intValue] forKey: @"BlockDuration"];
    [defaults_ synchronize];
}

- (void)extendBlockDuration:(NSDictionary*)options {
    NSInteger minutesToAdd = [options[@"minutesToAdd"] integerValue];
    minutesToAdd = MAX(minutesToAdd, 0); // make sure there's no funny business with negative minutes
    
    NSDate* oldBlockEndDate = [settings_ valueForKey: @"BlockEndDate"];
    NSDate* newBlockEndDate = [oldBlockEndDate dateByAddingTimeInterval: (minutesToAdd * 60)];
    
    // Before we try to extend the block, make sure the block time didn't run out (or is about to run out) in the meantime
    if (![SCUtilities blockShouldBeRunningInDictionary: settings_.dictionaryRepresentation] || [oldBlockEndDate timeIntervalSinceNow] < 1) {
        // we're done, or will be by the time we get to it! so just let it expire. they can restart it.
        return;
    }

    // set the new block end date
    [settings_ setValue: newBlockEndDate forKey: @"BlockEndDate"];
    
    // synchronize it to disk to the helper tool knows immediately
    [settings_ synchronizeSettings];
    
    // let the timer know it needs to recalculate
    [timerWindowController_ performSelectorOnMainThread:@selector(blockEndDateUpdated)
                                             withObject: nil
                                          waitUntilDone: YES];
}

- (IBAction)save:(id)sender {
	NSSavePanel *sp;
	long runResult;

	/* create or get the shared instance of NSSavePanel */
	sp = [NSSavePanel savePanel];
	sp.allowedFileTypes = @[@"selfcontrol"];

	/* display the NSSavePanel */
	runResult = [sp runModal];

	/* if successful, save file under designated name */
	if (runResult == NSOKButton) {
        NSString* errDescription;
        [SCUtilities writeBlocklistToFileURL: sp.URL settings: settings_ errorDescription: &errDescription];

        if(errDescription) {
			NSError* displayErr = [NSError errorWithDomain: kSelfControlErrorDomain code: -902 userInfo: @{NSLocalizedDescriptionKey: [@"Error 902: " stringByAppendingString: errDescription]}];
            NSBeep();
			[NSApp presentError: displayErr];
			return;
		}
	}
}

- (IBAction)open:(id)sender {
	NSOpenPanel* oPanel = [NSOpenPanel openPanel];
	oPanel.allowedFileTypes = @[@"selfcontrol"];
	oPanel.allowsMultipleSelection = NO;

	long result = [oPanel runModal];
	if (result == NSOKButton) {
		if([oPanel.URLs count] > 0) {
            [SCUtilities readBlocklistFromFile: oPanel.URLs[0] toSettings: settings_];

            // close the domain list (and reopen again if need be to refresh)
            BOOL domainListIsOpen = [[domainListWindowController_ window] isVisible];
			NSRect frame = [[domainListWindowController_ window] frame];
			[self closeDomainList];
			if(domainListIsOpen) {
				[self showDomainList: self];
				[[domainListWindowController_ window] setFrame: frame display: YES];
			}
            
            [self refreshUserInterface];
		}
	}
}

- (BOOL)application:(NSApplication*)theApplication openFile:(NSString*)filename {
	NSDictionary* openedDict = [NSDictionary dictionaryWithContentsOfFile: filename];
	if(openedDict == nil) return NO;

	NSArray* newBlocklist = openedDict[@"HostBlacklist"];
	NSNumber* newAllowlistChoice = openedDict[@"BlockAsWhitelist"];
	if(newBlocklist == nil || newAllowlistChoice == nil) return NO;
    
	[settings_ setValue: newBlocklist forKey: @"Blocklist"];
    [settings_ setValue: newAllowlistChoice forKey: @"BlockAsWhitelist"];
    
	BOOL domainListIsOpen = [[domainListWindowController_ window] isVisible];
	NSRect frame = [[domainListWindowController_ window] frame];
	[self closeDomainList];
	if(domainListIsOpen) {
		[self showDomainList: self];
		[[domainListWindowController_ window] setFrame: frame display: YES];
	}

	return YES;
}

- (IBAction)openFAQ:(id)sender {
	NSURL *url=[NSURL URLWithString: @"https://github.com/SelfControlApp/selfcontrol/wiki/FAQ#q-selfcontrols-timer-is-at-0000-and-i-cant-start-a-new-block-and-im-freaking-out"];
	[[NSWorkspace sharedWorkspace] openURL: url];
}

@end
