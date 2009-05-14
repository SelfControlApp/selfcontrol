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

NSString* const kSelfControlLockFilePath = @"/etc/SelfControl.lock";
NSString* const kSelfControlErrorDomain = @"SelfControlErrorDomain";

@implementation AppController

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
                                 nil];
    
    [defaults_ registerDefaults:appDefaults];
    
    // blockLock_ is a lock that allows us to ensure that the user interface will
    // be locked up while we're adding a block.
    blockLock_ = [[NSLock alloc] init];
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
  int numMinutes = [blockDurationSlider_ intValue];
  
  NSString* timeString;
  
  if (numMinutes == 0) {
    timeString = [NSString stringWithString:@"Disabled"];
    [submitButton_ setEnabled: NO];
  }
  else if (numMinutes < 60) {
    timeString = [NSString stringWithFormat:@"%d minutes", numMinutes];
    if([[defaults_ arrayForKey:@"HostBlacklist"] count] != 0)
      [submitButton_ setEnabled: YES];
  }
  else if (numMinutes % 60 == 0) { 
    timeString = [NSString stringWithFormat:@"%d hours", numMinutes / 60];
    if([[defaults_ arrayForKey:@"HostBlacklist"] count] != 0)
      [submitButton_ setEnabled: YES];
  }
  else {
    timeString = [NSString stringWithFormat:@"%d hours, %d minutes",
                                            numMinutes / 60,
                                            numMinutes % 60];
    if([[defaults_ arrayForKey:@"HostBlacklist"] count] != 0)
      [submitButton_ setEnabled: YES];
  }
  [blockSliderTimeDisplayLabel_ setStringValue:timeString];
}

- (IBAction)addBlock:(id)sender {
  [defaults_ synchronize];
  if(([[defaults_ objectForKey:@"BlockStartedDate"] timeIntervalSinceNow] < 0)) {
    // This method shouldn't be getting called, a block is on (block started date
    // is in the past, not distantFuture) so the Start button should be disabled.
    // Maybe the UI didn't get properly refreshed, so try refreshing it again
    // before we return.
    [self refreshUserInterface];
    
    NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain
                                       code: -101
                                   userInfo: [NSDictionary dictionaryWithObject: @"Error -101: Attempting to add block, but a block appears to be in progress."
                                                                         forKey: NSLocalizedDescriptionKey]];
    
    [NSApp presentError: err];
    
    return;
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
    [networkUnavailableAlert setMessageText: @"No network connection detected"];
    [networkUnavailableAlert setInformativeText:@"A block cannot be started without a working network connection.  You can override this setting in Preferences."];
    [networkUnavailableAlert addButtonWithTitle: @"Cancel"];
    [networkUnavailableAlert addButtonWithTitle: @"Network Diagnostics..."];
    if([networkUnavailableAlert runModal] == NSAlertFirstButtonReturn)
      return;
    
    // If the user selected Network Diagnostics launch an assisant to help them.
    // apple.com is an arbitrary host chosen to pass to Network Diagnostics.
    CFURLRef url = CFURLCreateWithString(NULL, CFSTR("http://apple.com"), NULL);
    CFNetDiagnosticRef diagRef = CFNetDiagnosticCreateWithURL(NULL, url);
    CFNetDiagnosticDiagnoseProblemInteractively(diagRef);
    return;
  }
  
  [NSThread detachNewThreadSelector: @selector(installBlock) toTarget: self withObject: nil];
}

