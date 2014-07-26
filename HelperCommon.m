/*
 *  HelperCommonFunctions.c
 *  SelfControl
 *
 *  Created by Charlie Stigler on 7/13/10.
 *  Copyright 2010 Harvard-Westlake Student. All rights reserved.
 *
 */

#include "HelperCommon.h"
#include "BlockManager.h"

void registerDefaults(signed long long int controllingUID) {
	[NSUserDefaults resetStandardUserDefaults];
	seteuid(controllingUID);
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults addSuiteNamed: @"org.eyebeam.SelfControl"];
	[defaults synchronize];
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
	[defaults synchronize];
	seteuid(0);
}
NSDictionary* getDefaultsDict(signed long long int controllingUID) {
	[NSUserDefaults resetStandardUserDefaults];
	seteuid(controllingUID);
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults addSuiteNamed: @"org.eyebeam.SelfControl"];
	[defaults synchronize];
	NSDictionary* dict = [defaults dictionaryRepresentation];
	seteuid(0);
	return dict;
}
void setDefaultsValue(NSString* prefName, NSString* prefValue, signed long long int controllingUID) {
	seteuid(controllingUID);
	CFPreferencesSetAppValue((__bridge CFStringRef)prefName, prefValue, (__bridge CFStringRef)@"org.eyebeam.SelfControl");
	CFPreferencesAppSynchronize((__bridge CFStringRef)@"org.eyebeam.SelfControl");
	seteuid(0);
}

void addRulesToFirewall(signed long long int controllingUID) {
  // get value for EvaluateCommonSubdomains
	NSDictionary* defaults = getDefaultsDict(controllingUID);
	BOOL shouldEvaluateCommonSubdomains = [[defaults objectForKey: @"EvaluateCommonSubdomains"] boolValue];
  BOOL allowLocalNetworks = [[defaults objectForKey: @"AllowLocalNetworks"] boolValue];

  // get value for BlockAsWhitelist
  BOOL blockAsWhitelist;
  NSDictionary* curDictionary = [NSDictionary dictionaryWithContentsOfFile: SelfControlLockFilePath];
  if(curDictionary == nil || [curDictionary objectForKey: @"BlockAsWhitelist"] == nil) {
    blockAsWhitelist = [[defaults objectForKey: @"BlockAsWhitelist"] boolValue];
  } else {
    blockAsWhitelist = [[curDictionary objectForKey: @"BlockAsWhitelist"] boolValue];
  }
  
  BlockManager* blockManager = [[BlockManager alloc] initAsWhitelist: blockAsWhitelist allowLocal: allowLocalNetworks includeCommonSubdomains: shouldEvaluateCommonSubdomains];
  
  [blockManager prepareToAddBlock];
  [blockManager addBlockEntries: domainList];
  [blockManager finalizeBlock];

  [blockManager release];
}

void removeRulesFromFirewall(signed long long int controllingUID) {
	// options don't really matter because we're only using it to clear
  BlockManager* blockManager = [[BlockManager alloc] initAsWhitelist: FALSE allowLocal: TRUE includeCommonSubdomains: TRUE];
	[blockManager clearBlock];
	[blockManager release];
  
  // We'll play the sound now rather than putting it in the "defaults block"
  // a few lines ago, because it is important that the UI get updated (by
  // the posted notification) before we sleep to play the sound.  Otherwise,
  // the app seems unresponsive and slow.
	NSDictionary* defaults = getDefaultsDict(controllingUID);
  if([[defaults objectForKey: @"BlockSoundShouldPlay"] boolValue]) {
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
    NSSound* alertSound = [NSSound soundNamed: [systemSoundNames objectAtIndex: [[defaults objectForKey: @"BlockSound"] intValue]]];
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
	NSDictionary* defaults = getDefaultsDict(controllingUID);
  if([[defaults objectForKey: @"ClearCaches"] boolValue]) {
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
                                            @"com.apple.Safari",
                                            nil];
        for(int i = 0; i < [leopardCacheDirs count]; i++) {
          NSString* cacheDir = [leopardCacheDirectory stringByAppendingPathComponent: [leopardCacheDirs objectAtIndex: i]];
          if([fileManager isDeletableFileAtPath: cacheDir]) {
            [fileManager removeItemAtPath: cacheDir error: nil];
          }
        }
      }
      
      // NSArray* userCacheDirectories = NSSearchPathForDirectoriesInDomain(NSCachesDirectory, NSUserDomainMask, NO);
      // I have no clue why this doesn't compile, I'm #importing properly I believe.
      // We'll have to do it the messy way...
      
      NSString* userLibraryDirectory = [@"~/Library" stringByExpandingTildeInPath];
      NSMutableArray* cacheDirs = [NSMutableArray arrayWithObjects:
                                   @"Caches/com.apple.Safari",
                                   nil];
      
      for(int i = 0; i < [cacheDirs count]; i++) {
        NSString* cacheDir = [userLibraryDirectory stringByAppendingPathComponent: [cacheDirs objectAtIndex: i]];
        if([fileManager isDeletableFileAtPath: cacheDir]) {
          [fileManager removeItemAtPath: cacheDir error: nil];
        }
      }
      
    }
  }
}

void printStatus(int status) {
  printf("%d", status);
  fflush(stdout);
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
	setDefaultsValue(@"BlockStartedDate", [NSDate distantFuture], controllingUID);

  removeRulesFromFirewall(controllingUID);
  
  if(![[NSFileManager defaultManager] removeItemAtPath: SelfControlLockFilePath error: nil] && [[NSFileManager defaultManager] fileExistsAtPath: SelfControlLockFilePath]) {
    NSLog(@"ERROR: Could not remove SelfControl lock file.");
    printStatus(-218);
  }
  
  [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                                 object: nil];
  
  clearCachesIfRequested(controllingUID);
  
  NSLog(@"INFO: Block cleared.");
  
  [LaunchctlHelper unloadLaunchdJobWithPlistAt:@"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];  
}