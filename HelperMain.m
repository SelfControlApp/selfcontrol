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

NSString* const kSelfControlLockFilePath = @"/etc/SelfControl.lock";

int main(int argc, char* argv[]) {
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
  if(geteuid()) {
    NSLog(@"ERROR: SelfControl's helper tool must be run as root.");
    printStatus(-201); 
    exit(EX_NOPERM);
  }
  
  setuid(0);
  
  if(argv[1] == NULL || argv[2] == NULL) {
    NSLog(@"ERROR: Not enough arguments");
    printStatus(-202);
    exit(EX_USAGE);
  }
    
  NSString* modeString = [NSString stringWithUTF8String: argv[2]];
  // We'll need the controlling UID to know what defaults database to search
  int controllingUID = [[NSString stringWithUTF8String: argv[1]] intValue];
  
  // For proper security, we need to make sure that SelfControl files are owned
  // by root and only writable by root.  We'll define this here so we can use it
  // throughout the main function.
  NSDictionary* fileAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithUnsignedLong: 0], NSFileOwnerAccountID,
                                  [NSNumber numberWithUnsignedLong: 0], NSFileGroupOwnerAccountID,
                                  // 493 (decimal) = 755 (octal) = rwxr-xr-x
                                  [NSNumber numberWithUnsignedLong: 493], NSFilePosixPermissions,
                                  nil];  
  
  // This is where we get going with the lockfile system, saving a "lock" in /etc/SelfControl.lock
  // to make a more reliable block detection system.  For most of the program,
  // the pattern exhibited here will be used: we attempt to use the lock file's
  // contents, and revert to the user's defaults if the lock file has unreasonable
  // contents.
  NSDictionary* curLockDict = [NSDictionary dictionaryWithContentsOfFile: kSelfControlLockFilePath];
  if(!([[curLockDict objectForKey: @"HostBlacklist"] count] <= 0))
    domainList = [curLockDict objectForKey: @"HostBlacklist"];
            
  // You'll see this pattern several times in this file.  The two resets and
  // set of euid to the controlling UID are necessary in order to successfully
  // return the NSUserDefaults object for the controlling user.  Also note that
  // the defaults object cannot be simply kept in a variable and repeatedly
  // referred to, the resets will invalidate it.  For now, we're just re-registering
  // the default settings, since they don't carry over from the main application.
  // TODO: Factor this code out into a function
  [NSUserDefaults resetStandardUserDefaults];
  seteuid(controllingUID);
  defaults = [NSUserDefaults standardUserDefaults];
  [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
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
  [defaults registerDefaults:appDefaults];    
  if(!domainList) {
    domainList = [defaults objectForKey:@"HostBlacklist"];
    if([domainList count] <= 0) {
      NSLog(@"ERROR: Not enough block information.");
      printStatus(-203);
      exit(EX_CONFIG);
    }
  }
  [defaults synchronize];
  [NSUserDefaults resetStandardUserDefaults];
  seteuid(0);  
  
  if([modeString isEqual: @"--install"]) {   
    NSFileManager* fileManager = [NSFileManager defaultManager];
        
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
      NSLog(@"ERROR: Could not write launchd plist file to LaunchDaemons folder.");
      printStatus(-204);
      exit(EX_IOERR);
    }
                    
    if(![fileManager fileExistsAtPath: @"/Library/PrivilegedHelperTools"]) {
      if(![fileManager createDirectoryAtPath: @"/Library/PrivilegedHelperTools"
                                  attributes: fileAttributes]) {
        NSLog(@"ERROR: Could not create PrivilegedHelperTools directory.");
        printStatus(-205);
        exit(EX_IOERR);
      }
    } else {
      if(![fileManager changeFileAttributes: fileAttributes
                                     atPath:  @"/Library/PrivilegedHelperTools"]) {
        NSLog(@"ERROR: Could not change permissions on PrivilegedHelperTools directory.");
        printStatus(-206);
        exit(EX_IOERR);
      }
    }
    // We should delete the old file if it exists and copy the new binary in,
    // because it might be a new version of the helper if we've upgraded SelfControl
    if([fileManager fileExistsAtPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl"]) {
      if(![fileManager removeFileAtPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl" handler: nil]) {
        NSLog(@"ERROR: Could not delete old helper binary.");
        printStatus(-207);
        exit(EX_IOERR);
      }
    }
    if(![fileManager copyPath: [NSString stringWithCString: argv[0]]
                             toPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl"
                              handler: NULL]) {
      NSLog(@"ERROR: Could not copy SelfControl's helper binary to PrivilegedHelperTools directory.");
      printStatus(-208);
      exit(EX_IOERR);
    }
    if(![fileManager changeFileAttributes: fileAttributes
                                   atPath:  @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl"]) {
      NSLog(@"ERROR: Could not change permissions on SelfControl's helper binary.");
      printStatus(-209);
      exit(EX_IOERR);
    }
        
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(controllingUID);
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
    NSDate* d = [NSDate date];
    [defaults setObject: d forKey: @"BlockStartedDate"];
    NSLog(@"set %@ for date in HelperMain main() --install", d);
    // In this case it doesn't make any sense to use an existing lock file (in
    // fact, one shouldn't exist), so we fail if the defaults system has unreasonable
    // settings.
    NSDictionary* lockDictionary = [NSDictionary dictionaryWithObjectsAndKeys: 
                                    [defaults objectForKey: @"HostBlacklist"], @"HostBlacklist",
                                    [defaults objectForKey: @"BlockDuration"], @"BlockDuration",
                                    [defaults objectForKey: @"BlockStartedDate"], @"BlockStartedDate",
                                    [defaults objectForKey: @"BlockAsWhitelist"], @"BlockAsWhitelist",
                                    nil];        
    if([[lockDictionary objectForKey: @"HostBlacklist"] count] <= 0 || [[lockDictionary objectForKey: @"BlockDuration"] intValue] < 1
       || [lockDictionary objectForKey: @"BlockStartedDate"] == nil
       || [[lockDictionary objectForKey: @"BlockStartedDate"] isEqualToDate: [NSDate distantFuture]]) {
      NSLog(@"ERROR: Not enough block information.");
      printStatus(-210);
      exit(EX_CONFIG);
    }
    [defaults synchronize];
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);

    // If perchance another lock is in existence already (which would be weird)
    // we try to remove a block and continue as normal.  This should definitely not be
    // happening though.
    if([fileManager fileExistsAtPath: kSelfControlLockFilePath]) {
      NSLog(@"WARNING: Lock already created--removing it and destroying any current block.");

      [fileManager removeFileAtPath: kSelfControlLockFilePath handler: nil];

      [NSUserDefaults resetStandardUserDefaults];
      seteuid(controllingUID);
      defaults = [NSUserDefaults standardUserDefaults];
      [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
      [defaults setObject: [NSDate distantFuture] forKey: @"BlockStartedDate"];
      NSLog(@"set %@ for date in HelperMain main() --install (second)", [NSDate distantFuture]);
      [defaults synchronize];
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(0);
      
      removeRulesFromFirewall(controllingUID);
            
      [LaunchctlHelper unloadLaunchdJobWithPlistAt:@"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
    }
    
    // And write out our lock...
    if(![lockDictionary writeToFile: kSelfControlLockFilePath atomically: YES]) {
      NSLog(@"ERROR: Could not write lock file.");
      printStatus(-216);
      exit(EX_IOERR);      
    }
    // Make sure the privileges are correct on our lock file
    [fileManager changeFileAttributes: fileAttributes atPath: kSelfControlLockFilePath];
        
    addRulesToFirewall(controllingUID);
                
    int result = [LaunchctlHelper loadLaunchdJobWithPlistAt: @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
            
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                                   object: nil];
        
    // Clear web browser caches if the user has the correct preference set, so
    // that blocked pages are not loaded from a cache.
    clearCachesIfRequested(controllingUID);
        
    if(result) {
      printStatus(-211);
      exit(EX_UNAVAILABLE);
      NSLog(@"WARNING: Launch daemon load returned a failure status code.");
    } else NSLog(@"INFO: Block successfully added.");
  }
  if([modeString isEqual: @"--remove"]) {
    // This was just too easy for the user to remove the block with.
    NSLog(@"INFO: Nice try.");
    printStatus(-212);
    exit(EX_UNAVAILABLE);
   /* [NSUserDefaults resetStandardUserDefaults];
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
    printStatus(printStatus_FAILURE); */
 /*  } else if([modeString isEqual: @"--add"]) {
    addRulesToFirewall(controllingUID);
    NSLog(@"INFO: Rules successfully added to firewall."); */
  } else if([modeString isEqual: @"--refresh"]) {
    // Check what the current block is (based on the lock file) because if possible
    // we want to keep most of its information.
    NSDictionary* curDictionary = [NSDictionary dictionaryWithContentsOfFile: kSelfControlLockFilePath];
    NSDictionary* newLockDictionary;
    
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(controllingUID);
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
    if(curDictionary == nil) {
      // If there is no block file we just use all information from defaults
      
      if([[defaults objectForKey: @"BlockStartedDate"] isEqualToDate: [NSDate distantFuture]]) {
        // But if the block is already over (which is going to happen if the user
        // starts authentication for the host add and then the block expires before
        // they authenticate), we shouldn't do anything at all.
        
        NSLog(@"ERROR: Refreshing domain blacklist, but no block is currently ongoing.");
        printStatus(-213);
        exit(EX_SOFTWARE);
      }
      
      NSLog(@"WARNING: Refreshing domain blacklist, but no block is currently ongoing.  Relaunching block.");
      newLockDictionary = [NSDictionary dictionaryWithObjectsAndKeys: 
                                        [defaults objectForKey: @"HostBlacklist"], @"HostBlacklist",
                                        [defaults objectForKey: @"BlockDuration"], @"BlockDuration",
                                        [defaults objectForKey: @"BlockStartedDate"], @"BlockStartedDate",
                                        [defaults objectForKey: @"BlockAsWhitelist"], @"BlockAsWhitelist",
                                        nil];
      // And later on we'll be reloading the launchd daemon if curDictionary
      // was nil, just in case.  Watch for it.
    } else {
      // If there is an existing block file we can save most of it from the old file
      newLockDictionary = [NSDictionary dictionaryWithObjectsAndKeys: 
                           [defaults objectForKey: @"HostBlacklist"], @"HostBlacklist",
                           [curDictionary objectForKey: @"BlockDuration"], @"BlockDuration",
                           [curDictionary objectForKey: @"BlockStartedDate"], @"BlockStartedDate",
                           [curDictionary objectForKey: @"BlockAsWhitelist"], @"BlockAsWhitelist",
                           nil];      
    }
    [defaults synchronize];
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);
    
    if([[newLockDictionary objectForKey: @"HostBlacklist"] count] <= 0 || [[newLockDictionary objectForKey: @"BlockDuration"] intValue] < 1
       || [newLockDictionary objectForKey: @"BlockStartedDate"] == nil
       || [[newLockDictionary objectForKey: @"BlockStartedDate"] isEqualToDate: [NSDate distantFuture]]) {
      NSLog(@"ERROR: Not enough block information.");
      printStatus(-214);
      exit(EX_CONFIG);
    }
    
    if(![newLockDictionary writeToFile: kSelfControlLockFilePath atomically: YES]) {
      NSLog(@"ERROR: Could not write lock file.");
      printStatus(-217);
      exit(EX_IOERR);      
    }
    // Make sure the privileges are correct on our lock file
    [[NSFileManager defaultManager] changeFileAttributes: fileAttributes atPath: kSelfControlLockFilePath];    
    domainList = [newLockDictionary objectForKey: @"HostBlacklist"];
    
    // Add and remove the rules to put in any new ones
    removeRulesFromFirewall(controllingUID);
    addRulesToFirewall(controllingUID);
    
    if(curDictionary == nil) {
      // aka if there was no lock file, and it's possible we're reloading the block,
      // and we're sure the block is still on (that's checked earlier).
      [LaunchctlHelper loadLaunchdJobWithPlistAt: @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
    }
    
    // Clear web browser caches if the user has the correct preference set.  We
    // need to do this again even if it's only a refresh because there might be
    // caches for the new host blocked.
    clearCachesIfRequested(controllingUID);
  } else if([modeString isEqual: @"--checkup"]) {    
    NSDictionary* curDictionary = [NSDictionary dictionaryWithContentsOfFile: kSelfControlLockFilePath];
    
    NSDate* blockStartedDate = [curDictionary objectForKey: @"BlockStartedDate"];
    NSTimeInterval blockDuration = [[curDictionary objectForKey: @"BlockDuration"] intValue];
    
    if(blockStartedDate == nil || [blockStartedDate isEqualToDate: [NSDate distantFuture]]
       || blockDuration < 1) {    
      // The lock file seems to be broken.  Read from defaults, then write out a
      // new lock file while we're at it.
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(controllingUID);
      defaults = [NSUserDefaults standardUserDefaults];
      [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
      blockStartedDate = [defaults objectForKey: @"BlockStartedDate"];
      blockDuration = [[defaults objectForKey: @"BlockDuration"] intValue];
      [defaults synchronize];
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(0);
      
      if(blockStartedDate == nil || [blockStartedDate isEqualToDate: [NSDate distantFuture]]
         || blockDuration < 1) {    
          // Defaults is broken too!  Let's get out of here!
        NSLog(@"ERROR: Checkup ran -- no block found.");
        printStatus(-215);
        exit(EX_SOFTWARE);
      }
      
      NSDictionary* newDictionary = [NSDictionary dictionaryWithObjectsAndKeys: 
                                     domainList, @"HostBlacklist",
                                     blockStartedDate, @"BlockStartedDate",
                                     blockDuration, @"BlockDuration",
                                     nil];
      [newDictionary writeToFile: kSelfControlLockFilePath atomically: YES];
      // Make sure the privileges are correct on our lock file
      [[NSFileManager defaultManager] changeFileAttributes: fileAttributes atPath: kSelfControlLockFilePath];    
    }
    
    NSTimeInterval timeSinceStarted = [[NSDate date] timeIntervalSinceDate: blockStartedDate];
    blockDuration *= 60;
    
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
      
      NSLog(@"");
      if([[NSFileManager defaultManager] isDeletableFileAtPath: kSelfControlLockFilePath] && ![[NSFileManager defaultManager] removeFileAtPath: kSelfControlLockFilePath handler: nil]) {
        NSLog(@"");
        NSLog(@"ERROR: Could not remove SelfControl lock file.");
        NSLog(@"");
        printStatus(-218);
        NSLog(@"");
        exit(EX_IOERR);
        NSLog(@"");
      }
      NSLog(@"");
      
      [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                                     object: nil];
      
      [LaunchctlHelper unloadLaunchdJobWithPlistAt:@"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
      
      // Execution should never reach this point.  Launchd unloading the job
      // should have killed this process.
      printStatus(-216);
      exit(EX_SOFTWARE);
    } else {
      // The block is still on.  Check if anybody removed our rules, and if so
      // re-add them.  Also make sure the user's defaults are set to the correct
      // settings just in case.
      IPFirewall* firewall = [[IPFirewall alloc] init];
      if(![firewall containsSelfControlBlockSet]) { 
        addRulesToFirewall(controllingUID);
        NSLog(@"INFO: Checkup ran, readded block rules.");
      } else NSLog(@"INFO: Checkup ran, no action needed.");
      
      // Why would we make sure the defaults are correct even if we can get the
      // info from the lock file?  In case one goes down, we want to make sure
      // we always have a backup.
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(controllingUID);
      defaults = [NSUserDefaults standardUserDefaults];
      [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
      [defaults setObject: blockStartedDate forKey: @"BlockStartedDate"];
      NSLog(@"set %@ for date in HelperMain main() --checkup because the lock file said so", blockStartedDate);
      [defaults setObject: [NSNumber numberWithInt: (blockDuration / 60)] forKey: @"BlockDuration"];
      [defaults setObject: domainList forKey: @"HostBlacklist"];
      [defaults synchronize];
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(0);
    }
  }
  
  [pool drain];
  printStatus(0);
  exit(EXIT_SUCCESS);
}

void addRulesToFirewall(int controllingUID) {
  // Note all arrays in the host blocking code were changed to sets to easily stop duplicates
  NSMutableSet* hostsToBlock = [NSMutableSet set];
      
  for(int i = 0; i < [domainList count]; i++) {
    NSString* hostName;
    int portNum;
    int maskLen;
    
    parseHost([domainList objectAtIndex: i], &hostName, &maskLen, &portNum);
        
    if([hostName isEqualToString: @"*"]) {
      [hostsToBlock addObject: [domainList objectAtIndex: i]];
    }
    
    NSString* ipValidationRegex = @"^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
    NSPredicate *regexTester = [NSPredicate
                                predicateWithFormat:@"SELF MATCHES %@",
                                ipValidationRegex];
    if ([regexTester evaluateWithObject: hostName])
      [hostsToBlock addObject: [domainList objectAtIndex: i]];
    else {
      // We have a domain name, we need to resolve it first
      NSHost* host = [NSHost hostWithName: hostName];
      
      if(host) {
        NSArray* addresses = [host addresses];
        
        for(int j = 0; j < [addresses count]; j++) {
          if(portNum != -1)
            [hostsToBlock addObject: [NSString stringWithFormat: @"%@:%d", [addresses objectAtIndex: j], portNum]];
          else [hostsToBlock addObject: [addresses objectAtIndex: j]];
        }
      }
      
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(controllingUID);
      defaults = [NSUserDefaults standardUserDefaults];
      [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
      BOOL shouldEvaluateCommonSubdomains = [[defaults objectForKey: @"EvaluateCommonSubdomains"] boolValue];
      [defaults synchronize];
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(0);
      
      if(shouldEvaluateCommonSubdomains) {
        // Get the evaluated hostnames and union (combine) them with our current set
        NSSet* evaluatedHosts = getEvaluatedHostNamesFromCommonSubdomains(hostName, portNum);
        [hostsToBlock unionSet: evaluatedHosts];
      }
    }
  }
  
  // This section is broken and plus seems to slow down parsing too much to be
  // useful.  Consider reintroduction later, possibly with modifications?
  /*
  // OpenDNS, the very popular DNS provider, doesn't return NXDOMAIN.  Instead,
  // all nonexistent DNS requests are pointed to hit-nxdomain.opendns.com.  We
  // don't want to accidentally block that if one of our DNS resolutions fails,
  // so we'll filter for those addresses.
  NSHost* openDNSNXDomain = [NSHost hostWithName: @"hit-nxdomain.opendns.com"];
  
  if(openDNSNXDomain) {
    NSArray* addresses = [openDNSNXDomain addresses];
    
    for(int j = 0; j < [addresses count]; j++) {
      NSPredicate* openDNSFilter = [NSPredicate predicateWithFormat: @"NOT SELF beginswith '%@'", [addresses objectAtIndex: j]];
      [hostsToBlock filterUsingPredicate: openDNSFilter];
    }
  }
  */
  
  BOOL blockAsWhitelist;
  NSDictionary* curDictionary = [NSDictionary dictionaryWithContentsOfFile: kSelfControlLockFilePath];
  
  if(curDictionary == nil || [curDictionary objectForKey: @"BlockAsWhitelist"] == nil)
    blockAsWhitelist = [defaults boolForKey: @"BlockAsWhitelist"];
  else
    blockAsWhitelist = [[curDictionary objectForKey: @"BlockAsWhitelist"] boolValue];
      
  // /etc/hosts blocking
  if(!blockAsWhitelist) {
    HostFileBlocker* hostFileBlocker = [[[HostFileBlocker alloc] init] autorelease];
    if(![hostFileBlocker containsSelfControlBlock]) {
      [hostFileBlocker addSelfControlBlockHeader];
      for(int i = 0; i < [domainList count]; i++) {
          NSString* hostName;
          int portNum;
          int maskLen;
          
          parseHost([domainList objectAtIndex: i], &hostName, &maskLen, &portNum);
        
          if([hostName isEqualToString: @"*"]) continue;
        
          if(portNum == -1) {
            NSString* ipValidationRegex = @"^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
            NSPredicate *regexTester = [NSPredicate
                                        predicateWithFormat:@"SELF MATCHES %@",
                                        ipValidationRegex];
            if ([regexTester evaluateWithObject: hostName] != YES)
              // It's not an IP, so we'll add it to the /etc/hosts block as well
              [hostFileBlocker addRuleBlockingDomain: hostName];
          }
      }
      [hostFileBlocker addSelfControlBlockFooter];
      [hostFileBlocker writeNewFileContents];
    }
  }
  
  IPFirewall* firewall = [[IPFirewall alloc] init];
  [firewall clearSelfControlBlockRuleSet];
  [firewall addSelfControlBlockHeader];
  
  // Iterate through the host list to add a block rule for each
  NSEnumerator* hostEnumerator = [hostsToBlock objectEnumerator];
  NSString* hostString;
    
  while(hostString = [hostEnumerator nextObject]) {
    NSString* hostName;
    int portNum;
    int maskLen;
    
    parseHost(hostString, &hostName, &maskLen, &portNum);
    
    if(blockAsWhitelist) {
      if([hostName isEqualToString: @"*"])
        [firewall addSelfControlBlockRuleAllowingPort: portNum];
      else if(portNum != -1 && maskLen != -1)
        [firewall addSelfControlBlockRuleAllowingIP: hostName port: portNum maskLength: maskLen];
      else if(portNum != -1)
        [firewall addSelfControlBlockRuleAllowingIP: hostName port: portNum];
      else if(maskLen != -1)
        [firewall addSelfControlBlockRuleAllowingIP: hostName maskLength: maskLen];
      else
        [firewall addSelfControlBlockRuleAllowingIP: hostName];
    } else {
      if([hostName isEqualToString: @"*"])
        [firewall addSelfControlBlockRuleBlockingPort: portNum];
      else if(portNum != -1 && maskLen != -1)
        [firewall addSelfControlBlockRuleBlockingIP: hostName port: portNum maskLength: maskLen];
      else if(portNum != -1)
        [firewall addSelfControlBlockRuleBlockingIP: hostName port: portNum];
      else if(maskLen != -1)
        [firewall addSelfControlBlockRuleBlockingIP: hostName maskLength: maskLen];
      else
        [firewall addSelfControlBlockRuleBlockingIP: hostName];
    }
  }
  
  if(blockAsWhitelist) 
    [firewall addWhitelistFooter];
  
  [firewall addSelfControlBlockFooter];  
}

void removeRulesFromFirewall(int controllingUID) {
  IPFirewall* firewall = [[IPFirewall alloc] init];
  if([firewall containsSelfControlBlockSet]) {
    HostFileBlocker* hostFileBlocker = [[[HostFileBlocker alloc] init] autorelease];
    [hostFileBlocker removeSelfControlBlock];
    [hostFileBlocker writeNewFileContents];
    [firewall clearSelfControlBlockRuleSet];
    NSLog(@"INFO: Blacklist blocking cleared.");
    
    // We'll play the sound now rather than putting it in the "defaults block"
    // a few lines ago, because it is important that the UI get updated (by
    // the posted notification) before we sleep to play the sound.  Otherwise,
    // the app seems unresponsive and slow.
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(controllingUID);
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
    if([defaults boolForKey: @"BlockSoundShouldPlay"]) {
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
      NSSound* alertSound = [NSSound soundNamed: [systemSoundNames objectAtIndex: [defaults integerForKey: @"BlockSound"]]];
      if(!alertSound)
        NSLog(@"WARNING: Alert sound not found.");
      else {
        [alertSound play];
        // Sleeping a second is a messy way of doing this, but otherwise the
        // sound is killed along with this process when it is unloaded in just
        // a few lines.
        sleep(1);
      }
    }
    [defaults synchronize];
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);    
    
  } else
    NSLog(@"WARNING: SelfControl rules do not appear to be loaded into ipfw.");
}

NSSet* getEvaluatedHostNamesFromCommonSubdomains(NSString* hostName, int port) {
  NSMutableSet* evaluatedAddresses = [NSMutableSet set];
  
  // If the domain ends in facebook.com...  Special case for Facebook because
  // users will often forget to block some of its many mirror subdomains that resolve
  // to different IPs, i.e. hs.facebook.com.  Thanks to Danielle for raising this issue.
  if([hostName rangeOfString: @"facebook.com"].location == ([hostName length] - 12)) {
    [evaluatedAddresses addObject: @"69.63.176.0/20"];
  }
 
  // Block the domain with no subdomains, if www.domain is blocked
  else if([hostName rangeOfString: @"www."].location == 0) {
    NSHost* modifiedHost = [NSHost hostWithName: [hostName substringFromIndex: 4]];
    
    if(modifiedHost) {
      NSArray* addresses = [modifiedHost addresses];
      
      for(int j = 0; j < [addresses count]; j++) {
        if(port != -1)
          [evaluatedAddresses addObject: [NSString stringWithFormat: @"%@:%d", [addresses objectAtIndex: j], port]];
        else [evaluatedAddresses addObject: [addresses objectAtIndex: j]];
      }
    }
  }
  // Or block www.domain otherwise
  else {
    NSHost* modifiedHost = [NSHost hostWithName: [@"www." stringByAppendingString: hostName]];
    
    if(modifiedHost) {
      NSArray* addresses = [modifiedHost addresses];
      
      for(int j = 0; j < [addresses count]; j++) {
        if(port != -1)
          [evaluatedAddresses addObject: [NSString stringWithFormat: @"%@:%d", [addresses objectAtIndex: j], port]];
        else [evaluatedAddresses addObject: [addresses objectAtIndex: j]];
      }
    }
  }  
  
  return evaluatedAddresses;
}

void clearCachesIfRequested(int controllingUID) {
  [NSUserDefaults resetStandardUserDefaults];
  seteuid(controllingUID);
  defaults = [NSUserDefaults standardUserDefaults];
  [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
  if([defaults boolForKey: @"ClearCaches"]) {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    unsigned int major, minor, bugfix;
    
    [SelfControlUtilities getSystemVersionMajor: &major minor: &minor bugFix: &bugfix];
    
    // We've got to check if we're on 10.5 or not, because earlier systems don't
    // have the DARWIN_USER_CACHE_DIR caches that we're about to remove.  This is
    // also why we have to spawn a task to get the directory path, the specific
    // API to get this path is Leopard-only and we need to have a single version
    // that works on Tiger and Leopard.
    if(major >= 10 && minor >= 5) {
      NSTask* task = [[[NSTask alloc] init] autorelease];
      [task setLaunchPath: @"/usr/bin/getconf"];
      [task setArguments: [NSArray arrayWithObject:
                           @"DARWIN_USER_CACHE_DIR"
                           ]];
      NSPipe* inPipe = [[[NSPipe alloc] init] autorelease];
      NSFileHandle* readHandle = [inPipe fileHandleForReading];
      [task setStandardOutput: inPipe];      
      [task launch];
      NSString* leopardCacheDirectory = [[[NSString alloc] initWithData:[readHandle readDataToEndOfFile]
                                                               encoding: NSUTF8StringEncoding] autorelease];
      close([readHandle fileDescriptor]);
      [task waitUntilExit];
      
      leopardCacheDirectory = [leopardCacheDirectory stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      
      if([task terminationStatus] == 0 && [leopardCacheDirectory length] > 0) {
        NSMutableArray* leopardCacheDirs = [NSMutableArray arrayWithObjects:
                                            @"org.mozilla.firefox",
                                            @"com.apple.Safari",
                                            @"jp.hmdt.shiira",
                                            @"org.mozilla.camino",
                                            nil];
        for(int i = 0; i < [leopardCacheDirs count]; i++) {
          NSString* cacheDir = [leopardCacheDirectory stringByAppendingPathComponent: [leopardCacheDirs objectAtIndex: i]];
          if([fileManager isDeletableFileAtPath: cacheDir]) {
            [fileManager removeFileAtPath: cacheDir handler: nil];
          }
        }
      }
      
      // NSArray* userCacheDirectories = NSSearchPathForDirectoriesInDomain(NSCachesDirectory, NSUserDomainMask, NO);
      // I have no clue why this doesn't compile, I'm #importing properly I believe.
      // We'll have to do it the messy way...
      
      NSString* userLibraryDirectory = [@"~/Library" stringByExpandingTildeInPath];
      NSMutableArray* cacheDirs = [NSMutableArray arrayWithObjects:
                                   @"Caches/Camino",
                                   @"Caches/com.apple.Safari",
                                   @"Caches/Firefox",
                                   @"Caches/Flock",
                                   @"Caches/Opera",
                                   @"Caches/Unison",
                                   @"Caches/com.omnigroup.OmniWeb5",
                                   @"Preferences/iCab Preferences/iCab Cache",
                                   @"Preferences/com.omnigroup.OmniWeb5",
                                   nil];
      
      for(int i = 0; i < [cacheDirs count]; i++) {
        NSString* cacheDir = [userLibraryDirectory stringByAppendingPathComponent: [cacheDirs objectAtIndex: i]];
        if([fileManager isDeletableFileAtPath: cacheDir]) {
          [fileManager removeFileAtPath: cacheDir handler: nil];
        }
      }
      
    }
  }
  [NSUserDefaults resetStandardUserDefaults];
  seteuid(0);
}

void printStatus(int status) {
  printf("%d", status);
}

void parseHost(NSString* hostName, NSString** baseName, int* maskLength, int* portNumber) {
  int maskLen = -1;
  int portNum = -1;
  
  NSArray* splitString = [hostName componentsSeparatedByString: @"/"];
  
  hostName = [splitString objectAtIndex: 0];
  
  NSString* stringToSearchForPort = hostName;
  
  if([splitString count] >= 2) {
    maskLen = [[splitString objectAtIndex: 1] intValue];
    // If the int value is 0, we couldn't find a valid integer representation
    // in the split off string
    if(maskLen == 0)
      maskLen = -1;
    
    stringToSearchForPort = [splitString objectAtIndex: 1];
  }
  
  splitString = [stringToSearchForPort componentsSeparatedByString: @":"];
  
  if([stringToSearchForPort isEqualToString: hostName])
    hostName = [splitString objectAtIndex: 0];
  
  if([splitString count] >= 2) {
    portNum = [[splitString objectAtIndex: 1] intValue];
    // If the int value is 0, we couldn't find a valid integer representation
    // in the split off string
    if(portNum == 0)
      portNum = -1;
  }
  
  if([hostName isEqualToString: @""])
    hostName = @"*";
  
  if(baseName) *baseName = hostName;
  if(portNumber) *portNumber = portNum;
  if(maskLength) *maskLength = maskLen;
}