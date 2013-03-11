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

NSString* const kSelfControlErrorDomain = @"SelfControlErrorDomain";

@implementation AppController

@synthesize addingBlock;

- (AppController*) init {
  if(self = [super init]) {
  
    defaults_ = [NSUserDefaults standardUserDefaults];
    
    NSDictionary* appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithInt: 0], @"BlockDuration",
                                 [NSDate distantFuture], @"BlockStartedDate",
                                 [NSArray array], @"HostBlacklist", 
                                 [NSNumber numberWithBool: YES], @"EvaluateCommonSubdomains",
                                 [NSNumber numberWithBool: YES], @"HighlightInvalidHosts",
                                 [NSNumber numberWithBool: YES], @"VerifyInternetConnection",
                                 [NSNumber numberWithBool: NO], @"TimerWindowFloats",
                                 [NSNumber numberWithBool: NO], @"BlockSoundShouldPlay",
                                 [NSNumber numberWithInt: 5], @"BlockSound",
                                 [NSNumber numberWithBool: YES], @"ClearCaches",
                                 [NSNumber numberWithBool: NO], @"BlockAsWhitelist",
                                 [NSNumber numberWithBool: YES], @"BadgeApplicationIcon",
                                 [NSNumber numberWithBool: YES], @"AllowLocalNetworks",
                                 [NSNumber numberWithInt: 1440], @"MaxBlockLength",
                                 [NSNumber numberWithInt: 15], @"BlockLengthInterval",
                                 [NSNumber numberWithBool: NO], @"WhitelistAlertSuppress",
                                 nil];
    
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
  int numMinutes = floor([blockDurationSlider_ intValue]);
    
  // Time-display code cleaned up thanks to the contributions of many users
  
  NSString* timeString = @"";

  int formatDays, formatHours, formatMinutes;
  
  formatDays = numMinutes / 1440;
  formatHours = (numMinutes % 1440) / 60;
  formatMinutes = (numMinutes % 60);
  
  if(numMinutes > 0) {
    if(formatDays > 0) {
      timeString = [NSString stringWithFormat:@"%d %@", formatDays, (formatDays == 1 ? NSLocalizedString(@"day", @"Single day time string") : NSLocalizedString(@"days", @"Plural days time string"))];
    }
    if(formatHours > 0) {
      timeString = [NSString stringWithFormat: @"%@%@%d %@", timeString, (formatDays > 0 ? @", " : @""), formatHours, (formatHours == 1 ? NSLocalizedString(@"hour", @"Single hour time string") : NSLocalizedString(@"hours", @"Plural hours time string"))];
    }
    if(formatMinutes > 0) {
      timeString = [NSString stringWithFormat:@"%@%@%d %@", timeString, (formatHours > 0 || formatDays > 0 ? @", " : @""), formatMinutes, (formatMinutes == 1 ? NSLocalizedString(@"minute", @"Single minute time string") : NSLocalizedString(@"minutes", @"Plural minutes time string"))];
    }
  }
  else {
    timeString = NSLocalizedString(@"Disabled", "Shows that SelfControl is disabled");
  }
    
  [blockSliderTimeDisplayLabel_ setStringValue:timeString];
  [submitButton_ setEnabled: (numMinutes > 0) && ([[defaults_ arrayForKey:@"HostBlacklist"] count] > 0)];
}

