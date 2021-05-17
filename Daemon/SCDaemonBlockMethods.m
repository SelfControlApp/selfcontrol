//
//  SCDaemonBlockMethods.m
//  org.eyebeam.selfcontrold
//
//  Created by Charlie Stigler on 7/4/20.
//

#import "SCDaemonBlockMethods.h"
#import "SCSettings.h"
#import "SCHelperToolUtilities.h"
#import "PacketFilter.h"
#import "BlockManager.h"
#import "SCDaemon.h"
#import "LaunchctlHelper.h"
#import "HostFileBlockerSet.h"

NSTimeInterval METHOD_LOCK_TIMEOUT = 5.0;
NSTimeInterval CHECKUP_LOCK_TIMEOUT = 0.5; // use a shorter lock timeout for checkups, because we'd prefer not to have tons pile up

@implementation SCDaemonBlockMethods

+ (NSLock*)daemonMethodLock {
    static NSLock* lock = nil;
    if (lock == nil) {
        lock = [[NSLock alloc] init];
    }
    return lock;
}

+ (BOOL)lockOrTimeout:(void(^)(NSError* error))reply timeout:(NSTimeInterval)timeout {
    // only run one request at a time, so we avoid weird situations like trying to run a checkup while we're starting a block
    if (![self.daemonMethodLock lockBeforeDate: [NSDate dateWithTimeIntervalSinceNow: timeout]]) {
        // if we couldn't get a lock within 10 seconds, something is weird
        // but we probably shouldn't still run, because that's just unexpected at that point
        // don't capture this error on Sentry because it's very usual for checkups to timeout
        NSError* err = [SCErr errorWithCode: 300];
        NSLog(@"ERROR: Timed out acquiring request lock (after %f seconds)", timeout);

        if (reply != nil) {
            reply(err);
        }
        return NO;
    }
    return YES;
}
+ (BOOL)lockOrTimeout:(void(^)(NSError* error))reply {
    return [self lockOrTimeout: reply timeout: METHOD_LOCK_TIMEOUT];
}


