//
//  SCLockFileUtilities.m
//  SelfControl
//
//  Created by Charles Stigler on 20/10/2018.
//

#import "SCSettings.h"
#import <AppKit/AppKit.h>

#ifndef TESTING
#import <Sentry/Sentry.h>
#endif

float const SYNC_INTERVAL_SECS = 30;
float const SYNC_LEEWAY_SECS = 30;
NSString* const SETTINGS_FILE_DIR = @"/usr/local/etc/";

@interface SCSettings ()

// Private vars
@property (readonly) NSMutableDictionary* settingsDict;
@property NSDate* lastSynchronizedWithDisk;
@property dispatch_source_t syncTimer;
@property dispatch_source_t debouncedChangeTimer;

@end

@implementation SCSettings

+ (instancetype)sharedSettings {
    static SCSettings* globalSettings = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        globalSettings = [SCSettings new];
    });
    return globalSettings;
}

- (instancetype)init {
    if (self = [super init]) {
        // we will only write out settings if we have root permissions (i.e. the EUID is 0)
        // otherwise, we won't/shouldn't have permissions to write to the settings file
        // in practice, what this means is that the daemon writes settings, and the app/CLI only read
        _readOnly = (geteuid() != 0);
        
        _settingsDict = nil;
        
        [[NSDistributedNotificationCenter defaultCenter] addObserver: self
                                                            selector: @selector(onSettingChanged:)
                                                                name: @"org.eyebeam.SelfControl.SCSettingsValueChanged"
                                                              object: nil
                                                  suspensionBehavior: NSNotificationSuspensionBehaviorDeliverImmediately];
    }
    return self;
}

+ (NSString*)settingsFileName {
    static NSString* fileName = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fileName = [NSString stringWithFormat: @".%@.plist", [SCMiscUtilities sha1: [NSString stringWithFormat: @"SelfControlUserPreferences%@", [SCMiscUtilities getSerialNumber]]]];
    });

    return fileName;
}
+ (NSString*)securedSettingsFilePath {
    static NSString* filePath = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        filePath = [NSString stringWithFormat: @"%@%@", SETTINGS_FILE_DIR, SCSettings.settingsFileName];
    });

    return filePath;
}

// NOTE: there should be a default setting for each valid setting, even if it's nil/zero/etc
- (NSDictionary*)defaultSettingsDict {
    return @{
        @"BlockEndDate": [NSDate distantPast],
        @"ActiveBlocklist": @[],
        @"ActiveBlockAsWhitelist": @NO,

        @"BlockIsRunning": @NO, // tells us whether a block is actually running on the system (to the best of our knowledge)
        @"TamperingDetected": @NO,
        
        // block settings
        // the user sets these in defaults, then when a block is started they're copied over to settings
        @"EvaluateCommonSubdomains": @YES,
        @"IncludeLinkedDomains": @YES,
        @"BlockSoundShouldPlay": @NO,
        @"BlockSound": @5,
        @"ClearCaches": @YES,
        @"AllowLocalNetworks": @YES,

        @"EnableErrorReporting": @([SCMiscUtilities systemThirdPartyCrashReportingEnabled]),

        @"SettingsVersionNumber": @0,
        @"LastSettingsUpdate": [NSDate distantPast] // special value that keeps track of when we last updated our settings
    };
}

