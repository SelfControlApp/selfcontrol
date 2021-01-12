//
//  SCBlockDateUtilities.m
//  SelfControl
//
//  Created by Charles Stigler on 07/07/2018.
//

#import "SCUtilities.h"
#import "HelperCommon.h"
#import "SCSettings.h"
#import "SCConstants.h"
#include <pwd.h>

@implementation SCUtilities

// copied from stevenojo's GitHub snippet: https://gist.github.com/stevenojo/e1dcc2b3e2fd4ed1f411eef88e254cb0
dispatch_source_t CreateDebounceDispatchTimer(double debounceTime, dispatch_queue_t queue, dispatch_block_t block) {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    if (timer) {
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, debounceTime * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, (1ull * NSEC_PER_SEC) / 10);
        dispatch_source_set_event_handler(timer, block);
        dispatch_resume(timer);
    }
    
    return timer;
}

// Standardize and clean up the input value so it'll block properly (and look good doing it)
// note that if the user entered line breaks, we'll split it into many entries, so this can return multiple
// cleaned entries in the NSArray it returns
+ (NSArray<NSString*>*) cleanBlocklistEntry:(NSString*)rawEntry {
    if (rawEntry == nil) return @[];
    
	// This'll remove whitespace and lowercase the string.
	NSString* str = [[rawEntry stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];

    // if there are newlines in the string, split it and process it as many strings
	if([str rangeOfCharacterFromSet: [NSCharacterSet newlineCharacterSet]].location != NSNotFound) {
		NSArray* splitEntries = [str componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
        
        NSMutableArray* returnArr = [NSMutableArray new];
        for (NSString* splitEntry in splitEntries) {
            // recursion makes the rest of the code prettier
            NSArray<NSString*>* cleanedSubEntries = [SCUtilities cleanBlocklistEntry: splitEntry];
            [returnArr addObjectsFromArray: cleanedSubEntries];
        }
        return returnArr;
    }
    
    // if the user entered a scheme (https://, http://, etc) remove it.
    // We only block hostnames so scheme is ignored anyway and it can gunk up the blocking
    NSArray* separatedStr = [str componentsSeparatedByString: @"://"];
    str = [separatedStr lastObject];
    
	// Remove URL login names/passwords (username:password@host) if a user tried to put that in
	separatedStr = [str componentsSeparatedByString: @"@"];
	str = [separatedStr lastObject];
    
    // now here's where it gets tricky. Besides just hostnames, we also support CIDR IP ranges, for example: 83.0.1.2/24
    // so we are gonna keep track of whether we might have received a valid CIDR IP range instead of hostname as we go...
    // we also take port numbers, so keep track of whether we have one of those
	int cidrMaskBits = -1;
	int portNum = -1;

    // first pull off everything after a slash
    // discard the end if it's just a path, but check to see if it might be our CIDR mask length
	separatedStr = [str componentsSeparatedByString: @"/"];
    str = [separatedStr firstObject];
    
    // if the part after a slash is an integer between 1 and 128, it could be our mask length
    if (separatedStr.count > 1) {
        int potentialMaskLen = [[separatedStr lastObject] intValue];
        if (potentialMaskLen > 0 && potentialMaskLen <= 128) cidrMaskBits = potentialMaskLen;
    }

    // check for the port
    separatedStr = [str componentsSeparatedByString: @":"];
    str = [separatedStr firstObject];
    
    if (separatedStr.count > 1) {
        int potentialPort = [[separatedStr lastObject] intValue];
        if (potentialPort > 0 && potentialPort <= 65535) {
            portNum = potentialPort;
        }
    }
    
    // remove invalid characters from the hostname
    // hostnames are 1-253 characters long, and can contain only a-z, A-Z, 0-9, -, and ., and maybe _ (mostly not but kinda)
    // for some reason [NSCharacterSet URLHostAllowedCharacterSet] has tons of other characters that aren't actually valid
    NSMutableCharacterSet* invalidHostnameChars = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
    [invalidHostnameChars addCharactersInString: @"-._"];
    [invalidHostnameChars invert];

    NSMutableString* validCharsOnly = [NSMutableString stringWithCapacity: str.length];
    for (NSUInteger i = 0; i < str.length && i < 253; i++) {
        unichar c = [str characterAtIndex: i];
        if (![invalidHostnameChars characterIsMember: c]) {
            [validCharsOnly appendFormat: @"%C", c];
        }
    }
    str = validCharsOnly;
    
    // allow blocking an empty hostname IFF we're only blocking a single port number (i.e. :80)
    // otherwise, empty hostname = nothing to do
    if (str.length < 1 && portNum < 0) {
        return @[];
    }

    NSString* maskString;
    NSString* portString;

    // create a mask string if we have one
    if (cidrMaskBits < 0) {
        maskString = @"";
    } else {
        maskString = [NSString stringWithFormat: @"/%d", cidrMaskBits];
    }
    
    // create a port string if we have one
    if (portNum < 0) {
        portString = @"";
    } else {
        portString = [NSString stringWithFormat: @":%d", portNum];
    }

    // combine em together and you got something!
    return @[[NSString stringWithFormat: @"%@%@%@", str, maskString, portString]];
}

+ (NSDictionary*) defaultsDictForUser:(uid_t) controllingUID {
    if (geteuid() != 0) {
        // if we're not root, we can't just get defaults for some arbitrary user
        return nil;
    }
    
    // pull up the user's defaults in the old legacy way
    // to do that, we have to seteuid to the controlling UID so NSUserDefaults thinks we're them
    seteuid(controllingUID);
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed: @"org.eyebeam.SelfControl"];
    [defaults synchronize];
    NSDictionary* dictValue = [defaults dictionaryRepresentation];
    // reset the euid so nothing else gets funky
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);
    
    return dictValue;
}

