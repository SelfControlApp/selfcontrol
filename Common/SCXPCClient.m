//
//  SCAppXPC.m
//  SelfControl
//
//  Created by Charlie Stigler on 7/4/20.
//

#import "SCXPCClient.h"
#import "SCDaemonProtocol.h"
#import <ServiceManagement/ServiceManagement.h>
#import "SCConstants.h"
#import "SCXPCAuthorization.h"

@interface SCXPCClient () {
    AuthorizationRef    _authRef;
}

@property (atomic, strong, readwrite) NSXPCConnection* daemonConnection;
@property (atomic, copy, readwrite) NSData* authorization;

@end

@implementation SCXPCClient

- (void)setupAuthorization {
    // this all mostly copied from Apple's Even Better Authorization Sample
    OSStatus err;
    AuthorizationExternalForm extForm;

    // Create our connection to the authorization system.
    //
    // If we can't create an authorization reference then the app is not going to be able
    // to do anything requiring authorization.  Generally this only happens when you launch
    // the app in some wacky, and typically unsupported, way.  In the debug build we flag that
    // with an assert.  In the release build we continue with self->_authRef as NULL, which will
    // cause all authorized operations to fail.
    
    err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, 0, &self->_authRef);
    if (err == errAuthorizationSuccess) {
        err = AuthorizationMakeExternalForm(self->_authRef, &extForm);
        self.authorization = [[NSData alloc] initWithBytes: &extForm length: sizeof(extForm)];
    }
    assert(err == errAuthorizationSuccess);
    
    // If we successfully connected to Authorization Services, add definitions for our default
    // rights (unless they're already in the database).
    
    if (self->_authRef) {
        [SCXPCAuthorization setupAuthorizationRights: self->_authRef];
    }

}

// Ensures that we're connected to our helper tool
// should only be called from the main thread
// Copied from Apple's EvenBetterAuthorizationSample
- (void)connectToHelperTool {
    assert([NSThread isMainThread]);
    NSLog(@"Connecting to helper tool, daemon connection is %@", self.daemonConnection);
    
    [self setupAuthorization];
    
    if (self.daemonConnection == nil) {
        self.daemonConnection = [[NSXPCConnection alloc] initWithMachServiceName: @"org.eyebeam.selfcontrold" options: NSXPCConnectionPrivileged];
        self.daemonConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(SCDaemonProtocol)];
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-retain-cycles"
        // We can ignore the retain cycle warning because a) the retain taken by the
        // invalidation handler block is released by us setting it to nil when the block
        // actually runs, and b) the retain taken by the block passed to -addOperationWithBlock:
        // will be released when that operation completes and the operation itself is deallocated
        // (notably self does not have a reference to the NSBlockOperation).
        // note we need a local reference to the daemonConnection since there is a race condition where
        // we could reinstantiate a new connection before the handler fires, and we don't want to clear the new connection
        NSXPCConnection* connection = self.daemonConnection;
        connection.invalidationHandler = ^{
            // If the connection gets invalidated then, on the main thread, nil out our
            // reference to it.  This ensures that we attempt to rebuild it the next time around.
            connection.invalidationHandler = connection.interruptionHandler = nil;
                        
            if (connection == self.daemonConnection) {
                // dispatch_sync on main thread would deadlock, so be careful
                if ([NSThread isMainThread]) {
                    self.daemonConnection = nil;
                } else {
                    // running this synchronously ensures that the daemonConnection is nil'd out even if
                    // reinstantiate the connection immediately
                    NSLog(@"About to dispatch_sync");
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        self.daemonConnection = nil;
                    });
                }
                NSLog(@"connection invalidated");
            }
        };
        // our interruption handler is just our invalidation handler, except we retry afterward
        connection.interruptionHandler = ^{
            NSLog(@"Helper tool connection interrupted");
            connection.invalidationHandler();

            // interruptions may have happened because the daemon crashed
            // so wait a second and try to reconnect
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                NSLog(@"Retrying helper tool connection!");
                [self connectToHelperTool];
            });
        };

        #pragma clang diagnostic pop
        [self.daemonConnection resume];
        
        NSLog(@"Started helper connection!");
    }
}

