//
//  SCBlockDateUtilities+HelperTools.h
//  SelfControl
//
//  Created by Charles Stigler on 07/07/2018.
//

#import "SCBlockDateUtilities.h"

// we have to put everything that uses helper tool only functions (setDefaultsValue) in this file
// because they break the linker if we put them with the rest of the utils!

@interface SCBlockDateUtilities (HelperTools)

+ (void) startDefaultsBlockWithDict:(NSDictionary*)defaultsDict forUID:(uid_t)uid;
+ (void) removeBlockFromDefaultsForUID:(uid_t)uid;

@end
