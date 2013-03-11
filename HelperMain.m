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

int main(int argc, char* argv[]) {
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
  if(geteuid()) {
    NSLog(@"ERROR: SelfControl's helper tool must be run as root.");
    printStatus(-201); 
    exit(EX_NOPERM);
  }
  
  setuid(0);
    
  if(argc < 3 || argv[1] == NULL || argv[2] == NULL) {
    NSLog(@"ERROR: Not enough arguments");
    printStatus(-202);
    exit(EX_USAGE);
  }
    
  NSString* modeString = [NSString stringWithUTF8String: argv[2]];
  // We'll need the controlling UID to know what defaults database to search
  // It's a signed long long int to avoid integer overflow with extra-long UIDs
  signed long long int controllingUID = [[NSString stringWithUTF8String: argv[1]] longLongValue];
  
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
  NSDictionary* curLockDict = [NSDictionary dictionaryWithContentsOfFile: SelfControlLockFilePath];
  if(!([[curLockDict objectForKey: @"HostBlacklist"] count] <= 0))
    domainList = [curLockDict objectForKey: @"HostBlacklist"];
            
  // You'll see this pattern several times in this file.  The two resets and
  // set of euid to the controlling UID are necessary in order to successfully
  // return the NSUserDefaults object for the controlling user.  Also note that
  // the defaults object cannot be simply kept in a variable and repeatedly
  // referred to, the resets will invalidate it.  For now, we're just re-registering
  // the default settings, since they don't carry over from the main application.
  // TODO: Factor this code out into a functionf
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
                               [NSNumber numberWithBool: YES], @"AllowLocalNetworks",
                               [NSNumber numberWithInt: 1440], @"MaxBlockLength",
                               [NSNumber numberWithInt: 15], @"BlockLengthInterval",
                               [NSNumber numberWithBool: NO], @"WhitelistAlertSuppress",
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
    
    NSString* plistFormatString = [NSString stringWithContentsOfFile: plistFormatPath  encoding: NSUTF8StringEncoding error: NULL];
    
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
    
    if(![fileManager copyPath: [NSString stringWithCString: argv[0] encoding: NSUTF8StringEncoding]
                             toPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl"
                              handler: NULL]) {
      NSLog(@"ERROR: Could not copy SelfControl's helper binary to PrivilegedHelperTools directory.");
      printStatus(-208);
      exit(EX_IOERR);
    }
    
    if([fileManager fileExistsAtPath: @"/Library/PrivilegedHelperTools/scheckup"]) {
      if(![fileManager removeFileAtPath: @"/Library/PrivilegedHelperTools/scheckup" handler: nil]) {
        NSLog(@"WARNING: Could not delete old scheckup binary.");
      }
    }    
    
    NSString* scheckupPath = [[NSString stringWithUTF8String: argv[0]] stringByDeletingLastPathComponent];
    scheckupPath = [scheckupPath stringByAppendingPathComponent: @"scheckup"];
    
    if(![fileManager copyPath: scheckupPath
                       toPath: @"/Library/PrivilegedHelperTools/scheckup"
                      handler: NULL]) {
      NSLog(@"WARNING: Could not copy scheckup to PrivilegedHelperTools directory.");
    }
    
    // Let's set up our backup system -- give scheckup the SUID bit
    NSDictionary* checkupAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSNumber numberWithInt: 0], NSFileOwnerAccountID,
                                       [NSNumber numberWithLongLong: controllingUID], NSFileGroupOwnerAccountID,
                                       // 2541 (decimal) = 4755 (octal) = rwsr-xr-x
                                       [NSNumber numberWithUnsignedLong: 2541], NSFilePosixPermissions,
                                       nil];    
    
    if(![[NSFileManager defaultManager] changeFileAttributes: checkupAttributes atPath: @"/Library/PrivilegedHelperTools/scheckup"]) {
      NSLog(@"WARNING: Could not change file attributes on scheckup.  Backup block-removal system may not work.");
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
    if([fileManager fileExistsAtPath: SelfControlLockFilePath]) {
      NSLog(@"ERROR: Lock already established.  Attempting to stop block.");

      removeBlock(controllingUID);
      
      printStatus(-219);
      exit(EX_CONFIG);
    }
    
    // And write out our lock...
    if(![lockDictionary writeToFile: SelfControlLockFilePath atomically: YES]) {
      NSLog(@"ERROR: Could not write lock file.");
      printStatus(-216);
      exit(EX_IOERR);      
    }
    // Make sure the privileges are correct on our lock file
    [fileManager changeFileAttributes: fileAttributes atPath: SelfControlLockFilePath];
        
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
    // So you think you can rid yourself of SelfControl just like that?
    NSLog(@"INFO: Nice try.");
    printStatus(-212);
    exit(EX_UNAVAILABLE);
   } else if([modeString isEqual: @"--refresh"]) {
    // Check what the current block is (based on the lock file) because if possible
    // we want to keep most of its information.
    NSDictionary* curDictionary = [NSDictionary dictionaryWithContentsOfFile: SelfControlLockFilePath];
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
    
    if(![newLockDictionary writeToFile: SelfControlLockFilePath atomically: YES]) {
      NSLog(@"ERROR: Could not write lock file.");
      printStatus(-217);
      exit(EX_IOERR);      
    }
    // Make sure the privileges are correct on our lock file
    [[NSFileManager defaultManager] changeFileAttributes: fileAttributes atPath: SelfControlLockFilePath];    
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
    NSDictionary* curDictionary = [NSDictionary dictionaryWithContentsOfFile: SelfControlLockFilePath];
    
    NSDate* blockStartedDate = [curDictionary objectForKey: @"BlockStartedDate"];
    NSTimeInterval blockDuration = [[curDictionary objectForKey: @"BlockDuration"] intValue];
    
    if(blockStartedDate == nil || [[NSDate distantFuture] isEqualToDate: blockStartedDate] || blockDuration < 1) {    
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
      
      if(blockStartedDate == nil || blockDuration < 1) {    
          // Defaults is broken too!  Let's get out of here!
        NSLog(@"ERROR: Checkup ran but no block found.  Attempting to remove block.");
        
        // get rid of this block
        removeBlock(controllingUID);
        
        printStatus(-215);
        exit(EX_SOFTWARE);
      }
    }

    // convert to seconds
    blockDuration *= 60;

    NSTimeInterval timeSinceStarted = [[NSDate date] timeIntervalSinceDate: blockStartedDate];
    
    // Note there are a few extra possible conditions on this if statement, this
    // makes it more likely that an improperly applied block might come right
    // off.
    if( blockStartedDate == nil || blockDuration < 1 || [[NSDate distantFuture] isEqualToDate: blockStartedDate] || timeSinceStarted >= blockDuration) {
      NSLog(@"INFO: Checkup ran, block expired, removing block.");            
      
      removeBlock(controllingUID);
      
      // Execution should never reach this point.  Launchd unloading the job in removeBlock()
      // should have killed this process.
      printStatus(-216);
      exit(EX_SOFTWARE);
    } else {
      // The block is still on.  Check if anybody removed our rules, and if so
      // re-add them.  Also make sure the user's defaults are set to the correct
      // settings just in case.
      IPFirewall* firewall = [[IPFirewall alloc] init];
      if(![firewall containsSelfControlBlockSet]) { 
        // The firewall is missing at least the block header.  Let's clear everything
        // before we re-add to make sure everything goes smoothly.
        
        HostFileBlocker* hostFileBlocker = [[[HostFileBlocker alloc] init] autorelease];
        [hostFileBlocker removeSelfControlBlock];
        BOOL success = [hostFileBlocker writeNewFileContents];
        // Revert the host file blocker's file contents to disk so we can check
        // whether or not it still contains the block (aka we messed up).
        [hostFileBlocker revertFileContentsToDisk];
        [firewall clearSelfControlBlockRuleSet];
        if(!success || [hostFileBlocker containsSelfControlBlock]) {
          NSLog(@"WARNING: Error removing host file block.  Attempting to restore backup.");
          
          if([hostFileBlocker restoreBackupHostsFile])
            NSLog(@"INFO: Host file backup restored.");
          else 
            NSLog(@"ERROR: Host file backup could not be restored.  This may result in a permanent block.");
        }
        
        // Get rid of the backup file since we're about to make a new one.
        [hostFileBlocker deleteBackupHostsFile];        
        
        // Perform the re-add of the rules
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
      [defaults setObject: [NSNumber numberWithInt: (blockDuration / 60)] forKey: @"BlockDuration"];
      [defaults setObject: domainList forKey: @"HostBlacklist"];
      [defaults synchronize];
      [NSUserDefaults resetStandardUserDefaults];
      seteuid(0);
    }
  }

  // by putting printStatus first (which tells the app we didn't crash), we fake it to
  // avoid memory-managment crashes (calling [pool drain] is essentially optional)
  printStatus(0);

  [pool drain];
  exit(EXIT_SUCCESS);
}