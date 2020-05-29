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

@interface NSXPCConnection(PrivateAuditToken)

// This property exists, but it's private. Make it available:
@property (nonatomic, readonly) audit_token_t auditToken;

@end

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
    // There is a potential security issue / race condition with matching based on PID, so we use the (technically private) auditToken instead
    audit_token_t auditToken = newConnection.auditToken;
    NSDictionary* guestAttributes = @{
        (id)kSecGuestAttributeAudit: [NSData dataWithBytes: &auditToken length: sizeof(audit_token_t)]
    };
    SecCodeRef guest;
    if (SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef _Nullable)(guestAttributes), kSecCSDefaultFlags, &guest) != errSecSuccess) {
        return NO;
    }
    
    SecRequirementRef isSelfControlApp;
    // versions before 4.0 didn't have hardened code signing, so aren't trustworthy to talk to the daemon
    // (plus the daemon didn't exist before 4.0 so there's really no reason they should want to run it!)
    SecRequirementCreateWithString(CFSTR("anchor apple generic and (identifier \"org.eyebeam.SelfControl\" or identifier \"org.eyebeam.selfcontrol-cli\") and info [CFBundleShortVersionString] >= \"4.0\" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = L6W5L88KN7)"), kSecCSDefaultFlags, &isSelfControlApp);
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
