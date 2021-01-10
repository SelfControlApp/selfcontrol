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
#import "SCUtilities.h"
#import <AppKit/AppKit.h>
#import "SCConstants.h"

float const SYNC_INTERVAL_SECS = 30;
float const SYNC_LEEWAY_SECS = 30;

@interface SCSettings ()

// Private vars
@property (readonly) NSMutableDictionary* settingsDict;
@property NSDate* lastSynchronizedWithDisk;
@property dispatch_source_t syncTimer;

@end

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
    
    @synchronized (settingsForUserIds) {
        if (settingsForUserIds[@(uid)] == nil) {
            // no settings object yet for this UID, instantiate one
            settingsForUserIds[@(uid)] = [[self alloc] initWithUserId: uid];
        }
    }
    
    // return the settings object we've got cached for this user id!
    return settingsForUserIds[@(uid)];
}
+ (instancetype)currentUserSettings {
    return [SCSettings settingsForUser: getuid()];
}
+ (instancetype)sharedSettings {
    return [SCSettings settingsForUser: 0];
}

- (instancetype)initWithUserId:(uid_t)userId {
    if (self = [super init]) {
        _userId = userId;
        _settingsDict = nil;
        
        [[NSDistributedNotificationCenter defaultCenter] addObserver: self
                                                            selector: @selector(onSettingChanged:)
                                                                name: @"org.eyebeam.SelfControl.SCSettingsValueChanged"
                                                              object: nil
                                                  suspensionBehavior: NSNotificationSuspensionBehaviorDeliverImmediately];
    }
    return self;
}
- (instancetype)init {
    return [self initWithUserId: 0];
}

- (NSString*)settingsFileName {
    return [NSString stringWithFormat: @".%@.plist", [self sha1: [NSString stringWithFormat: @"SelfControlUserPreferences%@", [self getSerialNumber]]]];
}
- (NSString*)securedSettingsFilePath {
    NSArray<NSURL*>* libraryURLs = [[NSFileManager defaultManager] URLsForDirectory: NSLibraryDirectory inDomains: NSLocalDomainMask];
    
    return [NSString stringWithFormat: @"/etc/%@", [self settingsFileName]];
}
- (NSString*)legacySecuredSettingsFilePathForUser:(uid_t)userId {
    NSString* homeDir = [self homeDirectoryForUid: userId];
    return [[NSString stringWithFormat: @"%@/Library/Preferences/%@", homeDir, [self settingsFileName]] stringByExpandingTildeInPath];
}

// NOTE: there should be a default setting for each valid setting, even if it's nil/zero/etc
- (NSDictionary*)defaultSettingsDict {
    return @{
        @"BlockEndDate": [NSDate distantPast],
        @"ActiveBlocklist": @[],
        @"ActiveBlockAsWhitelist": @NO,

        @"BlockIsRunning": @NO, // tells us whether a block is actually running on the system (to the best of our knowledge)
        
        @"TamperingDetected": @NO,

        @"SettingsVersionNumber": @0,
        @"LastSettingsUpdate": [NSDate distantPast] // special value that keeps track of when we last updated our settings
    };
}

- (void)initializeSettingsDict {
    // make sure we only load the settings dictionary once, even if called simultaneously from multiple threads
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        self->_settingsDict = [NSMutableDictionary dictionaryWithContentsOfFile: [self securedSettingsFilePath]];
        
        BOOL isTest = [[NSUserDefaults standardUserDefaults] boolForKey: @"isTest"];
        if (isTest) NSLog(@"Ignoring settings on disk because we're unit-testing");
        
        // if we don't have a settings dictionary on disk yet,
        // set it up with the default values (and migrate legacy settings also)
        // also if we're running tests, just use the default dict
        if (self->_settingsDict == nil || isTest) {
            self->_settingsDict = [[self defaultSettingsDict] mutableCopy];
            [self migrateLegacySettings];
            
            // write out our brand-new migrated settings to disk!
            [self writeSettings];
        }
        
        // we're now current with disk!
        self->lastSynchronizedWithDisk = [NSDate date];
        
        [self startSyncTimer];
    });
}

- (NSDictionary*)settingsDict {
    if (_settingsDict == nil) {
        [self initializeSettingsDict];
    }
    return _settingsDict;
}

- (NSDictionary*)dictionaryRepresentation {
    NSMutableDictionary* dictCopy = [self.settingsDict mutableCopy];
    
    // fill in any gaps with default values (like we did if they called valueForKey:)
    for (NSString* key in [[self defaultSettingsDict] allKeys]) {
        if (dictCopy[key] == nil) {
            dictCopy[key] = [self defaultSettingsDict][key];
        }
    }

    return dictCopy;
}