- (void)refreshUserInterface {
  BOOL blockIsReallyOn = [self selfControlLaunchDaemonIsLoaded];
  if(blockIsReallyOn != blockIsOn) {
    blockIsOn = blockIsReallyOn;
    if(blockIsOn) {
      [timerWindowController_ close];
      [timerWindowController_ release];
      timerWindowController_ = nil;
      [self showTimerWindow];
      [initialWindow_ close];
      [self closeDomainList];
    } else {
      [self updateTimeSliderDisplay: blockDurationSlider_];
      
      [defaults_ synchronize];
      
      // We check whether a block is currently being added by trying to lock
      // blockLock_.
      BOOL addBlockIsOngoing = ![blockLock_ tryLock];
          
      if([blockDurationSlider_ intValue] != 0 && [[defaults_ objectForKey: @"HostBlacklist"] count] != 0 && !addBlockIsOngoing)
        [submitButton_ setEnabled: YES];
      else
        [submitButton_ setEnabled: NO];
      
      // If we're adding a block, we want buttons disabled.
      if(!addBlockIsOngoing) {
        [blockDurationSlider_ setEnabled: YES];
        [editBlacklistButton_ setEnabled: YES];
        [submitButton_ setTitle: @"Start"];
      }
      else {
        [blockDurationSlider_ setEnabled: NO];
        [editBlacklistButton_ setEnabled: NO];
        [submitButton_ setTitle: @"Loading"];
      }
      
      // Unlock blockLock_ if we locked it
      if(!addBlockIsOngoing) {
        [blockLock_ unlock];
      }
      
      NSWindow* mainWindow = [NSApp mainWindow];
      // We don't necessarily want the initial window to be key and front,
      // but no other message seems to show it properly.
      [initialWindow_ makeKeyAndOrderFront: self];
      // So we work around it and make key and front whatever was the main window
      [mainWindow makeKeyAndOrderFront: self];
      
      [self closeTimerWindow];
    }
  }
  
  // We check whether a block is currently being added by trying to lock
  // blockLock_.
  BOOL addBlockIsOngoing = ![blockLock_ tryLock];
  
  if([blockDurationSlider_ intValue] != 0 && [[defaults_ objectForKey: @"HostBlacklist"] count] != 0 && !addBlockIsOngoing)
    [submitButton_ setEnabled: YES];
  else
    [submitButton_ setEnabled: NO];
  
  // If we're adding a block, we want buttons disabled.
  if(!addBlockIsOngoing) {
    [blockDurationSlider_ setEnabled: YES];
    [editBlacklistButton_ setEnabled: YES];
    [submitButton_ setTitle: @"Start"];
  }
  else {
    [blockDurationSlider_ setEnabled: NO];
    [editBlacklistButton_ setEnabled: NO];
    [submitButton_ setTitle: @"Loading"];
  }
  
  // Unlock blockLock_ if we locked it
  if(!addBlockIsOngoing) {
    [blockLock_ unlock];
  }  
}

- (void)showTimerWindow {
  if(timerWindowController_ == nil) {
     unsigned int major, minor, bugfix;
     
    [SelfControlUtilities getSystemVersionMajor: &major minor: &minor bugFix: &bugfix];
    
    if(major <= 10 && minor < 5)
      [NSBundle loadNibNamed: @"TigerTimerWindow" owner: self];
    else
      [NSBundle loadNibNamed: @"TimerWindow" owner: self];
  }
  else {
    [[timerWindowController_ window] makeKeyAndOrderFront: self];
    [[timerWindowController_ window] center];
  }
}

- (void)closeTimerWindow {
  [timerWindowController_ close];
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
  
  [self refreshUserInterface];                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         
}

- (BOOL)selfControlLaunchDaemonIsLoaded {
  return [[NSFileManager defaultManager] fileExistsAtPath: kSelfControlLockFilePath];
}

- (IBAction)showDomainList:(id)sender {
  // We check whether a block is currently being added by trying to lock
  // blockLock_.
  BOOL addBlockIsOngoing = ![blockLock_ tryLock];
  if([self selfControlLaunchDaemonIsLoaded] || addBlockIsOngoing) {
    NSAlert* blockInProgressAlert = [[[NSAlert alloc] init] autorelease];
    [blockInProgressAlert setMessageText: @"Block in progress"];
    [blockInProgressAlert setInformativeText:@"The blacklist cannot be edited while a block is in progress."];
    [blockInProgressAlert addButtonWithTitle: @"OK"];
    [blockInProgressAlert runModal];
    
    if(!addBlockIsOngoing)
      [blockLock_ unlock];
    
    return;
  }
  
  if(domainListWindowController_ == nil)
    [NSBundle loadNibNamed: @"DomainList" owner: self];
  else
    [[domainListWindowController_ window] makeKeyAndOrderFront: self];
  
  if(!addBlockIsOngoing)
    [blockLock_ unlock];
}

