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
#import "SCFileWatcher.h"

static NSString* serviceName = @"org.eyebeam.selfcontrold";
float const INACTIVITY_LIMIT_SECS = 60 * 2; // 2 minutes

@interface NSXPCConnection(PrivateAuditToken)

// This property exists, but it's private. Make it available:
@property (nonatomic, readonly) audit_token_t auditToken;

@end

@interface SCDaemon () <NSXPCListenerDelegate>

@property (nonatomic, strong, readwrite) NSXPCListener* listener;
@property (strong, readwrite) NSTimer* checkupTimer;
@property (strong, readwrite) NSTimer* inactivityTimer;
@property (nonatomic, strong, readwrite) NSDate* lastActivityDate;

@property (nonatomic, strong) SCFileWatcher* hostsFileWatcher;

@end

@implementation SCDaemon

+ (instancetype)sharedDaemon {
    static SCDaemon* daemon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        daemon = [SCDaemon new];
    });
    return daemon;
}

- (id) init {
    _listener = [[NSXPCListener alloc] initWithMachServiceName: serviceName];
    _listener.delegate = self;
    
    return self;
}

- (void)start {
    [self.listener resume];

    // if there's any evidence of a block (i.e. an official one running,
    // OR just block remnants remaining in hosts), we should start
    // running checkup regularly so the block gets found/removed
    // at the proper time.
    // we do NOT run checkup if there's no block, because it can result
    // in the daemon actually unloading itself before the app has a chance
    // to start the block
    if ([SCBlockUtilities anyBlockIsRunning] || [SCBlockUtilities blockRulesFoundOnSystem]) {
        [self startCheckupTimer];
    }
    
    [self startInactivityTimer];
    [self resetInactivityTimer];
    
    self.hostsFileWatcher = [SCFileWatcher watcherWithFile: @"/etc/hosts" block:^(NSError * _Nonnull error) {
        if ([SCBlockUtilities anyBlockIsRunning]) {
            NSLog(@"INFO: hosts file changed, checking block integrity");
            [SCDaemonBlockMethods checkBlockIntegrity];
        }
    }];
}

- (void)startCheckupTimer {
    // this method must always be called on the main thread, so the timer will work properly
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self startCheckupTimer];
        });
        return;
    }

    // if the timer's already running, don't stress it!
    if (self.checkupTimer != nil) {
        return;
    }
    
    self.checkupTimer = [NSTimer scheduledTimerWithTimeInterval: 1 repeats: YES block:^(NSTimer * _Nonnull timer) {
       [SCDaemonBlockMethods checkupBlock];
    }];

    // run the first checkup immediately!
    [SCDaemonBlockMethods checkupBlock];
}
- (void)stopCheckupTimer {
    if (self.checkupTimer == nil) {
        return;
    }
    
    [self.checkupTimer invalidate];
    self.checkupTimer = nil;
}


- (void)startInactivityTimer {
    self.inactivityTimer = [NSTimer scheduledTimerWithTimeInterval: 15.0 repeats: YES block:^(NSTimer * _Nonnull timer) {
        // we haven't had any activity in a while, the daemon appears to be idling
        // so kill it to avoid the user having unnecessary processes running!
        if ([[NSDate date] timeIntervalSinceDate: self.lastActivityDate] > INACTIVITY_LIMIT_SECS) {
            // if we're inactive but also there's a block running, that's a bad thing
            // start the checkups going again - unclear why they would've stopped
            if ([SCBlockUtilities anyBlockIsRunning] || [SCBlockUtilities blockRulesFoundOnSystem]) {
                [self startCheckupTimer];
                [SCDaemonBlockMethods checkupBlock];
                return;
            }
            
            NSLog(@"Daemon inactive for more than %f seconds, exiting!", INACTIVITY_LIMIT_SECS);
            [SCHelperToolUtilities unloadDaemonJob];
        }
    }];
}
- (void)resetInactivityTimer {
    self.lastActivityDate = [NSDate date];
}

- (void)dealloc {
    if (self.checkupTimer) {
        [self.checkupTimer invalidate];
        self.checkupTimer = nil;
    }
    if (self.inactivityTimer) {
        [self.inactivityTimer invalidate];
        self.inactivityTimer = nil;
    }
    if (self.hostsFileWatcher) {
        [self.hostsFileWatcher stopWatching];
        self.hostsFileWatcher = nil;
    }
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
    SecRequirementCreateWithString(CFSTR("anchor apple generic and (identifier \"org.eyebeam.SelfControl\" or identifier \"org.eyebeam.selfcontrol-cli\") and info [CFBundleVersion] >= \"407\" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = EG6ZYP3AQH)"), kSecCSDefaultFlags, &isSelfControlApp);
    OSStatus clientValidityStatus = SecCodeCheckValidity(guest, kSecCSDefaultFlags, isSelfControlApp);
    
    CFRelease(guest);
    CFRelease(isSelfControlApp);
    
    if (clientValidityStatus) {
        NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: clientValidityStatus userInfo: nil];
        NSLog(@"Rejecting XPC connection because of invalid client signing. Error was %@", error);
        [SCSentry captureError: error];
        return NO;
    }
    
    SCDaemonXPC* scdXPC = [[SCDaemonXPC alloc] init];
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol: @protocol(SCDaemonProtocol)];
    newConnection.exportedObject = scdXPC;

    [newConnection resume];
    
    NSLog(@"Accepted new connection!");
    [SCSentry addBreadcrumb: @"Daemon accepted new connection" category: @"daemon"];
    
    return YES;
}

@end
