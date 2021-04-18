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

+ (BOOL)promptBrowserRestartIfNecessary;

+ (NSString*)blockTeaserStringWithMaxLength:(NSInteger)maxStringLen;

// presents an error via a popup in the app
// this is mostly just a pass-through to [NSApp presentError:],
// but it first checks if the error is in the SelfControl domain
// and if so tries to fill in additional error fields
+ (void)presentError:(NSError*)err;

@end

NS_ASSUME_NONNULL_END
