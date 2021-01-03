//
//  SCDaemonUtilities.m
//  org.eyebeam.selfcontrold
//
//  Created by Charlie Stigler on 9/16/20.
//

#import "SCDaemonUtilities.h"
#import <ServiceManagement/ServiceManagement.h>
#import "SCSettings.h"
#import "SCUtilities.h"
#import "BlockManager.h"

@implementation SCDaemonUtilities

+ (void)unloadDaemonJobForUID:(uid_t)controllingUID {
    SCSettings* settings = [SCSettings settingsForUser: controllingUID];

    // we're about to unload the launchd job
    // this will kill this process, so we have to make sure
    // all settings are synced before we unload
    [settings synchronizeSettingsWithCompletion:^(NSError* err) {
        if (err != nil) {
            NSLog(@"WARNING: Settings failed to synchronize before unloading daemon, with error %@", err);
        }
                
        CFErrorRef cfError;
        SMJobRemove(kSMDomainSystemLaunchd, CFSTR("org.eyebeam.selfcontrold"), NULL, NO, &cfError);
        if (cfError) {
            NSLog(@"Failed to remove selfcontrold daemon with error %@", cfError);
        }
    }];
        
    // wait 5 seconds. assuming the synchronization completes during that time,
    // it'll unload the launchd job for us and we'll never get to the other side of this wait
    sleep(5);
        
    // uh-oh, looks like it's 5 seconds later and the sync hasn't completed yet. Bad news.
    NSLog(@"WARNING: Settings sync timed out before unloading block");
    CFErrorRef cfError;
    SMJobRemove(kSMDomainSystemLaunchd, CFSTR("org.eyebeam.selfcontrold"), NULL, NO, &cfError);
    if (cfError) {
        NSLog(@"Failed to remove selfcontrold daemon with error %@", cfError);
    }
}

// This method should be called when the blocklist has changed and a block is running
// to update the block to include newly added sites
// NOTE: this is a no-op for allowlist blocks (because we don't have the capability to do that),
// and when a block isn't running
// NOTE2: currently this works for _added_ sites, not removed ones, since that's all SC allows currently...
+ (void)updateActiveBlocklistForUID:(uid_t)controllingUID newBlocklist:(NSArray<NSString*>*)newBlocklist {
    SCSettings* settings = [SCSettings settingsForUser: controllingUID];
        
    if(![SCUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]) {
        NSLog(@"WARNING: Updating active blocklist but no block is running - ignoring.");
        return;
    }
    
    if ([settings boolForKey: @"ActiveBlockAsWhitelist"]) {
        NSLog(@"WARNING: Updating active blocklist but this is not possible with an allowlist block - ignoring.");
    }
    
    NSArray* activeBlocklist = [settings valueForKey: @"ActiveBlocklist"];
    NSMutableArray* added = [NSMutableArray arrayWithArray: newBlocklist];
    [added removeObjectsInArray: activeBlocklist];
    NSMutableArray* removed = [NSMutableArray arrayWithArray: activeBlocklist];
    [removed removeObjectsInArray: newBlocklist];
    
    // throw a warning if something got removed for some reason, since we ignore them
    if (removed.count > 0) {
        NSLog(@"WARNING: Active blocklist has removed items; these will not be updated. Removed items are %@", removed);
    }
    
    // TODO: add the added sites to the block via BlockManager
    BlockManager* blockManager = [[BlockManager alloc] initAsAllowlist: [settings boolForKey: @"ActiveBlockAsWhitelist"]
                                                            allowLocal: [settings boolForKey: @"EvaluateCommonSubdomains"]
                                               includeCommonSubdomains: [settings boolForKey: @"AllowLocalNetworks"]
                                                  includeLinkedDomains: [settings boolForKey: @"IncludeLinkedDomains"]];
    [blockManager enterAppendMode];
    
    [blockManager prepareToAddBlock];
//    [blockManager addBlockEntries: [settings valueForKey: @"ActiveBlocklist"]];
    [blockManager finalizeBlock];

    
    [settings setValue: blocklist forKey: @"ActiveBlocklist"];
}

@end