+ (BOOL)anyBlockIsRunning:(uid_t)controllingUID {
    return [SCUtilities modernBlockIsRunning] || [self legacyBlockIsRunning: controllingUID];
}
+ (BOOL)anyBlockIsRunning {
    return [SCUtilities anyBlockIsRunning: 0];
}

+ (BOOL)modernBlockIsRunning {
    SCSettings* settings = [SCSettings sharedSettings];
    
    if ([SCUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]) {
        return YES;
    }
    
    // just in case something went wrong with settings, check the hosts file to see if there's reallya  block there
    NSString* hostFileContents = [NSString stringWithContentsOfFile: @"/etc/hosts" encoding: NSUTF8StringEncoding error: NULL];
    if(hostFileContents != nil && [hostFileContents rangeOfString: @"# BEGIN SELFCONTROL BLOCK"].location != NSNotFound) {
        return YES;
    }

    return NO;
}

+ (BOOL)legacyBlockIsRunning:(uid_t)controllingUID {
    // first see if there's a legacy settings file from v3.x
    if (!controllingUID) controllingUID = getuid();
    NSString* legacySettingsPath = [SCUtilities legacySecuredSettingsFilePathForUser: controllingUID];
    NSDictionary* legacySettingsDict = [NSDictionary dictionaryWithContentsOfFile: legacySettingsPath];
    if ([SCUtilities blockIsRunningInLegacyDictionary: legacySettingsDict]) {
        return YES;
    }
    
    // nope? OK, how about a lock file from pre-3.0?
    if ([[NSFileManager defaultManager] fileExistsAtPath: SelfControlLegacyLockFilePath]) {
        return YES;
    }
    
    // hmm, is there anything in defaults from pre-3.0?
    NSDictionary* defaultsDict = [SCUtilities defaultsDictForUser: controllingUID];
    if ([SCUtilities blockIsRunningInLegacyDictionary: defaultsDict]) {
        return YES;
    }

    // last try: check the host file, and see if a block is in there
    NSString* hostFileContents = [NSString stringWithContentsOfFile: @"/etc/hosts" encoding: NSUTF8StringEncoding error: NULL];
    if(hostFileContents != nil && [hostFileContents rangeOfString: @"# BEGIN SELFCONTROL BLOCK"].location != NSNotFound) {
        return YES;
    }
    
    return NO;
}
+ (BOOL)legacyBlockIsRunning {
    return [SCUtilities legacyBlockIsRunning: 0];
}

// returns YES if a block is actively running (to the best of our knowledge), and NO otherwise
+ (BOOL) blockIsRunningInDictionary:(NSDictionary *)dict {
    // simple: the block is running if BlockIsRunning is set to true!
    return [[dict valueForKey: @"BlockIsRunning"] boolValue];
}