- (void)closeDomainList {
  [domainListWindowController_ close];
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
  
  NSMutableArray* list = [[defaults_ arrayForKey: @"HostBlacklist"] mutableCopy];
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
    NSMutableArray* list = [[defaults_ arrayForKey: @"HostBlacklist"] mutableCopy];
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
    [networkUnavailableAlert setMessageText: @"No network connection detected"];
    [networkUnavailableAlert setInformativeText:@"A block cannot be started without a working network connection.  You can override this setting in Preferences."];
    [networkUnavailableAlert addButtonWithTitle: @"Cancel"];
    [networkUnavailableAlert addButtonWithTitle: @"Network Diagnostics..."];
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
      [description appendString: @"Remove option called"];
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
      
    default: 
      [description appendString: [NSString stringWithFormat: @"Helper tool failed with unknown error code: %d", status]];
  }
    
  return [NSError errorWithDomain: domain code: status userInfo: [NSDictionary dictionaryWithObject: description
                                                                                                     forKey: NSLocalizedDescriptionKey]];
}

- (void)installBlock {
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  // Lock blockLock_ so that refreshUserInterface knows to disable buttons.
  [blockLock_ lock];
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
    [blockLock_ unlock];
    [self refreshUserInterface];
    return;
  }
  
  // We need to pass our UID to the helper tool.  It needs to know whose defaults
  // it should reading in order to properly load the blacklist.
  char uidString[10];
  snprintf(uidString, sizeof(uidString), "%d", getuid());
  
  FILE* commPipe;
  
  char* args[] = { uidString, "--install", NULL };
  status = AuthorizationExecuteWithPrivileges(authorizationRef,
                                              helperToolPath,
                                              kAuthorizationFlagDefaults,
                                              args,
                                              &commPipe);
  
  if(status) {
    NSLog(@"WARNING: Authorized execution of helper tool returned failure status code %d", status);
    
    NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain
                                       code: status
                                   userInfo: [NSDictionary dictionaryWithObject: [NSString stringWithFormat: @"Error %d received from the Security Server.",
                                                                            status]
                                                                         forKey: NSLocalizedDescriptionKey]];
    
    [NSApp presentError: err];
    
    [blockLock_ unlock];
    [self refreshUserInterface];
    
    return;
  }
  
  NSFileHandle* helperToolHandle = [[NSFileHandle alloc] initWithFileDescriptor: fileno(commPipe) closeOnDealloc: YES];
  
  NSData* inData = [helperToolHandle readDataToEndOfFile];
  
  [helperToolHandle release];
  
  NSString* inDataString = [[NSString alloc] initWithData: inData encoding: NSUTF8StringEncoding];
  int exitCode = [inDataString intValue];
    
  if(exitCode) {
    NSError* err = [self errorFromHelperToolStatusCode: exitCode];
    
    [NSApp presentError: err];    
  }  
  
  [blockLock_ unlock];
  [self refreshUserInterface];
  [pool drain];
}

- (void)refreshBlock:(NSLock*)lockToUse {
  if(![lockToUse tryLock])
    return;
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
  char uidString[10];
  snprintf(uidString, sizeof(uidString), "%d", getuid());
  
  FILE* commPipe;
  
  char* args[] = { uidString, "--refresh", NULL };
  status = AuthorizationExecuteWithPrivileges(authorizationRef,
                                              helperToolPath,
                                              kAuthorizationFlagDefaults,
                                              args,
                                              &commPipe);
  
  if(status) {
    NSLog(@"WARNING: Authorized execution of helper tool returned failure status code %d", status);
    
    NSError* err = [self errorFromHelperToolStatusCode: status];
    
    [NSApp presentError: err];
    
    [lockToUse unlock];
    
    return;
  }
  
  NSFileHandle* helperToolHandle = [[NSFileHandle alloc] initWithFileDescriptor: fileno(commPipe) closeOnDealloc: YES];
  
  NSData* inData = [helperToolHandle readDataToEndOfFile];
  NSString* inDataString = [[NSString alloc] initWithData: inData encoding: NSUTF8StringEncoding];
  int exitCode = [inDataString intValue];
  NSLog(@"exitCode is %d", exitCode);
  
  if(exitCode) {
    NSError* err = [self errorFromHelperToolStatusCode: exitCode];
    
    [NSApp presentError: err];    
  }  
    
  [timerWindowController_ closeAddSheet: self];
  [pool drain];
  [lockToUse unlock];
}

- (BOOL)isTiger {
  unsigned int major, minor, bugfix;
  
  [SelfControlUtilities getSystemVersionMajor: &major minor: &minor bugFix: &bugfix];
  
  if(major <= 10 && minor < 5)
    return YES;
  else
    return NO;
}

@end