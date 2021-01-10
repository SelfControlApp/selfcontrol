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
- (void)installHelperTool:(void(^)(NSError*))callback;
- (void)refreshConnectionAndRun:(void(^)(void))callback;
- (void)connectAndExecuteCommandBlock:(void(^)(NSError *))commandBlock;

- (void)getVersion;
- (void)startBlockWithControllingUID:(uid_t)controllingUID blocklist:(NSArray<NSString*>*)blocklist isAllowlist:(BOOL)isAllowlist endDate:(NSDate*)endDate reply:(void(^)(NSError* error))reply;
- (void)updateBlocklistWithControllingUID:(uid_t)controllingUID newBlocklist:(NSArray<NSString*>*)newBlocklist reply:(void(^)(NSError* error))reply;
- (void)updateBlockEndDateWithControllingUID:(uid_t)controllingUID newEndDate:(NSDate*)newEndDate reply:(void(^)(NSError* error))reply;

@end

NS_ASSUME_NONNULL_END
