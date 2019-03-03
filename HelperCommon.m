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
#import "SCBlockDateUtilities.h"
#import "SCSettings.h"

void addRulesToFirewall(uid_t controllingUID) {
    SCSettings* settings = [SCSettings settingsForUser: controllingUID];
    BOOL shouldEvaluateCommonSubdomains = [[settings valueForKey: @"EvaluateCommonSubdomains"] boolValue];
	BOOL allowLocalNetworks = [[settings valueForKey: @"AllowLocalNetworks"] boolValue];
	BOOL includeLinkedDomains = [[settings valueForKey: @"IncludeLinkedDomains"] boolValue];

	// get value for BlockAsWhitelist
	BOOL blockAsWhitelist = [[settings valueForKey: @"BlockAsWhitelist"] boolValue];

	BlockManager* blockManager = [[BlockManager alloc] initAsWhitelist: blockAsWhitelist allowLocal: allowLocalNetworks includeCommonSubdomains: shouldEvaluateCommonSubdomains includeLinkedDomains: includeLinkedDomains];

	[blockManager prepareToAddBlock];
	[blockManager addBlockEntries: [settings valueForKey: @"Blocklist"]];
	[blockManager finalizeBlock];

}

void removeRulesFromFirewall(uid_t controllingUID) {
	// options don't really matter because we're only using it to clear
	BlockManager* blockManager = [[BlockManager alloc] init];
	[blockManager clearBlock];

	// We'll play the sound now rather than earlier, because
	//  it is important that the UI get updated (by the posted
	//  notification) before we sleep to play the sound.  Otherwise,
	// the app seems unresponsive and slow.
    SCSettings* settings = [SCSettings settingsForUser: controllingUID];
    if([[settings valueForKey: @"BlockSoundShouldPlay"] boolValue]) {
		// Map the tags used in interface builder to the sound
		NSArray* systemSoundNames = @[@"Basso",
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
									  @"Tink"];
        NSSound* alertSound = [NSSound soundNamed: systemSoundNames[[[settings valueForKey: @"BlockSound"] intValue]]];
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
					[evaluatedAddresses addObject: [NSString stringWithFormat: @"%@:%d", addresses[j], port]];
				else [evaluatedAddresses addObject: addresses[j]];
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
					[evaluatedAddresses addObject: [NSString stringWithFormat: @"%@:%d", addresses[j], port]];
				else [evaluatedAddresses addObject: addresses[j]];
			}
		}
	}

	return evaluatedAddresses;
}

void clearCachesIfRequested(uid_t controllingUID) {
    SCSettings* settings = [SCSettings settingsForUser: controllingUID];
	if([[settings valueForKey: @"ClearCaches"] boolValue]) {
		NSFileManager* fileManager = [NSFileManager defaultManager];

		NSTask* task = [[NSTask alloc] init];
		[task setLaunchPath: @"/usr/bin/getconf"];
		[task setArguments: @[@"DARWIN_USER_CACHE_DIR"]];
		NSPipe* inPipe = [[NSPipe alloc] init];
		NSFileHandle* readHandle = [inPipe fileHandleForReading];
		[task setStandardOutput: inPipe];
		[task launch];
		NSString* leopardCacheDirectory = [[NSString alloc] initWithData:[readHandle readDataToEndOfFile]
																encoding: NSUTF8StringEncoding];
		close([readHandle fileDescriptor]);
		[task waitUntilExit];

		leopardCacheDirectory = [leopardCacheDirectory stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

		if([task terminationStatus] == 0 && [leopardCacheDirectory length] > 0) {
			NSMutableArray* leopardCacheDirs = [NSMutableArray arrayWithObjects:
												@"com.apple.Safari",
												nil];
			for(int i = 0; i < [leopardCacheDirs count]; i++) {
				NSString* cacheDir = [leopardCacheDirectory stringByAppendingPathComponent: leopardCacheDirs[i]];
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
			NSString* cacheDir = [userLibraryDirectory stringByAppendingPathComponent: cacheDirs[i]];
			if([fileManager isDeletableFileAtPath: cacheDir]) {
				[fileManager removeItemAtPath: cacheDir error: nil];
			}
		}
	}
}

void printStatus(int status) {
	printf("%d", status);
	fflush(stdout);
}

void removeBlock(uid_t controllingUID) {
    [SCBlockDateUtilities removeBlockFromSettingsForUID: controllingUID];
	removeRulesFromFirewall(controllingUID);
    
    // go ahead and remove any remaining legacy block info at the same time to avoid confusion
    // (and migrate them to the new SCSettings system if not already migrated)
    [[SCSettings settingsForUser: controllingUID] clearLegacySettings];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
																   object: nil];
	clearCachesIfRequested(controllingUID);

	NSLog(@"INFO: Block cleared.");

	[LaunchctlHelper unloadLaunchdJobWithPlistAt:@"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
}
