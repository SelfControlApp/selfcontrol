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
#import "SCSettings.h"
#import <ServiceManagement/ServiceManagement.h>

void installBlockRulesFromSettings() {
    SCSettings* settings = [SCSettings sharedSettings];
    BOOL shouldEvaluateCommonSubdomains = [settings boolForKey: @"EvaluateCommonSubdomains"];
	BOOL allowLocalNetworks = [settings boolForKey: @"AllowLocalNetworks"];
	BOOL includeLinkedDomains = [settings boolForKey: @"IncludeLinkedDomains"];

	// get value for ActiveBlockAsWhitelist
	BOOL blockAsAllowlist = [settings boolForKey: @"ActiveBlockAsWhitelist"];

	BlockManager* blockManager = [[BlockManager alloc] initAsAllowlist: blockAsAllowlist allowLocal: allowLocalNetworks includeCommonSubdomains: shouldEvaluateCommonSubdomains includeLinkedDomains: includeLinkedDomains];

    NSLog(@"About to run BlockManager commands");
    
	[blockManager prepareToAddBlock];
	[blockManager addBlockEntries: [settings valueForKey: @"ActiveBlocklist"]];
	[blockManager finalizeBlock];

}

void uninstallBlockRules() {
	// options don't really matter because we're only using it to clear
	BlockManager* blockManager = [[BlockManager alloc] init];
	[blockManager clearBlock];

	// We'll play the sound now rather than earlier, because
	//  it is important that the UI get updated (by the posted
	//  notification) before we sleep to play the sound.  Otherwise,
	// the app seems unresponsive and slow.
    SCSettings* settings = [SCSettings sharedSettings];
    if([settings boolForKey: @"BlockSoundShouldPlay"]) {
		// Map the tags used in interface builder to the sound
        NSArray* systemSoundNames = SCConstants.systemSoundNames;
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

void clearCachesIfRequested() {
    SCSettings* settings = [SCSettings sharedSettings];
    if(![settings boolForKey: @"ClearCaches"]) {
        return;
    }
    
    NSError* err = [SCHelperToolUtilities clearBrowserCaches];
    if (err) {
        NSLog(@"WARNING: Error clearing browser caches: %@", err);
        [SCSentry captureError: err];
    }

    [SCHelperToolUtilities clearOSDNSCache];
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

void removeBlock() {
    SCSettings* settings = [SCSettings sharedSettings];

    [SCBlockUtilities removeBlockFromSettings];
	[SCHelperToolUtilities uninstallBlockRules];
        
    // always synchronize settings ASAP after removing a block to let everybody else know
    [settings synchronizeSettings];

    // let the main app know things have changed so it can update the UI!
    [SCHelperToolUtilities sendConfigurationChangedNotification];

    NSLog(@"INFO: Block cleared.");
    
    [SCHelperToolUtilities clearCachesIfRequested];
}

void sendConfigurationChangedNotification() {
    // if you don't include the NSNotificationPostToAllSessions option,
    // it will not deliver when run by launchd (root) to the main app being run by the user
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                                   object: nil
                                                                 userInfo: nil
                                                                  options: NSNotificationDeliverImmediately | NSNotificationPostToAllSessions];
}
