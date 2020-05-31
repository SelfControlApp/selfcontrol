//
//  SCDaemon.m
//  SelfControl
//
//  Created by Charlie Stigler on 5/28/20.
//

#import "SCDaemon.h"
#import "SCDaemonProtocol.h"
#import "SCDaemonXPC.h"

static NSString* serviceName = @"org.eyebeam.selfcontrold";

@interface SCDaemon () <NSXPCListenerDelegate>

@property (nonatomic, strong, readwrite) NSXPCListener* listener;

@end

@implementation SCDaemon

- (id) init {
    _listener = [[NSXPCListener alloc] initWithMachServiceName: serviceName];
    _listener.delegate = self;
    
    return self;
}

- (void)start {
    [self.listener resume];
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval: 0.5 repeats: YES block:^(NSTimer * _Nonnull timer) {
        NSLog(@"still running still running");
    }];    
}

#pragma mark - NSXPCListenerDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    SCDaemonXPC* scdXPC = [[SCDaemonXPC alloc] init];
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol: @protocol(SCDaemonProtocol)];
    newConnection.exportedObject = scdXPC;
    
    [newConnection resume];
    
    return YES;
}

@end
