//
//  SCDaemonBlockMethods.h
//  org.eyebeam.selfcontrold
//
//  Created by Charlie Stigler on 7/4/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCDaemonBlockMethods : NSObject

+ (void)startBlockWithControllingUID:(uid_t)controllingUID blocklist:(NSArray<NSString*>*)blocklist endDate:(NSDate*)endDate authorization:(NSData *)authData reply:(void(^)(NSError* error))reply;

@end

NS_ASSUME_NONNULL_END
