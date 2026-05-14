#import "SCBlockClock.h"
#import "SCSettings.h"
#import <mach/mach_time.h>
#import <sys/sysctl.h>

static NSString* const kBlockTimekeepingKey       = @"BlockTimekeeping";
static NSString* const kBlockStartWallClockKey    = @"blockStartWallClock";
static NSString* const kBlockStartContinuousKey   = @"blockStartContinuousTime";
static NSString* const kBootSessionUUIDKey        = @"bootSessionUUID";
static NSString* const kBlockDurationSecondsKey   = @"blockDurationSeconds";
static NSString* const kElapsedAccumulatedKey     = @"elapsedSecondsAccumulated";
static NSString* const kLastCheckpointWallKey     = @"lastCheckpointWallClock";
static NSString* const kLastCheckpointContKey     = @"lastCheckpointContinuous";

@implementation SCBlockClock

+ (NSString*)currentBootSessionUUID {
    struct timeval boottime;
    size_t size = sizeof(boottime);
    if (sysctlbyname("kern.boottime", &boottime, &size, NULL, 0) != 0) {
        return @"unknown";
    }
    return [NSString stringWithFormat: @"%ld.%d", (long)boottime.tv_sec, boottime.tv_usec];
}

+ (uint64_t)continuousNanos {
    return mach_continuous_time();
}

+ (void)recordBlockStartWithDuration:(NSTimeInterval)durationSeconds {
    NSDate* now = [NSDate date];
    uint64_t cont = [self continuousNanos];
    NSDictionary* tk = @{
        kBlockStartWallClockKey:   now,
        kBlockStartContinuousKey:  @(cont),
        kBootSessionUUIDKey:       [self currentBootSessionUUID],
        kBlockDurationSecondsKey:  @(durationSeconds),
        kElapsedAccumulatedKey:    @(0.0),
        kLastCheckpointWallKey:    now,
        kLastCheckpointContKey:    @(cont),
    };
    [[SCSettings sharedSettings] setValue: tk forKey: kBlockTimekeepingKey];
}

+ (void)tickCheckpoint { /* implemented in Task 2 */ }
+ (NSTimeInterval)elapsedSecondsForCurrentBlock { return 0.0; /* Task 2 */ }
+ (BOOL)blockDurationHasElapsed { return NO; /* Task 2 */ }

@end
