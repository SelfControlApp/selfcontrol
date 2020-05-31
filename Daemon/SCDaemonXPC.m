//
//  SCDaemonXPC.m
//  selfcontrold
//
//  Created by Charlie Stigler on 5/30/20.
//

#import "SCDaemonXPC.h"

@implementation SCDaemonXPC

- (BOOL) install {
    NSLog(@"XPC method called: install");
    return YES;
}

- (BOOL) checkup {
    NSLog(@"XPC method called: checkup");
    return YES;
}

- (BOOL) getVersion {
    NSLog(@"XPC method called: getVersion");
    return YES;
}


@end
