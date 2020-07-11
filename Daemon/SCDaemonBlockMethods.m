//
//  SCDaemonBlockMethods.m
//  org.eyebeam.selfcontrold
//
//  Created by Charlie Stigler on 7/4/20.
//

#import "SCDaemonBlockMethods.h"
#import "SCSettings.h"
#import "HelperCommon.h"

NSString* const kSelfControlErrorDomain = @"SelfControlErrorDomain";

@implementation SCDaemonBlockMethods

+ (void)startBlockWithControllingUID:(uid_t)controllingUID blocklist:(NSArray<NSString*>*)blocklist endDate:(NSDate*)endDate authorization:(NSData *)authData reply:(void(^)(NSError* error))reply {
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
    NSLog(@"Replacing settings end date %@ with %@, and blocklist %@ with %@", [settings valueForKey: @"BlockEndDate"], endDate, [settings valueForKey: @"Blocklist"], blocklist);
    [settings setValue: blocklist forKey: @"Blocklist"];
    [settings setValue: endDate forKey: @"BlockEndDate"];
    
    if([blocklist count] <= 0 || ![SCUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]) {
        NSLog(@"ERROR: Blocklist is empty, or block end date is in the past");
        NSLog(@"Block End Date: %@", [settings valueForKey: @"BlockEndDate"]);
        NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain code: -210 userInfo: @{
            NSLocalizedDescriptionKey: NSLocalizedString(@"Blocklist is empty, or block end date is in the past", nil)
        }];
        reply(err);
        return;
    }

    addRulesToFirewall(controllingUID);
    [settings setValue: @YES forKey: @"BlockIsRunning"];
    [settings synchronizeSettings]; // synchronize ASAP since BlockIsRunning is a really important one

    // TODO: is this still necessary in the new daemon world?
    sendConfigurationChangedNotification();

    // Clear all caches if the user has the correct preference set, so
    // that blocked pages are not loaded from a cache.
    clearCachesIfRequested(controllingUID);

    NSLog(@"INFO: Block successfully added.");
    reply(nil);
}

@end
