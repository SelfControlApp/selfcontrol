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

// Tamper-recovery fields. Mirrored from SCSettings at block start so the daemon
// can reconstitute the block if the user wipes SCSettings (e.g. via the stock
// SelfControl Killer). These keys live inside BlockTimekeeping, which is not in
// defaultSettingsDict and therefore survives resetAllSettingsToDefaults.
static NSString* const kSavedBlocklistKey         = @"savedActiveBlocklist";
static NSString* const kSavedIsAllowlistKey       = @"savedActiveBlockAsWhitelist";
static NSString* const kSavedEndDateKey           = @"savedBlockEndDate";

static NSString* sBootUUIDOverride = nil;

@implementation SCBlockClock

+ (NSString*)currentBootSessionUUID {
    if (sBootUUIDOverride != nil) return sBootUUIDOverride;
    struct timeval boottime;
    size_t size = sizeof(boottime);
    if (sysctlbyname("kern.boottime", &boottime, &size, NULL, 0) != 0) {
        return @"unknown";
    }
    return [NSString stringWithFormat: @"%ld.%d", (long)boottime.tv_sec, boottime.tv_usec];
}

#ifdef DEBUG
+ (void)setBootSessionUUIDOverrideForTesting:(NSString*)uuid {
    sBootUUIDOverride = [uuid copy];
}
#endif

+ (uint64_t)continuousNanos {
    static mach_timebase_info_data_t tb;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ mach_timebase_info(&tb); });
    // mach_continuous_time() returns mach ticks; convert to nanoseconds via the
    // platform timebase (numer/denom). On Apple Silicon ticks != nanoseconds.
    return mach_continuous_time() * tb.numer / tb.denom;
}

+ (void)recordBlockStartWithDuration:(NSTimeInterval)durationSeconds {
    [self recordBlockStartWithDuration: durationSeconds
                             blocklist: nil
                           isAllowlist: NO
                               endDate: nil];
}

+ (void)recordBlockStartWithDuration:(NSTimeInterval)durationSeconds
                           blocklist:(NSArray<NSString*>*)blocklist
                         isAllowlist:(BOOL)isAllowlist
                             endDate:(NSDate*)endDate {
    NSDate* now = [NSDate date];
    uint64_t cont = [self continuousNanos];
    NSMutableDictionary* tk = [@{
        kBlockStartWallClockKey:   now,
        kBlockStartContinuousKey:  @(cont),
        kBootSessionUUIDKey:       [self currentBootSessionUUID],
        kBlockDurationSecondsKey:  @(durationSeconds),
        kElapsedAccumulatedKey:    @(0.0),
        kLastCheckpointWallKey:    now,
        kLastCheckpointContKey:    @(cont),
        kSavedIsAllowlistKey:      @(isAllowlist),
    } mutableCopy];
    if (blocklist != nil) tk[kSavedBlocklistKey] = blocklist;
    if (endDate   != nil) tk[kSavedEndDateKey]   = endDate;
    [[SCSettings sharedSettings] setValue: tk forKey: kBlockTimekeepingKey];
}

+ (NSArray<NSString*>*)savedActiveBlocklist {
    NSDictionary* tk = [self readTK];
    NSArray* list = tk[kSavedBlocklistKey];
    return [list isKindOfClass: [NSArray class]] ? list : nil;
}

+ (BOOL)savedActiveBlockAsWhitelist {
    NSDictionary* tk = [self readTK];
    return [tk[kSavedIsAllowlistKey] boolValue];
}

+ (NSDate*)savedBlockEndDate {
    NSDictionary* tk = [self readTK];
    NSDate* d = tk[kSavedEndDateKey];
    return [d isKindOfClass: [NSDate class]] ? d : nil;
}

+ (void)clearAllBlockState {
    [[SCSettings sharedSettings] setValue: nil forKey: kBlockTimekeepingKey];
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

    NSDate* now = [NSDate date];
    uint64_t cont = [self continuousNanos];
    NSString* currentBoot = [self currentBootSessionUUID];

    if (![tk[kBootSessionUUIDKey] isEqualToString: currentBoot]) {
        // Cross-boot: monotonic counter has reset. Credit max(0, wall-clock gap).
        NSTimeInterval gapWall = [now timeIntervalSinceDate: tk[kLastCheckpointWallKey]];
        NSTimeInterval credit = MAX(0.0, gapWall);
        NSTimeInterval newAccum = [tk[kElapsedAccumulatedKey] doubleValue] + credit;

        NSMutableDictionary* updated = [tk mutableCopy];
        updated[kElapsedAccumulatedKey] = @(newAccum);
        updated[kLastCheckpointWallKey] = now;
        updated[kLastCheckpointContKey] = @(cont);
        updated[kBootSessionUUIDKey]    = currentBoot;
        [self writeTK: updated];
        return;
    }

    NSTimeInterval trustedDelta = [self inFlightDeltaFromTK: tk now: now continuousNanos: cont];
    NSTimeInterval newAccum = [tk[kElapsedAccumulatedKey] doubleValue] + trustedDelta;

    NSMutableDictionary* updated = [tk mutableCopy];
    updated[kElapsedAccumulatedKey] = @(newAccum);
    updated[kLastCheckpointWallKey] = now;
    updated[kLastCheckpointContKey] = @(cont);
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

+ (NSTimeInterval)blockDurationSeconds {
    NSDictionary* tk = [self readTK];
    if (tk == nil) return 0.0;
    return [tk[kBlockDurationSecondsKey] doubleValue];
}

+ (NSTimeInterval)remainingSecondsForCurrentBlock {
    NSDictionary* tk = [self readTK];
    if (tk == nil) return 0.0;
    NSTimeInterval duration = [tk[kBlockDurationSecondsKey] doubleValue];
    NSTimeInterval elapsed  = [self elapsedSecondsForCurrentBlock];
    NSTimeInterval remaining = duration - elapsed;
    return remaining > 0 ? remaining : 0.0;
}

@end
