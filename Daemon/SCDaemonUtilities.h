//
//  SCDaemonUtilities.h
//  org.eyebeam.selfcontrold
//
//  Created by Charlie Stigler on 9/16/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCDaemonUtilities : NSObject

+ (void)unloadDaemonJobForUID:(uid_t)controllingUID;

@end

NS_ASSUME_NONNULL_END
