//
//  SCBlockUtilities.h
//  SelfControl
//
//  Created by Charlie Stigler on 1/19/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCBlockUtilities : NSObject

// uses the below methods as well as filesystem checks to see if the block is REALLY running or not
+ (BOOL)anyBlockIsRunning;
+ (BOOL)modernBlockIsRunning;
+ (BOOL)legacyBlockIsRunning;

+ (BOOL)currentBlockIsExpired;

/// Strict check: both wall-clock and monotonic counter say the block is over.
/// Use this in the daemon before tearing down firewall rules.
+ (BOOL)currentBlockIsTrulyExpired;

+ (BOOL)blockRulesFoundOnSystem;

+ (void)removeBlockFromSettings;

@end

NS_ASSUME_NONNULL_END
