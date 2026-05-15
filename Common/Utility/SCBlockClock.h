#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Tamper-resistant block-elapsed-time accounting.
/// Combines mach_continuous_time() with a periodic on-disk checkpoint so that
/// changing the system clock with `sudo date` cannot end a block early.
///
/// All mutating class methods (recordBlockStart, tickCheckpoint) must be invoked
/// serialized — e.g. from the daemon's main runloop. SCSettings @synchronized
/// protects each get/set leg, but not the combined read-modify-write pattern.
@interface SCBlockClock : NSObject

/// Called once at block start. Writes the BlockTimekeeping dictionary into SCSettings.
+ (void)recordBlockStartWithDuration:(NSTimeInterval)durationSeconds;

/// As above, but also persists enough block-config to rebuild the block if SCSettings
/// is tampered with (e.g. the stock SelfControl Killer running resetAllSettingsToDefaults).
/// BlockTimekeeping is intentionally NOT in defaultSettingsDict, so it survives that reset.
+ (void)recordBlockStartWithDuration:(NSTimeInterval)durationSeconds
                           blocklist:(nullable NSArray<NSString*>*)blocklist
                         isAllowlist:(BOOL)isAllowlist
                             endDate:(nullable NSDate*)endDate;

/// Block-config previously stashed by recordBlockStart, for the daemon's tampering-
/// recovery path. Returns nil if no block is recorded or the metadata was never stored.
+ (nullable NSArray<NSString*>*)savedActiveBlocklist;
+ (BOOL)savedActiveBlockAsWhitelist;
+ (nullable NSDate*)savedBlockEndDate;

/// Erase all block-tracking state. Call after a legitimate block end so a future
/// checkupBlock does not misread stale data as evidence of tampering.
+ (void)clearAllBlockState;

/// Called every ~30 s by the daemon. Updates elapsedSecondsAccumulated and the
/// last-checkpoint values, using the smaller of the wall-clock delta and the
/// monotonic delta. A negative wall-clock delta credits zero.
+ (void)tickCheckpoint;

/// Total real seconds elapsed since the block started. Returns 0 if no block.
+ (NSTimeInterval)elapsedSecondsForCurrentBlock;

/// YES iff elapsedSecondsForCurrentBlock >= the recorded duration.
+ (BOOL)blockDurationHasElapsed;

/// Recorded total block duration in seconds. Returns 0 if no block is recorded.
+ (NSTimeInterval)blockDurationSeconds;

/// Seconds left until elapsedSecondsForCurrentBlock reaches blockDurationSeconds.
/// Clamped at 0; returns 0 if no block is recorded.
+ (NSTimeInterval)remainingSecondsForCurrentBlock;

#ifdef DEBUG
/// Test-only override. Pass nil to clear.
+ (void)setBootSessionUUIDOverrideForTesting:(nullable NSString*)uuid;
#endif

@end

NS_ASSUME_NONNULL_END
