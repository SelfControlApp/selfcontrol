//
//  SCMigrationUtilities.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/19/21.
//

#define SelfControlLegacyLockFilePath @"/etc/SelfControl.lock"

#import "SCMigrationUtilities.h"
#import <pwd.h>
#import "SCSettings.h"

@implementation SCMigrationUtilities

+ (NSString*)homeDirectoryForUid:(uid_t)uid {
    struct passwd *pwd = getpwuid(uid);
    
    // I can't think of why getpwuid() could ever fail, but we've
    // had a user crash report where it has! so be graceful
    if (pwd == NULL || pwd->pw_dir == NULL) return nil;
    
    return [NSString stringWithCString: pwd->pw_dir encoding: NSString.defaultCStringEncoding];
}

+ (NSString*)legacySecuredSettingsFilePathForUser:(uid_t)userId {
    NSString* homeDir = [SCMigrationUtilities homeDirectoryForUid: userId];
    return [[NSString stringWithFormat: @"%@/Library/Preferences/%@", homeDir, SCSettings.settingsFileName] stringByExpandingTildeInPath];
}

// check all legacy settings (old secured settings, lockfile, old-school defaults)
// to see if there's anything there
+ (BOOL)legacySettingsFoundForUser:(uid_t)controllingUID {
    NSFileManager* fileMan = [NSFileManager defaultManager];
    NSString* legacySettingsPath = [SCMigrationUtilities legacySecuredSettingsFilePathForUser: controllingUID];
    NSArray* defaultsHostBlacklist;

    if (geteuid() == 0 && controllingUID) {
        // we're running as root, so get the defaults dictionary using our special function)
        NSDictionary* defaultsDict = [SCMiscUtilities defaultsDictForUser: controllingUID];
        defaultsHostBlacklist = defaultsDict[@"HostBlacklist"];
    } else {
        // normal times, just use standard defaults
        defaultsHostBlacklist = [[NSUserDefaults standardUserDefaults] objectForKey: @"HostBlacklist"];
    }
    
    return defaultsHostBlacklist || [fileMan fileExistsAtPath: legacySettingsPath] || [fileMan fileExistsAtPath: SelfControlLegacyLockFilePath];
}
+ (BOOL)legacySettingsFoundForCurrentUser {
    return [SCMigrationUtilities legacySettingsFoundForUser: getuid()];
}

+ (BOOL)legacyLockFileExists {
    return [[NSFileManager defaultManager] fileExistsAtPath: SelfControlLegacyLockFilePath];
}

+ (NSDate*)legacyBlockEndDate {
    // if we're running this as a normal user (generally that means app/CLI), it's easy: just get the standard user defaults
    // this method can't be run as root, it won't work
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary* lockDict = [NSDictionary dictionaryWithContentsOfFile: SelfControlLegacyLockFilePath];
    NSString* legacySettingsPath = [SCMigrationUtilities legacySecuredSettingsFilePathForUser: getuid()];
    NSDictionary* settingsFromDisk = [NSDictionary dictionaryWithContentsOfFile: legacySettingsPath];
    
    // if we have a v3.x settings dictionary, take from that
    if (settingsFromDisk != nil && settingsFromDisk[@"BlockEndDate"] != nil) {
        return settingsFromDisk[@"BlockEndDate"];
    }

    // otherwise, we can look in defaults or the lockfile, both from pre-3.x versions
    // these would have BlockStartedDate + BlockDuration instead of BlockEndDate, so conversion is needed
    NSDate* startDate = [defaults objectForKey: @"BlockStartedDate"];
    NSTimeInterval duration = [defaults floatForKey: @"BlockDuration"];
    
    // if defaults didn't have valid values, try the lockfile
    if (startDate == nil || [startDate timeIntervalSinceNow] >= 0 || duration <= 0) {
        startDate = lockDict[@"BlockStartedDate"];
        duration = [lockDict[@"BlockStartedDate"] floatValue];
    }
    if (startDate == nil || [startDate timeIntervalSinceNow] >= 0 || duration <= 0) {
        // if still not, we give up! no end date found, so call it the past
        return [NSDate distantPast];
    }
    return [startDate dateByAddingTimeInterval: (duration * 60)];
}

+ (BOOL)legacyBlockIsRunningInSettingsFile:(NSURL*)settingsFileURL {
    NSDictionary* legacySettingsDict = [NSDictionary dictionaryWithContentsOfURL: settingsFileURL];
    
    // if the file doesn't exist, there's definitely no block
    if (legacySettingsDict == nil) return NO;
    
    return [SCMigrationUtilities blockIsRunningInLegacyDictionary: legacySettingsDict];
}

+ (BOOL)blockIsRunningInLegacyDictionary:(NSDictionary*)dict {
    if (dict == nil) return NO;

    NSDate* blockStartedDate = [dict objectForKey:@"BlockStartedDate"];
    BOOL blockIsRunningValue = [[dict objectForKey: @"BlockIsRunning"] boolValue];

    // for v3.0-3.0.3: the block is running if the BlockIsRunning key is true
    // super old legacy (pre-3.0): the block is running if BlockStartedDate exists and isn't equal to the default value
    if (blockIsRunningValue || (blockStartedDate != nil && ![blockStartedDate isEqualToDate: [NSDate distantFuture]])) {
        return YES;
    } else {
        return NO;
    }
}

