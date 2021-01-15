//
//  SCSentry.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/15/21.
//

#import "SCSentry.h"
#import "SCSettings.h"

@implementation SCSentry

//org.eyebeam.SelfControl
+ (void)startSentry:(NSString*)componentId {
    [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
        options.dsn = @"https://58fbe7145368418998067f88896007b2@o504820.ingest.sentry.io/5592195";
        options.debug = YES; // Enabled debug when first installing is always helpful
        options.releaseName = [NSString stringWithFormat: @"%@%@", componentId, SELFCONTROL_VERSION_STRING];
        options.enableAutoSessionTracking = NO;
        options.environment = @"dev";
    }];
    [SentrySDK configureScope:^(SentryScope * _Nonnull scope) {
        [scope setTagValue: [[NSLocale currentLocale] localeIdentifier] forKey: @"localeId"];
    }];
}

+ (void)updateDefaultsContext {
    // if we're root, we can't get defaults properly, so forget it
    if (!geteuid()) {
        return;
    }

    NSMutableDictionary* defaultsDict = [[[NSUserDefaults standardUserDefaults] persistentDomainForName: @"org.eyebeam.SelfControl"] mutableCopy];

    // delete blocklist (because PII) and check time (because unnecessary, and Sentry doesn't like dates)
    [defaultsDict removeObjectForKey: @"Blocklist"];
    [defaultsDict removeObjectForKey: @"SULastCheckTime"];
    
    [SentrySDK configureScope:^(SentryScope * _Nonnull scope) {
        [scope setContextValue: defaultsDict forKey: @"NSUserDefaults"];
    }];
}

+ (void)captureError:(NSError*)error {
    NSLog(@"Reporting error %@ to Sentry...", error);
    [[SCSettings sharedSettings] updateSentryContext];
    [SCSentry updateDefaultsContext];
    [SentrySDK captureError: error];
}

+ (void)captureMessage:(NSString*)message {
    NSLog(@"Reporting message %@ to Sentry...", message);
    [[SCSettings sharedSettings] updateSentryContext];
    [SCSentry updateDefaultsContext];
    [SentrySDK captureMessage: message];
}

@end
