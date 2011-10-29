/*
 *  HelperCommonFunctions.c
 *  SelfControl
 *
 *  Created by Charlie Stigler on 7/13/10.
 *  Copyright 2010 Harvard-Westlake Student. All rights reserved.
 *
 */

#include "HelperCommon.h"

void addRulesToFirewall(signed long long int controllingUID) {
  // Note all arrays in the host blocking code were changed to sets to easily stop duplicates
  NSMutableSet* hostsToBlock = [NSMutableSet set];

  [NSUserDefaults resetStandardUserDefaults];
  seteuid(controllingUID);
  defaults = [NSUserDefaults standardUserDefaults];
  [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
  BOOL shouldEvaluateCommonSubdomains = [[defaults objectForKey: @"EvaluateCommonSubdomains"] boolValue];
  [defaults synchronize];
  [NSUserDefaults resetStandardUserDefaults];
  seteuid(0);

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
  NSDictionary* curDictionary = [NSDictionary dictionaryWithContentsOfFile: SelfControlLockFilePath];

  if(curDictionary == nil || [curDictionary objectForKey: @"BlockAsWhitelist"] == nil) {
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(controllingUID);
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
    blockAsWhitelist = [defaults boolForKey: @"BlockAsWhitelist"];
    [defaults synchronize];
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);
  }
  else
    blockAsWhitelist = [[curDictionary objectForKey: @"BlockAsWhitelist"] boolValue];

  // /etc/hosts blocking
  if(!blockAsWhitelist) {
    HostFileBlocker* hostFileBlocker = [[[HostFileBlocker alloc] init] autorelease];
    if(![hostFileBlocker containsSelfControlBlock] && [hostFileBlocker createBackupHostsFile]) {
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
          if ([regexTester evaluateWithObject: hostName] != YES) {
            // It's not an IP, so we'll add it to the /etc/hosts block as well
            [hostFileBlocker addRuleBlockingDomain: hostName];

            // If we're supposed to evaluate common subdomains, block www subdomain also
            if(shouldEvaluateCommonSubdomains) {
              // Block the normal domain if www. was added
              if([hostName rangeOfString: @"www."].location == 0)
                [hostFileBlocker addRuleBlockingDomain: [hostName substringFromIndex: 4]];

              // Or block www.domain otherwise
              else
                [hostFileBlocker addRuleBlockingDomain: [@"www." stringByAppendingString: hostName]];
            }
          }
        }
      }
      [hostFileBlocker addSelfControlBlockFooter];
      [hostFileBlocker writeNewFileContents];
    } else if([hostFileBlocker containsSelfControlBlock]) {
      [hostFileBlocker removeSelfControlBlock];
      [hostFileBlocker writeNewFileContents];
    } else {
      NSLog(@"WARNING: Could not create backup file.  Giving up on host file blocking.");
    }
  }

  IPFirewall* firewall = [[IPFirewall alloc] init];
  [firewall clearSelfControlBlockRuleSet];
  [firewall addSelfControlBlockHeader];

  if(blockAsWhitelist) {
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(controllingUID);
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
    BOOL allowLocalNetworks = [defaults boolForKey: @"AllowLocalNetworks"];
    [defaults synchronize];
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);
    if(allowLocalNetworks) {
      [firewall addSelfControlBlockRuleAllowingIP: @"10.0.0.0" maskLength: 8];
      [firewall addSelfControlBlockRuleAllowingIP: @"172.16.0.0" maskLength: 12];
      [firewall addSelfControlBlockRuleAllowingIP: @"192.168.0.0" maskLength: 16];
    }
  }

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

void removeRulesFromFirewall(signed long long int controllingUID) {
  IPFirewall* firewall = [[IPFirewall alloc] init];
  if(![firewall containsSelfControlBlockSet])
    NSLog(@"WARNING: SelfControl rules do not appear to be loaded into ipfw.");
  HostFileBlocker* hostFileBlocker = [[[HostFileBlocker alloc] init] autorelease];
  [hostFileBlocker removeSelfControlBlock];
  BOOL hostSuccess = [hostFileBlocker writeNewFileContents];
  // Revert the host file blocker's file contents to disk so we can check
  // whether or not it still contains the block (aka we messed up).
  [hostFileBlocker revertFileContentsToDisk];
  // We use ! (NOT) of the method as success because it returns a shell termination status, so 0 is the success code
  BOOL ipfwSuccess = ![firewall clearSelfControlBlockRuleSet];
  if(hostSuccess && ipfwSuccess && ![hostFileBlocker containsSelfControlBlock] && ![firewall containsSelfControlBlockSet])
    NSLog(@"INFO: Hostfile block successfully cleared.");
  else {
    NSLog(@"WARNING: Error removing hostfile block.  Attempting to restore host file backup.");

    [firewall clearSelfControlBlockRuleSet];

    if([hostFileBlocker restoreBackupHostsFile])
      NSLog(@"INFO: Host file backup restored.");
    else if([hostFileBlocker containsSelfControlBlock])
      NSLog(@"ERROR: Host file backup could not be restored.  This may result in a permanent block.");
    else if([firewall containsSelfControlBlockSet])
      NSLog(@"ERROR: Firewall rules could not be cleared.  This may result in a permanent block.");
    else
      NSLog(@"INFO: Firewall rules successfully cleared.");
  }

  [hostFileBlocker deleteBackupHostsFile];

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

  //  } else
  //    NSLog(@"WARNING: SelfControl rules do not appear to be loaded into ipfw.");
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

void clearCachesIfRequested(signed long long int controllingUID) {
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

void removeBlock(signed long long int controllingUID) {
  [NSUserDefaults resetStandardUserDefaults];
  seteuid(controllingUID);
  defaults = [NSUserDefaults standardUserDefaults];
  [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
  [defaults setObject: [NSDate distantFuture] forKey: @"BlockStartedDate"];
  [defaults synchronize];
  [NSUserDefaults resetStandardUserDefaults];
  seteuid(0);

  removeRulesFromFirewall(controllingUID);

  if(![[NSFileManager defaultManager] removeFileAtPath: SelfControlLockFilePath handler: nil] && [[NSFileManager defaultManager] fileExistsAtPath: SelfControlLockFilePath]) {
    NSLog(@"ERROR: Could not remove SelfControl lock file.");
    printStatus(-218);
  }

  [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                                 object: nil];

  clearCachesIfRequested(controllingUID);

  NSLog(@"INFO: Block cleared.");

  [LaunchctlHelper unloadLaunchdJobWithPlistAt:@"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
}