// copies settings from legacy locations (user-based secured settings used from 3.0-3.0.3,
// or older defaults/lockfile used pre-3.0) to their modern destinations in NSUserDefaults.
// does NOT update any of the values in SCSettings, and does NOT clear out settings from anywhere
// that makes this safe to call anytime, includig while a block is running
+ (void)copyLegacySettingsToDefaults:(uid_t)controllingUID {
    NSLog(@"Copying legacy settings to defaults...");
    BOOL runningAsRoot = (geteuid() == 0);
    if (runningAsRoot && !controllingUID) {
        // if we're running as root, but we didn't get a valid non-root controlling UID
        // we don't really have anywhere to copy those legacy settings to, because root doesn't have defaults
        NSLog(@"WARNING: Can't copy legacy settings to defaults, because SCSettings is being run as root and no controlling UID was sent.");
        return;
    }
    if (controllingUID <= 0) controllingUID = getuid();

    NSDictionary<NSString*, id>* defaultDefaults = SCConstants.defaultUserDefaults;
    // if we're running this as a normal user (generally that means app/CLI), it's easy: just get the standard user defaults
    // if we're running this as root, we need to be given a UID target, then we imitate them to grab their defaults
    NSUserDefaults* defaults;
    if (runningAsRoot) {
        seteuid(controllingUID);
        defaults = [NSUserDefaults standardUserDefaults];
        [defaults addSuiteNamed: @"org.eyebeam.SelfControl"];
        [defaults registerDefaults: SCConstants.defaultUserDefaults];
        [defaults synchronize];
    } else {
        defaults = [NSUserDefaults standardUserDefaults];
    }
    
    // if we already completed a migration into these defaults, DON'T do it again!
    // (we don't want to overwrite any changes post-migration)
    BOOL migrationComplete = [defaults boolForKey: @"V4MigrationComplete"];
    
    if (!migrationComplete) {
        NSDictionary* lockDict = [NSDictionary dictionaryWithContentsOfFile: SelfControlLegacyLockFilePath];
        
        NSString* legacySettingsPath = [SCMigrationUtilities legacySecuredSettingsFilePathForUser: controllingUID];
        NSDictionary* settingsFromDisk = [NSDictionary dictionaryWithContentsOfFile: legacySettingsPath];
        
        // if we have a v3.x settings dictionary, copy what we can from that
        if (settingsFromDisk != nil) {
            NSLog(@"Migrating all settings from legacy secured settings file %@", legacySettingsPath);

            // we assume the settings from disk are newer / should override existing values
            // UNLESS the user has set a default to its non-default value

            // we'll look at all the possible keys in defaults - some of them should really
            // have never ended up in settings at any point, but shouldn't matter
            for (NSString* key in [defaultDefaults allKeys]) {
                id settingsValue = settingsFromDisk[key];
                id defaultsValue = [defaults objectForKey: key];
                
                // we have a value from settings, and the defaults value is unset or equal to the default value
                // so pull the value from settings in!
                if (settingsValue != nil && (defaultsValue == nil || [defaultsValue isEqualTo: defaultDefaults[key]])) {
                    NSLog(@"Migrating keypair (%@, %@) from settings to defaults", key, settingsValue);
                    [defaults setObject: settingsValue forKey: key];
                }
            }

            NSLog(@"Done migrating preferences from legacy secured settings to defaults!");
        }

        // if we're on a pre-3.0 version, we may need to migrate the blocklist from defaults or the lock dictionary
        // the Blocklist attribute used to be named HostBlacklist, so needs a special migration
        NSArray<NSString*>* blocklistInDefaults = [defaults arrayForKey: @"Blocklist"];
        // of course, don't overwrite if we already have a blocklist in today's defaults
        if (blocklistInDefaults == nil || blocklistInDefaults.count == 0) {
            if (lockDict != nil && lockDict[@"HostBlacklist"] != nil) {
                [defaults setObject: lockDict[@"HostBlacklist"] forKey: @"Blocklist"];
                NSLog(@"Migrated blocklist from pre-3.0 lock dictionary: %@", lockDict[@"HostBlacklist"]);
            } else if ([defaults objectForKey: @"HostBlacklist"] != nil) {
                [defaults setObject: [defaults objectForKey: @"HostBlacklist"] forKey: @"Blocklist"];
                NSLog(@"Migrated blocklist from pre-3.0 legacy defaults: %@", [defaults objectForKey: @"HostBlacklist"]);
            }
        }
        
        [defaults setBool: YES forKey: @"V4MigrationComplete"];
    } else {
        NSLog(@"Skipping copy to defaults because migration to V4 was already completed.");
    }
    
    [defaults synchronize];
    // if we're running as root and imitated the user to get their defaults, we need to put things back in place when done
    if (runningAsRoot) {
        [NSUserDefaults resetStandardUserDefaults];
        seteuid(0);
    }
    
    [SCSentry addBreadcrumb: @"Copied legacy settings to defaults successfully" category: @"settings"];
    NSLog(@"Done copying settings!");
}

