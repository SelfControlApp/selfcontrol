//
//  SCBlockDateUtilities.h
//  SelfControl
//
//  Created by Charles Stigler on 07/07/2018.
//

#import <Foundation/Foundation.h>

@class SCSettings;

// The point of this class is basically to abstract out whether we're using blockStartedDate (the old system)
// or blockEndDate (the new system) for tracking blocks in settings/lockfile. We want to be backwards-compatible for a while so people
// who upgrade mid-block (foolishly!) have a better chance of surviving and we don't bork their stuff.
// eventually, another way to do this would just be to convert all blockStartedDates to blockEndDates on launch,
// but that sounds risky (updating lock files is not guaranteed) and this seems safer for now...

@interface SCBlockSettingUtilities : NSObject

/* Actions */

// Sets the appropriate blockEndDate in settings based on the current time and the blockDuration
// Note this does NOT set blockIsRunning - we set that only when the block is actually applied
+ (void) addBlockInSettings:(SCSettings*)settings withBlockDuration:(NSTimeInterval)blockDuration;

// removes the block from settings by clearing BlockEndDate and BlockIsRunning
+ (void) removeBlockFromSettings:(SCSettings*)settings;

// removes the block from settings, but instead of using the current user, looks up the user to clear
+ (void) removeBlockFromSettingsForUID:(uid_t)uid;


/* Info */

// check if a block is currently on (i.e. blocking connections)
// returns YES if a block is actively running (to the best of our knowledge), and NO otherwise
+ (BOOL) blockIsRunningInDictionary:(NSDictionary*)dict;

// check if it's time for a block to be enabled, based on our settings
// returns YES if the block should be active based on the specified end time (i.e. it is in the future), or NO otherwise
+ (BOOL) blockShouldBeRunningInDictionary:(NSDictionary *)dict;

// check if a block is currently on (i.e. blocking connections) in a legacy (SC 2.2.2 or older) dictionary
// the block is considered to be on if BlockStartedDate exists and isn't equal to the default value
// returns YES if a block is actively running (to the best of our knowledge), and NO otherwise
+ (BOOL) blockIsRunningInLegacyDictionary:(NSDictionary*)dict;

// returns the date that the block is set to end from a legacy (SC 2.2.2 or older) dictionary
// calculates this using BlockStartedDate and BlockDuration, since we did not use BlockEndDate previously
// returns the date that the block is set to end, or [NSDate distantPast] if no block is active
+ (NSDate*) endDateFromLegacyBlockDictionary:(NSDictionary *)dict;

@end
