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
        @"HostBlacklist": @[],
        @"EvaluateCommonSubdomains": @YES,
        @"IncludeLinkedDomains": @YES,
        @"BlockSoundShouldPlay": @NO,
        @"BlockSound": @5,
        @"ClearCaches": @YES,
        @"BlockAsWhitelist": @NO,
        @"AllowLocalNetworks": @YES,
    };
}
- (NSDictionary*)settingsDictionary {
    if (_settingsDictionary == nil) {
        _settingsDictionary = [NSMutableDictionary dictionaryWithContentsOfFile: [self securedSettingsFilePath]];
        
        if (_settingsDictionary == nil) {
            _settingsDictionary = [[self defaultSettingsDict] mutableCopy];
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
- (id)getValueForKey:(NSString*)key {
    return [self.settingsDictionary valueForKey: key];
}

@synthesize settingsDictionary = _settingsDictionary;

@end