// both reloadSettings and writeSettings are synchronized with the same object, so
// at any given time we are running a maximum of one of these methods, on one thread.
// we don't want to be reading the file on one thread and writing out two different versions
// on two other threads

- (void)reloadSettings {
    // if the settings dictionary hasn't been loaded the first time, do that instead of reloading
    if (_settingsDict == nil) {
        [self initializeSettingsDict];
        return;
    }

    @synchronized (self) {
        NSDictionary* settingsFromDisk = [NSDictionary dictionaryWithContentsOfFile: [self securedSettingsFilePath]];
        
        int diskSettingsVersion = [settingsFromDisk[@"SettingsVersionNumber"] intValue];
        int memorySettingsVersion = [[self valueForKey: @"SettingsVersionNumber"] intValue];
        NSDate* diskSettingsLastUpdated = settingsFromDisk[@"LastSettingsUpdate"];
        NSDate* memorySettingsLastUpdated = [self valueForKey: @"LastSettingsUpdate"];
        
        // occasionally we can end up with timestamps from the future
        // (usually because the user moved their system clock forward, then back again)
        // it's a weird edge case and we should just fix that when we see it
        if ([diskSettingsLastUpdated timeIntervalSinceNow] > 0) {
            // we'll pretend the disk was written 1 second ago in this case to avoid weird edge conditions
            diskSettingsLastUpdated = [[NSDate date] dateByAddingTimeInterval: 1.0];
        }
        if ([memorySettingsLastUpdated timeIntervalSinceNow] > 0) {
            memorySettingsLastUpdated = [NSDate date];
            [self setValue: memorySettingsLastUpdated forKey: @"LastSettingsUpdate"];
        }

        if (diskSettingsLastUpdated == nil) diskSettingsLastUpdated = [NSDate distantPast];
        
        // try to decide which is more recent by version number, tiebreak by date
        BOOL diskMoreRecentThanMemory = NO;
        if (diskSettingsVersion == memorySettingsVersion) {
            diskMoreRecentThanMemory = ([diskSettingsLastUpdated timeIntervalSinceDate: memorySettingsLastUpdated] > 0);
        } else {
            diskMoreRecentThanMemory = (diskSettingsVersion > memorySettingsVersion);
        }

        if (diskMoreRecentThanMemory) {
            _settingsDict = [settingsFromDisk mutableCopy];
            self.lastSynchronizedWithDisk = [NSDate date];
            NSLog(@"Newer SCSettings found on disk (version %d vs %d with time interval %f), updating...", diskSettingsVersion, memorySettingsVersion, [diskSettingsLastUpdated timeIntervalSinceDate: memorySettingsLastUpdated]);
            
        }
    }
}
- (void)writeSettingsWithCompletion:(nullable void(^)(NSError* _Nullable))completionBlock {
    @synchronized (self) {
        if (geteuid() != 0) {
            NSLog(@"Attempting to write out SCSettings with non-root permissions (%u), failing...", geteuid());
            if (completionBlock != nil) {
                completionBlock([NSError errorWithDomain: kSelfControlErrorDomain code: -501 userInfo: @{
                    NSLocalizedDescriptionKey: NSLocalizedString(@"Attempting to write out SCSettings with non-root permissions (%d), failing...", nil)
                }]);
            }
            return;
        }

        if ([[NSUserDefaults standardUserDefaults] boolForKey: @"isTest"]) {
            // no writing to disk during unit tests
            NSLog(@"Would write settings to disk now (but no writing during unit tests)");
            if (completionBlock != nil) completionBlock(nil);
            return;
        }
        
        // don't spend time on the main thread writing out files - it's OK for this to happen without blocking other things
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError* serializationErr;
            NSData* plistData = [NSPropertyListSerialization dataWithPropertyList: self.settingsDict
                                                                           format: NSPropertyListBinaryFormat_v1_0
                                                                          options: kNilOptions
                                                                            error: &serializationErr];
                            
            if (plistData == nil) {
                NSLog(@"NSPropertyListSerialization error: %@", serializationErr);
                if (completionBlock != nil) completionBlock(serializationErr);
                return;
            }

            NSError* writeErr;
            BOOL writeSuccessful = [plistData writeToFile: self.securedSettingsFilePath
                                                  options: NSDataWritingAtomic
                                                    error: &writeErr
                                    ];
            
            NSError* chmodErr;
            BOOL chmodSuccessful = [[NSFileManager defaultManager]
                                    setAttributes: @{
                                        @"NSFileOwnerAccountID": [NSNumber numberWithUnsignedLong: 0],
                                        @"NSFilePosixPermissions": [NSNumber numberWithShort: 0755]
                                    }
                                    ofItemAtPath: self.securedSettingsFilePath
                                    error: &chmodErr];

            if (writeSuccessful) {
                self.lastSynchronizedWithDisk = [NSDate date];
                NSLog(@"wrote %@ to %@", plistData, self.securedSettingsFilePath);
            }

            if (!writeSuccessful) {
                NSLog(@"Failed to write secured settings to file %@", self.securedSettingsFilePath);
                if (completionBlock != nil) completionBlock(writeErr);
            } else if (!chmodSuccessful) {
                NSLog(@"Failed to change secured settings file owner/permissions secured settings for file %@ with error %@", self.securedSettingsFilePath, chmodErr);
                if (completionBlock != nil) completionBlock(chmodErr);
            } else {
                if (completionBlock != nil) completionBlock(nil);
            }
        });
    }
}
- (void)writeSettings {
    // by default, just log all errors
    [self writeSettingsWithCompletion:^(NSError * _Nullable err) {
        if (err != nil) {
            NSLog(@"Error writing SCSettings: %@", err);
        }
    }];
}
- (void)synchronizeSettingsWithCompletion:(nullable void (^)(NSError * _Nullable))completionBlock {
    [self reloadSettings];
    
    NSDate* lastSettingsUpdate = [self valueForKey: @"LastSettingsUpdate"];
    
    // occasionally we can end up with timestamps from the future
    // (usually because the user moved their system clock forward, then back again)
    // it's a weird edge case and we should just fix that when we see it
    if ([lastSettingsUpdate timeIntervalSinceNow] > 0) {
        [self setValue: [NSDate date] forKey: @"LastSettingsUpdate"];
    }
    
    if ([lastSettingsUpdate timeIntervalSinceDate: self.lastSynchronizedWithDisk] > 0 && geteuid() == 0) {
        NSLog(@" --> Writing settings to disk (haven't been written since %@)", self.lastSynchronizedWithDisk);
        [self writeSettingsWithCompletion: completionBlock];
    } else {
        if(completionBlock != nil) completionBlock(nil);
    }
}
- (void)synchronizeSettings {
    [self synchronizeSettingsWithCompletion: nil];
}

