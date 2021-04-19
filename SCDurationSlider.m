//
//  SCTimeSlider.m
//  SelfControl
//
//  Created by Charlie Stigler on 4/17/21.
//

#import "SCDurationSlider.h"
#import "SCTimeIntervalFormatter.h"
#import <TransformerKit/NSValueTransformer+TransformerKit.h>

#define kValueTransformerName @"BlockDurationSliderTransformer"

@implementation SCDurationSlider

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder: coder]) {
        [self initializeDurationProperties];
    }
    return self;
}
- (instancetype)init {
    if (self = [super init]) {
        [self initializeDurationProperties];
    }
    return self;
}

- (void)initializeDurationProperties {
    // default: 1 day max
    _maxDuration = 1440;

    // register an NSValueTransformer
    [self registerMinutesValueTransformer];
}

- (void)setMaxDuration:(NSInteger)maxDuration {
    _maxDuration = maxDuration;
    [self recalculateSliderIntervals];
}

- (void)recalculateSliderIntervals {
    [self setMinValue: 1]; // never start a block shorter than 1 minute
    [self setMaxValue: self.maxDuration];
    
    // how many tick marks should we have? it's based on the max block duration
    // TODO: can we make this work better with the start at 1-minute (vs 0)? if not, should we just eliminate ticks?
    long tickInterval = 1;
    if (self.maxDuration >= 5256000) {
        // if max block duration is at least 10 years, tick marks are per-year
        tickInterval = 525600;
    } else if (self.maxDuration >= 525600) {
        // if max block duration is at least 1 year, tick marks are per-month
        tickInterval = 43800;
    } else if (self.maxDuration >= 131400) {
        // if max block duration is at least 3 months, tick marks are per-week
        tickInterval = 10080;
    } else if (self.maxDuration >= 10080) {
        // if max block duration is at least 1 week, tick marks are per-day
        tickInterval = 1440;
    } else if (self.maxDuration >= 5760) {
        // if max block duration is at least 4 days, tick marks are per 6 hours
        tickInterval = 360;
    } else if (self.maxDuration >= 1440) {
        // if max block duration is at least 1 day, tick marks are per hour
        tickInterval = 60;
    } else if (self.maxDuration >= 720) {
        // if max block duration is at least 12 hours, tick marks are per 30 minutes
        tickInterval = 30;
    } else if (self.maxDuration >= 60) {
        // if max block duration is at least 1 hour, tick marks are per minute
        tickInterval = 1;
    }
    
    // no more than 72 ticks max
    long numTicks = MIN(self.maxDuration / tickInterval, 72) + 1;
    [self setNumberOfTickMarks: numTicks];
}

- (void)registerMinutesValueTransformer {
    [NSValueTransformer registerValueTransformerWithName: kValueTransformerName
                                   transformedValueClass: [NSNumber class]
                      returningTransformedValueWithBlock:^id _Nonnull(id  _Nonnull value) {
        // if it's not a number or convertable to one, IDK man
        if (![value respondsToSelector: @selector(floatValue)]) return @0;
        
        long minutesValue = lroundf([value floatValue]);
        return @(minutesValue);
    }];
}

- (NSInteger)durationValueMinutes {
    return lroundf(self.floatValue);
}

- (void)bindDurationToObject:(id)obj keyPath:(NSString*)keyPath {
    [self bind: @"value"
      toObject: obj
   withKeyPath: keyPath
       options: @{
                  NSContinuouslyUpdatesValueBindingOption: @YES,
                  NSValueTransformerNameBindingOption: kValueTransformerName
                  }];
}

- (NSString*)durationDescription {
    return [SCDurationSlider timeSliderDisplayStringFromNumberOfMinutes: self.durationValueMinutes];
}

// String conversion utility methods

+ (NSString *)timeSliderDisplayStringFromTimeInterval:(NSTimeInterval)numberOfSeconds {
    static SCTimeIntervalFormatter* formatter = nil;
    if (formatter == nil) {
        formatter = [[SCTimeIntervalFormatter alloc] init];
    }

    NSString* formatted = [formatter stringForObjectValue:@(numberOfSeconds)];
    return formatted;
}

+ (NSString *)timeSliderDisplayStringFromNumberOfMinutes:(NSInteger)numberOfMinutes {
    if (numberOfMinutes < 0) return @"Invalid duration";

    static NSCalendar* gregorian = nil;
    if (gregorian == nil) {
        gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    }

    NSRange secondsRangePerMinute = [gregorian
                                     rangeOfUnit:NSCalendarUnitSecond
                                     inUnit:NSCalendarUnitMinute
                                     forDate:[NSDate date]];
    NSInteger numberOfSecondsPerMinute = (NSInteger)NSMaxRange(secondsRangePerMinute);

    NSTimeInterval numberOfSecondsSelected = (NSTimeInterval)(numberOfSecondsPerMinute * numberOfMinutes);

    NSString* displayString = [SCDurationSlider timeSliderDisplayStringFromTimeInterval:numberOfSecondsSelected];
    return displayString;
}


@end
