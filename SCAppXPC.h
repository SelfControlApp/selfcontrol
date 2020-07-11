//
//  SCAppXPC.h
//  SelfControl
//
//  Created by Charlie Stigler on 7/4/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCAppXPC : NSObject

- (void)connectToHelperTool;
- (void)refreshConnection;
- (void)connectAndExecuteCommandBlock:(void(^)(NSError *))commandBlock;

- (void)getVersion;
- (void)startBlockWithControllingUID:(uid_t)controllingUID blocklist:(NSArray<NSString*>*)blocklist endDate:(NSDate*)endDate authorization:(NSData *)authData reply:(void(^)(NSError* error))reply;

@end

NS_ASSUME_NONNULL_END
