//
//  SCTimeIntervalFormatter.m
//  SelfControl
//
//  Created by Sam Stigler on 10/14/14.
//
//

#import <FormatterKit/TTTTimeIntervalFormatter.h>
#import "SCTimeIntervalFormatter.h"

@implementation SCTimeIntervalFormatter

- (NSString *)stringForObjectValue:(id)obj {
    NSString* string = @"";
    if ([obj isKindOfClass:[NSNumber class]]) {
        string = [self formatSeconds:[obj doubleValue]];
    }

    return string;
}

- (NSString *)formatSeconds:(NSTimeInterval)seconds {
    NSString* formatted;

    BOOL useModernBehavior = (NSAppKitVersionNumber >= NSAppKitVersionNumber10_8);
    if (useModernBehavior) {
        formatted = [self formatSecondsUsingModernBehavior:seconds];
    }
    else {
        formatted = [self formatSecondsUsingLegacyBehavior:seconds];
    }

    return formatted;
}

- (NSString *)formatSecondsUsingModernBehavior:(NSTimeInterval)seconds
{
    static TTTTimeIntervalFormatter* timeIntervalFormatter = nil;
    if (timeIntervalFormatter == nil) {
        timeIntervalFormatter = [[TTTTimeIntervalFormatter alloc] init];
        timeIntervalFormatter.pastDeicticExpression = @"";
        timeIntervalFormatter.presentDeicticExpression = @"";
        timeIntervalFormatter.futureDeicticExpression = @"";
        timeIntervalFormatter.significantUnits = (NSCalendarUnitYear |
                                                  NSCalendarUnitMonth |
                                                  NSCalendarUnitDay |
                                                  NSCalendarUnitHour |
                                                  NSCalendarUnitMinute);
        timeIntervalFormatter.numberOfSignificantUnits = 0;
        timeIntervalFormatter.leastSignificantUnit = NSCalendarUnitMinute;
    }
    
    NSString* formatted = [timeIntervalFormatter stringForTimeInterval:seconds];
    if ([formatted length] == 0) {
        formatted = [self stringIndicatingZeroMinutes];
    }

    return formatted;
}

- (NSString *)formatSecondsUsingLegacyBehavior:(NSTimeInterval)seconds {
    int formatDays, formatHours, formatMinutes;
    int numMinutes = seconds / 60;

    formatDays = numMinutes / 1440;
    formatHours = (numMinutes % 1440) / 60;
    formatMinutes = (numMinutes % 60);
    
    NSString* timeString = @"";

    if(numMinutes > 0) {
        if(formatDays > 0) {
            timeString = [NSString stringWithFormat:@"%d %@", formatDays, (formatDays == 1 ? NSLocalizedString(@"day", @"Single day time string") : NSLocalizedString(@"days", @"Plural days time string"))];
        }
        if(formatHours > 0) {
            timeString = [NSString stringWithFormat: @"%@%@%d %@", timeString, (formatDays > 0 ? @", " : @""), formatHours, (formatHours == 1 ? NSLocalizedString(@"hour", @"Single hour time string") : NSLocalizedString(@"hours", @"Plural hours time string"))];
        }
        if(formatMinutes > 0) {
            timeString = [NSString stringWithFormat:@"%@%@%d %@", timeString, (formatHours > 0 || formatDays > 0 ? @", " : @""), formatMinutes, (formatMinutes == 1 ? NSLocalizedString(@"minute", @"Single minute time string") : NSLocalizedString(@"minutes", @"Plural minutes time string"))];
        }
    }
    else {
        timeString = [self stringIndicatingZeroMinutes];
    }

    return timeString;
}

- (NSString *)stringIndicatingZeroMinutes {
    NSString* disabledString = [NSString stringWithFormat: @"0 %@ (%@)",
                                NSLocalizedString(@"minutes", @"Plural minutes time string"),
                                NSLocalizedString(@"disabled", "Shows that SelfControl is disabled")];
    return disabledString;
}

@end
