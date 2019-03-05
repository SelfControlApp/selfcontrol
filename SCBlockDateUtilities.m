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


// "enabled" means we have a start or end date set to a valid value (even if it's technically "finished" but hasn't been cleaned up yet)
+ (BOOL) blockIsEnabledInDictionary:(NSDictionary *)dict {
    NSDate* blockEndDate = [dict objectForKey: @"BlockEndDate"];
    NSDate* blockStartedDate = [dict objectForKey:@"BlockStartedDate"];

    // the block is enabled if one of BlockStartedDate or BlockEndDate exists and isn't equal to the default value
    if (
        (blockEndDate != nil && ![blockEndDate isEqualToDate: [NSDate distantPast]]) ||
        (blockStartedDate != nil && ![blockStartedDate isEqualToDate: [NSDate distantFuture]])
        ) {
        return YES;
    } else {
        return NO;
    }
}

// "active" means the block is enabled and end date has not yet arrived - the block *should* be running
+ (BOOL) blockIsActiveInDictionary:(NSDictionary *)defaultsDict {
    // the block is active if the end date hasn't arrived yet
    if ([[SCBlockDateUtilities blockEndDateInDictionary: defaultsDict] timeIntervalSinceNow] > 0) {
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
    
    // we always _set_ BlockEndDate, because BlockStartedDate is some legacy ish
    [settings setValue: blockEndDate forKey: @"BlockEndDate"];
}


+ (void) removeBlockFromSettings:(SCSettings*)settings {
    // remove both BlockEndDate and legacy BlockStartedDate, just in case an old version comes back and tries to read that
    // TODO: will this work setting nil instead of [NSDate dateWithTimeIntervalSince1970: 0]?
    [settings setValue: nil forKey: @"BlockEndDate"];
}

+ (void) removeBlockFromSettingsForUID:(uid_t)uid {
    SCSettings* settings = [SCSettings settingsForUser: uid];
    [SCBlockDateUtilities removeBlockFromSettings: settings];
}

+ (NSDate*) blockEndDateInDictionary:(NSDictionary *)dict {
    // if it's not enabled, it's always the distant past!
    if (![SCBlockDateUtilities blockIsEnabledInDictionary: dict]) {
        return [NSDate distantPast];
    }
    
    NSDate* startDate = [dict objectForKey: @"BlockStartedDate"];
    NSDate* endDate = [dict objectForKey: @"BlockEndDate"];
    NSTimeInterval duration = [[dict objectForKey: @"BlockDuration"] floatValue];
    
    // if we've got BlockEndDate set, this is easy - that's the value we're looking for
    if (endDate != nil && ![endDate isEqualToDate: [NSDate distantPast]]) {
        return endDate;
    } else {
        // the block is enabled but we don't have an end date
        // so we must have the legacy start date, which we now need to convert to an end date
        return [startDate dateByAddingTimeInterval: (duration * 60)];
    }
}

@end
