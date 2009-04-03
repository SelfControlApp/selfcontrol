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
#import <Security/Security.h>
#import <SystemConfiguration/SCNetwork.h>
#import <unistd.h>

@implementation AppController

- (AppController*) init {
  [super init];
  
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
                               nil];
  
  [defaults_ registerDefaults:appDefaults];
  
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

- (IBAction)addBlock:(id)sender{
  [defaults_ synchronize];
  if(([[defaults_ objectForKey:@"BlockStartedDate"] timeIntervalSinceNow] < 0)) {
    // This method shouldn't be getting called, a block is on (block started date
    // is in the past, not distantFuture) so the Start button should be disabled.
    // Maybe the UI didn't get properly refreshed, so try refreshing it again
    // before we return.
    [self refreshUserInterface];
    return;
  }
  if([[defaults_ arrayForKey:@"HostBlacklist"] count] == 0)
    // Since the Start button should be disabled when the blacklist has no entries,
    // this should definitely not be happening.  Exit.
    return;
  
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
    return;
  }
    
  // We need to pass our UID to the helper tool.  It needs to know whose defaults
  // it should reading in order to properly load the blacklist.
  char uidString[10];
  snprintf(uidString, sizeof(uidString), "%d", getuid());
  
  char* args[] = { uidString, "--install", NULL };
  status = AuthorizationExecuteWithPrivileges(authorizationRef,
                                              helperToolPath,
                                              kAuthorizationFlagDefaults,
                                              args,
                                              NULL);
    if(status) {
    NSLog(@"WARNING: Authorized execution of helper tool returned failure status code %d", status);
  }
}

- (void)refreshUserInterface {
  if([self selfControlLaunchDaemonIsLoaded]) {
    [self showAndReloadTimerWindow];
    [initialWindow_ close];
    [self closeDomainList];
  } else {
    [self updateTimeSliderDisplay: blockDurationSlider_];
    
    [defaults_ synchronize];
    
    if([blockDurationSlider_ intValue] != 0 && [[defaults_ objectForKey: @"HostBlacklist"] count] != 0)
      [submitButton_ setEnabled: YES];
    else
      [submitButton_ setEnabled: NO];
    
    NSWindow* mainWindow = [NSApp mainWindow];
    // We don't necessarily want the initial window to be key and front,
    // but no other message seems to show it properly.
    [initialWindow_ makeKeyAndOrderFront: self];
    // So we work around it and make key and front whatever was the main window
    [mainWindow makeKeyAndOrderFront: self];
    
    [self closeTimerWindow];
  }
}

- (void)showAndReloadTimerWindow {
  if(timerWindowController_ == nil) {
    timerWindowController_ = [[TimerWindowController alloc] init];
  }
  
  [[timerWindowController_ window] center];
  [timerWindowController_ showWindow: self];
  [timerWindowController_ reloadTimer];
}

- (void)closeTimerWindow {
  [timerWindowController_ close];
}

- (void)removeBlock {
  // Remember not to use this method, it defeats the point of SelfControl!
  
  [defaults_ synchronize];
  
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
  status = AuthorizationCreate (&authRights, kAuthorizationEmptyEnvironment, myFlags, &authorizationRef);
  
  if(status) {
    NSLog(@"ERROR: Failed to authorize block removal.");
    return;
  }    
  
  char uidString[10];
  snprintf(uidString, sizeof(uidString), "%d", getuid());
  char* args[] = { uidString, "--remove", NULL };
  status = AuthorizationExecuteWithPrivileges(authorizationRef,
                                              [self selfControlHelperToolPathUTF8String],
                                              kAuthorizationFlagDefaults, args,
                                              NULL);
  
  if(status) {
    NSLog(@"WARNING: Helper tool returned failure status code %d.");
    return;
  }    
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
  
  [self refreshUserInterface];                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         
}

- (BOOL)selfControlLaunchDaemonIsLoaded {
  [defaults_ synchronize];
  NSDate* blockStartedDate = [defaults_ objectForKey:@"BlockStartedDate"];
  return (![blockStartedDate isEqualToDate: [NSDate distantFuture]]);
  // If the user deletes the defaults and therefore destroys our flag (that the
  // blockStartedDate will be set to distantFuture if no block is on) our program
  // will get very confused.  Oh well.
}

- (IBAction)showDomainList:(id)sender {
  if([self selfControlLaunchDaemonIsLoaded]) {
    NSAlert* blockInProgressAlert = [[[NSAlert alloc] init] autorelease];
    [blockInProgressAlert setMessageText: @"Block in progress"];
    [blockInProgressAlert setInformativeText:@"The blacklist cannot be edited while a block is in progress."];
    [blockInProgressAlert addButtonWithTitle: @"OK"];
    [blockInProgressAlert runModal];
    return;
  }
  if(domainListWindowController_ == nil) {
    domainListWindowController_ = [[DomainListWindowController alloc] init];
  }
  
  [domainListWindowController_ showWindow: self];
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
  if(!alertSound)
    NSLog(@"WARNING: Alert sound not found.");
  else
    [alertSound play];
}

- (void)dealloc {
  [domainListWindowController_ release];
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

@end