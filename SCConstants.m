//
//  SCConstants.m
//  SelfControl
//
//  Created by Charlie Stigler on 3/31/19.
//

#import "SCConstants.h"

OSStatus const AUTH_CANCELLED_STATUS = -60006;

@implementation SCConstants

+  (NSArray<NSString*>*)systemSoundNames {
    static NSArray<NSString*>* soundsArr = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        soundsArr = @[@"Basso",
                      @"Blow",
                      @"Bottle",
                      @"Frog",
                      @"Funk",
                      @"Glass",
                      @"Hero",
                      @"Morse",
                      @"Ping",
                      @"Pop",
                      @"Purr",
                      @"Sosumi",
                      @"Submarine",
                      @"Tink"];
    });
    
    return soundsArr;
}

+ (NSDictionary<NSString*, id>*)defaultUserDefaults {
    static NSDictionary<NSString*, id>* defaultDefaultsDict = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultDefaultsDict = @{
            @"Blocklist": @[],
            @"BlockAsWhitelist": @NO,
            @"HighlightInvalidHosts": @YES,
            @"VerifyInternetConnection": @YES,
            @"TimerWindowFloats": @NO,
            @"BadgeApplicationIcon": @YES,
            @"BlockDuration": @1,
            @"MaxBlockLength": @1440,
            @"WhitelistAlertSuppress": @NO,
            @"GetStartedShown": @NO,
            @"EvaluateCommonSubdomains": @YES,
            @"IncludeLinkedDomains": @YES,
            @"BlockSoundShouldPlay": @NO,
            @"BlockSound": @5,
            @"ClearCaches": @YES,
            @"AllowLocalNetworks": @YES,
            // if the user has checked the box to "send crash reports to third-party developers", we'll default Sentry on
            // otherwise it defaults off, but we'll still prompt to ask them if we can send data
            @"EnableErrorReporting": @([SCMiscUtilities systemThirdPartyCrashReportingEnabled]),
            @"ErrorReportingPromptDismissed": @NO,
            @"SuppressLongBlockWarning": @NO,
            @"SuppressRestartFirefoxWarning": @NO,
            @"FirstBlockStarted": @NO,
            
            @"V4MigrationComplete": @NO
        };
    });
    
    return defaultDefaultsDict;
}

@end
