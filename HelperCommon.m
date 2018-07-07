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
#import "SCUtilities.h"
#import "SCUtilities+HelperTools.h"

NSDictionary* getAppDefaultsDictionary() {
    return @{@"BlockDuration": @15,
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
}

void registerDefaults(uid_t controllingUID) {
	[NSUserDefaults resetStandardUserDefaults];
	seteuid(controllingUID);
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults addSuiteNamed: @"org.eyebeam.SelfControl"];
	[defaults synchronize];
	[defaults registerDefaults: getAppDefaultsDictionary()];
	[defaults synchronize];
	seteuid(0);
}
NSDictionary* getDefaultsDict(uid_t controllingUID) {
	[NSUserDefaults resetStandardUserDefaults];
	seteuid(controllingUID);
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults addSuiteNamed: @"org.eyebeam.SelfControl"];
	[defaults synchronize];

	// in the 10.13 High Sierra public beta (as of build 17A291m) registering defaults needs to be done immediately
	// before pulling the dictionary representation, or the default values won't be returned (we'll get nils instead and crash)
	[defaults registerDefaults: getAppDefaultsDictionary()];

	NSDictionary* dict = [defaults dictionaryRepresentation];
	[NSUserDefaults resetStandardUserDefaults];
	seteuid(0);
	return dict;
}
void setDefaultsValue(NSString* prefName, id prefValue, uid_t controllingUID) {
	[NSUserDefaults resetStandardUserDefaults];
	seteuid(controllingUID);
	CFPreferencesSetAppValue((__bridge CFStringRef)prefName, (__bridge CFPropertyListRef)(prefValue), (__bridge CFStringRef)@"org.eyebeam.SelfControl");
	CFPreferencesAppSynchronize((__bridge CFStringRef)@"org.eyebeam.SelfControl");
	[NSUserDefaults resetStandardUserDefaults];
	seteuid(0);
}

void addRulesToFirewall(uid_t controllingUID) {
	// get value for EvaluateCommonSubdomains
	NSDictionary* defaults = getDefaultsDict(controllingUID);
	BOOL shouldEvaluateCommonSubdomains = [defaults[@"EvaluateCommonSubdomains"] boolValue];
	BOOL allowLocalNetworks = [defaults[@"AllowLocalNetworks"] boolValue];
	BOOL includeLinkedDomains = [defaults[@"IncludeLinkedDomains"] boolValue];

	// get value for BlockAsWhitelist
	BOOL blockAsWhitelist;
	NSDictionary* curDictionary = [NSDictionary dictionaryWithContentsOfFile: SelfControlLockFilePath];
	if(curDictionary == nil || curDictionary[@"BlockAsWhitelist"] == nil) {
		blockAsWhitelist = [defaults[@"BlockAsWhitelist"] boolValue];
	} else {
		blockAsWhitelist = [curDictionary[@"BlockAsWhitelist"] boolValue];
	}

	BlockManager* blockManager = [[BlockManager alloc] initAsWhitelist: blockAsWhitelist allowLocal: allowLocalNetworks includeCommonSubdomains: shouldEvaluateCommonSubdomains includeLinkedDomains: includeLinkedDomains];

	[blockManager prepareToAddBlock];
	[blockManager addBlockEntries: domainList];
	[blockManager finalizeBlock];

}

void removeRulesFromFirewall(uid_t controllingUID) {
	// options don't really matter because we're only using it to clear
	BlockManager* blockManager = [[BlockManager alloc] init];
	[blockManager clearBlock];

	// We'll play the sound now rather than putting it in the "defaults block"
	// a few lines ago, because it is important that the UI get updated (by
	// the posted notification) before we sleep to play the sound.  Otherwise,
	// the app seems unresponsive and slow.
	NSDictionary* defaults = getDefaultsDict(controllingUID);
	if([defaults[@"BlockSoundShouldPlay"] boolValue]) {
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
		NSSound* alertSound = [NSSound soundNamed: systemSoundNames[[defaults[@"BlockSound"] intValue]]];
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
	NSDictionary* defaults = getDefaultsDict(controllingUID);
	if([defaults[@"ClearCaches"] boolValue]) {
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
    [SCUtilities removeBlockFromDefaultsForUID: controllingUID];
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