- (void)setValue:(id)value forKey:(NSString*)key stopPropagation:(BOOL)stopPropagation {
    // we can't store nils in a dictionary
    // so we sneak around it
    if (value == nil) {
        value = [NSNull null];
    }
    
    // locking everything on self is kinda inefficient/unnecessary
    // since it means we can only set one value at a time, and never when reading/writing from disk
    // but it seems to be OK for now - we'll improve later
    @synchronized (self) {
        // if we're about to insert NSNull anyway, may as well just unset the value
        if ([value isEqual: [NSNull null]]) {
            [self.settingsDict removeObjectForKey: key];
        } else {
            [self.settingsDict setValue: value forKey: key];
        }
        
        // record the update
        int newVersionNumber = [[self valueForKey: @"SettingsVersionNumber"] intValue] + 1;
        [self.settingsDict setValue: [NSNumber numberWithInt: newVersionNumber] forKey: @"SettingsVersionNumber"];
        [self.settingsDict setValue: [NSDate date] forKey: @"LastSettingsUpdate"];
    }
    
    // notify other instances (presumably in other processes)
    // stopPropagation is a flag that stops one setting change from bouncing back and forth for ages
    // between two processes
    if (!stopPropagation) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"org.eyebeam.SelfControl.SCSettingsValueChanged"
                                                                       object: self.description
                                                                     userInfo: @{
                                                                                 @"key": key,
                                                                                 @"value": value,
                                                                                 @"versionNumber": self.settingsDict[@"SettingsVersionNumber"],
                                                                                 @"date": [NSDate date]
                                                                                 }
                                                                      options: NSNotificationDeliverImmediately | NSNotificationPostToAllSessions
         ];
    }
}
- (void)setValue:(id)value forKey:(NSString*)key {
    [self setValue: value forKey: key stopPropagation: NO];
}

- (id)valueForKey:(NSString*)key {
    id value = [self.settingsDict valueForKey: key];
    
    // when we get an NSNull we have to unwrap it and remember that means nil
    if ([value isEqual: [NSNull null]]) {
        value = nil;
    }
    
    // if we don't have a value in our dictionary but we do have a default value, use that instead!
    if (value == nil && [self defaultSettingsDict][key] != nil) {
        value = [self defaultSettingsDict][key];
    }

    return value;
}
- (BOOL)boolForKey:(NSString*)key {
    return [[self valueForKey: key] boolValue];
}

