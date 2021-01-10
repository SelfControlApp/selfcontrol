//
//  SCDaemonBlockMethods.m
//  org.eyebeam.selfcontrold
//
//  Created by Charlie Stigler on 7/4/20.
//

#import "SCDaemonBlockMethods.h"
#import "SCSettings.h"
#import "HelperCommon.h"
#import "PacketFilter.h"
#import "SCDaemonUtilities.h"
#import "BlockManager.h"
#import "SCConstants.h"

@implementation SCDaemonBlockMethods

+ (void)startBlockWithControllingUID:(uid_t)controllingUID blocklist:(NSArray<NSString*>*)blocklist isAllowlist:(BOOL)isAllowlist endDate:(NSDate*)endDate authorization:(NSData *)authData reply:(void(^)(NSError* error))reply {
    @synchronized (self) {
        NSLog(@"startign block in methods");
        if (blockIsRunningInSettingsOrDefaults(controllingUID)) {
            NSLog(@"ERROR: Block is already running");
            NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain code: -222 userInfo: @{
                NSLocalizedDescriptionKey: NSLocalizedString(@"Block is already running", nil)
            }];
            reply(err);
            return;
        }
        
        // clear any legacy block information - no longer useful since we're using SCSettings now
        // (and could potentially confuse things)
        SCSettings* settings = [SCSettings settingsForUser: controllingUID];
        [settings clearLegacySettings];
        
        // update SCSettings with the blocklist and end date that've been requested
        NSLog(@"Replacing settings end date %@ with %@, and blocklist %@ with %@ (%@ of %@)", [settings valueForKey: @"BlockEndDate"], endDate, [settings valueForKey: @"ActiveBlocklist"], blocklist, [blocklist class], [blocklist[0] class]);
        [settings setValue: blocklist forKey: @"ActiveBlocklist"];
        [settings setValue: @(isAllowlist) forKey: @"ActiveBlockAsWhitelist"];
        [settings setValue: endDate forKey: @"BlockEndDate"];
        NSLog(@"And now ActiveBlocklist is %@", [settings valueForKey: @"ActiveBlocklist"]);
        
        if([blocklist count] <= 0 || ![SCUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]) {
            NSLog(@"ERROR: Blocklist is empty, or block end date is in the past");
            NSLog(@"Block End Date: %@ (%@), vs now is %@", [settings valueForKey: @"BlockEndDate"], [[settings valueForKey: @"BlockEndDate"] class], [NSDate date]);
            NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain code: -210 userInfo: @{
                NSLocalizedDescriptionKey: NSLocalizedString(@"Blocklist is empty, or block end date is in the past", nil)
            }];
            reply(err);
            return;
        }

        NSLog(@"Adding firewall rules...");
        addRulesToFirewall(controllingUID);
        [settings setValue: @YES forKey: @"BlockIsRunning"];
        [settings synchronizeSettings]; // synchronize ASAP since BlockIsRunning is a really important one

        NSLog(@"Firewall rules added!");
        
        // TODO: is this still necessary in the new daemon world?
        sendConfigurationChangedNotification();

        // Clear all caches if the user has the correct preference set, so
        // that blocked pages are not loaded from a cache.
        clearCachesIfRequested(controllingUID);

        NSLog(@"INFO: Block successfully added.");
        reply(nil);
    }
}

+ (void)updateBlocklist:(uid_t)controllingUID newBlocklist:(NSArray<NSString*>*)newBlocklist authorization:(NSData *)authData reply:(void(^)(NSError* error))reply {
    @synchronized (self) {
        NSLog(@"updating blocklist in methods");
        if (!blockIsRunningInSettingsOrDefaults(controllingUID)) {
            NSLog(@"ERROR: Can't update blocklist since block isn't running");
            NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain code: -213 userInfo: @{
                NSLocalizedDescriptionKey: NSLocalizedString(@"Refreshing blocklist, but no block is currently running", nil)
            }];
            reply(err);
            return;
        }
        
        SCSettings* settings = [SCSettings settingsForUser: controllingUID];
            
        if ([settings boolForKey: @"ActiveBlockAsWhitelist"]) {
            NSLog(@"ERROR: Attempting to update active blocklist, but this is not possible with an allowlist block");
            // TODO: replace this with a better error code
            NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain code: -213 userInfo: @{
                NSLocalizedDescriptionKey: NSLocalizedString(@"Attempting to update active blocklist, but this is not possible with an allowlist block", nil)
            }];
            reply(err);
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
        [blockManager addBlockEntries: added];
        [blockManager finishAppending];
        
        [settings setValue: newBlocklist forKey: @"ActiveBlocklist"];
        [settings synchronizeSettings]; // make sure everyone knows about our new list

        // TODO: is this still necessary in the new daemon world?
        sendConfigurationChangedNotification();

        // Clear all caches if the user has the correct preference set, so
        // that blocked pages are not loaded from a cache.
        clearCachesIfRequested(controllingUID);

        NSLog(@"INFO: Blocklist successfully updated.");
        reply(nil);
    }
}