- (IBAction)addBlock:(id)sender {
  [defaults_ synchronize];
  if(([[defaults_ objectForKey:@"BlockStartedDate"] timeIntervalSinceNow] < 0)) {
    // This method shouldn't be getting called, a block is on (block started date
    // is in the past, not distantFuture) so the Start button should be disabled.

    NSLog(@"WARNING: Block started date is in the past (%@)", [defaults_ objectForKey: @"BlockStartedDate"]);
        
  }
  if([[defaults_ arrayForKey:@"HostBlacklist"] count] == 0) {
    // Since the Start button should be disabled when the blacklist has no entries,
    // this should definitely not be happening.  Exit.
    
    NSError* err = [NSError errorWithDomain:kSelfControlErrorDomain
                                       code: -102
                                   userInfo: [NSDictionary dictionaryWithObject: @"Error -102: Attempting to add block, but no blocklist is set."
                                                                         forKey: NSLocalizedDescriptionKey]];
    
    [NSApp presentError: err];    
    
    return;
  }
    
  if([defaults_ boolForKey: @"VerifyInternetConnection"] && ![self networkConnectionIsAvailable]) {
    NSAlert* networkUnavailableAlert = [[[NSAlert alloc] init] autorelease];
    [networkUnavailableAlert setMessageText: NSLocalizedString(@"No network connection detected", "No network connection detected message")];
    [networkUnavailableAlert setInformativeText:NSLocalizedString(@"A block cannot be started without a working network connection.  You can override this setting in Preferences.", @"Message when network connection is unavailable")];
    [networkUnavailableAlert addButtonWithTitle: NSLocalizedString(@"Cancel", "Cancel button")];
    [networkUnavailableAlert addButtonWithTitle: NSLocalizedString(@"Network Diagnostics...", @"Network Diagnostics button")];
    if([networkUnavailableAlert runModal] == NSAlertFirstButtonReturn)
      return;
    
    // If the user selected Network Diagnostics launch an assisant to help them.
    // apple.com is an arbitrary host chosen to pass to Network Diagnostics.
    CFURLRef url = CFURLCreateWithString(NULL, CFSTR("http://apple.com"), NULL);
    CFNetDiagnosticRef diagRef = CFNetDiagnosticCreateWithURL(NULL, url);
    CFNetDiagnosticDiagnoseProblemInteractively(diagRef);
    return;
  }
  
  [timerWindowController_ resetStrikes];
  
  [NSThread detachNewThreadSelector: @selector(installBlock) toTarget: self withObject: nil];
}

