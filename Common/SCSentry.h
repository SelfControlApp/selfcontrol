//
//  SCSentry.h
//  SelfControl
//
//  Created by Charlie Stigler on 1/15/21.
//

#import <Foundation/Foundation.h>
#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCSentry : NSObject

+ (void)startSentry:(NSString*)componentId;
+ (void)captureError:(NSError*)error;
+ (void)captureMessage:(NSString*)message;

@end

NS_ASSUME_NONNULL_END
