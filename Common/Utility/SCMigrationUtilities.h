//SCMigrationUtilities//  SCMigration.h
//  SelfControl
//
//  Created by Charlie Stigler on 1/19/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Utility methods dealing with legacy settings, legacy blocks,
// and migrating us from old versions of the app to the new one

@interface SCMigrationUtilities : NSObject

+ (NSString*)legacySecuredSettingsFilePathForUser:(uid_t)userId;

+ (BOOL)legacySettingsFoundForUser:(uid_t)controllingUID;
+ (BOOL)legacySettingsFoundForCurrentUser;
+ (BOOL)legacyLockFileExists;

+ (BOOL)legacyBlockIsRunningInSettingsFile:(NSURL*)settingsFileURL;
+ (BOOL)blockIsRunningInLegacyDictionary:(NSDictionary*)dict;

+ (NSDate*)legacyBlockEndDate;

+ (void)copyLegacySettingsToDefaults:(uid_t)controllingUID;
+ (void)copyLegacySettingsToDefaults;

+ (NSError*)clearLegacySettingsForUser:(uid_t)controllingUID;
+ (NSError*)clearLegacySettingsForUser:(uid_t)controllingUID ignoreRunningBlock:(BOOL)ignoreRunningBlock;

@end

NS_ASSUME_NONNULL_END
