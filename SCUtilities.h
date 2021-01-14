//
//  SCBlockDateUtilities.h
//  SelfControl
//
//  Created by Charles Stigler on 07/07/2018.
//

#import <Foundation/Foundation.h>

@class SCSettings;

// Holds utility methods for use throughout SelfControl


@interface SCUtilities : NSObject

dispatch_source_t CreateDebounceDispatchTimer(double debounceTime, dispatch_queue_t queue, dispatch_block_t block);

+ (NSArray<NSString*>*) cleanBlocklistEntry:(NSString*)rawEntry;

/* BLOCK SETTING METHODS */

// The point of these methods is basically to abstract out whether we're using blockStartedDate (the old system)
// or blockEndDate (the new system) for tracking blocks in settings/lockfile. We want to be backwards-compatible for a while so people
// who upgrade mid-block (foolishly!) have a better chance of surviving and we don't bork their stuff.
// eventually, another way to do this would just be to convert all blockStartedDates to blockEndDates on launch,
// but that sounds risky (updating lock files is not guaranteed) and this seems safer for now...

+ (NSDictionary*) defaultsDictForUser:(uid_t)controllingUID;

// Main app functions taking NSUserDefaults and SCSettings

+ (void) removeBlockFromSettings;

// Helper tool functions dealing with dictionaries and setDefaultsValue helper

// uses the below methods as well as filesystem checks to see if the block is REALLY running or not
+ (BOOL)anyBlockIsRunning:(uid_t)controllingUID;
+ (BOOL)anyBlockIsRunning;
+ (BOOL)modernBlockIsRunning;
+ (BOOL)legacyBlockIsRunning:(uid_t)controllingUID;
+ (BOOL)legacyBlockIsRunning;

+ (BOOL) blockIsRunningInDictionary:(NSDictionary*)dict;
+ (BOOL) blockShouldBeRunningInDictionary:(NSDictionary *)dict;

+ (BOOL) blockIsRunningInLegacyDictionary:(NSDictionary*)dict;

// read and write saved block files
+ (BOOL)writeBlocklistToFileURL:(NSURL*)targetFileURL blockInfo:(NSDictionary*)blockInfo errorDescription:(NSString**)errDescriptionRef;
+ (NSDictionary*)readBlocklistFromFile:(NSURL*)fileURL;

// migration methods
+ (NSString*)legacySecuredSettingsFilePathForUser:(uid_t)userId;
+ (BOOL)legacySettingsFound:(uid_t)controllingUID;
+ (BOOL)legacySettingsFound;
+ (NSDate*)legacyBlockEndDate;
+ (void)copyLegacySettingsToDefaults:(uid_t)controllingUID;
+ (void)copyLegacySettingsToDefaults;
+ (void)clearLegacySettings:(uid_t)controllingUID;

@end