- (void)refreshUserInterface {
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
    
    if([blockDurationSlider_ intValue] != 0 && [[defaults_ objectForKey: @"HostBlacklist"] count] != 0 && !addBlockIsOngoing)
      [submitButton_ setEnabled: YES];
    else
      [submitButton_ setEnabled: NO];
    
    // If we're adding a block, we want buttons disabled.
    if(!addBlockIsOngoing) {
      [blockDurationSlider_ setEnabled: YES];
      [editBlacklistButton_ setEnabled: YES];
      [submitButton_ setTitle: NSLocalizedString(@"Start", @"Start button")];
    }
    else {
      [blockDurationSlider_ setEnabled: NO];
      [editBlacklistButton_ setEnabled: NO];
      [submitButton_ setTitle: NSLocalizedString(@"Loading", @"Loading button")];
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
  [timerWindowController_ release];
  timerWindowController_ = nil;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [NSApp setDelegate: self];
  
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
  int numTickMarks = ([defaults_ integerForKey: @"MaxBlockLength"] / [defaults_ integerForKey: @"BlockLengthInterval"]) + 1;
  [blockDurationSlider_ setMaxValue: [defaults_ integerForKey: @"MaxBlockLength"]];
  [blockDurationSlider_ setNumberOfTickMarks: numTickMarks];
  
  [self refreshUserInterface];                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         
}

- (BOOL)selfControlLaunchDaemonIsLoaded {
  // First we check the host file, and see if a block is in there
  NSString* hostFileContents = [NSString stringWithContentsOfFile: @"/etc/hosts" encoding: NSUTF8StringEncoding error: NULL];
  if(hostFileContents != nil && [hostFileContents rangeOfString: @"# BEGIN SELFCONTROL BLOCK"].location != NSNotFound) {
    return YES;
  }
  
  [defaults_ synchronize];
  NSDate* blockStartedDate = [defaults_ objectForKey: @"BlockStartedDate"];
    
  // NSDate* blockStartedDate = [defaults_ objectForKey: @"BlockStartedDate"];
  if(blockStartedDate != nil && ![blockStartedDate isEqualToDate: [NSDate distantFuture]]) {
    return YES;
  }
  
  // If there's no block in the hosts file, no defaults BlockStartedDate, and no lock-file,
  // we'll assume we're clear of blocks.  Checking ipfw would be nice but usually requires 
  // root permissions, so it would be difficult to do here.
  return [[NSFileManager defaultManager] fileExistsAtPath: SelfControlLockFilePath];
}

- (IBAction)showDomainList:(id)sender {
  BOOL addBlockIsOngoing = self.addingBlock;
  if([self selfControlLaunchDaemonIsLoaded] || addBlockIsOngoing) {
    NSAlert* blockInProgressAlert = [[[NSAlert alloc] init] autorelease];
    [blockInProgressAlert setMessageText: NSLocalizedString(@"Block in progress", @"Block in progress error title")];
    [blockInProgressAlert setInformativeText:NSLocalizedString(@"The blacklist cannot be edited while a block is in progress.", @"Block in progress explanation")];
    [blockInProgressAlert addButtonWithTitle: NSLocalizedString(@"OK", @"OK button")];
    [blockInProgressAlert runModal];
        
    return;
  }
  
  if(domainListWindowController_ == nil)
    [NSBundle loadNibNamed: @"DomainList" owner: self];
  else
    [[domainListWindowController_ window] makeKeyAndOrderFront: self];
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
  return YES;
}

- (BOOL)networkConnectionIsAvailable {
  SCNetworkConnectionFlags status; 
  
  // This method goes haywire if Google ever goes down...
  BOOL reachable = SCNetworkCheckReachabilityByName ("google.com", &status);
  
  return reachable && (status & kSCNetworkFlagsReachable) && !(status & kSCNetworkFlagsConnectionRequired);
}

- (IBAction)soundSelectionChanged:(id)sender {
  // Map the tags used in interface builder to the sound
  NSArray* systemSoundNames = [NSArray arrayWithObjects:
                               @"Basso",
                               @"Blow",
                               @"Bottle",
                               @"Frog",
                               @"Funk",
                               @"Glass",
                               @"Hero",
                               @"Morse",
                               @"Ping",
                               @"Pop",
                               @"Purr",
                               @"Sosumi",
                               @"Submarine",
                               @"Tink",
                               nil
                               ];
  NSSound* alertSound = [NSSound soundNamed: [systemSoundNames objectAtIndex: [defaults_ integerForKey: @"BlockSound"]]];
  if(!alertSound) {
    NSLog(@"WARNING: Alert sound not found.");
    
    NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain
                                       code: -901
                                   userInfo: [NSDictionary dictionaryWithObject: @"Error -901: Selected sound not found."
                                                                         forKey: NSLocalizedDescriptionKey]];
    
    [NSApp presentError: err];

  }
  else
    [alertSound play];
}

