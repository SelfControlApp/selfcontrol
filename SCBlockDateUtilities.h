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

@interface SCBlockDateUtilities : NSObject

// Main app functions taking NSUserDefaults and SCSettings

+ (void) startBlockInSettings:(SCSettings*)settings withBlockDuration:(NSTimeInterval)blockDuration;
+ (void) removeBlockFromSettings:(SCSettings*)settings;
+ (void) removeBlockFromSettingsForUID:(uid_t)uid;

// Helper tool functions dealing with dictionaries and setDefaultsValue helper

+ (BOOL) blockIsEnabledInDictionary:(NSDictionary*)dict;
+ (BOOL) blockIsActiveInDictionary:(NSDictionary *)dict;
+ (NSDate*) blockEndDateInDictionary:(NSDictionary*)dict;

@end
