//
//  SCDaemonUtilities.m
//  org.eyebeam.selfcontrold
//
//  Created by Charlie Stigler on 9/16/20.
//

#import "SCDaemonUtilities.h"
#import <ServiceManagement/ServiceManagement.h>
#import "SCSettings.h"
#import "SCUtilities.h"
#import "BlockManager.h"

@implementation SCDaemonUtilities

+ (void)unloadDaemonJob {
    SCSettings* settings = [SCSettings sharedSettings];

    // we're about to unload the launchd job
    // this will kill this process, so we have to make sure
    // all settings are synced before we unload
    [settings synchronizeSettingsWithCompletion:^(NSError* err) {
        if (err != nil) {
            NSLog(@"WARNING: Settings failed to synchronize before unloading daemon, with error %@", err);
        }
                
        CFErrorRef cfError;
        SMJobRemove(kSMDomainSystemLaunchd, CFSTR("org.eyebeam.selfcontrold"), NULL, NO, &cfError);
        if (cfError) {
            NSLog(@"Failed to remove selfcontrold daemon with error %@", cfError);
        }
    }];
        
    // wait 5 seconds. assuming the synchronization completes during that time,
    // it'll unload the launchd job for us and we'll never get to the other side of this wait
    sleep(5);
        
    // uh-oh, looks like it's 5 seconds later and the sync hasn't completed yet. Bad news.
    NSLog(@"WARNING: Settings sync timed out before unloading block");
    CFErrorRef cfError;
    SMJobRemove(kSMDomainSystemLaunchd, CFSTR("org.eyebeam.selfcontrold"), NULL, NO, &cfError);
    if (cfError) {
        NSLog(@"Failed to remove selfcontrold daemon with error %@", cfError);
    }
}

@end