- (void)addToBlockList:(NSString*)host lock:(NSLock*)lock {  
  if(host == nil)
    return;
  
  host = [[host stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
  
  // Remove "http://" if a user tried to put that in
  NSArray* splitString = [host componentsSeparatedByString: @"http://"];
  for(int i = 0; i < [splitString count]; i++) {
    if(![[splitString objectAtIndex: i] isEqual: @""]) {
      host = [splitString objectAtIndex: i];
      break;
    }
  }
  
  // Delete anything after a "/" in case a user tried to copy-paste a web address.
  host = [[host componentsSeparatedByString: @"/"] objectAtIndex: 0];

  if([host isEqualToString: @""])
    return;
  
  NSMutableArray* list = [[[defaults_ arrayForKey: @"HostBlacklist"] mutableCopy] autorelease];
  [list addObject: host];
  [defaults_ setObject: list forKey: @"HostBlacklist"];
  [defaults_ synchronize];
  
  if(([[defaults_ objectForKey:@"BlockStartedDate"] isEqualToDate: [NSDate distantFuture]])) {
    // This method shouldn't be getting called, a block is not on (block started
    // is in the distantFuture) so the Start button should be disabled.
    // Maybe the UI didn't get properly refreshed, so try refreshing it again
    // before we return.
    [self refreshUserInterface];
    
    // Reverse the blacklist change made before we fail
    NSMutableArray* list = [[[defaults_ arrayForKey: @"HostBlacklist"] mutableCopy] autorelease];
    [list removeLastObject];
    [defaults_ setObject: list forKey: @"HostBlacklist"];
    
    NSError* err = [NSError errorWithDomain:kSelfControlErrorDomain
                                       code: -103
                                   userInfo: [NSDictionary dictionaryWithObject: @"Error -103: Attempting to add host to block, but no block appears to be in progress."
                                                                         forKey: NSLocalizedDescriptionKey]];
    
    [NSApp presentError: err];    
    
    return;
  }
  
  if([defaults_ boolForKey: @"VerifyInternetConnection"] && ![self networkConnectionIsAvailable]) {
    NSAlert* networkUnavailableAlert = [[[NSAlert alloc] init] autorelease];
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
    CFNetDiagnosticRef diagRef = CFNetDiagnosticCreateWithURL(NULL, url);
    CFNetDiagnosticDiagnoseProblemInteractively(diagRef);
    
    // Reverse the blacklist change made before we fail
    NSMutableArray* list = [[defaults_ arrayForKey: @"HostBlacklist"] mutableCopy];
    [list removeLastObject];
    [defaults_ setObject: list forKey: @"HostBlacklist"];    
    
    return;
  }
    
  [NSThread detachNewThreadSelector: @selector(refreshBlock:) toTarget: self withObject: lock];
}

- (void)dealloc {
  [timerWindowController_ release];
  
  [[NSNotificationCenter defaultCenter] removeObserver: self
                                                  name: @"SCConfigurationChangedNotification"
                                                object: nil];
  [[NSDistributedNotificationCenter defaultCenter] removeObserver: self
                                                             name: @"SCConfigurationChangedNotification"
                                                           object: nil];  
  
  [super dealloc];
}

// @synthesize initialWindow = initialWindow_;
- (id)initialWindow {
  return initialWindow_;
}

- (id)domainListWindowController {
  return domainListWindowController_;
}

- (void)setDomainListWindowController:(id)newController {
  [newController retain];
  [domainListWindowController_ release];
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
    
  return [NSError errorWithDomain: domain code: status userInfo: [NSDictionary dictionaryWithObject: description
                                                                                                     forKey: NSLocalizedDescriptionKey]];
}

- (void)installBlock {
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  self.addingBlock = true;
  [self refreshUserInterface];
  AuthorizationRef authorizationRef;
  char* helperToolPath = [self selfControlHelperToolPathUTF8String];
  int helperToolPathSize = strlen(helperToolPath);
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
    NSLog(@"WARNING: Authorized execution of helper tool returned failure status code %ld", status);
    
    NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain
                                       code: status
                                   userInfo: [NSDictionary dictionaryWithObject: [NSString stringWithFormat: @"Error %ld received from the Security Server.", status]
                                                                         forKey: NSLocalizedDescriptionKey]];
    
    [NSApp performSelectorOnMainThread: @selector(presentError:)
                            withObject: err
                         waitUntilDone: YES];
    
    self.addingBlock = false;
    [self refreshUserInterface];
    
    return;
  }
  
  NSFileHandle* helperToolHandle = [[NSFileHandle alloc] initWithFileDescriptor: fileno(commPipe) closeOnDealloc: YES];
  
  NSData* inData = [helperToolHandle readDataToEndOfFile];
  
  [helperToolHandle release];
  
  NSString* inDataString = [[NSString alloc] initWithData: inData encoding: NSUTF8StringEncoding];
  
  if([inDataString isEqualToString: @""]) {
    NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain
                                       code: -104
                                   userInfo: [NSDictionary dictionaryWithObject: @"Error -104: The helper tool crashed.  This may cause unexpected errors."
                                                                         forKey: NSLocalizedDescriptionKey]];
    
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
  
  self.addingBlock = false;
  [self refreshUserInterface];
  [pool drain];
}

