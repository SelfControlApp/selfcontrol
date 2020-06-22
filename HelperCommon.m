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
#import "SCSettings.h"
#import "SCConstants.h"

BOOL blockIsRunningInSettingsOrDefaults(uid_t controllingUID) {
    SCSettings* settings = [SCSettings settingsForUser: controllingUID];

    // pull up the user's defaults to check for the existence of a legacy block
    // to do that, we have to seteuid to the controlling UID so NSUserDefaults thinks we're them
    seteuid(controllingUID);
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed: @"org.eyebeam.SelfControl"];
    [defaults synchronize];
    
    BOOL response = [SCUtilities blockIsRunningWithSettings: settings defaults: defaults];
    
    // reset the euid so nothing else gets funky
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);
    
    return response;
}

void addRulesToFirewall(uid_t controllingUID) {
    SCSettings* settings = [SCSettings settingsForUser: controllingUID];
    BOOL shouldEvaluateCommonSubdomains = [[settings valueForKey: @"EvaluateCommonSubdomains"] boolValue];
	BOOL allowLocalNetworks = [[settings valueForKey: @"AllowLocalNetworks"] boolValue];
	BOOL includeLinkedDomains = [[settings valueForKey: @"IncludeLinkedDomains"] boolValue];

	// get value for BlockAsWhitelist
	BOOL blockAsAllowlist = [[settings valueForKey: @"BlockAsWhitelist"] boolValue];

	BlockManager* blockManager = [[BlockManager alloc] initAsAllowlist: blockAsAllowlist allowLocal: allowLocalNetworks includeCommonSubdomains: shouldEvaluateCommonSubdomains includeLinkedDomains: includeLinkedDomains];

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
        NSArray* systemSoundNames = [SCConstants systemSoundNames];
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
    if(![[settings valueForKey: @"ClearCaches"] boolValue]) {
        return;
    }
    
    clearBrowserCaches(controllingUID);
    clearOSDNSCache();
}

void clearBrowserCaches(uid_t controllingUID) {
    NSFileManager* fileManager = [NSFileManager defaultManager];

    // need to seteuid so the tilde expansion will work properly
    seteuid(controllingUID);
    NSString* libraryDirectoryExpanded = [@"~/Library" stringByExpandingTildeInPath];
    seteuid(0);

    NSArray<NSString*>* cacheDirs = @[
        // chrome
        @"/Caches/Google/Chrome/Default",
        @"/Caches/Google/Chrome/com.google.Chrome",
        
        // firefox
        @"/Caches/Firefox/Profiles",
        
        // safari
        @"/Caches/com.apple.Safari",
        @"/Containers/com.apple.Safari/Data/Library/Caches" // this one seems to fail due to permissions issues, but not sure how to fix
    ];
    for (NSString* cacheDir in cacheDirs) {
        NSString* absoluteCacheDir = [libraryDirectoryExpanded stringByAppendingString: cacheDir];
        NSLog(@"Clearing browser cache folder %@", absoluteCacheDir);
        [fileManager removeItemAtPath: absoluteCacheDir error: nil];
    }
}

void clearOSDNSCache() {
    // no error checks - if it works it works!
    NSTask* flushDsCacheUtil = [[NSTask alloc] init];
    [flushDsCacheUtil setLaunchPath: @"/usr/bin/dscacheutil"];
    [flushDsCacheUtil setArguments: @[@"-flushcache"]];
    [flushDsCacheUtil launch];
    [flushDsCacheUtil waitUntilExit];
    
    NSTask* killResponder = [[NSTask alloc] init];
    [killResponder setLaunchPath: @"/usr/bin/killall"];
    [killResponder setArguments: @[@"-HUP", @"mDNSResponder"]];
    [killResponder launch];
    [killResponder waitUntilExit];
    
    NSTask* killResponderHelper = [[NSTask alloc] init];
    [killResponderHelper setLaunchPath: @"/usr/bin/killall"];
    [killResponderHelper setArguments: @[@"mDNSResponderHelper"]];
    [killResponderHelper launch];
    [killResponderHelper waitUntilExit];
    
    NSLog(@"Cleared OS DNS caches");
}

void printStatus(int status) {
	printf("%d", status);
	fflush(stdout);
}

void removeBlock(uid_t controllingUID) {
    SCSettings* settings = [SCSettings settingsForUser: controllingUID];

    [SCUtilities removeBlockFromSettingsForUID: controllingUID];
	removeRulesFromFirewall(controllingUID);
    
    // go ahead and remove any remaining legacy block info at the same time to avoid confusion
    // (and migrate them to the new SCSettings system if not already migrated)
    [settings clearLegacySettings];
    
    // always synchronize settings ASAP after removing a block to let everybody else know
    [settings synchronizeSettings];

    // let the main app know things have changed so it can update the UI!
    sendConfigurationChangedNotification();

    NSLog(@"INFO: Block cleared.");
    
    clearCachesIfRequested(controllingUID);
    
    // the final step is to unload the launchd job
    // this will kill this process, so we have to make sure
    // all settings are synced before we unload
    [settings synchronizeSettingsWithCompletion:^(NSError* err) {
        if (err != nil) {
            NSLog(@"WARNING: Settings failed to synchronize before unloading block, with error %@", err);
        }
        
        [LaunchctlHelper unloadLaunchdJobWithPlistAt:@"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
    }];
        
    // wait 5 seconds. assuming the synchronization completes during that time,
    // it'll unload the launchd job for us and we'll never get to the other side of this wait
    sleep(5);
        
    // uh-oh, looks like it's 5 seconds later and the sync hasn't completed yet. Bad news.
    NSLog(@"WARNING: Settings sync timed out before unloading block");
    [LaunchctlHelper unloadLaunchdJobWithPlistAt:@"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
}

void sendConfigurationChangedNotification() {
    // if you don't include the NSNotificationPostToAllSessions option,
    // it will not deliver when run by launchd (root) to the main app being run by the user
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                                   object: nil
                                                                 userInfo: nil
                                                                  options: NSNotificationDeliverImmediately | NSNotificationPostToAllSessions];
}

void syncSettingsAndExit(SCSettings* settings, int status) {
    // this should always be run on the main thread so it blocks main()
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            syncSettingsAndExit(settings, status);
        });
    }

    [settings synchronizeSettingsWithCompletion:^(NSError* err) {
        if (err != nil) {
            NSLog(@"WARNING: Settings failed to synchronize before exit, with error %@", err);
        }
        
        exit(status);
    }];
        
    // wait 5 seconds. assuming the synchronization completes during that time,
    // it'll exit() for us and we'll never get to the other side of this wait
    sleep(5);
        
    // uh-oh, looks like it's 5 seconds later and the sync hasn't completed yet. Bad news.
    NSLog(@"WARNING: Settings sync timed out before exiting");
    
    exit(status);
}
