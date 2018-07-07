//
//  SCUtilities.h
//  SelfControl
//
//  Created by Charles Stigler on 07/07/2018.
//

#import <Foundation/Foundation.h>

// The point of this class is basically to abstract out whether we're using blockStartedDate (the old system)
// or blockEndDate (the new system) for tracking blocks in defaults/lockfile. We want to be backwards-compatible for a while so people
// who upgrade mid-block (foolishly!) have a better chance of surviving and we don't bork their stuff.
// eventually, another way to do this would just be to convert all blockStartedDates to blockEndDates on launch,
// but that sounds risky (updating lock files is not guaranteed) and this seems safer for now...

// the main app works with standard NSUserDefaults objects, but the helper tools have very weird patterns for reading/writing defaults
// (because of the UID issues), so we have two versions of some functions to accommodate

@interface SCUtilities : NSObject

// Main app functions taking NSUserDefaults

+ (BOOL) blockIsEnabledInDefaults:(NSUserDefaults*)defaults;
+ (BOOL) blockIsActiveInDefaults:(NSUserDefaults*)defaults;
+ (void) startBlockInDefaults:(NSUserDefaults*)defaults;
+ (void) removeBlockFromDefaults:(NSUserDefaults*)defaults;
+ (NSDate*) blockEndDateInDefaults:(NSUserDefaults*)defaults;

// Helper tool functions dealing with dictionaries and setDefaultsValue helper

+ (BOOL) blockIsEnabledInDictionary:(NSDictionary*)defaultsDict;
+ (BOOL) blockIsActiveInDictionary:(NSDictionary *)defaultsDict;
+ (NSDate*) blockEndDateInDictionary:(NSDictionary*)defaultsDict;

@end
