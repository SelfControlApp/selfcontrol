//
//  SCDaemon.m
//  SelfControl
//
//  Created by Charlie Stigler on 5/28/20.
//

#import "SCDaemon.h"
#import "SCDaemonProtocol.h"
#import "SCDaemonXPC.h"
#import"SCDaemonBlockMethods.h"

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
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval: 1 repeats: YES block:^(NSTimer * _Nonnull timer) {
        // TODO: DON'T HARDCODE THIS VALUE
        [SCDaemonBlockMethods checkupBlockWithControllingUID: 501];
    }];    
}

#pragma mark - NSXPCListenerDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    // There is a potential security issue / race condition with matching based on PID, but seems unlikely in this case
    NSDictionary* guestAttributes = @{
        (id)kSecGuestAttributePid: @(newConnection.processIdentifier)
    };
    SecCodeRef guest;
    SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef _Nullable)(guestAttributes), kSecCSDefaultFlags, &guest);
    SecRequirementRef isSelfControlApp;
    SecRequirementCreateWithString(CFSTR("anchor apple generic and identifier \"org.eyebeam.SelfControl\" and certificate leaf[subject.OU] = L6W5L88KN7"), kSecCSDefaultFlags, &isSelfControlApp);
    OSStatus clientValidityStatus = SecCodeCheckValidity(guest, kSecCSDefaultFlags, isSelfControlApp);
    
    if (clientValidityStatus) {
        NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: clientValidityStatus userInfo: nil];
        NSLog(@"Rejecting XPC connection because of invalid client signing. Error was %@", error);
        return NO;
    }
    
    SCDaemonXPC* scdXPC = [[SCDaemonXPC alloc] init];
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol: @protocol(SCDaemonProtocol)];
    newConnection.exportedObject = scdXPC;
    
    [newConnection resume];
    
    NSLog(@"Accepted new connection!");
    
    return YES;
}

@end
