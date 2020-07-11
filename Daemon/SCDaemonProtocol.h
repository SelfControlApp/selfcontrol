//
//  SCDaemonProtocol.h
//  selfcontrold
//
//  Created by Charlie Stigler on 5/30/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SCDaemonProtocol <NSObject>

- (void)startBlockWithControllingUID:(uid_t)controllingUID blocklist:(NSArray<NSString*>*)blocklist endDate:(NSDate*)endDate authorization:(NSData *)authData reply:(void(^)(NSError* error))reply;

- (BOOL) checkup;

- (void)getVersionWithReply:(void(^)(NSString * version))reply;

@end

NS_ASSUME_NONNULL_END
