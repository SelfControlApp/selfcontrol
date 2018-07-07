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

NSString* const kSelfControlErrorDomain = @"SelfControlErrorDomain";

@implementation AppController {
	NSWindowController* getStartedWindowController;
}

@synthesize addingBlock;

- (AppController*) init {
	if(self = [super init]) {

		defaults_ = [NSUserDefaults standardUserDefaults];

		NSDictionary* appDefaults = @{@"BlockDuration": @15,
									  @"BlockStartedDate": [NSDate distantFuture],
                                      @"BlockEndDate": [NSDate distantPast],
									  @"HostBlacklist": @[],
									  @"EvaluateCommonSubdomains": @YES,
									  @"IncludeLinkedDomains": @YES,
									  @"HighlightInvalidHosts": @YES,
									  @"VerifyInternetConnection": @YES,
									  @"TimerWindowFloats": @NO,
									  @"BlockSoundShouldPlay": @NO,
									  @"BlockSound": @5,
									  @"ClearCaches": @YES,
									  @"BlockAsWhitelist": @NO,
									  @"BadgeApplicationIcon": @YES,
									  @"AllowLocalNetworks": @YES,
									  @"MaxBlockLength": @1440,
									  @"BlockLengthInterval": @15,
									  @"WhitelistAlertSuppress": @NO,
									  @"GetStartedShown": @NO};

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
		path = [thisBundle pathForAuxiliaryExecutable: @"org.eyebeam.SelfControl"];
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
	NSInteger numMinutes = floor([blockDurationSlider_ integerValue]);

	// Time-display code cleaned up thanks to the contributions of many users

	NSString* timeString = [self timeSliderDisplayStringFromNumberOfMinutes:numMinutes];

	[blockSliderTimeDisplayLabel_ setStringValue:timeString];
	[submitButton_ setEnabled: (numMinutes > 0) && ([[defaults_ arrayForKey:@"HostBlacklist"] count] > 0)];
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
    if ([SCUtilities blockIsActiveInDefaults: defaults_]) {
		// This method shouldn't be getting called, a block is on so the Start button should be disabled.
		NSError* err = [NSError errorWithDomain:kSelfControlErrorDomain
										   code: -102
									   userInfo: @{NSLocalizedDescriptionKey: @"We can't start a block, because one is currently ongoing."}];
		[NSApp presentError: err];
		return;
	}
	if([[defaults_ arrayForKey:@"HostBlacklist"] count] == 0) {
		// Since the Start button should be disabled when the blacklist has no entries,
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
	blockIsOn = [self selfControlLaunchDaemonIsLoaded];

	if(blockIsOn) { // block is on
		if(!blockWasOn) { // if we just switched states to on...
			[self closeTimerWindow];
			[self showTimerWindow];
			[initialWindow_ close];
			[self closeDomainList];
		}
	} else { // block is off
		if(blockWasOn) { // if we just switched states to off...
			[timerWindowController_ blockEnded];

			// Makes sure the domain list will refresh when it comes back
			[self closeDomainList];

			NSWindow* mainWindow = [NSApp mainWindow];
			// We don't necessarily want the initial window to be key and front,
			// but no other message seems to show it properly.
			[initialWindow_ makeKeyAndOrderFront: self];
			// So we work around it and make key and front whatever was the main window
			[mainWindow makeKeyAndOrderFront: self];

			[self closeTimerWindow];
		}

		[defaults_ synchronize];

		[self updateTimeSliderDisplay: blockDurationSlider_];

		BOOL addBlockIsOngoing = self.addingBlock;

		if([blockDurationSlider_ intValue] != 0 && [[defaults_ objectForKey: @"HostBlacklist"] count] != 0 && !addBlockIsOngoing) {
			[submitButton_ setEnabled: YES];
		} else {
			[submitButton_ setEnabled: NO];
		}

		// If we're adding a block, we want buttons disabled.
		if(!addBlockIsOngoing) {
			[blockDurationSlider_ setEnabled: YES];
			[editBlacklistButton_ setEnabled: YES];
			[submitButton_ setTitle: NSLocalizedString(@"Start", @"Start button")];
		} else {
			[blockDurationSlider_ setEnabled: NO];
			[editBlacklistButton_ setEnabled: NO];
			[submitButton_ setTitle: NSLocalizedString(@"Loading", @"Loading button")];
		}

		// if block's off, and we haven't shown it yet, show the first-time modal
		if (![defaults_ boolForKey: @"GetStartedShown"]) {
			[defaults_ setBool: YES forKey: @"GetStartedShown"];
			[defaults_ synchronize];
			[self showGetStartedWindow: self];
		}
	}
	[refreshUILock_ unlock];
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
    PFMoveToApplicationsFolderIfNecessary();
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[NSApplication sharedApplication].delegate = self;

	// Register observers on both distributed and normal notification centers
	// to receive notifications from the helper tool and the other parts of the
	// main SelfControl app.  Note that they are divided thusly because distributed
	// notifications are very expensive and should be minimized.
	[[NSDistributedNotificationCenter defaultCenter] addObserver: self
														selector: @selector(refreshUserInterface)
															name: @"SCConfigurationChangedNotification"
														  object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(refreshUserInterface)
												 name: @"SCConfigurationChangedNotification"
											   object: nil];

	[initialWindow_ center];

	// We'll set blockIsOn to whatever is NOT right, so that in refreshUserInterface
	// it'll fix it and properly refresh the user interface.
	blockIsOn = ![self selfControlLaunchDaemonIsLoaded];

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

- (BOOL)selfControlLaunchDaemonIsLoaded {
	// First we check the host file, and see if a block is in there
	NSString* hostFileContents = [NSString stringWithContentsOfFile: @"/etc/hosts" encoding: NSUTF8StringEncoding error: NULL];
	if(hostFileContents != nil && [hostFileContents rangeOfString: @"# BEGIN SELFCONTROL BLOCK"].location != NSNotFound) {
		return YES;
	}

	[defaults_ synchronize];
    if ([SCUtilities blockIsEnabledInDefaults: defaults_]) {
		return YES;
	}

	// If there's no block in the hosts file, no block in the defaults, and no lock-file,
	// we'll assume we're clear of blocks.  Checking pf would be nice but usually requires
	// root permissions, so it would be difficult to do here.
	return [[NSFileManager defaultManager] fileExistsAtPath: SelfControlLockFilePath];
}

- (IBAction)showDomainList:(id)sender {
	BOOL addBlockIsOngoing = self.addingBlock;
	if([self selfControlLaunchDaemonIsLoaded] || addBlockIsOngoing) {
		NSAlert* blockInProgressAlert = [[NSAlert alloc] init];
		[blockInProgressAlert setMessageText: NSLocalizedString(@"Block in progress", @"Block in progress error title")];
		[blockInProgressAlert setInformativeText:NSLocalizedString(@"The blacklist cannot be edited while a block is in progress.", @"Block in progress explanation")];
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
	if(host == nil)
		return;

	host = [[host stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];

	// Remove "http://" if a user tried to put that in
	NSArray* splitString = [host componentsSeparatedByString: @"http://"];
	for(int i = 0; i < [splitString count]; i++) {
		if(![splitString[i] isEqual: @""]) {
			host = splitString[i];
			break;
		}
	}

	// Delete anything after a "/" in case a user tried to copy-paste a web address.
	host = [host componentsSeparatedByString: @"/"][0];

	if([host isEqualToString: @""])
		return;

	NSMutableArray* list = [[defaults_ arrayForKey: @"HostBlacklist"] mutableCopy];
	[list addObject: host];
	[defaults_ setObject: list forKey: @"HostBlacklist"];
	[defaults_ synchronize];

	if(![SCUtilities blockIsEnabledInDefaults: defaults_]) {
		// This method shouldn't be getting called, a block is not on (block started
		// is in the distantFuture) so the Start button should be disabled.
		// Maybe the UI didn't get properly refreshed, so try refreshing it again
		// before we return.
		[self refreshUserInterface];

		// Reverse the blacklist change made before we fail
		NSMutableArray* list = [[defaults_ arrayForKey: @"HostBlacklist"] mutableCopy];
		[list removeLastObject];
		[defaults_ setObject: list forKey: @"HostBlacklist"];

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
			// Reverse the blacklist change made before we fail
			NSMutableArray* list = [[defaults_ arrayForKey: @"HostBlacklist"] mutableCopy];
			[list removeLastObject];
			[defaults_ setObject: list forKey: @"HostBlacklist"];

			return;
		}

		// If the user selected Network Diagnostics, launch an assisant to help them.
		// apple.com is an arbitrary host chosen to pass to Network Diagnostics.
		CFURLRef url = CFURLCreateWithString(NULL, CFSTR("http://apple.com"), NULL);
		CFNetDiagnosticRef diagRef = CFNetDiagnosticCreateWithURL(kCFAllocatorDefault, url);
		CFNetDiagnosticDiagnoseProblemInteractively(diagRef);

		// Reverse the blacklist change made before we fail
		NSMutableArray* list = [[defaults_ arrayForKey: @"HostBlacklist"] mutableCopy];
		[list removeLastObject];
		[defaults_ setObject: list forKey: @"HostBlacklist"];

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
    if(![SCUtilities blockIsEnabledInDefaults: defaults_]) {
        // This method shouldn't be getting called, a block is not on (block started
        // is in the distantFuture) so the Start button should be disabled.
        // Maybe the UI didn't get properly refreshed, so try refreshing it again
        // before we return.
        [self refreshUserInterface];
        
        NSError* err = [NSError errorWithDomain:kSelfControlErrorDomain
                                           code: -103
                                       userInfo: @{NSLocalizedDescriptionKey: @"Error -103: Attempting to add host to block, but no block appears to be in progress."}];
        
        [NSApp presentError: err];
        
        return;
    }
    
    NSInteger currentBlockDuration = [defaults_ integerForKey: @"BlockDuration"];
    NSInteger newBlockDuration = MIN(currentBlockDuration + minutesToAdd, 0); // make sure we don't do something freaky if BlockDuration is negative for some reason
        
    [NSThread detachNewThreadSelector: @selector(setBlockDuration:)
                             toTarget: self
                           withObject: @{
                                         @"lock": lock,
                                         @"duration": @(newBlockDuration)
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
			[description appendString: @"Refreshing domain blacklist, but no block is currently ongoing."];
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
		char* helperToolPath = [self selfControlHelperToolPathUTF8String];
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
			NSLog(@"ERROR: Failed to authorize block start.");
			self.addingBlock = false;
			[self refreshUserInterface];
			return;
		}

        [SCUtilities startBlockInDefaults: defaults_];

		// We need to pass our UID to the helper tool.  It needs to know whose defaults
		// it should reading in order to properly load the blacklist.
		char uidString[32];
		snprintf(uidString, sizeof(uidString), "%d", getuid());

		FILE* commPipe;

		char* args[] = { uidString, "--install", NULL };
		status = AuthorizationExecuteWithPrivileges(authorizationRef,
													helperToolPath,
													kAuthorizationFlagDefaults,
													args,
													&commPipe);

		if(status) {
			NSLog(@"WARNING: Authorized execution of helper tool returned failure status code %d", (int)status);

			// reset defaults on failure
            [SCUtilities removeBlockFromDefaults: defaults_];

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

		NSFileHandle* helperToolHandle = [[NSFileHandle alloc] initWithFileDescriptor: fileno(commPipe) closeOnDealloc: YES];

		NSData* inData = [helperToolHandle readDataToEndOfFile];


		NSString* inDataString = [[NSString alloc] initWithData: inData encoding: NSUTF8StringEncoding];

		if([inDataString isEqualToString: @""]) {
            // reset defaults on failure
            [SCUtilities removeBlockFromDefaults: defaults_];

			NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain
											   code: -104
										   userInfo: @{NSLocalizedDescriptionKey: @"Error -104: The helper tool crashed.  This may cause unexpected errors."}];

			[NSApp performSelectorOnMainThread: @selector(presentError:)
									withObject: err
								 waitUntilDone: YES];
		}

		int exitCode = [inDataString intValue];

		if(exitCode) {
            // reset defaults on failure
            [SCUtilities removeBlockFromDefaults: defaults_];

			NSError* err = [self errorFromHelperToolStatusCode: exitCode];

			[NSApp performSelectorOnMainThread: @selector(presentError:)
									withObject: err
								 waitUntilDone: YES];
		}

		self.addingBlock = false;
		[self refreshUserInterface];
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

			// Reverse the blacklist change made before we fail
			NSMutableArray* list = [[defaults_ arrayForKey: @"HostBlacklist"] mutableCopy];
			[list removeLastObject];
			[defaults_ setObject: list forKey: @"HostBlacklist"];

			[lockToUse unlock];

			return;
		}

		// We need to pass our UID to the helper tool.  It needs to know whose defaults
		// it should read in order to properly load the blacklist.
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

		[timerWindowController_ closeAddSheet: self];
	}
	[lockToUse unlock];
}

- (void)setBlockDuration:(NSDictionary*)options {
    NSLock* lock = options[@"lock"];
    NSInteger newDuration = [options[@"duration"] integerValue];
    if(![lock tryLock]) {
        return;
    }
    
    NSInteger oldDuration = [defaults_ integerForKey: @"BlockDuration"];
    NSDate* oldBlockEndDate = [SCUtilities blockEndDateInDefaults: defaults_];

    [defaults_ setInteger: newDuration forKey: @"BlockDuration"];
    [defaults_ synchronize];

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
            NSLog(@"ERROR: Failed to authorize setting new block duration.");
            
            // Reverse the block duration change made before we fail
            [defaults_ setInteger: oldDuration forKey: @"BlockDuration"];
            
            [lock unlock];
            
            return;
        }
        
        // We need to pass our UID to the helper tool.  It needs to know whose defaults
        // it should read in order to properly load the blacklist.
        char uidString[32];
        snprintf(uidString, sizeof(uidString), "%d", getuid());
        
        FILE* commPipe;
        
        char* args[] = { uidString, "--rewrite-lock-file", NULL };
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
            
            [lock unlock];
            
            return;
        }
        
        // Before we try to fix the block in the helper tool, make sure the block time didn't run out in the meantime
        // (note that the AuthorizationExecuteWithPrivileges blocks on user input, so we can't check the time left earlier in this function)
        // Block is finished if it's unset in the defaults, OR if it's only a second left until we'll do that (allow some buffer for the helper tool)
        if ([SCUtilities blockIsActiveInDefaults: defaults_] || [oldBlockEndDate timeIntervalSinceNow] < 1) {
            // we're done, or will be by the time we get to it! so just let it expire. they can restart it.
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
        
        [timerWindowController_ performSelectorOnMainThread:@selector(blockDurationUpdated)
                                                 withObject: nil
                                              waitUntilDone: YES];
    }
    [lock unlock];
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
		[defaults_ synchronize];
		NSString* err;
		NSDictionary* saveDict = @{@"HostBlacklist": [defaults_ objectForKey: @"HostBlacklist"],
								   @"BlockAsWhitelist": [defaults_ objectForKey: @"BlockAsWhitelist"]};
		NSData* saveData = [NSPropertyListSerialization dataFromPropertyList: saveDict format: NSPropertyListBinaryFormat_v1_0 errorDescription: &err];
		if(err) {
			NSError* displayErr = [NSError errorWithDomain: kSelfControlErrorDomain code: -902 userInfo: @{NSLocalizedDescriptionKey: [@"Error 902: " stringByAppendingString: err]}];
			[NSApp presentError: displayErr];
			return;
		}
		if (![saveData writeToURL: sp.URL atomically: YES]) {
			NSBeep();
		} else {
			NSDictionary* attribs = @{NSFileExtensionHidden: @YES};
			[[NSFileManager defaultManager] setAttributes: attribs ofItemAtPath: [sp.URL path] error: NULL];
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
			NSDictionary* openedDict = [NSDictionary dictionaryWithContentsOfURL: oPanel.URLs[0]];
			[defaults_ setObject: openedDict[@"HostBlacklist"] forKey: @"HostBlacklist"];
			[defaults_ setObject: openedDict[@"BlockAsWhitelist"] forKey: @"BlockAsWhitelist"];
			BOOL domainListIsOpen = [[domainListWindowController_ window] isVisible];
			NSRect frame = [[domainListWindowController_ window] frame];
			[self closeDomainList];
			if(domainListIsOpen) {
				[self showDomainList: self];
				[[domainListWindowController_ window] setFrame: frame display: YES];
			}
		}
	}
}

- (BOOL)application:(NSApplication*)theApplication openFile:(NSString*)filename {
	NSDictionary* openedDict = [NSDictionary dictionaryWithContentsOfFile: filename];
	if(openedDict == nil) return NO;
	NSArray* newBlocklist = openedDict[@"HostBlacklist"];
	NSNumber* newWhitelistChoice = openedDict[@"BlockAsWhitelist"];
	if(newBlocklist == nil || newWhitelistChoice == nil) return NO;
	[defaults_ setObject: newBlocklist forKey: @"HostBlacklist"];
	[defaults_ setObject: newWhitelistChoice forKey: @"BlockAsWhitelist"];
	BOOL domainListIsOpen = [[domainListWindowController_ window] isVisible];
	NSRect frame = [[domainListWindowController_ window] frame];
	[self closeDomainList];
	if(domainListIsOpen) {
		[self showDomainList: self];
		[[domainListWindowController_ window] setFrame: frame display: YES];
	}

	return YES;
}

- (int)blockLength {
	return [blockDurationSlider_ intValue];
}

- (void)setBlockLength:(int)blockLength {
	[blockDurationSlider_ setIntValue: blockLength];
	[self updateTimeSliderDisplay: blockDurationSlider_];
}

- (IBAction)openFAQ:(id)sender {
	NSURL *url=[NSURL URLWithString: @"https://github.com/SelfControlApp/selfcontrol/wiki/FAQ#q-selfcontrols-timer-is-at-0000-and-i-cant-start-a-new-block-and-im-freaking-out"];
	[[NSWorkspace sharedWorkspace] openURL: url];
}

- (void)switchedToWhitelist:(id)sender {
	if(![defaults_ boolForKey: @"WhitelistAlertSuppress"]) {
		NSAlert* a = [NSAlert alertWithMessageText: NSLocalizedString(@"Are you sure you want a whitelist block?", @"Whitelist block confirmation prompt") defaultButton: NSLocalizedString(@"OK", @"OK button") alternateButton: @"" otherButton: @"" informativeTextWithFormat: NSLocalizedString(@"A whitelist block means that everything on the internet BESIDES your specified list will be blocked.  This includes the web, email, SSH, and anything else your computer accesses via the internet.  If a web site requires resources such as images or scripts from a site that is not on your whitelist, the site may not work properly.", @"Whitelist block explanation")];
		if([a respondsToSelector: @selector(setShowsSuppressionButton:)]) {
			[a setShowsSuppressionButton: YES];
		}
		[a runModal];
		if([a respondsToSelector: @selector(suppressionButton)] && [[a suppressionButton] state] == NSOnState) {
			[defaults_ setBool: YES forKey: @"WhitelistAlertSuppress"];
		}
	}
}

@end