- (void)initializeSettingsDict {
    // make sure we only load the settings dictionary once, even if called simultaneously from multiple threads
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @synchronized (self) {
            self->_settingsDict = [NSMutableDictionary dictionaryWithContentsOfFile: SCSettings.securedSettingsFilePath];
            
            BOOL isTest = [[NSUserDefaults standardUserDefaults] boolForKey: @"isTest"];
            if (isTest) NSLog(@"Ignoring settings on disk because we're unit-testing");
            
            // if we don't have a settings dictionary on disk yet,
            // set it up with the default values (and migrate legacy settings also)
            // also if we're running tests, just use the default dict
            if (self->_settingsDict == nil || isTest) {
                self->_settingsDict = [[self defaultSettingsDict] mutableCopy];
                
                // write out our brand-new settings to disk!
                if (!self.readOnly) {
                    [self writeSettings];
                }
                [SCSentry addBreadcrumb: @"Initialized SCSettings to default settings" category: @"settings"];
            }
            
            // we're now current with disk!
            self->lastSynchronizedWithDisk = [NSDate date];

            [self startSyncTimer];
        }
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
        NSDictionary* settingsFromDisk = [NSDictionary dictionaryWithContentsOfFile: SCSettings.securedSettingsFilePath];
        
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
            [SCSentry addBreadcrumb: @"Updated SCSettings to newer settings found on disk" category: @"settings"];
        }
    }
}
- (void)writeSettingsWithCompletion:(nullable void(^)(NSError* _Nullable))completionBlock {
    @synchronized (self) {
        if (self.readOnly) {
            NSLog(@"WARNING: Read-only SCSettings instance can't write out settings");
            NSError* err = [SCErr errorWithCode: 600];
            [SCSentry captureError: err];
            if (completionBlock != nil) {
                completionBlock(err);
            }
            return;
        }

#if TESTING
        // no writing to disk during unit tests
        NSLog(@"Would write settings to disk now (but no writing during unit tests)");
        if (completionBlock != nil) completionBlock(nil);
        return;
#endif
        
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
            
            NSError* createDirectoryErr;
            BOOL createDirectorySuccessful = [[NSFileManager defaultManager] createDirectoryAtURL: [NSURL fileURLWithPath: SETTINGS_FILE_DIR]
                                                                      withIntermediateDirectories: YES
                                                                                       attributes: @{
                                                                                           NSFileOwnerAccountID: [NSNumber numberWithUnsignedLong: 0],
                                                                                           NSFileGroupOwnerAccountID: [NSNumber numberWithUnsignedLong: 0],
                                                                                           NSFilePosixPermissions: [NSNumber numberWithShort: 0755]
                                                                                       }
                                                                                            error: &createDirectoryErr];
            if (!createDirectorySuccessful) {
                NSLog(@"WARNING: Failed to create %@ folder to store SCSettings. Error was %@", SETTINGS_FILE_DIR, createDirectoryErr);
                [SCSentry addBreadcrumb: [NSString stringWithFormat: @"Failed to create directory for SCSettings with error %@", createDirectoryErr] category:@"settings"];
            }

            NSError* chmodDirectoryErr;
            BOOL chmodDirectorySuccessful = [[NSFileManager defaultManager]
                                             setAttributes: @{
                                                 NSFilePosixPermissions: [NSNumber numberWithShort: 0755]
                                             }
                                             ofItemAtPath: SETTINGS_FILE_DIR
                                             error: &chmodDirectoryErr];
            if (!chmodDirectorySuccessful) {
                NSLog(@"WARNING: Failed to set permissions on %@ folder to store SCSettings. Error was %@", SETTINGS_FILE_DIR, chmodDirectoryErr);
                [SCSentry addBreadcrumb: [NSString stringWithFormat: @"Failed to set directory permissions for SCSettings with error %@", chmodDirectoryErr] category:@"settings"];
            }

            NSError* writeErr;
            BOOL writeSuccessful = [plistData writeToFile: SCSettings.securedSettingsFilePath
                                                  options: NSDataWritingAtomic
                                                    error: &writeErr
                                    ];
            
            NSError* chmodErr;
            BOOL chmodSuccessful = [[NSFileManager defaultManager]
                                    setAttributes: @{
                                        NSFileOwnerAccountID: [NSNumber numberWithUnsignedLong: 0],
                                        NSFileGroupOwnerAccountID: [NSNumber numberWithUnsignedLong: 0],
                                        NSFilePosixPermissions: [NSNumber numberWithShort: 0755]
                                    }
                                    ofItemAtPath: SCSettings.securedSettingsFilePath
                                    error: &chmodErr];

            if (writeSuccessful) {
                self.lastSynchronizedWithDisk = [NSDate date];
            }

            if (!writeSuccessful) {
                NSLog(@"Failed to write secured settings to file %@", SCSettings.securedSettingsFilePath);
                [SCSentry captureError: writeErr];
                if (completionBlock != nil) completionBlock(writeErr);
            } else if (!chmodSuccessful) {
                NSLog(@"Failed to change secured settings file owner/permissions secured settings for file %@ with error %@", SCSettings.securedSettingsFilePath, chmodErr);
                [SCSentry captureError: chmodErr];
                if (completionBlock != nil) completionBlock(chmodErr);
            } else {
                [SCSentry addBreadcrumb: @"Successfully wrote SCSettings out to file" category: @"settings"];
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
    
    if ([lastSettingsUpdate timeIntervalSinceDate: self.lastSynchronizedWithDisk] > 0 && !self.readOnly) {
        NSLog(@" --> Writing settings to disk (haven't been written since %@)", self.lastSynchronizedWithDisk);
        [self writeSettingsWithCompletion: completionBlock];
    } else {
        if(completionBlock != nil) {
            // don't just run the callback asynchronously, since it makes this method harder to reason about
            // (it'd sometimes call back synchronously and sometimes async)
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                completionBlock(nil);
//            });
        }
    }
}
- (void)synchronizeSettings {
    [self synchronizeSettingsWithCompletion: nil];
}

- (NSError*)syncSettingsAndWait:(NSInteger)timeoutSecs {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSError* retErr = nil;

    // do this on another thread so it doesn't deadlock our semaphore
    // (also dispatch_async ensures correct behavior even if synchronizeSettingsWithCompletion itself returns synchronously)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self synchronizeSettingsWithCompletion:^(NSError* err) {
            retErr = err;
            
            dispatch_semaphore_signal(sema);
        }];
    });
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)timeoutSecs * (int64_t)NSEC_PER_SEC))) {
        retErr = [SCErr errorWithCode: 601];
    }
    
    return retErr;
}

