//
//  SCUIUtilities.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/20/21.
//

#import "SCUIUtilities.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "SCTimeIntervalFormatter.h"
#import "HostFileBlocker.h"

@implementation SCUIUtilities

+ (NSString*)blockTeaserString {
    NSArray<NSString*>* blocklist;
    BOOL isAllowlist;
    if ([SCUIUtilities blockIsRunning]) {
        SCSettings* settings = [SCSettings sharedSettings];
        blocklist = [settings valueForKey: @"ActiveBlocklist"];
        isAllowlist = [settings boolForKey: @"ActiveBlockAsWhitelist"];
    } else {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        blocklist = [defaults arrayForKey: @"Blocklist"];
        isAllowlist = [defaults boolForKey: @"BlockAsWhitelist"];
    }
    
    // special strings if the list is empty
    if (blocklist.count == 0) {
        if (isAllowlist) {
            return @"Blocking the entire Internet";
        } else {
            return @"Blocking nothing (blocklist is empty)";
        }
    }
    
    NSString* startStr;
    if (isAllowlist) {
        startStr = @"Blocking the entire Internet EXCEPT ";
    } else {
        startStr = @"Blocking ";
    }
    
    NSMutableString* siteStr = [NSMutableString stringWithCapacity: 60];
    int MAX_SITE_CHARS = 35;
    int MAX_HOSTS_IN_STRING = 3;
    int hostsInString = 0;
    NSUInteger curIndex = 0;
        
    for (NSString* hostString in blocklist) {
        if (hostString.length + siteStr.length <= MAX_SITE_CHARS && hostsInString + 1 <= MAX_HOSTS_IN_STRING) {
            if (hostsInString > 0) {
                if (blocklist.count > 2) {
                    [siteStr appendString: @", "];
                } else {
                    [siteStr appendString: @" "];
                }
            }
            
            if (curIndex == (blocklist.count - 1) && blocklist.count > 1) {
                [siteStr appendFormat: @"and %@", hostString];
            } else {
                [siteStr appendString: hostString];
            }

            hostsInString++;
        } else {
            break;
        }

        curIndex++;
    }
    
    int numOthers = (int)blocklist.count - hostsInString;
    if (numOthers > 0) {
        if (hostsInString == 0) {
            [siteStr appendFormat: @"%d %@", numOthers, numOthers > 1 ? @"sites" : @"site"];
        } else if (hostsInString <= 2) {
            [siteStr appendFormat: @" and %d %@", numOthers, numOthers > 1 ? @"others" : @"other"];
        } else {
            [siteStr appendFormat: @", and %d %@", numOthers, numOthers > 1 ? @"others" : @"other"];
        }
    }

    return [startStr stringByAppendingString: siteStr];
}

+ (NSString *)timeSliderDisplayStringFromTimeInterval:(NSTimeInterval)numberOfSeconds {
    static SCTimeIntervalFormatter* formatter = nil;
    if (formatter == nil) {
        formatter = [[SCTimeIntervalFormatter alloc] init];
    }

    NSString* formatted = [formatter stringForObjectValue:@(numberOfSeconds)];
    return formatted;
}

+ (NSString *)timeSliderDisplayStringFromNumberOfMinutes:(NSInteger)numberOfMinutes {
    static NSCalendar* gregorian = nil;
    if (gregorian == nil) {
        gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    }

    NSRange secondsRangePerMinute = [gregorian
                                     rangeOfUnit:NSCalendarUnitSecond
                                     inUnit:NSCalendarUnitMinute
                                     forDate:[NSDate date]];
    NSUInteger numberOfSecondsPerMinute = NSMaxRange(secondsRangePerMinute);

    NSTimeInterval numberOfSecondsSelected = (NSTimeInterval)(numberOfSecondsPerMinute * numberOfMinutes);

    NSString* displayString = [SCUIUtilities timeSliderDisplayStringFromTimeInterval:numberOfSecondsSelected];
    return displayString;
}

+ (BOOL)networkConnectionIsAvailable {
    SCNetworkReachabilityFlags flags;

    // This method goes haywire if Google ever goes down...
    SCNetworkReachabilityRef target = SCNetworkReachabilityCreateWithName (kCFAllocatorDefault, "google.com");

    BOOL reachable = SCNetworkReachabilityGetFlags (target, &flags);
    
    return reachable && (flags & kSCNetworkFlagsReachable) && !(flags & kSCNetworkFlagsConnectionRequired);
}

+ (BOOL)blockIsRunning {
    // we'll say a block is running if we find the block info, but
    // also, importantly, if we find a block still going in the hosts file
    // that way if this happens, the user will still see the timer window -
    // which will let them manually clear the remaining block info after 10 seconds
    return [SCBlockUtilities anyBlockIsRunning] || [HostFileBlocker blockFoundInHostsFile];
}

@end
