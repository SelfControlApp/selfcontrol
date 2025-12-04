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
    [self setMinValue: 1]; // never start a block shorter than 1 minute
    [self setMaxValue: self.maxDuration];
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

- (NSString*)timeDurationDescription {
    return [SCDurationSlider timeSliderDurationDisplayStringFromNumberOfMinutes: self.durationValueMinutes];
}

- (NSString*)timeEndDescription {
    return [SCDurationSlider timeSliderEndDisplayStringFromNumberOfMinutes: self.durationValueMinutes];
}

// String conversion utility methods

+ (NSString *)timeSliderDurationDisplayStringFromTimeInterval:(NSTimeInterval)numberOfSeconds {
    static SCTimeIntervalFormatter* formatter = nil;
    if (formatter == nil) {
        formatter = [[SCTimeIntervalFormatter alloc] init];
    }

    NSString* formatted = [formatter stringForObjectValue:@(numberOfSeconds)];
    return formatted;
}

+ (NSString *)timeSliderEndDisplayStringFromTimeInterval:(NSTimeInterval)numberOfSeconds {
    static NSDateFormatter* formatter = nil;
    if (formatter == nil) {
        formatter = [[NSDateFormatter alloc] init];
    }
    formatter.timeStyle = NSDateFormatterNoStyle;
    formatter.dateStyle = NSDateFormatterShortStyle;
    NSString* todayDateStr = [formatter stringFromDate: [NSDate date]];
    NSDate* targetDate = [NSDate dateWithTimeIntervalSinceNow:numberOfSeconds];
    NSString* targetDateStr = [formatter stringFromDate: targetDate];
    
    formatter.timeStyle = NSDateFormatterShortStyle;
    formatter.dateStyle = [targetDateStr isEqual:todayDateStr] ? NSDateFormatterNoStyle : NSDateFormatterShortStyle;
    
    NSString* formatted = [formatter stringForObjectValue:targetDate];
    return formatted;
}

+ (NSString *)timeSliderDurationDisplayStringFromNumberOfMinutes:(NSInteger)numberOfMinutes {
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

    NSString* displayString = [SCDurationSlider timeSliderDurationDisplayStringFromTimeInterval:numberOfSecondsSelected];
    return displayString;
}

+ (NSString *)timeSliderEndDisplayStringFromNumberOfMinutes:(NSInteger)numberOfMinutes {
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

    NSString* displayString = [SCDurationSlider timeSliderEndDisplayStringFromTimeInterval:numberOfSecondsSelected];
    return displayString;
}


@end
