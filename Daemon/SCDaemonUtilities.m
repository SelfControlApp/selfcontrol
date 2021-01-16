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
    NSLog(@"Unloading SelfControl daemon...");
    [SCSentry addBreadcrumb: @"Daemon about to unload" category: @"daemon"];
    SCSettings* settings = [SCSettings sharedSettings];

    // we're about to unload the launchd job
    // this will kill this process, so we have to make sure
    // all settings are synced before we unload
    NSError* syncErr;
    [settings syncSettingsAndWait: 5.0 error: &syncErr];
    if (syncErr != nil) {
        NSLog(@"WARNING: Sync failed or timed out with error %@ before unloading daemon job", syncErr);
        [SCSentry captureError: syncErr];
    }
    
    // uh-oh, looks like it's 5 seconds later and the sync hasn't completed yet. Bad news.
    CFErrorRef cfError;
    // this should block until the process is dead, so we should never get to the other side if it's successful
    SMJobRemove(kSMDomainSystemLaunchd, CFSTR("org.eyebeam.selfcontrold"), NULL, YES, &cfError);
    if (cfError) {
        NSLog(@"Failed to remove selfcontrold daemon with error %@", cfError);
    }
}

@end
