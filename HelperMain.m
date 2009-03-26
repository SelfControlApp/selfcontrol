//
//  helpermain.m
//  SelfControl
//
//  Created by Charlie Stigler on 2/4/09.
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


#import "HelperMain.h"
#import "IPFirewall.h"
#import "LaunchctlHelper.h"

NSString* const kSelfControlLaunchDaemonPlist = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n<key>Label</key>\n<string>org.eyebeam.SelfControl</string>\n<key>ProgramArguments</key>\n<array>\n<string>%@</string>\n<string>%d</string>\n<string>--checkup</string>\n</array>\n<key>StartInterval</key>\n<integer>60</integer>\n<key>StartOnMount</key>\n<false/>\n</dict>\n</plist>";

int main(int argc, char* argv[]) {
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
  if(geteuid()) {
    NSLog(@"ERROR: SelfControl's helper tool must be run as root.");
    exit(EXIT_FAILURE);
  }
  
  setuid(0);
  
  if(argv[1] == NULL || argv[2] == NULL) {
    NSLog(@"ERROR: Not enough arguments");
    exit(EXIT_FAILURE);
  }
  
  NSString* modeString = [NSString stringWithUTF8String: argv[2]];
  // We'll need the controlling UID to know what defaults database to search
  int controllingUID = [[NSString stringWithUTF8String: argv[1]] intValue];
        
  if([modeString isEqual: @"--install"]) {
    // You'll see this pattern several times in this file.  The two resets and
    // set of euid to the controlling UID are necessary in order to successfully
    // return the NSUserDefaults object for the controlling user.  Also note that
    // the defaults object cannot be simply kept in a variable and repeatedly
    // referred to, the resets will invalidate it.
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(controllingUID);
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
    domainList = [defaults objectForKey:@"HostBlacklist"];
    [defaults synchronize];
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);
    
    if(!domainList) {
      NSLog(@"ERROR: No blacklist set.");
      exit(EXIT_FAILURE);
    }       
            
    // Initialize writeErr to nil so calling messages on it later don't cause
    // crashes (it doesn't make sense we need to do this, but whatever).
    NSError* writeErr = nil; 
    NSString* plistFormatPath = [[NSBundle mainBundle] pathForResource:@"org.eyebeam.SelfControl"
                                                                ofType:@"plist"];
    
    NSString* plistFormatString = [NSString stringWithContentsOfFile: plistFormatPath];
    
    NSString* plistString = [NSString stringWithFormat:
                             plistFormatString,
                             controllingUID];
    
    [plistString writeToFile: @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"
                  atomically: YES
                    encoding: NSUTF8StringEncoding
                       error: &writeErr];
        
    if([writeErr code]) {
      NSLog(@"ERROR: Could not write launchd plist file to disk.");
      exit(EXIT_FAILURE);
    }
            
    NSFileManager* fileManager = [NSFileManager defaultManager];
    // For proper security, we need to make sure that the helper binary is owned
    // by root and only writable by root
    NSDictionary* fileAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedLong: 0], NSFileOwnerAccountID,
                                    [NSNumber numberWithUnsignedLong: 0], NSFileGroupOwnerAccountID,
                                    // 493 (decimal) = 755 (octal) = rwxr-xr-x
                                    [NSNumber numberWithUnsignedLong: 493], NSFilePosixPermissions,
                                    nil];
        
    if(![fileManager fileExistsAtPath: @"/Library/PrivilegedHelperTools"]) {
      if(![fileManager createDirectoryAtPath: @"/Library/PrivilegedHelperTools"
                                  attributes: fileAttributes]) {
        NSLog(@"ERROR: Could not create PrivilegedHelperTools directory.");
        exit(EXIT_FAILURE);
      }
    } else {
      if(![fileManager changeFileAttributes: fileAttributes
                                     atPath:  @"/Library/PrivilegedHelperTools"]) {
        NSLog(@"ERROR: Could not change permissions on PrivilegedHelperTools directory.");
        exit(EXIT_FAILURE);
      }
    }
    // We should delete the old file if it exists and copy the new binary in,
    // because it might be a new version of the helper if we've upgraded SelfControl
    if([fileManager fileExistsAtPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl"]) {
      if(![fileManager removeItemAtPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl" error: NULL]) {
        NSLog(@"ERROR: Could not delete old helper binary.");
        exit(EXIT_FAILURE);
      }
    }
    if(![fileManager copyItemAtPath: [NSString stringWithCString: argv[0]]
                             toPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl"
                              error: NULL]) {
      NSLog(@"ERROR: Could not copy SelfControl's helper binary to PrivilegedHelperTools directory.");
      exit(EXIT_FAILURE);
    }
    if(![fileManager changeFileAttributes: fileAttributes
                                   atPath:  @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl"]) {
      NSLog(@"ERROR: Could not change permissions on SelfControl's helper binary.");
      exit(EXIT_FAILURE);
    }
        
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(controllingUID);
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
    [defaults setObject: [NSDate date] forKey: @"BlockStartedDate"];
    [defaults synchronize];
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);
    
    addRulesToFirewall(controllingUID);
    
    int result = [LaunchctlHelper loadLaunchdJobWithPlistAt: @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
    
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                                   object: nil];
    
    if(result) {
      exit(EXIT_FAILURE);
      NSLog(@"WARNING: Launch daemon load returned a failure status code.");
    } else NSLog(@"INFO: Block successfully added.");
  }
  if([modeString isEqual: @"--remove"]) {
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(controllingUID);
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
    [defaults setObject: [NSDate distantFuture] forKey: @"BlockStartedDate"];
    [defaults synchronize];
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);
        
    removeRulesFromFirewall(controllingUID);
    
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                                   object: nil];
    
    [LaunchctlHelper unloadLaunchdJobWithPlistAt:@"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
    
    // Execution should never reach this point if the job was unloaded
    // successfully, because the unload will kill the helper tool.
    NSLog(@"WARNING: Launch daemon unload failed.");
    exit(EXIT_FAILURE);
  } else if([modeString isEqual: @"--add"]) {
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(controllingUID);
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
    domainList = [defaults objectForKey: @"HostBlacklist"];
    [defaults synchronize];
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);
    
    if(!domainList) {
      NSLog(@"ERROR: No blacklist set.");
      exit(EXIT_FAILURE);
    }       
    addRulesToFirewall(controllingUID);
    
    NSLog(@"INFO: Rules successfully added to firewall.");
  } else if([modeString isEqual: @"--checkup"]) {    
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(controllingUID);
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
    NSDate* blockStartedDate = [defaults objectForKey: @"BlockStartedDate"];
    NSString* blockDurationString = [defaults objectForKey: @"BlockDuration"];
    [defaults synchronize];
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);
    
    NSTimeInterval timeSinceStarted = [[NSDate date] timeIntervalSinceDate: blockStartedDate];
    NSTimeInterval blockDuration = [blockDurationString intValue] * 60;
    
    // Note there are a few extra possible conditions on this if statement, this
    // makes it more likely that an improperly applied block might come right
    // off.
    if( blockStartedDate == nil || [[NSDate distantFuture] isEqualToDate: blockStartedDate] || timeSinceStarted >= blockDuration) {
      NSLog(@"INFO: Checkup ran, block expired, removing block.");            
                        
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(controllingUID);
      defaults = [NSUserDefaults standardUserDefaults];
      [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
      [defaults setObject: [NSDate distantFuture] forKey: @"BlockStartedDate"];
      [defaults synchronize];
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(0);
                  
      removeRulesFromFirewall(controllingUID);
      
      [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                                     object: nil];
      
      [LaunchctlHelper unloadLaunchdJobWithPlistAt:@"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
      
      // Execution should never reach this point.  Launchd unloading the job
      // should have killed this process.
      exit(EXIT_FAILURE);
    } else {
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(controllingUID);
      defaults = [NSUserDefaults standardUserDefaults];
      [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
      domainList = [defaults objectForKey: @"HostBlacklist"];
      [defaults synchronize];
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(0);
      
      if(!domainList) {
        NSLog(@"ERROR: No blacklist set.");
        exit(EXIT_FAILURE);
      }           
      IPFirewall* firewall = [[IPFirewall alloc] init];
      if(![firewall containsSelfControlBlockSet]) { 
        addRulesToFirewall(controllingUID);
        NSLog(@"INFO: Checkup ran, readded block rules.");
      } else NSLog(@"INFO: Checkup ran, no action needed.");
    }
  }
  
  [pool drain];
  return 0;
}

void addRulesToFirewall(int controllingUID) {
  NSMutableArray* hostsToBlock = [NSMutableArray array];
    
  for(int i = 0; i < [domainList count]; i++) {
    NSArray* hostAndPort = [[domainList objectAtIndex: i] componentsSeparatedByString:@":"];
    NSString* hostToBeBlocked = [hostAndPort objectAtIndex: 0];
    NSString* portToBeBlocked = nil;
    if([hostAndPort count] > 1) {
      portToBeBlocked = [hostAndPort objectAtIndex: 1];
    }      
    NSString* ipValidationRegex = @"^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
    NSPredicate *regexTester = [NSPredicate
                                predicateWithFormat:@"SELF MATCHES %@",
                                ipValidationRegex];
    if ([regexTester evaluateWithObject: hostToBeBlocked] == YES) {
      // We're dealing with an IP address, block it
      if(portToBeBlocked != nil)
        [hostsToBlock addObject: [NSString stringWithFormat: @"%@:%@", hostToBeBlocked, portToBeBlocked]];
      else 
        [hostsToBlock addObject: hostToBeBlocked];
    } else {
      // We have a domain name, we need to resolve it first
      NSHost* host = [NSHost hostWithName: hostToBeBlocked];
      
      if(host) {
        NSArray* addresses = [host addresses];
        
        for(int j = 0; j < [addresses count]; j++) {
          if(portToBeBlocked != nil)
            [hostsToBlock addObject: [NSString stringWithFormat: @"%@:%@", [addresses objectAtIndex: j], portToBeBlocked]];
          else [hostsToBlock addObject: [addresses objectAtIndex: j]];
        }
      }
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(controllingUID);
      defaults = [NSUserDefaults standardUserDefaults];
      [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
      int evaluateCommonSubdomains = [[defaults objectForKey: @"EvaluateCommonSubdomains"] intValue];
      [defaults synchronize];
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(0);
      
      if(evaluateCommonSubdomains) {
        // If we've been told to evaluate common subdomains, also block the www
        // subdomain.  More intelligent-style blocks may be included with this
        // preference later.
        if([hostToBeBlocked rangeOfString: @"www."].location == 0) {
          NSHost* modifiedHost = [NSHost hostWithName: [hostToBeBlocked substringFromIndex: 4]];
                    
          if(modifiedHost) {
            NSArray* addresses = [modifiedHost addresses];
            
            for(int j = 0; j < [addresses count]; j++) {
              if(portToBeBlocked != nil)
                [hostsToBlock addObject: [NSString stringWithFormat: @"%@:%@", [addresses objectAtIndex: j], portToBeBlocked]];
              else [hostsToBlock addObject: [addresses objectAtIndex: j]];
            }
          }
        } else {
          NSHost* modifiedHost = [NSHost hostWithName: [@"www." stringByAppendingString: hostToBeBlocked]];
                    
          if(modifiedHost) {
            NSArray* addresses = [modifiedHost addresses];
            
            for(int j = 0; j < [addresses count]; j++) {
              if(portToBeBlocked != nil)
                [hostsToBlock addObject: [NSString stringWithFormat: @"%@:%@", [addresses objectAtIndex: j], portToBeBlocked]];
              else [hostsToBlock addObject: [addresses objectAtIndex: j]];
            }
          }
        }
      }
    }
  }
  IPFirewall* firewall = [[IPFirewall alloc] init];
  [firewall clearSelfControlBlockRuleSet];
  [firewall addSelfControlBlockHeader];
  for(int i = 0; i < [hostsToBlock count]; i++) {
    [firewall addSelfControlBlockRuleBlockingIP: [hostsToBlock objectAtIndex: i]];
  }
  [firewall addSelfControlBlockFooter];
}

void removeRulesFromFirewall(int controllingUID) {
  IPFirewall* firewall = [[IPFirewall alloc] init];
  if([firewall containsSelfControlBlockSet] ) {
    [firewall clearSelfControlBlockRuleSet];
    NSLog(@"INFO: Blacklist blocking cleared.");
    
    NSLog(@"INFO: About to enter block sound code");
    // We'll play the sound now rather than putting it in the "defaults block"
    // a few lines ago, because it is important that the UI get updated (by
    // the posted notification) before we sleep to play the sound.  Otherwise,
    // the app seems unresponsive and slow.
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(controllingUID);
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
    if([defaults boolForKey: @"BlockSoundShouldPlay"]) {
      NSLog(@"INFO: BlockSoundShouldPlay was true");
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
      NSLog(@"INFO: The matching sound name for %d is %@", [defaults integerForKey:@"BlockSound"], [systemSoundNames objectAtIndex: [defaults integerForKey: @"BlockSound"]]);
      NSSound* alertSound = [NSSound soundNamed: [systemSoundNames objectAtIndex: [defaults integerForKey: @"BlockSound"]]];
      if(!alertSound)
        NSLog(@"WARNING: Alert sound not found.");
      else {
        NSLog(@"INFO: alertSound was %@", alertSound);
        [alertSound play];
        NSLog(@"INFO: alertSound played, about to sleep...");
        // Sleeping a second is a messy way of doing this, but otherwise the
        // sound is killed along with this process when it is unloaded in just
        // a few lines.
        sleep(1);
        NSLog(@"INFO: Slept");
      }
    } else NSLog(@"INFO: BlockSoundShouldPlay was false");
    [defaults synchronize];
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);    
    
  } else
    NSLog(@"WARNING: SelfControl rules do not appear to be loaded into ipfw.");
}