// We might have "legacy" block settings hiding in one of two places:
//  - a "lock file" at /etc/SelfControl.lock (aka SelfControlLegacyLockFilePath)
//  - the defaults system
// we should check for block settings in both of these places and move them to the new SCSettings system
// (defaults continues to be used for some settings that only affect the UI and don't need to be read by helper tools)
// NOTE: this method should only be called when SCSettings is uninitialized, since it will overwrite any existing settings
// NOTE2: this method does NOT clear the settings from legacy locations, because that may break ongoing blocks being cleared
//        by older versions of the helper tool. Instead, we will clean out legacy locations from the helper when
//        blocks are started or finished.
// NOTE3: this method always pulls user defaults for the current user, regardless of what instance it's called on
- (void)migrateLegacySettings {
    // try to migrate from the user-based secured settings model (v3.0-3.0.3)
    // basically, we're gonna take the most-recently-updated settings, if they exist
    // of course, we can only access settings that are readable to us, i.e.
    // if this first gets run as user X, they generally won't be able to read user Y's prefs
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSArray<NSURL*>* libraryURLs = [fileManager URLsForDirectory: NSLibraryDirectory inDomains: NSAllDomainsMask];
    NSMutableArray<NSString*>* preferencePaths = [NSMutableArray arrayWithCapacity: libraryURLs.count];
    for (NSURL* libraryURL in libraryURLs) {
        [preferencePaths addObject: [NSString stringWithFormat: @"%@/Preferences/%@", libraryURL.path, [self settingsFileName]]];
    }
    NSDictionary* latestSettingsDict;
    for (NSString* prefPath in preferencePaths) {
        if ([fileManager isReadableFileAtPath: prefPath]) {

            NSDictionary* settingsFromDisk = [NSDictionary dictionaryWithContentsOfFile: prefPath];
            if (!settingsFromDisk) continue;
            
            if (latestSettingsDict == nil || [settingsFromDisk[@"LastSettingsUpdate"] timeIntervalSinceDate: latestSettingsDict[@"LastSettingsUpdate"]] > 0) {
                latestSettingsDict = settingsFromDisk;
            }
        }
    }
    
    if (latestSettingsDict != nil) {
        NSLog(@"Migrating all settings from %@", latestSettingsDict);

        for (NSString* key in [[self defaultSettingsDict] allKeys]) {
            if (latestSettingsDict[key] != nil) {
                [self setValue: latestSettingsDict[key] forKey: key];
            }
        }

        // Blocklist setting no longer in use (moved to ActiveBlocklist)
        [self setValue: nil forKey: @"Blocklist"];

        NSLog(@"Migrated!");
        return;
    }
    
    
    // if no user-based secured settings exist, we try to read from the even older legacy defaults settings
    
    
    NSDictionary* lockDict = [NSDictionary dictionaryWithContentsOfFile: SelfControlLegacyLockFilePath];
    // note that the defaults will generally only be defined in the main app, not helper tool (because helper tool runs as root)
    NSDictionary* userDefaultsDict = [NSUserDefaults standardUserDefaults].dictionaryRepresentation;
    
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

    // BlockStartedDate was migrated to a simpler BlockEndDate property (which doesn't require BlockDuration to function)
    // so we need to specially convert the old BlockStartedDate into BlockEndDates
    // NOTE: we do NOT set BlockIsRunning to YES in Settings for a legacy migration
    // Why? the old version of the helper tool is still involved, and it doesn't know
    // to clear that setting. So it will stay stuck on.
    if ([SCUtilities blockIsRunningInLegacyDictionary: lockDict]) {
        [self setValue: [SCUtilities endDateFromLegacyBlockDictionary: lockDict] forKey: @"BlockEndDate"];
    } else if ([SCUtilities blockIsRunningInDictionary: userDefaultsDict]) {
        [self setValue: [SCUtilities endDateFromLegacyBlockDictionary: userDefaultsDict] forKey: @"BlockEndDate"];
    }
}

