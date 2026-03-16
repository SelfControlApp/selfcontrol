//
//  SCSchedule.m
//  SelfControl
//
//  Model for a recurring scheduled block.
//

#import "SCSchedule.h"

@implementation SCSchedule

- (instancetype)init {
    if (self = [super init]) {
        _identifier = [[NSUUID UUID] UUIDString];
        _name = @"";
        _weekdays = @[];
        _hour = 9;
        _minute = 0;
        _durationMinutes = 60;
        _blocklist = @[];
        _enabled = YES;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        _identifier = dict[@"identifier"] ?: [[NSUUID UUID] UUIDString];
        _name = dict[@"name"] ?: @"";
        _weekdays = dict[@"weekdays"] ?: @[];
        _hour = [dict[@"hour"] integerValue];
        _minute = [dict[@"minute"] integerValue];
        _durationMinutes = [dict[@"durationMinutes"] integerValue];
        _blocklist = dict[@"blocklist"] ?: @[];
        _enabled = [dict[@"enabled"] boolValue];
    }
    return self;
}

+ (instancetype)scheduleFromDictionary:(NSDictionary *)dict {
    return [[SCSchedule alloc] initWithDictionary:dict];
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"identifier": self.identifier ?: @"",
        @"name": self.name ?: @"",
        @"weekdays": self.weekdays ?: @[],
        @"hour": @(self.hour),
        @"minute": @(self.minute),
        @"durationMinutes": @(self.durationMinutes),
        @"blocklist": self.blocklist ?: @[],
        @"enabled": @(self.enabled)
    };
}

- (NSString *)launchdLabel {
    return [NSString stringWithFormat:@"org.eyebeam.SelfControl.schedule.%@", self.identifier];
}

@end
