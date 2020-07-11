//
//  SCAppXPC.m
//  SelfControl
//
//  Created by Charlie Stigler on 7/4/20.
//

#import "SCAppXPC.h"
#import "SCDaemonProtocol.h"

@interface SCAppXPC () {}

@property (atomic, strong, readwrite) NSXPCConnection* daemonConnection;

@end

@implementation SCAppXPC

// Ensures that we're connected to our helper tool
// should only be called from the main thread
// Copied from Apple's EvenBetterAuthorizationSample
- (void)connectToHelperTool {
    assert([NSThread isMainThread]);
    NSLog(@"Connecting to helper tool, daemon connection is %@", self.daemonConnection);
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
            connection.invalidationHandler = nil;
            NSLog(@"called invalidation handler");
                        
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                if (connection == self.daemonConnection) {
                    self.daemonConnection = nil;
                    NSLog(@"connection invalidated");
                }
            }];
        };
        #pragma clang diagnostic pop
        [self.daemonConnection resume];
        
        NSLog(@"Started helper connection!");
    }
}
- (void)refreshConnection {
    // when we're refreshing the connection, we can end up in a slightly awkward situation:
    // if we call invalidate, but immediately start to reconnect before daemonConnection can be nil'd out
    // then we risk trying to use the invalidated connection
    // the fix? nil out daemonConnection before invalidating it in the refresh case
    
    NSXPCConnection* oldConnection = self.daemonConnection;
    
    // dispatch_sync on main thread would deadlock, so be careful
    if ([NSThread isMainThread]) {
        self.daemonConnection = nil;
    } else {
        // running this synchronously ensures that the daemonConnection is nil'd out even if
        // reinstantiate the connection immediately
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.daemonConnection = nil;
        });
    }

    [oldConnection performSelectorOnMainThread: @selector(invalidate) withObject: nil waitUntilDone: YES];
    
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

- (void)startBlockWithControllingUID:(uid_t)controllingUID blocklist:(NSArray<NSString*>*)blocklist endDate:(NSDate*)endDate authorization:(NSData *)authData reply:(void(^)(NSError* error))reply {
    NSLog(@"sending command block");
    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        if (connectError != nil) {
            NSLog(@"Command failed with connection error: %@", connectError);
        } else {
            [[self.daemonConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                NSLog(@"Command failed with remote object proxy error: %@", proxyError);
            }] startBlockWithControllingUID: controllingUID blocklist: blocklist endDate:endDate authorization: [NSData new] reply:^(NSError* error) {
                NSLog(@"installed with error = %@\n", error);
            }];
        }
    }];
}

@end