+ (void)updateBlockEndDate:(uid_t)controllingUID newEndDate:(NSDate*)newEndDate authorization:(NSData *)authData reply:(void(^)(NSError* error))reply {
    @synchronized (self) {
        NSLog(@"updating block end date in methods");
        if (!blockIsRunningInSettingsOrDefaults(controllingUID)) {
            NSLog(@"ERROR: Can't update block end date since block isn't running");
            NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain code: -213 userInfo: @{
                NSLocalizedDescriptionKey: NSLocalizedString(@"Updating block end date, but no block is currently running", nil)
            }];
            reply(err);
            return;
        }
        
        SCSettings* settings = [SCSettings settingsForUser: controllingUID];
        
        // this can only be used to *extend* the block end date - not shorten it!
        // and we also won't let them extend by more than 24 hours at a time, for safety...
        // TODO: they should be able to extend up to MaxBlockLength minutes, right?
        NSDate* currentEndDate = [settings valueForKey: @"BlockEndDate"];
        if ([newEndDate timeIntervalSinceDate: currentEndDate] < 0) {
            NSLog(@"ERROR: Can't update block end date to an earlier date");
            NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain code: -301 userInfo: @{
                NSLocalizedDescriptionKey: NSLocalizedString(@"Can't update block end date to an earlier date", nil)
            }];
            reply(err);
        }
        if ([newEndDate timeIntervalSinceDate: currentEndDate] > 86400) { // 86400 seconds = 1 day
            NSLog(@"ERROR: Can't extend block end date by more than 1 day at a time");
            NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain code: -302 userInfo: @{
                NSLocalizedDescriptionKey: NSLocalizedString(@"Can't extend block end date by more than 1 day at a time", nil)
            }];
            reply(err);
        }
        
        [settings setValue: newEndDate forKey: @"BlockEndDate"];
        [settings synchronizeSettings]; // make sure everyone knows about our new end date

        // TODO: is this still necessary in the new daemon world?
        sendConfigurationChangedNotification();

        NSLog(@"INFO: Block successfully extended.");
        reply(nil);
    }
}

+ (void)checkupBlockWithControllingUID:(uid_t)controllingUID {
    // TODO: is synchronized the wrong tool here? it could be several seconds for the block to start = a bunch of checkup threads piling up
    @synchronized (self) {
        SCSettings* settings = [SCSettings settingsForUser: controllingUID];

        if(![SCUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]) {
            // No block appears to be running at all in our settings.
            // Most likely, the user removed it trying to get around the block. Boo!
            // but for safety and to avoid permablocks (we no longer know when the block should end)
            // we should clear the block now.
            // but let them know that we noticed their (likely) cheating and we're not happy!
            NSLog(@"INFO: Checkup ran, no active block found.");
            [SCDaemonUtilities unloadDaemonJobForUID: controllingUID];

            // get rid of this block
            // Temporarily disabled the TamperingDetection flag because it was sometimes causing false positives
            // (i.e. people having the background set repeatedly despite no attempts to cheat)
            // We will try to bring this feature back once we can debug it
            // GitHub issue: https://github.com/SelfControlApp/selfcontrol/issues/621
            // [settings setValue: @YES forKey: @"TamperingDetected"];
    //        [settings synchronizeSettings];
    //
    //        removeBlock(controllingUID);

            // syncSettingsAndExit(settings, EX_SOFTWARE);
        }

        if (![SCUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]) {
            NSLog(@"INFO: Checkup ran, block expired, removing block.");
            
            removeBlock(controllingUID);
            [SCDaemonUtilities unloadDaemonJobForUID: controllingUID];

            // Execution should never reach this point.  Launchd unloading the job in
            // should have killed this process. TODO: but maybe doesn't always with a daemon?
            printStatus(-216);
            syncSettingsAndExit(settings, EX_SOFTWARE);
        } else {
            // The block is still on.  Check if anybody removed our rules, and if so
            // re-add them.  Also make sure the user's settings are set to the correct
            // settings just in case.
            PacketFilter* pf = [[PacketFilter alloc] init];
            HostFileBlocker* hostFileBlocker = [[HostFileBlocker alloc] init];
            if(![pf containsSelfControlBlock] || (![settings boolForKey: @"ActiveBlockAsWhitelist"] && ![hostFileBlocker containsSelfControlBlock])) {
                // The firewall is missing at least the block header.  Let's clear everything
                // before we re-add to make sure everything goes smoothly.

                [pf stopBlock: false];
                [hostFileBlocker writeNewFileContents];
                BOOL success = [hostFileBlocker writeNewFileContents];
                // Revert the host file blocker's file contents to disk so we can check
                // whether or not it still contains the block (aka we messed up).
                [hostFileBlocker revertFileContentsToDisk];
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
                
                clearCachesIfRequested(controllingUID);
                NSLog(@"INFO: Checkup ran, readded block rules.");
            } else NSLog(@"INFO: Checkup ran, no action needed.");
        }
    }
}

@end
