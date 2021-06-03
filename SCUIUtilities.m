//
//  SCUIUtilities.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/20/21.
//

#import "SCUIUtilities.h"
#import <SystemConfiguration/SystemConfiguration.h>

@implementation SCUIUtilities

+ (NSString*)blockTeaserStringWithMaxLength:(NSInteger)maxStringLen {
    NSArray<NSString*>* blocklist;
    BOOL isAllowlist;
    
    // if we've got a block running (and it's from the modern system),
    // the real source of truth is secured settings.
    // if no block is running (or it's an old-school one), the best we've got is what's in defaults
    if ([SCBlockUtilities modernBlockIsRunning]) {
        SCSettings* settings = [SCSettings sharedSettings];
        blocklist = [settings valueForKey: @"ActiveBlocklist"];
        isAllowlist = [settings boolForKey: @"ActiveBlockAsWhitelist"];
    } else {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        blocklist = [defaults arrayForKey: @"Blocklist"];
        isAllowlist = [defaults boolForKey: @"BlockAsWhitelist"];
    }
    
    // special strings if the list is empty
    if (blocklist.count == 0) {
        if (isAllowlist) {
            return @"Blocking the entire Internet";
        } else {
            return @"Blocking nothing (blocklist is empty)";
        }
    }
    
    NSString* startStr;
    if (isAllowlist) {
        startStr = @"Blocking the entire Internet EXCEPT ";
    } else {
        startStr = @"Blocking ";
    }
    
    NSMutableString* siteStr = [NSMutableString stringWithCapacity: (NSUInteger)maxStringLen];
    NSInteger ESTIMATED_OTHERS_STR_LEN = 15; // this is a guesstimate of how long the end-string will be - we don't really know yet
    NSInteger MAX_SITE_CHARS = (NSInteger)maxStringLen - (NSInteger)startStr.length - ESTIMATED_OTHERS_STR_LEN;
    NSInteger MAX_HOSTS_IN_STRING = 3;
    NSInteger hostsInString = 0;
    NSInteger curIndex = 0;

    for (NSString* hostString in blocklist) {
        // don't go over our max host allotment
        if (hostsInString + 1 > MAX_HOSTS_IN_STRING) break;

        // don't go over our max string length
        if ((NSInteger)hostString.length + (NSInteger)siteStr.length > MAX_SITE_CHARS) break;

        if (hostsInString > 0) {
            if (blocklist.count > 2) {
                [siteStr appendString: @", "];
            } else {
                [siteStr appendString: @" "];
            }
        }
        
        if (curIndex == ((NSInteger)blocklist.count - 1) && (NSInteger)blocklist.count > 1) {
            [siteStr appendFormat: @"and %@", hostString];
        } else {
            [siteStr appendString: hostString];
        }

        hostsInString++;

        curIndex++;
    }
    
    NSInteger numOthers = (NSInteger)blocklist.count - hostsInString;
    if (numOthers > 0) {
        if (hostsInString == 0) {
            [siteStr appendFormat: @"%ld %@", (long)numOthers, numOthers > 1 ? @"sites" : @"site"];
        } else if (hostsInString <= 2) {
            [siteStr appendFormat: @" and %ld %@", (long)numOthers, numOthers > 1 ? @"others" : @"other"];
        } else {
            [siteStr appendFormat: @", and %ld %@", (long)numOthers, numOthers > 1 ? @"others" : @"other"];
        }
    }

    return [startStr stringByAppendingString: siteStr];
}

+ (BOOL)networkConnectionIsAvailable {
    SCNetworkReachabilityFlags flags;

    // This method goes haywire if Google ever goes down...
    SCNetworkReachabilityRef target = SCNetworkReachabilityCreateWithName (kCFAllocatorDefault, "google.com");

    BOOL reachable = (BOOL)SCNetworkReachabilityGetFlags (target, &flags);
    
    return reachable && (flags & kSCNetworkFlagsReachable) && !(flags & kSCNetworkFlagsConnectionRequired);
}

+ (BOOL)promptBrowserRestartIfNecessary {
    NSString* ffBundleId = @"org.mozilla.firefox";
    NSArray<NSRunningApplication*>* runningFF = [NSRunningApplication runningApplicationsWithBundleIdentifier: ffBundleId];
    if (runningFF.count < 1) {
        // Firefox isn't running, no stress!
        return NO;
    }

    // all UI stuff MUST be done on the main thread
    if (![NSThread isMainThread]) {
        __block BOOL retVal = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            retVal = [SCUIUtilities promptBrowserRestartIfNecessary];
        });
        return retVal;
    }

    NSString* RESTART_FF_SUPPRESSION_KEY = @"SuppressRestartFirefoxWarning";
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    // if they don't want the warnings, they don't get the warnings
    if ([defaults boolForKey: RESTART_FF_SUPPRESSION_KEY]) {
        return NO;
    }

    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText: NSLocalizedString(@"Restart Firefox", "FireFox browser restart prompt")];
    [alert setInformativeText:NSLocalizedString(@"SelfControl's block may not work properly in Firefox until you restart the browser. Do you want to quit Firefox now?", @"Message explaining Firefox restart requirement")];
    [alert addButtonWithTitle: NSLocalizedString(@"Quit Firefox", @"Button to quit Firefox")];
    [alert addButtonWithTitle: NSLocalizedString(@"Continue Without Restart", "Button to decline restarting Firefox")];
    alert.showsSuppressionButton = YES;

    NSModalResponse modalResponse = [alert runModal];
    if (alert.suppressionButton.state == NSControlStateValueOn) {
        // no more warnings, they say
        [defaults setBool: YES forKey: RESTART_FF_SUPPRESSION_KEY];
    }
    if (modalResponse == NSAlertFirstButtonReturn) {
        for (NSRunningApplication* ff in runningFF) {
            [ff terminate];
        }
        
        return YES;
    }
    
    return NO;
}

+ (BOOL)blockIsRunning {
    // we'll say a block is running if we find the block info, but
    // also, importantly, if we find a block still going in the hosts file
    // that way if this happens, the user will still see the timer window -
    // which will let them manually clear the remaining block info after 10 seconds
    return [SCBlockUtilities anyBlockIsRunning] || [SCBlockUtilities blockRulesFoundOnSystem];
}

+ (void)presentError:(NSError*)err {
    if (err == nil) return;

    // When errors are generated in the daemon, they generally don't have access to the localized .strings
    // files which are in our bundle, so the errors won't have a proper localized description.
    if ([err.domain isEqualToString: kSelfControlErrorDomain] && [err.userInfo[@"SCDescriptionNotFound"] boolValue]) {
        err = [SCErr errorWithCode: err.code];
    }
    
    // we don't present auth cancelled errors, since they generally don't indicate a "real" problem
    if ([SCMiscUtilities errorIsAuthCanceled: err]) return;
    
    // always present errors on the main thread since it's a UI task
    [NSApp performSelectorOnMainThread: @selector(presentError:)
                            withObject: err
                         waitUntilDone: YES];
}

@end
