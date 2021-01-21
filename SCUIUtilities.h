//
//  SCUIUtilities.h
//  SelfControl
//
//  Created by Charlie Stigler on 1/20/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCUIUtilities : NSObject

// Returns YES if, according to settings or the hostfile, the
// SelfControl block is running  Returns NO if it is not.
+ (BOOL)blockIsRunning;

// Checks whether a network connection is available by checking the reachabilty
// of google.com  This method may not be correct if the network configuration
// was just changed a few seconds ago.
+ (BOOL)networkConnectionIsAvailable;

+ (NSString *)timeSliderDisplayStringFromTimeInterval:(NSTimeInterval)numberOfSeconds;
+ (NSString *)timeSliderDisplayStringFromNumberOfMinutes:(NSInteger)numberOfMinutes;

+ (NSString*)blockTeaserString;

@end

NS_ASSUME_NONNULL_END
