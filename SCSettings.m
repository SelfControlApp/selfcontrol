//
//  SCLockFileUtilities.m
//  SelfControl
//
//  Created by Charles Stigler on 20/10/2018.
//

#import "SCSettings.h"
#include <IOKit/IOKitLib.h>
#import <CommonCrypto/CommonCrypto.h>
#include <pwd.h>
#import "SCBlockDateUtilities.h"

@implementation SCSettings

/* TODO: move these two functions to a utility class */

// by Martin R et al on StackOverflow: https://stackoverflow.com/a/15451318
- (NSString *)getSerialNumber {
    NSString *serial = nil;
    io_service_t platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                              IOServiceMatching("IOPlatformExpertDevice"));
    if (platformExpert) {
        CFTypeRef serialNumberAsCFString =
        IORegistryEntryCreateCFProperty(platformExpert,
                                        CFSTR(kIOPlatformSerialNumberKey),
                                        kCFAllocatorDefault, 0);
        if (serialNumberAsCFString) {
            serial = CFBridgingRelease(serialNumberAsCFString);
        }
        
        IOObjectRelease(platformExpert);
    }
    return serial;
}
// by hypercrypt et al on StackOverflow: https://stackoverflow.com/a/7571583
- (NSString *)sha1:(NSString*)stringToHash
{
    NSData *data = [stringToHash dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
    {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    return output;
}
- (NSString*)homeDirectoryForUid:(uid_t)uid {
    struct passwd *pwd = getpwuid(uid);
    return [NSString stringWithCString: pwd->pw_dir encoding: NSString.defaultCStringEncoding];
}

+ (instancetype)settingsForUser:(uid_t)uid {
    // on first run, set up a cache of SCSettings objects so can reuse the same one for a given user
    static NSMutableDictionary* settingsForUserIds;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        settingsForUserIds = [NSMutableDictionary new];
    });
    
    if (settingsForUserIds[@(uid)] == nil) {
        // no settings object yet for this UID, instantiate one
        settingsForUserIds[@(uid)] = [[self alloc] initWithUserId: uid];
    }
    
    // return the settings object we've got cached for this user id!
    return settingsForUserIds[@(uid)];
}
+ (instancetype)currentUserSettings {
    return [SCSettings settingsForUser: getuid()];
}
- (instancetype)initWithUserId:(uid_t)userId {
    NSLog(@"init SCSettings");
    if (self = [super init]) {
        _userId = userId;
        _settingsDictionary = nil;
    }
    return self;
}


/* put these files at random-ish locations to make them harder for users to find and tamper with */
- (NSString*)lockFilePath {
    NSString* hash = [self sha1: [NSString stringWithFormat: @"SelfControlSystemLock%@", [self getSerialNumber]]];
    return [NSString stringWithFormat: @"/etc/.%@.plist", hash];
}
- (NSString*)securedSettingsFilePath {
    NSString* homeDir = [self homeDirectoryForUid: self.userId];
    NSString* hash = [self sha1: [NSString stringWithFormat: @"SelfControlUserPreferences%@", [self getSerialNumber]]];
    NSLog(@"securedSettingsFilePath = %@ (homeDir = %@ and hash = %@)", [[NSString stringWithFormat: @"%@/Library/Preferences/.%@.plist", homeDir, hash] stringByExpandingTildeInPath], homeDir, hash);
    return [[NSString stringWithFormat: @"%@/Library/Preferences/.%@.plist", homeDir, hash] stringByExpandingTildeInPath];
}