// returns YES if the block should be active based on the specified end time (i.e. it is in the future), or NO otherwise
+ (BOOL) blockShouldBeRunningInDictionary:(NSDictionary *)dict {
    // the block should be running if the end date hasn't arrived yet
    if ([[dict objectForKey: @"BlockEndDate"] timeIntervalSinceNow] > 0) {
        return YES;
    } else {
        return NO;
    }
}

+ (void) removeBlockFromSettings {
    // TODO: will this work setting nil instead of [NSDate dateWithTimeIntervalSince1970: 0]?
    SCSettings* settings = [SCSettings sharedSettings];
    [settings setValue: nil forKey: @"BlockEndDate"];
    [settings setValue: nil forKey: @"BlockIsRunning"];
    [settings setValue: nil forKey: @"ActiveBlocklist"];
    [settings setValue: nil forKey: @"ActiveBlockAsWhitelist"];
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

+ (BOOL)writeBlocklistToFileURL:(NSURL*)targetFileURL blockInfo:(NSDictionary*)blockInfo errorDescription:(NSString**)errDescriptionRef {
    NSDictionary* saveDict = @{@"HostBlacklist": [blockInfo objectForKey: @"Blocklist"],
                               @"BlockAsWhitelist": [blockInfo objectForKey: @"BlockAsWhitelist"]};

    NSString* saveDataErr;
    NSData* saveData = [NSPropertyListSerialization dataFromPropertyList: saveDict format: NSPropertyListBinaryFormat_v1_0 errorDescription: &saveDataErr];
    if (saveDataErr != nil) {
        *errDescriptionRef = saveDataErr;
        return NO;
    }

    if (![saveData writeToURL: targetFileURL atomically: YES]) {
        NSLog(@"ERROR: Failed to write blocklist to URL %@", targetFileURL);
        return NO;
    }
    
    // for prettiness sake, attempt to hide the file extension
    NSDictionary* attribs = @{NSFileExtensionHidden: @YES};
    [[NSFileManager defaultManager] setAttributes: attribs ofItemAtPath: [targetFileURL path] error: NULL];
    
    return YES;
}

+ (NSDictionary*)readBlocklistFromFile:(NSURL*)fileURL {
    NSDictionary* openedDict = [NSDictionary dictionaryWithContentsOfURL: fileURL];
    
    if (openedDict == nil || openedDict[@"HostBlacklist"] == nil || openedDict[@"BlockAsWhitelist"] == nil) {
        NSLog(@"ERROR: Could not read a valid block from file %@", fileURL);
        return nil;
    }
    
    return @{
        @"Blocklist": openedDict[@"HostBlacklist"],
        @"BlockAsWhitelist": openedDict[@"BlockAsWhitelist"]
    };
}

// migration functions

+ (NSString*)homeDirectoryForUid:(uid_t)uid {
    struct passwd *pwd = getpwuid(uid);
    return [NSString stringWithCString: pwd->pw_dir encoding: NSString.defaultCStringEncoding];
}

+ (NSString*)legacySecuredSettingsFilePathForUser:(uid_t)userId {
    NSString* homeDir = [SCUtilities homeDirectoryForUid: userId];
    return [[NSString stringWithFormat: @"%@/Library/Preferences/%@", homeDir, SCSettings.settingsFileName] stringByExpandingTildeInPath];
}

// check all legacy settings (old secured settings, lockfile, old-school defaults)
// to see if there's anything there
+ (BOOL)legacySettingsFound:(uid_t)controllingUID {
    if (!controllingUID) controllingUID = getuid();
    NSFileManager* fileMan = [NSFileManager defaultManager];
    NSString* legacySettingsPath = [SCUtilities legacySecuredSettingsFilePathForUser: controllingUID];
    NSArray* defaultsHostBlacklist;

    if (geteuid() == 0 && controllingUID) {
        // we're running as root, so get the defaults dictionary using our special function)
        NSDictionary* defaultsDict = [SCUtilities defaultsDictForUser: controllingUID];
        defaultsHostBlacklist = defaultsDict[@"HostBlacklist"];
    } else {
        // normal times, just use standard defaults
        defaultsHostBlacklist = [[NSUserDefaults standardUserDefaults] objectForKey: @"HostBlacklist"];
    }
    
    return defaultsHostBlacklist || [fileMan fileExistsAtPath: legacySettingsPath] || [fileMan fileExistsAtPath: SelfControlLegacyLockFilePath];
}
+ (BOOL)legacySettingsFound {
    return [SCUtilities legacySettingsFound: 0];
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
    if (!controllingUID) controllingUID = getuid();

    NSDictionary<NSString*, id>* defaultDefaults = SCConstants.defaultUserDefaults;
    // if we're running this as a normal user (generally that means app/CLI), it's easy: just get the standard user defaults
    // if we're running this as root, we need to be given a UID target, then we imitate them to grab their defaults
    NSUserDefaults* defaults;
    if (runningAsRoot) {
        seteuid(controllingUID);
        defaults = [NSUserDefaults standardUserDefaults];
        [defaults addSuiteNamed: @"org.eyebeam.SelfControl"];
        [defaults synchronize];
    } else {
        defaults = [NSUserDefaults standardUserDefaults];
    }
    
    NSDictionary* lockDict = [NSDictionary dictionaryWithContentsOfFile: SelfControlLegacyLockFilePath];
    
    NSString* legacySettingsPath = [SCUtilities legacySecuredSettingsFilePathForUser: controllingUID];
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
    
    // if we're running as root and imitated the user to get their defaults, we need to put things back in place when done
    if (runningAsRoot) {
        [NSUserDefaults resetStandardUserDefaults];
        seteuid(0);
    }
    
    NSLog(@"Done copying settings!");
}

+ (void)copyLegacySettingsToDefaults {
    [SCUtilities copyLegacySettingsToDefaults: 0];
}

// We might have "legacy" block settings hiding in one of three places:
//  - a "lock file" at /etc/SelfControl.lock (aka SelfControlLegacyLockFilePath)
//  - the defaults system
//  - a v3.x per-user secured settings file
// we should check for block settings in all of these places and get rid of them
+ (void)clearLegacySettings:(uid_t)controllingUID {
    NSLog(@"Clearing legacy settings!");
    
    BOOL runningAsRoot = (geteuid() == 0);
    if (!runningAsRoot || !controllingUID) {
        // if we're not running as root, or we didn't get a valid non-root controlling UID
        // we won't have permissions to make this work. This method MUST be called with root perms
        NSLog(@"ERROR: Can't clear legacy settings, because we aren't running as root.");
        return;
    }
    
    // if we're gonna clear settings, there can't be a block running anywhere. otherwise, we should wait!
    if ([SCUtilities legacyBlockIsRunning: controllingUID]) {
        NSLog(@"ERROR: Can't clear legacy settings because a block is ongoing!");
        return;
    }

    // besides Blocklist and the values copied from the v3.0-3.0.3 settings file to defaults in copyLegacySettingsToDefaults
    // we actually don't need to move anything else over! Why?
    //   1. The other settings from 3.0-3.0.3 don't matter as long as a block isn't running (i.e. BlockIsRunning should be false
    //      and BlockEndDate shouldn't be set).
    //   2. All of the non-block settings from pre-3.0 can stay in defaults, ahd BlockStartedDate should be false if no block running
    // so all that's left is to clear out the legacy crap for good

    // first, clear the pre-3.0 lock dictionary
    NSError* removeLockFileErr;
    NSFileManager* fileMan = [NSFileManager defaultManager];
    if(![fileMan removeItemAtPath: SelfControlLegacyLockFilePath error: &removeLockFileErr] && [fileMan fileExistsAtPath: SelfControlLegacyLockFilePath]) {
        NSLog(@"WARNING: Could not remove legacy SelfControl lock file because of error: %@", removeLockFileErr);
    }
    
    // then, clear keys out of defaults which aren't used
    // prepare defaults by imitating the appropriate user
    seteuid(controllingUID);
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed: @"org.eyebeam.SelfControl"];
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
    
    // finally, clear the old settings file if they have it from a v3.0-3.0.3 version
    NSError* removeOldSettingsFileErr;
    NSString* legacySettingsPath = [SCUtilities legacySecuredSettingsFilePathForUser: controllingUID];
    if(![fileMan removeItemAtPath: legacySettingsPath error: &removeOldSettingsFileErr] && [fileMan fileExistsAtPath: legacySettingsPath]) {
        NSLog(@"WARNING: Could not remove legacy SelfControl lock file because of error: %@", removeOldSettingsFileErr);
    }
    
    // and that's it! note that we don't touch the modern SCSettings at all, and that's OK - it'll restart from scratch and be fine
    NSLog(@"Cleared legacy settings!");
}


@end
