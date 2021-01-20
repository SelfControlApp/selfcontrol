//
//  SCDaemon.h
//  SelfControl
//
//  Created by Charlie Stigler on 5/28/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// SCDaemon is the top-level class that runs the SelfControl
// daemon process (selfcontrold). It runs from DaemonMain.
@interface SCDaemon : NSObject

// Singleton instance of SCDaemon
+ (instancetype)sharedDaemon;


// Starts the daemon tasks, including accepting XPC connections
// and running block checkup jobs if necessary
- (void)start;

// Starts checking up on the block on a regular basis
// to make sure it hasn't expired, been tampered with, etc
// (and will remove it or fix it if so)
- (void)startCheckupTimer;

// Stops the checkup timer (this should only be called if there's
// no block running, because we should have checkups going for all blocks)
- (void)stopCheckupTimer;

// Lets the daemon know that there was recent activity
// so we can reset our inactivity timer.
// The daemon will die if goes for too long without activity.
- (void)resetInactivityTimer;

@end

NS_ASSUME_NONNULL_END
