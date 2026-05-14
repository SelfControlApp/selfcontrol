#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Tamper-resistant block-elapsed-time accounting.
/// Combines mach_continuous_time() with a periodic on-disk checkpoint so that
/// changing the system clock with `sudo date` cannot end a block early.
@interface SCBlockClock : NSObject

/// Called once at block start. Writes the BlockTimekeeping dictionary into SCSettings.
+ (void)recordBlockStartWithDuration:(NSTimeInterval)durationSeconds;

/// Called every ~30 s by the daemon. Updates elapsedSecondsAccumulated and the
/// last-checkpoint values, using the smaller of the wall-clock delta and the
/// monotonic delta. A negative wall-clock delta credits zero.
+ (void)tickCheckpoint;

/// Total real seconds elapsed since the block started. Returns 0 if no block.
+ (NSTimeInterval)elapsedSecondsForCurrentBlock;

/// YES iff elapsedSecondsForCurrentBlock >= the recorded duration.
+ (BOOL)blockDurationHasElapsed;

@end

NS_ASSUME_NONNULL_END
