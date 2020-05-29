//
//  SCDaemon.m
//  SelfControl
//
//  Created by Charlie Stigler on 5/28/20.
//

#import "SCDaemon.h"

@implementation SCDaemon

- (void)start {
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval: 0.5 repeats: YES block:^(NSTimer * _Nonnull timer) {
        NSLog(@"still running still running");
    }];    
}

@end