// NOTE: this method always clears the user defaults for the current user, regardless of what instance
// it's called on
- (void)clearLegacySettings {
    // TODO: figure out what this should do in the new world!
    return;
    
    // make sure the settings dictionary is set up (and migration has occurred if necessary)
    [self initializeSettingsDict];

    NSError* err;

    // no more need for the old lock file!
    if(![[NSFileManager defaultManager] removeItemAtPath: SelfControlLegacyLockFilePath error: &err] && [[NSFileManager defaultManager] fileExistsAtPath: SelfControlLegacyLockFilePath]) {
        NSLog(@"WARNING: Could not remove legacy SelfControl lock file because of error: %@", err);
    }

    // clear keys out of user defaults which are now stored in SCSettings
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray* defaultsKeysToClear = @[
                             @"BlockStartedDate",
                             @"HostBlacklist",
                             @"EvaluateCommonSubdomains",
                             @"IncludeLinkedDomains",
                             @"BlockSoundShouldPlay",
                             @"BlockSound",
                             @"ClearCaches",
                             @"AllowLocalNetworks"
                             ];
    for (NSString* key in defaultsKeysToClear) {
        [userDefaults removeObjectForKey: key];
    }
    
    // clear keys out of SCSettings which are no longer used
    NSArray* settingsKeysToClear = @[
                             @"Blocklist",
                             @"BlockAsWhitelist"
                             ];
    for (NSString* key in settingsKeysToClear) {
        [self setValue:nil forKey: key];
    }
}
- (void)startSyncTimer {
    if (self.syncTimer != nil) {
        // we already have a timer, so no need to start another
        return;
    }
    
    // set up a timer so values get synchronized to disk on a regular basis
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self.syncTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    if (self.syncTimer) {
        dispatch_source_set_timer(self.syncTimer, dispatch_time(DISPATCH_TIME_NOW, SYNC_INTERVAL_SECS * NSEC_PER_SEC), SYNC_INTERVAL_SECS * NSEC_PER_SEC, SYNC_LEEWAY_SECS * NSEC_PER_SEC);
        dispatch_source_set_event_handler(self.syncTimer, ^{
            [self synchronizeSettings];
        });
        dispatch_resume(self.syncTimer);
    }
}
- (void)cancelSyncTimer {
    if (self.syncTimer == nil) {
        // no active timer, no need to cancel
        return;
    }

    dispatch_source_cancel(self.syncTimer);
    self.syncTimer = nil;
}

- (void)onSettingChanged:(NSNotification*)note {
    // note.object is a string, so we can't just do a simple == to see if the object is self
    // but if we check our description against it, that will do the same thing because description
    // includes the memory address. Don't override description or this logic will break!!
    if ([note.object isEqualToString: [self description]]) {
        // we don't need to listen to our own notifications
        return;
    }
    
    if (note.userInfo[@"key"] == nil) {
        // something's wrong - we don't have a key to set
        return;
    }
    
    // if this change happened before our latest update, it's kinda unclear what the end state should be
    // so ignore it and just queue up a sync instead
    int noteVersionNumber = [note.userInfo[@"versionNumber"] intValue];
    NSDate* noteSettingUpdated = note.userInfo[@"date"];
    int ourSettingsVersionNumber = [[self valueForKey: @"SettingsVersionNumber"] intValue];
    NSDate* ourSettingsLastUpdated = [self valueForKey: @"LastSettingsUpdate"];

    // check by version number, tiebreak by last updated date
    BOOL noteMoreRecentThanSettings = NO;
    if (noteVersionNumber == ourSettingsVersionNumber) {
        noteMoreRecentThanSettings = ([noteSettingUpdated timeIntervalSinceDate: ourSettingsLastUpdated] > 0);
    } else {
        noteMoreRecentThanSettings = (noteVersionNumber > ourSettingsVersionNumber);
    }

    if (!noteMoreRecentThanSettings) {
        NSLog(@"Ignoring setting change notification as %@ is older than %@", noteSettingUpdated, ourSettingsLastUpdated);
        [self synchronizeSettings];
        return;
    } else {
        NSLog(@"Accepting propagated change (%@ --> %@) since version %d is newer than %d and/or %@ is newer than %@", note.userInfo[@"key"], note.userInfo[@"value"], noteVersionNumber, ourSettingsVersionNumber, noteSettingUpdated, ourSettingsLastUpdated);
        
        // mirror the change on our own instance - but don't propagate the change to avoid loopin
        [self setValue: note.userInfo[@"value"] forKey: note.userInfo[@"key"] stopPropagation: YES];
        
        // and then make a note to go refresh from disk in the near future (but debounce so we don't do this a million times for rapid changes)
        static dispatch_source_t debouncedReloadTimer = nil;
        if (debouncedReloadTimer != nil) {
            dispatch_source_cancel(debouncedReloadTimer);
            debouncedReloadTimer = nil;
        }
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        double throttleSecs = 0.25f;
        debouncedReloadTimer = CreateDebounceDispatchTimer(throttleSecs, queue, ^{
            NSLog(@"Reloading settings due to propagated changes");
            [self reloadSettings];
        });
    }
}

- (void)dealloc {
    [self cancelSyncTimer];
}

@synthesize settingsDict = _settingsDict, lastSynchronizedWithDisk;

@end
