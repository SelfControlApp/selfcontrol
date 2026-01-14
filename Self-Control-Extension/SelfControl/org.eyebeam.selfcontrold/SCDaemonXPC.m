//
//  SCDaemonXPC.m
//  selfcontrold
//
//  Created by Charlie Stigler on 5/30/20.
//

#import "SCDaemonXPC.h"
#import "SCDaemonBlockMethods.h"
#import "SCXPCAuthorization.h"
#import "SCMiscUtilities.h"
#import "ConsoleLog.h"

@implementation SCDaemonXPC

- (void)startBlockWithControllingUID:(uid_t)controllingUID blocklist:(NSArray<NSString*>*)blocklist isAllowlist:(BOOL)isAllowlist endDate:(NSDate*)endDate blockSettings:(NSDictionary*)blockSettings authorization:(NSData *)authData reply:(void(^)(NSError* error))reply {
    NSLog(@"SCDaemonXPC: XPC method called: startBlockWithControllingUID");
    [ConsoleLog log:[NSString stringWithFormat:@"SCDaemonXPC: XPC method called: startBlockWithControllingUID"]];

    NSError* error = [SCXPCAuthorization checkAuthorization: authData command: _cmd];
    if (error != nil) {
        if (![SCMiscUtilities errorIsAuthCanceled: error]) {
            NSLog(@"SCDaemonXPC: ERROR: XPC authorization failed due to error %@", error);
            // [SCSentry captureError: error];
        }
        reply(error);
        return;
    } else {
        NSLog(@"SCDaemonXPC: AUTHORIZATION ACCEPTED for startBlock with authData %@ and command %s", authData, sel_getName(_cmd));
        [ConsoleLog log:[NSString stringWithFormat:@"SCDaemonXPC: AUTHORIZATION ACCEPTED for startBlock with authData %@ and command %s", authData, sel_getName(_cmd)]];
    }

    [SCDaemonBlockMethods startBlockWithControllingUID: controllingUID blocklist: blocklist isAllowlist:isAllowlist endDate: endDate blockSettings:blockSettings authorization: authData reply: reply];
}

- (void)updateBlocklist:(NSArray<NSString*>*)newBlocklist authorization:(NSData *)authData reply:(void(^)(NSError* error))reply {
    NSLog(@"SCDaemonXPC: XPC method called: updateBlocklist");
    [ConsoleLog log:[NSString stringWithFormat:@"SCDaemonXPC: XPC method called: updateBlocklist"]];

    NSError* error = [SCXPCAuthorization checkAuthorization: authData command: _cmd];
    if (error != nil) {
        if (![SCMiscUtilities errorIsAuthCanceled: error]) {
            NSLog(@"SCDaemonXPC: ERROR: XPC authorization failed due to error %@", error);
            [ConsoleLog log:[NSString stringWithFormat:@"SCDaemonXPC: ERROR: XPC authorization failed due to error %@", error]];
            // [SCSentry captureError: error];
        }
        reply(error);
        return;
    } else {
        NSLog(@"SCDaemonXPC: AUTHORIZATION ACCEPTED for updateBlocklist with authData %@ and command %s", authData, sel_getName(_cmd));
        [ConsoleLog log:[NSString stringWithFormat:@"SCDaemonXPC: AUTHORIZATION ACCEPTED for updateBlocklist with authData %@ and command %s", authData, sel_getName(_cmd)]];

    }
    
    [SCDaemonBlockMethods updateBlocklist: newBlocklist authorization: authData reply: reply];
}

- (void)updateBlockEndDate:(NSDate*)newEndDate authorization:(NSData *)authData reply:(void(^)(NSError* error))reply {
    NSLog(@"SCDaemonXPC: XPC method called: updateBlockEndDate");
    [ConsoleLog log:[NSString stringWithFormat:@"SCDaemonXPC: XPC method called: updateBlockEndDate"]];

    NSError* error = [SCXPCAuthorization checkAuthorization: authData command: _cmd];
    if (error != nil) {
        if (![SCMiscUtilities errorIsAuthCanceled: error]) {
            NSLog(@"SCDaemonXPC: ERROR: XPC authorization failed due to error %@", error);
            [ConsoleLog log:[NSString stringWithFormat:@"SCDaemonXPC: XPC method called: updateBlockEndDate: %@", error]];
            // [SCSentry captureError: error];
        }
        reply(error);
        return;
    } else {
        NSLog(@"SCDaemonXPC: AUTHORIZATION ACCEPTED for updateBlockENdDate with authData %@ and command %s", authData, sel_getName(_cmd));
        [ConsoleLog log:[NSString stringWithFormat:@"SCDaemonXPC: AUTHORIZATION ACCEPTED for updateBlockENdDate with authData %@ and command %s", authData, sel_getName(_cmd)]];
    }
    
    [SCDaemonBlockMethods updateBlockEndDate: newEndDate authorization: authData reply: reply];
}

// Part of the HelperToolProtocol.  Returns the version number of the tool.  Note that never
// requires authorization.
- (void)getVersionWithReply:(void(^)(NSString * version))reply {
    NSLog(@"SCDaemonXPC: XPC method called: getVersionWithReply");
    [ConsoleLog log:[NSString stringWithFormat:@"SCDaemonXPC: XPC method called: getVersionWithReply"]];

    // We specifically don't check for authorization here.  Everyone is always allowed to get
    // the version of the helper tool.
    reply(@"4.0.2");
}

@end