- (void)installDaemon:(void(^)(NSError*))callback {
    AuthorizationRef authorizationRef;
    char* daemonPath = [self selfControlHelperToolPathUTF8String];
    NSUInteger daemonPathSize = strlen(daemonPath);
    AuthorizationItem right = {
        kSMRightBlessPrivilegedHelper,
        daemonPathSize,
        daemonPath,
        0
    };
    AuthorizationRights authRights = {
        1,
        &right
    };
    AuthorizationFlags myFlags = kAuthorizationFlagDefaults |
    kAuthorizationFlagExtendRights |
    kAuthorizationFlagInteractionAllowed;
    OSStatus status;

    status = AuthorizationCreate (&authRights,
                                  kAuthorizationEmptyEnvironment,
                                  myFlags,
                                  &authorizationRef);

    if(status) {
        NSLog(@"ERROR: Failed to authorize installing selfcontrold.");
        callback([NSError errorWithDomain: @"SelfControlErrorDomain" code: status userInfo: nil]);
        return;
    }

    CFErrorRef cfError;
    BOOL result = (BOOL)SMJobBless(
                                   kSMDomainSystemLaunchd,
                                   CFSTR("org.eyebeam.selfcontrold"),
                                   authorizationRef,
                                   &cfError);

    if(!result) {
        NSError* error = CFBridgingRelease(cfError);
        
        NSLog(@"WARNING: Authorized installation of selfcontrold returned failure status code %d and error %@", (int)status, error);

        NSError* err = [NSError errorWithDomain: kSelfControlErrorDomain
                                           code: status
                                       userInfo: @{NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Error %d received from the Security Server.", (int)status]}];
        callback(err);
        return;
    } else {
        NSLog(@"Daemon installed successfully!");
        callback(nil);
    }
}

- (BOOL)connectionIsActive {
    return (self.daemonConnection != nil);
}

- (void)refreshConnectionAndRun:(void(^)(void))callback {
    // when we're refreshing the connection, we can end up in a slightly awkward situation:
    // if we call invalidate, but immediately start to reconnect before daemonConnection can be nil'd out
    // then we risk trying to use the invalidated connection
    // the fix? nil out daemonConnection before invalidating it in the refresh case
    
    if (self.daemonConnection == nil) {
        callback();
        return;
    }
    void (^standardInvalidationHandler)(void) = self.daemonConnection.invalidationHandler;
    
    // wait until the invalidation handler runs, then run our callback
    self.daemonConnection.invalidationHandler = ^{
        standardInvalidationHandler();
        callback();
    };
    
    [self.daemonConnection performSelectorOnMainThread: @selector(invalidate) withObject: nil waitUntilDone: YES];
}

// Also copied from Apple's EvenBetterAuthorizationSample
// Connects to the helper tool and then executes the supplied command block on the
// main thread, passing it an error indicating if the connection was successful.
- (void)connectAndExecuteCommandBlock:(void(^)(NSError *))commandBlock {
    // Ensure that there's a helper tool connection in place.
    
    [self performSelectorOnMainThread: @selector(connectToHelperTool) withObject:nil waitUntilDone: YES];

    // Run the command block.  Note that we never error in this case because, if there is
    // an error connecting to the helper tool, it will be delivered to the error handler
    // passed to -remoteObjectProxyWithErrorHandler:.  However, I maintain the possibility
    // of an error here to allow for future expansion.

    commandBlock(nil);
}

// Called when the user clicks the Get Version button.  This is the simplest form of
// NSXPCConnection request because it doesn't require any authorization.
- (void)getVersion {
    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        if (connectError != nil) {
            NSLog(@"%@", connectError);
        } else {
            [[self.daemonConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                NSLog(@"%@", proxyError);
            }] getVersionWithReply:^(NSString *version) {
                NSLog(@"version = %@\n", version);
            }];
        }
    }];
}

- (void)startBlockWithControllingUID:(uid_t)controllingUID blocklist:(NSArray<NSString*>*)blocklist isAllowlist:(BOOL)isAllowlist endDate:(NSDate*)endDate blockSettings:(NSDictionary*)blockSettings reply:(void(^)(NSError* error))reply {
    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        if (connectError != nil) {
            NSLog(@"Install command failed with connection error: %@", connectError);
            reply(connectError);
        } else {
            [[self.daemonConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                NSLog(@"Install command failed with remote object proxy error: %@", proxyError);
                reply(proxyError);
            }] startBlockWithControllingUID: controllingUID blocklist: blocklist isAllowlist:isAllowlist endDate:endDate blockSettings: blockSettings authorization: self.authorization reply:^(NSError* error) {
                NSLog(@"Install failed with error = %@\n", error);
                reply(error);
            }];
        }
    }];
}

- (void)updateBlocklistWithControllingUID:(uid_t)controllingUID newBlocklist:(NSArray<NSString*>*)newBlocklist reply:(void(^)(NSError* error))reply {
    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        if (connectError != nil) {
            NSLog(@"Blocklist update failed with connection error: %@", connectError);
            reply(connectError);
        } else {
            [[self.daemonConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                NSLog(@"Blocklist update command failed with remote object proxy error: %@", proxyError);
                reply(proxyError);
            }] updateBlocklistWithControllingUID: controllingUID newBlocklist: newBlocklist authorization: self.authorization reply:^(NSError* error) {
                NSLog(@"Blocklist update failed with error = %@\n", error);
                reply(error);
            }];
        }
    }];
}

- (void)updateBlockEndDateWithControllingUID:(uid_t)controllingUID newEndDate:(NSDate*)newEndDate reply:(void(^)(NSError* error))reply {
    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        if (connectError != nil) {
            NSLog(@"Block end date update failed with connection error: %@", connectError);
            reply(connectError);
        } else {
            [[self.daemonConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                NSLog(@"Block end date update command failed with remote object proxy error: %@", proxyError);
                reply(proxyError);
            }] updateBlockEndDateWithControllingUID: controllingUID newEndDate: newEndDate authorization: self.authorization reply:^(NSError* error) {
                NSLog(@"Block end date update failed with error = %@\n", error);
                reply(error);
            }];
        }
    }];
}

- (NSString*)selfControlHelperToolPath {
    static NSString* path;

    // Cache the path so it doesn't have to be searched for again.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle* thisBundle = [NSBundle mainBundle];
        path = [thisBundle.bundlePath stringByAppendingString: @"/Contents/Library/LaunchServices/org.eyebeam.selfcontrold"];
    });

    return path;
}

- (char*)selfControlHelperToolPathUTF8String {
    static char* path;

    // Cache the converted path so it doesn't have to be converted again
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        path = malloc(512);
        [[self selfControlHelperToolPath] getCString: path
                                           maxLength: 512
                                            encoding: NSUTF8StringEncoding];
    });

    return path;
}

@end
