//
//  SCBlockDateUtilities.m
//  SelfControl
//
//  Created by Charles Stigler on 07/07/2018.
//

#import "SCBlockDateUtilities.h"
#import "HelperCommon.h"
#import "SCSettings.h"

@implementation SCBlockDateUtilities


// returns YES if a block is actively running (to the best of our knowledge), and NO otherwise
+ (BOOL) blockIsRunningInDictionary:(NSDictionary *)dict {
    // simple: the block is running if BlockIsRunning is set to true!
    return [[dict valueForKey: @"BlockIsRunning"] boolValue];
}

// returns YES if the block should be active based on the specified end time (i.e. it is in the future), or NO otherwise
+ (BOOL) blockShouldBeRunningInDictionary:(NSDictionary *)dict {
    // the block should be running if the end date hasn't arrived yet
    if ([[dict objectForKey: @"BlockEndDate"] timeIntervalSinceNow] > 0) {
        return YES;
    } else {
        return NO;
    }
}

+ (void) startBlockInSettings:(SCSettings*)settings withBlockDuration:(NSTimeInterval)blockDuration {
    // sanity check duration (must be above zero)
    blockDuration = MAX(blockDuration, 0);
    
    // assume the block is starting now
    NSDate* blockEndDate = [NSDate dateWithTimeIntervalSinceNow: blockDuration];
    
    [settings setValue: blockEndDate forKey: @"BlockEndDate"];
}


+ (void) removeBlockFromSettings:(SCSettings*)settings {
    // TODO: will this work setting nil instead of [NSDate dateWithTimeIntervalSince1970: 0]?
    [settings setValue: nil forKey: @"BlockEndDate"];
    [settings setValue: nil forKey: @"BlockIsRunning"];
}

+ (void) removeBlockFromSettingsForUID:(uid_t)uid {
    SCSettings* settings = [SCSettings settingsForUser: uid];
    [SCBlockDateUtilities removeBlockFromSettings: settings];
}

+ (BOOL)blockIsRunningInLegacyDictionary:(NSDictionary*)dict {
    NSDate* blockStartedDate = [dict objectForKey:@"BlockStartedDate"];

    // the block is running if BlockStartedDate exists and isn't equal to the default value
    if (blockStartedDate != nil && ![blockStartedDate isEqualToDate: [NSDate distantFuture]]) {
        return YES;
    } else {
        return NO;
    }
}
+ (NSDate*) endDateFromLegacyBlockDictionary:(NSDictionary *)dict {
    NSDate* startDate = [dict objectForKey: @"BlockStartedDate"];
    NSTimeInterval duration = [[dict objectForKey: @"BlockDuration"] floatValue];
    
    // if we don't have a start date in the past and a duration greater than 0, we don't have a block end date
    if (startDate == nil || [startDate timeIntervalSinceNow] >= 0 || duration <= 0) {
        return [NSDate distantPast];
    }
    
    // convert the legacy start date to an end date
    return [startDate dateByAddingTimeInterval: (duration * 60)];
}

@end
