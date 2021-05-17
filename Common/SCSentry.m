//
//  SCSentry.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/15/21.
//

#import "SCSentry.h"
#import "SCSettings.h"

#ifndef TESTING
#import <Sentry/Sentry.h>
#endif

@implementation SCSentry

//org.eyebeam.SelfControl
+ (void)startSentry:(NSString*)componentId {
#ifndef TESTING
    [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
        options.dsn = @"https://58fbe7145368418998067f88896007b2@o504820.ingest.sentry.io/5592195";
        options.releaseName = [NSString stringWithFormat: @"%@%@", componentId, SELFCONTROL_VERSION_STRING];
        options.enableAutoSessionTracking = NO;
        options.environment = @"dev";
        
        // make sure no data leaves the device if error reporting isn't enabled
        options.beforeSend = ^SentryEvent * _Nullable(SentryEvent * _Nonnull event) {
            if ([SCSentry errorReportingEnabled]) {
                return event;
            } else {
                return NULL;
            }
        };
    }];
    [SentrySDK configureScope:^(SentryScope * _Nonnull scope) {
        [scope setTagValue: [[NSLocale currentLocale] localeIdentifier] forKey: @"localeId"];
    }];
#endif
}

+ (BOOL)errorReportingEnabled {
#ifdef TESTING
    // don't report to Sentry while unit-testing!
    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"isTest"]) {
        return YES;
    }
#endif
    if (geteuid() != 0) {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        return [defaults boolForKey: @"EnableErrorReporting"];
    } else {
        // since we're root, we've gotta see what's in SCSettings (where the user's defaults will have been copied)
        return [[SCSettings sharedSettings] boolForKey: @"EnableErrorReporting"];
    }
}

// returns YES if we turned on error reporting based on the prompt return
+ (BOOL)showErrorReportingPromptIfNeeded {
    // no need to show the prompt if we're root (aka in the CLI/daemon), or already enabled error reporting, or if the user already dismissed it
    if (!geteuid()) return NO;
    if ([SCSentry errorReportingEnabled]) return NO;
    
    // if they've already dismissed this once, don't show it again
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey: @"ErrorReportingPromptDismissed"]) {
        return NO;
    }
    
    // all UI stuff MUST be done on the main thread
    if (![NSThread isMainThread]) {
        __block BOOL retVal = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            retVal = [SCSentry showErrorReportingPromptIfNeeded];
        });
        return retVal;
    }
    
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText: NSLocalizedString(@"Enable automatic error reporting", "Title of error reporting prompt")];
    [alert setInformativeText:NSLocalizedString(@"SelfControl can automatically send bug reports to help us improve the software. All data is anonymized, your blocklist is never shared, and no identifying information is sent.", @"Message explaining error reporting")];
    [alert addButtonWithTitle: NSLocalizedString(@"Enable Error Reporting", @"Button to enable error reporting")];
    [alert addButtonWithTitle: NSLocalizedString(@"Don't Send Reports", "Button to decline error reporting")];
    
    NSModalResponse modalResponse = [alert runModal];
    if (modalResponse == NSAlertFirstButtonReturn) {
        [defaults setBool: YES forKey: @"EnableErrorReporting"];
        [defaults setBool: YES forKey: @"ErrorReportingPromptDismissed"];
        return YES;
    } else if (modalResponse == NSAlertSecondButtonReturn) {
        [defaults setBool: NO forKey: @"EnableErrorReporting"];
        [defaults setBool: YES forKey: @"ErrorReportingPromptDismissed"];
    } // if the modal exited some other way, do nothing
    
    return NO;
}

+ (void)updateDefaultsContext {
    // if we're root, we can't get defaults properly, so forget it
    if (!geteuid()) {
        return;
    }

    NSMutableDictionary* defaultsDict = [[[NSUserDefaults standardUserDefaults] persistentDomainForName: @"org.eyebeam.SelfControl"] mutableCopy];

    // delete blocklist (because PII) and update check time
    // (because unnecessary, and Sentry dies if you feed it dates)
    // but store the blocklist length as a useful piece of debug info
    id blocklist = defaultsDict[@"Blocklist"];
    NSUInteger blocklistLength = (blocklist == nil) ? 0 : ((NSArray*)blocklist).count;
    [defaultsDict setObject: @(blocklistLength) forKey: @"BlocklistLength"];
    [defaultsDict removeObjectForKey: @"Blocklist"];
    [defaultsDict removeObjectForKey: @"SULastCheckTime"];
    [defaultsDict removeObjectForKey: @"SULastProfileSubmissionDate"];

#ifndef TESTING
    [SentrySDK configureScope:^(SentryScope * _Nonnull scope) {
        [scope setContextValue: defaultsDict forKey: @"NSUserDefaults"];
    }];
#endif
}

+ (void)addBreadcrumb:(NSString*)message category:(NSString*)category {
#ifndef TESTING
    SentryBreadcrumb* crumb = [[SentryBreadcrumb alloc] init];
    crumb.level = kSentryLevelInfo;
    crumb.category = category;
    crumb.message = message;
    [SentrySDK addBreadcrumb: crumb];
#endif
}

+ (void)captureError:(NSError*)error {
    if (![SCSentry errorReportingEnabled]) {
        // if we're root (CLI/daemon), we can't show prompts
        if (!geteuid()) {
            return;
        }
        
        // prompt 'em to turn on error reports now if we haven't already! if they do we can continue
        BOOL enabledReports = [SCSentry showErrorReportingPromptIfNeeded];
        if (!enabledReports) {
            return;
        }
    }

    NSLog(@"Reporting error %@ to Sentry...", error);
    [[SCSettings sharedSettings] updateSentryContext];
    [SCSentry updateDefaultsContext];
#ifndef TESTING
    [SentrySDK captureError: error];
#endif
}

+ (void)captureMessage:(NSString*)message withScopeBlock:(nullable void (^)(SentryScope * _Nonnull))block {
    if (![SCSentry errorReportingEnabled]) {
        // if we're root (CLI/daemon), we can't show prompts
        if (!geteuid()) {
            return;
        }
        
        // prompt 'em to turn on error reports now if we haven't already! if they do we can continue
        BOOL enabledReports = [SCSentry showErrorReportingPromptIfNeeded];
        if (!enabledReports) {
            return;
        }
    }

    NSLog(@"Reporting message %@ to Sentry...", message);
    [[SCSettings sharedSettings] updateSentryContext];
    [SCSentry updateDefaultsContext];
    
#ifndef TESTING
    if (block != nil) {
        [SentrySDK captureMessage: message withScopeBlock: block];
    } else {
        [SentrySDK captureMessage: message];
    }
#endif
}

+ (void)captureMessage:(NSString*)message {
    [SCSentry captureMessage: message withScopeBlock: nil];
}

@end