+ (void)startBlockWithControllingUID:(uid_t)controllingUID blocklist:(NSArray<NSString*>*)blocklist isAllowlist:(BOOL)isAllowlist endDate:(NSDate*)endDate blockSettings:(NSDictionary*)blockSettings authorization:(NSData *)authData reply:(void(^)(NSError* error))reply {
    if (![SCDaemonBlockMethods lockOrTimeout: reply]) {
        return;
    }
    
    // we reset at the _end_ of every method, but we'll also reset at the _start_ here
    // because startBlock can sometimes take a while, and it'd be a shame if the daemon killed itself
    // before we were done
    [[SCDaemon sharedDaemon] resetInactivityTimer];
    
    [SCSentry addBreadcrumb: @"Daemon method startBlock called" category: @"daemon"];
    
    if ([SCBlockUtilities anyBlockIsRunning]) {
        NSLog(@"ERROR: Can't start block since a block is already running");
        NSError* err = [SCErr errorWithCode: 301];
        [SCSentry captureError: err];
        reply(err);
        [self.daemonMethodLock unlock];
        return;
    }
    
    // clear any legacy block information - no longer useful and could potentially confuse things
    // but first, copy it over one more time (this should've already happened once in the app, but you never know)
    if ([SCMigrationUtilities legacySettingsFoundForUser: controllingUID]) {
        [SCMigrationUtilities copyLegacySettingsToDefaults: controllingUID];
        [SCMigrationUtilities clearLegacySettingsForUser: controllingUID];
        
        // if we had legacy settings, there's a small chance the old helper tool could still be around
        // make sure it's dead and gone
        [LaunchctlHelper unloadLaunchdJobWithPlistAt: @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
    }

    SCSettings* settings = [SCSettings sharedSettings];
    // update SCSettings with the blocklist and end date that've been requested
    [settings setValue: blocklist forKey: @"ActiveBlocklist"];
    [settings setValue: @(isAllowlist) forKey: @"ActiveBlockAsWhitelist"];
    [settings setValue: endDate forKey: @"BlockEndDate"];
    
    // update all the settings for the block, which we're basically just copying from defaults to settings
    [settings setValue: blockSettings[@"ClearCaches"] forKey: @"ClearCaches"];
    [settings setValue: blockSettings[@"AllowLocalNetworks"] forKey: @"AllowLocalNetworks"];
    [settings setValue: blockSettings[@"EvaluateCommonSubdomains"] forKey: @"EvaluateCommonSubdomains"];
    [settings setValue: blockSettings[@"IncludeLinkedDomains"] forKey: @"IncludeLinkedDomains"];
    [settings setValue: blockSettings[@"BlockSoundShouldPlay"] forKey: @"BlockSoundShouldPlay"];
    [settings setValue: blockSettings[@"BlockSound"] forKey: @"BlockSound"];
    [settings setValue: blockSettings[@"EnableErrorReporting"] forKey: @"EnableErrorReporting"];

    if(([blocklist count] <= 0 && !isAllowlist) || [SCBlockUtilities currentBlockIsExpired]) {
        NSLog(@"ERROR: Blocklist is empty, or block end date is in the past");
        NSLog(@"Block End Date: %@ (%@), vs now is %@", [settings valueForKey: @"BlockEndDate"], [[settings valueForKey: @"BlockEndDate"] class], [NSDate date]);
        NSError* err = [SCErr errorWithCode: 302];
        [SCSentry captureError: err];
        reply(err);
        [self.daemonMethodLock unlock];
        return;
    }

    NSLog(@"Adding firewall rules...");
    [SCHelperToolUtilities installBlockRulesFromSettings];
    [settings setValue: @YES forKey: @"BlockIsRunning"];
    
    NSError* syncErr = [settings syncSettingsAndWait: 5]; // synchronize ASAP since BlockIsRunning is a really important one
    if (syncErr != nil) {
        NSLog(@"WARNING: Sync failed or timed out with error %@ after starting block", syncErr);
        [SCSentry captureError: syncErr];
    }

    NSLog(@"Firewall rules added!");
    
    [SCHelperToolUtilities sendConfigurationChangedNotification];

    // Clear all caches if the user has the correct preference set, so
    // that blocked pages are not loaded from a cache.
    [SCHelperToolUtilities clearCachesIfRequested];

    [SCSentry addBreadcrumb: @"Daemon added block successfully" category: @"daemon"];
    NSLog(@"INFO: Block successfully added.");
    reply(nil);

    [[SCDaemon sharedDaemon] resetInactivityTimer];
    [[SCDaemon sharedDaemon] startCheckupTimer];
    [self.daemonMethodLock unlock];
}

+ (void)updateBlocklist:(NSArray<NSString*>*)newBlocklist authorization:(NSData *)authData reply:(void(^)(NSError* error))reply {
    if (![SCDaemonBlockMethods lockOrTimeout: reply]) {
        return;
    }
    
    [SCSentry addBreadcrumb: @"Daemon method updateBlocklist called" category: @"daemon"];
    if ([SCBlockUtilities legacyBlockIsRunning]) {
        NSLog(@"ERROR: Can't update blocklist because a legacy block is running");
        NSError* err = [SCErr errorWithCode: 303];
        [SCSentry captureError: err];
        reply(err);
        [self.daemonMethodLock unlock];
        return;
    }
    if (![SCBlockUtilities modernBlockIsRunning]) {
        NSLog(@"ERROR: Can't update blocklist since block isn't running");
        NSError* err = [SCErr errorWithCode: 304];
        [SCSentry captureError: err];
        reply(err);
        [self.daemonMethodLock unlock];
        return;
    }
    
    SCSettings* settings = [SCSettings sharedSettings];
        
    if ([settings boolForKey: @"ActiveBlockAsWhitelist"]) {
        NSLog(@"ERROR: Attempting to update active blocklist, but this is not possible with an allowlist block");
        NSError* err = [SCErr errorWithCode: 305];
        [SCSentry captureError: err];
        reply(err);
        [self.daemonMethodLock unlock];
        return;
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
    
    BlockManager* blockManager = [[BlockManager alloc] initAsAllowlist: [settings boolForKey: @"ActiveBlockAsWhitelist"]
                                                            allowLocal: [settings boolForKey: @"EvaluateCommonSubdomains"]
                                               includeCommonSubdomains: [settings boolForKey: @"AllowLocalNetworks"]
                                                  includeLinkedDomains: [settings boolForKey: @"IncludeLinkedDomains"]];
    [blockManager enterAppendMode];
    [blockManager addBlockEntriesFromStrings: added];
    [blockManager finishAppending];
    
    [settings setValue: newBlocklist forKey: @"ActiveBlocklist"];
    
    // make sure everyone knows about our new list
    NSError* syncErr = [settings syncSettingsAndWait: 5];
    if (syncErr != nil) {
        NSLog(@"WARNING: Sync failed or timed out with error %@ after updating blocklist", syncErr);
        [SCSentry captureError: syncErr];
    }

    [SCHelperToolUtilities sendConfigurationChangedNotification];

    // Clear all caches if the user has the correct preference set, so
    // that blocked pages are not loaded from a cache.
    [SCHelperToolUtilities clearCachesIfRequested];

    [SCSentry addBreadcrumb: @"Daemon updated blocklist successfully" category: @"daemon"];
    NSLog(@"INFO: Blocklist successfully updated.");
    reply(nil);

    [[SCDaemon sharedDaemon] resetInactivityTimer];
    [self.daemonMethodLock unlock];
}

+ (void)updateBlockEndDate:(NSDate*)newEndDate authorization:(NSData *)authData reply:(void(^)(NSError* error))reply {
    if (![SCDaemonBlockMethods lockOrTimeout: reply]) {
        return;
    }
    
    [SCSentry addBreadcrumb: @"Daemon method updateBlockEndDate called" category: @"daemon"];

    if ([SCBlockUtilities legacyBlockIsRunning]) {
        NSLog(@"ERROR: Can't update block end date because a legacy block is running");
        NSError* err = [SCErr errorWithCode: 306];
        [SCSentry captureError: err];
        reply(err);
        [self.daemonMethodLock unlock];
        return;
    }
    if (![SCBlockUtilities modernBlockIsRunning]) {
        NSLog(@"ERROR: Can't update block end date since block isn't running");
        NSError* err = [SCErr errorWithCode: 307];
        [SCSentry captureError: err];
        reply(err);
        [self.daemonMethodLock unlock];
        return;
    }
    
    SCSettings* settings = [SCSettings sharedSettings];
    
    // this can only be used to *extend* the block end date - not shorten it!
    // and we also won't let them extend by more than 24 hours at a time, for safety...
    // TODO: they should be able to extend up to MaxBlockLength minutes, right?
    NSDate* currentEndDate = [settings valueForKey: @"BlockEndDate"];
    if ([newEndDate timeIntervalSinceDate: currentEndDate] < 0) {
        NSLog(@"ERROR: Can't update block end date to an earlier date");
        NSError* err = [SCErr errorWithCode: 308];
        [SCSentry captureError: err];
        reply(err);
        [self.daemonMethodLock unlock];
    }
    if ([newEndDate timeIntervalSinceDate: currentEndDate] > 86400) { // 86400 seconds = 1 day
        NSLog(@"ERROR: Can't extend block end date by more than 1 day at a time");
        NSError* err = [SCErr errorWithCode: 309];
        [SCSentry captureError: err];
        reply(err);
        [self.daemonMethodLock unlock];
    }
    
    [settings setValue: newEndDate forKey: @"BlockEndDate"];
    
    // make sure everyone knows about our new end date
    NSError* syncErr = [settings syncSettingsAndWait: 5];
    if (syncErr != nil) {
        NSLog(@"WARNING: Sync failed or timed out with error %@ after extending block", syncErr);
        [SCSentry captureError: syncErr];
    }

    [SCHelperToolUtilities sendConfigurationChangedNotification];

    [SCSentry addBreadcrumb: @"Daemon extended block successfully" category: @"daemon"];
    NSLog(@"INFO: Block successfully extended.");
    reply(nil);
    
    [[SCDaemon sharedDaemon] resetInactivityTimer];
    [self.daemonMethodLock unlock];
}

+ (void)checkupBlock {
    if (![SCDaemonBlockMethods lockOrTimeout: nil timeout: CHECKUP_LOCK_TIMEOUT]) {
        return;
    }
    
    [SCSentry addBreadcrumb: @"Daemon method checkupBlock called" category: @"daemon"];

    NSTimeInterval integrityCheckIntervalSecs = 15.0;
    static NSDate* lastBlockIntegrityCheck;
    if (lastBlockIntegrityCheck == nil) {
        lastBlockIntegrityCheck = [NSDate distantPast];
    }

    BOOL shouldRunIntegrityCheck = NO;
    if(![SCBlockUtilities anyBlockIsRunning]) {
        // No block appears to be running at all in our settings.
        // Most likely, the user removed it trying to get around the block. Boo!
        // but for safety and to avoid permablocks (we no longer know when the block should end)
        // we should clear the block now.
        // but let them know that we noticed their (likely) cheating and we're not happy!
        NSLog(@"INFO: Checkup ran, no active block found.");
        
        [SCSentry captureMessage: @"Checkup ran and no active block found! Removing block, tampering suspected..."];
        
        [SCHelperToolUtilities removeBlock];

        [SCHelperToolUtilities sendConfigurationChangedNotification];
        
        // Temporarily disabled the TamperingDetection flag because it was sometimes causing false positives
        // (i.e. people having the background set repeatedly despite no attempts to cheat)
        // We will try to bring this feature back once we can debug it
        // GitHub issue: https://github.com/SelfControlApp/selfcontrol/issues/621
        // [settings setValue: @YES forKey: @"TamperingDetected"];
        //        [settings synchronizeSettings];
        //
        
        // once the checkups stop, the daemon will clear itself in a while due to inactivity
        [[SCDaemon sharedDaemon] stopCheckupTimer];
    } else if ([SCBlockUtilities currentBlockIsExpired]) {
        NSLog(@"INFO: Checkup ran, block expired, removing block.");
        
        [SCHelperToolUtilities removeBlock];

        [SCHelperToolUtilities sendConfigurationChangedNotification];

        [SCSentry addBreadcrumb: @"Daemon found and cleared expired block" category: @"daemon"];

        // once the checkups stop, the daemon will clear itself in a while due to inactivity
        [[SCDaemon sharedDaemon] stopCheckupTimer];
    } else if ([[NSDate date] timeIntervalSinceDate: lastBlockIntegrityCheck] > integrityCheckIntervalSecs) {
        lastBlockIntegrityCheck = [NSDate date];
        // The block is still on.  Every once in a while, we should
        // check if anybody removed our rules, and if so
        // re-add them.
        shouldRunIntegrityCheck = YES;
    }
    
    [[SCDaemon sharedDaemon] resetInactivityTimer];
    [self.daemonMethodLock unlock];
    
    // if we need to run an integrity check, we need to do it at the very end after we give up our lock
    // because checkBlockIntegrity requests its own lock, and we don't want it to deadlock
    if (shouldRunIntegrityCheck) {
        [SCDaemonBlockMethods checkBlockIntegrity];
    }
}

+ (void)checkBlockIntegrity {
    if (![SCDaemonBlockMethods lockOrTimeout: nil timeout: CHECKUP_LOCK_TIMEOUT]) {
        return;
    }
    
    [SCSentry addBreadcrumb: @"Daemon method checkBlockIntegrity called" category: @"daemon"];

    SCSettings* settings = [SCSettings sharedSettings];
    PacketFilter* pf = [[PacketFilter alloc] init];
    HostFileBlockerSet* hostFileBlockerSet = [[HostFileBlockerSet alloc] init];
    if(![pf containsSelfControlBlock] || (![settings boolForKey: @"ActiveBlockAsWhitelist"] && ![hostFileBlockerSet.defaultBlocker containsSelfControlBlock])) {
        NSLog(@"INFO: Block is missing in PF or hosts, re-adding...");
        // The firewall is missing at least the block header.  Let's clear everything
        // before we re-add to make sure everything goes smoothly.

        [pf stopBlock: false];

        [hostFileBlockerSet removeSelfControlBlock];
        BOOL success = [hostFileBlockerSet writeNewFileContents];
        // Revert the host file blocker's file contents to disk so we can check
        // whether or not it still contains the block after our write (aka we messed up).
        [hostFileBlockerSet revertFileContentsToDisk];
        if(!success || [hostFileBlockerSet.defaultBlocker containsSelfControlBlock]) {
            NSLog(@"WARNING: Error removing host file block.  Attempting to restore backup.");

            if([hostFileBlockerSet restoreBackupHostsFile])
                NSLog(@"INFO: Host file backup restored.");
            else
                NSLog(@"ERROR: Host file backup could not be restored.  This may result in a permanent block.");
        }

        // Get rid of the backup file since we're about to make a new one.
        [hostFileBlockerSet deleteBackupHostsFile];

        // Perform the re-add of the rules
        [SCHelperToolUtilities installBlockRulesFromSettings];
        
        [SCHelperToolUtilities clearCachesIfRequested];

        [SCSentry addBreadcrumb: @"Daemon found compromised block integrity and re-added rules" category: @"daemon"];
        NSLog(@"INFO: Integrity check ran; readded block rules.");
    } else NSLog(@"INFO: Integrity check ran; no action needed.");
    
    [self.daemonMethodLock unlock];
}

@end