+ (void)copyLegacySettingsToDefaults {
    [SCMigrationUtilities copyLegacySettingsToDefaults: 0];
}

// We might have "legacy" block settings hiding in one of three places:
//  - a "lock file" at /etc/SelfControl.lock (aka SelfControlLegacyLockFilePath)
//  - the defaults system
//  - a v3.x per-user secured settings file
// we should check for block settings in all of these places and get rid of them
+ (NSError*)clearLegacySettingsForUser:(uid_t)controllingUID ignoreRunningBlock:(BOOL)ignoreRunningBlock {
    NSLog(@"Clearing legacy settings!");
    
    BOOL runningAsRoot = (geteuid() == 0);
    if (!runningAsRoot || !controllingUID) {
        // if we're not running as root, or we didn't get a valid non-root controlling UID
        // we won't have permissions to make this work. This method MUST be called with root perms
        NSLog(@"ERROR: Can't clear legacy settings, because we aren't running as root.");
        NSError* err = [SCErr errorWithCode: 701];
        [SCSentry captureError: err];
        return err;
    }
    
    // if we're gonna clear settings, there can't be a block running anywhere. otherwise, we should wait!
    if ([SCBlockUtilities legacyBlockIsRunning] && !ignoreRunningBlock) {
        NSLog(@"ERROR: Can't clear legacy settings because a block is ongoing!");
        NSError* err = [SCErr errorWithCode: 702];
        [SCSentry captureError: err];
        return err;
    }
    
    NSFileManager* fileMan = [NSFileManager defaultManager];
 
    // besides Blocklist and the values copied from the v3.0-3.0.3 settings file to defaults in copyLegacySettingsToDefaults
    // we actually don't need to move anything else over! Why?
    //   1. The other settings from 3.0-3.0.3 don't matter as long as a block isn't running (i.e. BlockIsRunning should be false
    //      and BlockEndDate shouldn't be set).
    //   2. All of the non-block settings from pre-3.0 can stay in defaults, ahd BlockStartedDate should be false if no block running
    // so all that's left is to clear out the legacy crap for good

    // if an error happens trying to clear any portion of the old settings,
    // we'll remember it, log it, and return it, but still try to clear the rest (best-effort)
    NSError* retErr = nil;
    
    // first, clear the pre-3.0 lock dictionary
    if(![fileMan removeItemAtPath: SelfControlLegacyLockFilePath error: &retErr] && [fileMan fileExistsAtPath: SelfControlLegacyLockFilePath]) {
        NSLog(@"WARNING: Could not remove legacy SelfControl lock file because of error: %@", retErr);
        [SCSentry captureError: retErr];
    }
    
    // then, clear keys out of defaults which aren't used
    // prepare defaults by imitating the appropriate user
    seteuid(controllingUID);
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed: @"org.eyebeam.SelfControl"];
    [defaults registerDefaults: SCConstants.defaultUserDefaults];
    [defaults synchronize];
    NSArray* defaultsKeysToClear = @[
                             @"BlockStartedDate",
                             @"BlockEndDate",
                             @"HostBlacklist"
                             ];
    for (NSString* key in defaultsKeysToClear) {
        [defaults removeObjectForKey: key];
    }
    [defaults synchronize];
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);
    
    // clear all legacy per-user secured settings (v3.0-3.0.3) in every user's home folder
    NSArray<NSURL *>* homeDirectoryURLs = [SCMiscUtilities allUserHomeDirectoryURLs: &retErr];
    if (homeDirectoryURLs != nil) {
        for (NSURL* homeDirURL in homeDirectoryURLs) {
            NSString* relativeSettingsPath = [NSString stringWithFormat: @"/Library/Preferences/%@", SCSettings.settingsFileName];
            NSURL* settingsFileURL = [homeDirURL URLByAppendingPathComponent: relativeSettingsPath isDirectory: NO];
            
            if(![fileMan removeItemAtURL: settingsFileURL error: &retErr] && [fileMan fileExistsAtPath: settingsFileURL.path]) {
                NSLog(@"WARNING: Could not remove legacy SelfControl settings file at URL %@ because of error: %@", settingsFileURL, retErr);
                [SCSentry captureError: retErr];
            }
        }
    }

    // and that's it! note that we don't touch the modern SCSettings at all, and that's OK - it'll restart from scratch and be fine
    [SCSentry addBreadcrumb: @"Cleared legacy settings successfully" category: @"settings"];
    NSLog(@"Cleared legacy settings!");
    
    return retErr;
}

+ (NSError*)clearLegacySettingsForUser:(uid_t)controllingUID {
    return [SCMigrationUtilities clearLegacySettingsForUser: controllingUID ignoreRunningBlock: NO];
}



@end
