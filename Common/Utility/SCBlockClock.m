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
    static mach_timebase_info_data_t tb;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ mach_timebase_info(&tb); });
    // mach_continuous_time() returns mach ticks; convert to nanoseconds via the
    // platform timebase (numer/denom). On Apple Silicon ticks != nanoseconds.
    return mach_continuous_time() * tb.numer / tb.denom;
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

+ (NSDictionary*)readTK {
    return [[SCSettings sharedSettings] valueForKey: kBlockTimekeepingKey];
}

+ (void)writeTK:(NSDictionary*)tk {
    [[SCSettings sharedSettings] setValue: tk forKey: kBlockTimekeepingKey];
}

+ (NSTimeInterval)inFlightDeltaFromTK:(NSDictionary*)tk
                                  now:(NSDate*)now
                       continuousNanos:(uint64_t)cont {
    NSDate* lastWall  = tk[kLastCheckpointWallKey];
    uint64_t lastCont = [tk[kLastCheckpointContKey] unsignedLongLongValue];

    NSTimeInterval deltaWall = [now timeIntervalSinceDate: lastWall];
    NSTimeInterval deltaCont = ((double)(cont - lastCont)) / 1e9;

    NSTimeInterval trustedDelta = MIN(deltaCont, MAX(0.0, deltaWall));
    if (trustedDelta < 0) trustedDelta = 0; // defense vs corrupt persisted lastCont
    return trustedDelta;
}

+ (void)tickCheckpoint {
    NSDictionary* tk = [self readTK];
    if (tk == nil) return;

    // Same-boot guard: cross-boot path is Task 3.
    if (![tk[kBootSessionUUIDKey] isEqualToString: [self currentBootSessionUUID]]) {
        return;
    }

    NSDate* now = [NSDate date];
    uint64_t cont = [self continuousNanos];

    NSTimeInterval trustedDelta = [self inFlightDeltaFromTK: tk now: now continuousNanos: cont];
    NSTimeInterval newAccum = [tk[kElapsedAccumulatedKey] doubleValue] + trustedDelta;

    NSMutableDictionary* updated = [tk mutableCopy];
    updated[kElapsedAccumulatedKey]    = @(newAccum);
    updated[kLastCheckpointWallKey]    = now;
    updated[kLastCheckpointContKey]    = @(cont);
    [self writeTK: updated];
}

+ (NSTimeInterval)elapsedSecondsForCurrentBlock {
    NSDictionary* tk = [self readTK];
    if (tk == nil) return 0.0;
    if (![tk[kBootSessionUUIDKey] isEqualToString: [self currentBootSessionUUID]]) {
        return [tk[kElapsedAccumulatedKey] doubleValue];
    }
    return [tk[kElapsedAccumulatedKey] doubleValue]
         + [self inFlightDeltaFromTK: tk now: [NSDate date] continuousNanos: [self continuousNanos]];
}

+ (BOOL)blockDurationHasElapsed {
    NSDictionary* tk = [self readTK];
    if (tk == nil) return NO;
    return [self elapsedSecondsForCurrentBlock] >= [tk[kBlockDurationSecondsKey] doubleValue];
}

@end
