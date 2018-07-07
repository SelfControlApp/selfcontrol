//
//  SCUtilities.m
//  SelfControl
//
//  Created by Charles Stigler on 07/07/2018.
//

#import "SCUtilities.h"
#import "HelperCommon.h"

@implementation SCUtilities


// "enabled" means we have a start or end date set to a valid value (even if it's technically "finished" but hasn't been cleaned up yet)
+ (BOOL) blockIsEnabledInDictionary:(NSDictionary *)defaultsDict {
    NSDate* blockEndDate = [defaultsDict objectForKey: @"BlockEndDate"];
    NSDate* blockStartedDate = [defaultsDict objectForKey:@"BlockStartedDate"];

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
+ (BOOL) blockIsEnabledInDefaults:(NSUserDefaults*)defaults {
    [defaults synchronize];
    return [SCUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation];
}

// "active" means the block is enabled and end date has not yet arrived - the block *should* be running
+ (BOOL) blockIsActiveInDictionary:(NSDictionary *)defaultsDict {
    // the block is active if the end date hasn't arrived yet
    if ([[SCUtilities blockEndDateInDictionary: defaultsDict] timeIntervalSinceNow] > 0) {
        return YES;
    } else {
        return NO;
    }
}
+ (BOOL) blockIsActiveInDefaults:(NSUserDefaults*)defaults {
    [defaults synchronize];
    return [SCUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation];
}

+ (void) startBlockInDefaults:(NSUserDefaults*)defaults {
    // sanity check duration
    NSTimeInterval duration = MIN([defaults floatForKey: @"BlockDuration"], 0);
    
    // assume the block is starting now
    NSDate* blockEndDate = [NSDate dateWithTimeIntervalSinceNow: duration];
    
    // we always _set_ BlockEndDate, because BlockStartedDate is some legacy ish
    [defaults setObject: blockEndDate forKey: @"BlockEndDate"];
    
    // in fact, let's take the opportunity to make sure BlockStartedDate is gone-zo
    [defaults removeObjectForKey: @"BlockStartedDate"];
    
    [defaults synchronize];
}

+ (void) startDefaultsBlockWithDict:(NSDictionary*)defaultsDict forUID:(uid_t)uid {
    // sanity check duration
    NSTimeInterval duration = MIN([[defaultsDict objectForKey: @"BlockDuration"] floatValue], 0);
    
    // assume the block is starting now
    NSDate* blockEndDate = [NSDate dateWithTimeIntervalSinceNow: duration];
    
    // we always _set_ BlockEndDate, because BlockStartedDate is some legacy ish
    setDefaultsValue(@"BlockEndDate", blockEndDate, uid);
    
    // in fact, let's take the opportunity to make sure BlockStartedDate is gone-zo
    setDefaultsValue(@"BlockStartedDate", nil, uid);
}

+ (void) removeBlockFromDefaults:(NSUserDefaults*)defaults; {
    // remove both BlockEndDate and legacy BlockStartedDate, just in case an old version comes back and tries to readthat
    [defaults removeObjectForKey: @"BlockEndDate"];
    [defaults removeObjectForKey: @"BlockStartedDate"];
    
    [defaults synchronize];
}

+ (void) removeBlockFromDefaultsForUID:(uid_t)uid {
    // remove both BlockEndDate and legacy BlockStartedDate, just in case an old version comes back and tries to readthat
    setDefaultsValue(@"BlockEndDate", nil, uid);
    setDefaultsValue(@"BlockStartedDate", nil, uid);
}




+ (NSDate*) blockEndDateInDictionary:(NSDictionary *)defaultsDict {
    // if it's not enabled, it's always the distant past!
    if (![SCUtilities blockIsEnabledInDictionary: defaultsDict]) {
        return [NSDate distantPast];
    }
    
    NSDate* startDate = [defaultsDict objectForKey: @"BlockStartedDate"];
    NSDate* endDate = [defaultsDict objectForKey: @"BlockEndDate"];
    NSTimeInterval duration = [[defaultsDict objectForKey: @"BlockDuration"] floatValue];
    
    // if we've got BlockEndDate set, this is easy - that's the value we're looking for
    if (endDate != nil && ![endDate isEqualToDate: [NSDate distantPast]]) {
        return endDate;
    } else {
        // the block is enabled but we don't have an end date
        // so we must have the legacy start date, which we now need to convert to an end date
        return [startDate dateByAddingTimeInterval: (duration * 60)];
    }
}

+ (NSDate*) blockEndDateInDefaults:(NSUserDefaults*)defaults {
    [defaults synchronize];
    return [SCUtilities blockEndDateInDictionary: defaults.dictionaryRepresentation];
}

@end