- (NSDictionary*)defaultSettingsDict {
    return @{
        @"BlockEndDate": [NSDate distantPast],
        @"Blocklist": @[],
        @"EvaluateCommonSubdomains": @YES,
        @"IncludeLinkedDomains": @YES,
        @"BlockSoundShouldPlay": @NO,
        @"BlockSound": @5,
        @"ClearCaches": @YES,
        @"BlockAsWhitelist": @NO,
        @"AllowLocalNetworks": @YES,
        @"BlockIsRunning": @NO // tells us whether a block is actually running on the system (to the best of our knowledge)
    };
}
- (NSDictionary*)settingsDictionary {
    if (_settingsDictionary == nil) {
        _settingsDictionary = [NSMutableDictionary dictionaryWithContentsOfFile: [self securedSettingsFilePath]];
        
        if (_settingsDictionary == nil) {
            _settingsDictionary = [[self defaultSettingsDict] mutableCopy];
            [self migrateLegacySettings];
        }
        NSLog(@"initialized settingsDictionary with contents of %@ to %@", [self securedSettingsFilePath], _settingsDictionary);
    }
    return _settingsDictionary;
}
- (void)reloadSettings {
    _settingsDictionary = [NSDictionary dictionaryWithContentsOfFile: [self securedSettingsFilePath]];
}
- (void)writeSettings {
    NSString* serializationErrString;
    NSData* plistData = [NSPropertyListSerialization dataFromPropertyList: self.settingsDictionary
                                                                   format: NSPropertyListBinaryFormat_v1_0
                                                         errorDescription: &serializationErrString];
    if (plistData == nil) {
        NSLog(@"NSPropertyListSerialization error: %@", serializationErrString);
        return;
    }
    NSLog(@"writing %@ to %@", plistData, self.securedSettingsFilePath);
    [plistData writeToFile: [self securedSettingsFilePath]
                atomically: YES];
}
- (void)synchronizeSettings {
    // read and write and combine?
}
- (void)setValue:(id)value forKey:(NSString*)key {
    [self.settingsDictionary setValue: value forKey: key];
}
- (id)valueForKey:(NSString*)key {
    NSLog(@"value for key %@ is %@", key, [self.settingsDictionary valueForKey: key]);
    return [self.settingsDictionary valueForKey: key];
}

// We might have "legacy" block settings hiding in one of two places:
//  - a "lock file" at /etc/SelfControl.lock (aka SelfControlLegacyLockFilePath)
//  - the defaults system
// we should check for block settings in both of these places and move them to the new SCSettings system
// (defaults continues to be used for some settings that only affect the UI and don't need to be read by helper tools)
// NOTE: this method should only be called when SCSettings is uninitialized, since it will overwrite any existing settings
// NOTE2: this method does NOT clear the settings from legacy locations, because that may break ongoing blocks being cleared
//        by older versions of the helper tool. Insteads, we will clean out legacy locations from the helper when
//        blocks are started or finished.
- (void)migrateLegacySettings {
    NSDictionary* lockDict = [NSDictionary dictionaryWithContentsOfFile: SelfControlLegacyLockFilePath];
    // note that the defaults will generally only be defined in the main app, not helper tool (because helper tool runs as root)
    NSDictionary* userDefaultsDict = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    
    // prefer reading from the lock file, using defaults as a backup only
    for (NSString* key in [[self defaultSettingsDict] allKeys]) {
        if (lockDict[key] != nil) {
            [self setValue: lockDict[key] forKey: key];
        } else if (userDefaultsDict[key] != nil) {
            [self setValue: userDefaultsDict[key] forKey: key];
        }
    }

    // Blocklist attribute was renamed so needs a special migration
    if (lockDict[@"HostBlacklist"] != nil) {
        [self setValue: lockDict[@"HostBlacklist"] forKey: @"Blocklist"];
    } else if (userDefaultsDict[@"HostBlacklist"] != nil) {
        [self setValue: userDefaultsDict[@"HostBlacklist"] forKey: @"Blocklist"];
    }

    // BlockStartedDate and BlockDuration were migrated to a simpler BlockEndDate property
    if ([SCBlockDateUtilities blockIsEnabledInDictionary: lockDict]) {
        [self setValue: [SCBlockDateUtilities blockEndDateInDictionary: lockDict] forKey: @"BlockEndDate"];
    } else if ([SCBlockDateUtilities blockIsEnabledInDictionary: userDefaultsDict]) {
        [self setValue: [SCBlockDateUtilities blockEndDateInDictionary: userDefaultsDict] forKey: @"BlockEndDate"];
    }
    
    // write out our brand-new migrated settings to disk!
    [self writeSettings];
}

+ (void)clearLegacySettings {
    
}

@synthesize settingsDictionary = _settingsDictionary;

@end