- (void)setValue:(id)value forKey:(NSString*)key stopPropagation:(BOOL)stopPropagation {
    // if we're a readonly instance, we generally shouldn't be allowing values to be set
    // the only exception is receiving value updates (via notification) from other processes
    // in which case stopPropagation will be true
    if (self.readOnly && !stopPropagation) {
        NSLog(@"WARNING: Read-only SCSettings instance can't update values (setting %@ to %@)", key, value);
        return;
    }
    
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
    // between two processes. It indicates that the change started in another process
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
- (void)cancelSyncTimers {
    if (self.syncTimer != nil) {
        dispatch_source_cancel(self.syncTimer);
        self.syncTimer = nil;
    }
    
    if (self.debouncedChangeTimer != nil) {
        dispatch_source_cancel(self.debouncedChangeTimer);
        self.debouncedChangeTimer = nil;
    }
}

- (void)updateSentryContext {
    // make sure Sentry has the latest context in the event of a crash
    
    NSMutableDictionary* dictCopy = [self.settingsDict mutableCopy];
    
    // fill in any gaps with default values (like we did if they called valueForKey:)
    for (NSString* key in [[self defaultSettingsDict] allKeys]) {
        if (dictCopy[key] == nil) {
            dictCopy[key] = [self defaultSettingsDict][key];
        }
    }
    
    // eliminate privacy-sensitive data (i.e. blocklist)
    // but store the blocklist length as a useful piece of debug info
    id activeBlocklist = dictCopy[@"ActiveBlocklist"];
    NSUInteger blocklistLength = (activeBlocklist == nil) ? 0 : ((NSArray*)activeBlocklist).count;
    [dictCopy setObject: @(blocklistLength) forKey: @"ActiveBlocklistLength"];
    [dictCopy removeObjectForKey: @"Blocklist"];
    [dictCopy removeObjectForKey: @"ActiveBlocklist"];

    // and serialize dates to string, since Sentry has a hard time with that
    NSArray<NSString*>* dateKeys = @[@"BlockEndDate", @"LastSettingsUpdate"];
    for (NSString* dateKey in dateKeys) {
        dictCopy[dateKey] = [NSDateFormatter localizedStringFromDate: dictCopy[dateKey]
                                                                 dateStyle: NSDateFormatterShortStyle
                                                                 timeStyle: NSDateFormatterFullStyle];
    }

#ifndef TESTING
    [SentrySDK configureScope:^(SentryScope * _Nonnull scope) {
        [scope setContextValue: dictCopy forKey: @"SCSettings"];
    }];
#endif
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
    } else {
        NSLog(@"Accepting propagated change (%@ --> %@) since version %d is newer than %d and/or %@ is newer than %@", note.userInfo[@"key"], note.userInfo[@"value"], noteVersionNumber, ourSettingsVersionNumber, noteSettingUpdated, ourSettingsLastUpdated);
        
        // mirror the change on our own instance - but don't propagate the change to avoid loopin
        [self setValue: note.userInfo[@"value"] forKey: note.userInfo[@"key"] stopPropagation: YES];
    }
    
    // regardless of which is more recent, we should really go get the new deal from disk
    // in the near future (but debounce so we don't do this a million times for rapid changes)
    if (self.debouncedChangeTimer != nil) {
        dispatch_source_cancel(self.debouncedChangeTimer);
        self.debouncedChangeTimer = nil;
    }
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    double throttleSecs = 0.25f;
    self.debouncedChangeTimer = [SCMiscUtilities createDebounceDispatchTimer: throttleSecs
                                                                   queue: queue
                                                                   block: ^{
        NSLog(@"Syncing settings due to propagated changes");
        [self synchronizeSettings];
    }];
}

- (void)resetAllSettingsToDefaults {
    // we _basically_ just copy the default settings dict in,
    // except we leave the settings version number and last settings update
    // intact - that helps keep us in sync with any other instances
    NSDictionary* defaultSettings = [self defaultSettingsDict];
    for (NSString* key in defaultSettings) {
        if ([key isEqualToString: @"SettingsVersionNumber"] || [key isEqualToString: @"LastSettingsUpdate"]) {
            continue;
        }
        
        [self setValue: defaultSettings[key] forKey: key];
    }
}

- (void)dealloc {
    [self cancelSyncTimers];
}

@synthesize settingsDict = _settingsDict, lastSynchronizedWithDisk;

@end
