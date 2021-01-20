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
            @"MaxBlockLength": @1440,
            @"BlockLengthInterval": @15,
            @"WhitelistAlertSuppress": @NO,
            @"GetStartedShown": @NO,
            @"EvaluateCommonSubdomains": @YES,
            @"IncludeLinkedDomains": @YES,
            @"BlockSoundShouldPlay": @NO,
            @"BlockSound": @5,
            @"ClearCaches": @YES,
            @"AllowLocalNetworks": @YES,
            @"EnableErrorReporting": @NO,
            @"ErrorReportingPromptDismissed": @NO
        };
    });
    
    return defaultDefaultsDict;
}

@end