- (void)refreshBlock:(NSLock*)lockToUse {
  if(![lockToUse tryLock]) {
    return;
  }
  
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  AuthorizationRef authorizationRef;
  char* helperToolPath = [self selfControlHelperToolPathUTF8String];
  int helperToolPathSize = strlen(helperToolPath);
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
    NSLog(@"WARNING: Authorized execution of helper tool returned failure status code %ld", status);
    
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
                                   userInfo: [NSDictionary dictionaryWithObject: @"Error -105: The helper tool crashed.  This may cause unexpected errors."
                                                                         forKey: NSLocalizedDescriptionKey]];
    
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
  [pool drain];
  [lockToUse unlock];
}

- (IBAction)save:(id)sender {
  NSSavePanel *sp;
  int runResult;
  
  /* create or get the shared instance of NSSavePanel */
  sp = [NSSavePanel savePanel];
  
  /* set up new attributes */
  [sp setRequiredFileType: @"selfcontrol"];
  
  /* display the NSSavePanel */
  runResult = [sp runModal];
  
  /* if successful, save file under designated name */
  if (runResult == NSOKButton) {
    [defaults_ synchronize];
    NSString* err;
    NSDictionary* saveDict = [NSDictionary dictionaryWithObjectsAndKeys: [defaults_ objectForKey: @"HostBlacklist"], @"HostBlacklist",
                                                                         [defaults_ objectForKey: @"BlockAsWhitelist"], @"BlockAsWhitelist",
                                                                         nil];
    NSData* saveData = [NSPropertyListSerialization dataFromPropertyList: saveDict format: NSPropertyListBinaryFormat_v1_0 errorDescription: &err];
    if(err) {
      NSError* displayErr = [NSError errorWithDomain: kSelfControlErrorDomain code: -902 userInfo: [NSDictionary dictionaryWithObject: [@"Error 902: " stringByAppendingString: err]
                                                                                                                               forKey: NSLocalizedDescriptionKey]];
      [NSApp presentError: displayErr];
      return;
    }
    if (![saveData writeToFile:[sp filename] atomically: YES]) {
      NSBeep();
    } else {
      NSDictionary* attribs = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool: YES], NSFileExtensionHidden, nil];
      [[NSFileManager defaultManager] setAttributes: attribs ofItemAtPath: [sp filename] error: NULL];
    }
  }
}

- (IBAction)open:(id)sender {
  int result;
  NSArray *fileTypes = [NSArray arrayWithObject:@"selfcontrol"];
  NSOpenPanel *oPanel = [NSOpenPanel openPanel];
  
  [oPanel setAllowsMultipleSelection: NO];
  result = [oPanel runModalForTypes: fileTypes];
  if (result == NSOKButton) {
    NSArray *filesToOpen = [oPanel filenames];
    if([filesToOpen count] > 0) {
      NSDictionary* openedDict = [NSDictionary dictionaryWithContentsOfFile: [filesToOpen objectAtIndex: 0]];
      [defaults_ setObject: [openedDict objectForKey: @"HostBlacklist"] forKey: @"HostBlacklist"];
      [defaults_ setObject: [openedDict objectForKey: @"BlockAsWhitelist"] forKey: @"BlockAsWhitelist"];
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
  NSArray* newBlocklist = [openedDict objectForKey: @"HostBlacklist"];
  NSNumber* newWhitelistChoice = [openedDict objectForKey: @"BlockAsWhitelist"];
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
    NSURL *url=[NSURL URLWithString: @"https://github.com/slambert/selfcontrol/wiki/FAQ"];
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