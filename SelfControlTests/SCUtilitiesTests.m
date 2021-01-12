//
//  BlockDateUtilitiesTests.m
//  SelfControlTests
//
//  Created by Charles Stigler on 17/07/2018.
//

#import <XCTest/XCTest.h>
#import "SCUtilities.h"
#import "SCSettings.h"

@interface SCUtilitiesTests : XCTestCase

@end

// Static dictionaries of block values to test against

NSDictionary* activeBlockLegacyDict; // Active (started 5 minutes ago, duration 10 min)
NSDictionary* expiredBlockLegacyDict; // Expired (started 10 minutes 10 seconds ago, duration 10 min)
NSDictionary* noBlockLegacyDict; // start date is distantFuture
NSDictionary* noBlockLegacyDict2; // start date is nil
NSDictionary* emptyLegacyDict; // literally an empty dictionary
NSDictionary* futureStartDateLegacyDict; // start date is in the future
NSDictionary* negativeBlockDurationLegacyDict; // block duration is negative
NSDictionary* veryLongBlockLegacyDict; // year-long block, one day in

@implementation SCUtilitiesTests

- (NSUserDefaults*)testDefaults {
    return [[NSUserDefaults alloc] initWithSuiteName: @"BlockDateUtilitiesTests"];
}

+ (void)setUp {
    // Initialize the sample legacy setting dictionaries
    activeBlockLegacyDict = @{
        @"BlockStartedDate": [NSDate dateWithTimeIntervalSinceNow: -300], // 5 minutes ago
        @"BlockDuration": @10 // 10 minutes
    };
    expiredBlockLegacyDict = @{
        @"BlockStartedDate": [NSDate dateWithTimeIntervalSinceNow: -610], // 10 min 10 seconds ago
        @"BlockDuration": @10 // 10 minutes
    };
    noBlockLegacyDict = @{
        @"BlockStartedDate": [NSDate distantFuture],
        @"BlockDuration": @300 // 6 hours
    };
    noBlockLegacyDict2 = @{
        @"BlockDuration": @300 // 6 hours
    };
    futureStartDateLegacyDict = @{
        @"BlockStartedDate": [NSDate dateWithTimeIntervalSinceNow: 600], // 10 min from now
        @"BlockDuration": @300 // 6 hours
    };
    negativeBlockDurationLegacyDict = @{
        @"BlockStartedDate": [NSDate dateWithTimeIntervalSinceNow: -600], // 10 min ago
        @"BlockDuration": @-15 // negative 15 minutes
    };
    veryLongBlockLegacyDict = @{
        @"BlockStartedDate": [NSDate dateWithTimeIntervalSinceNow: -86400], // 1 day ago
        @"BlockDuration": @432000 // 300 days
    };
    emptyLegacyDict = @{
    };
}

- (void)setUp {
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void) testCleanBlocklistEntries {
    // ignores weird invalid entries
    XCTAssert([SCUtilities cleanBlocklistEntry: nil].count == 0);
    XCTAssert([SCUtilities cleanBlocklistEntry: @""].count == 0);
    XCTAssert([SCUtilities cleanBlocklistEntry: @"      "].count == 0);
    XCTAssert([SCUtilities cleanBlocklistEntry: @"  \n\n   \n***!@#$%^*()+=<>,/?| "].count == 0);
    XCTAssert([SCUtilities cleanBlocklistEntry: @"://}**"].count == 0);
    
    // can take a plain hostname
    NSArray* cleaned = [SCUtilities cleanBlocklistEntry: @"selfcontrolapp.com"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"selfcontrolapp.com"]);
    
    // and lowercase it
    cleaned = [SCUtilities cleanBlocklistEntry: @"selFconTROLapp.com"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"selfcontrolapp.com"]);
    
    // with subdomains
    cleaned = [SCUtilities cleanBlocklistEntry: @"www.selFconTROLapp.com"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"www.selfcontrolapp.com"]);
    
    // with http scheme
    cleaned = [SCUtilities cleanBlocklistEntry: @"http://www.selFconTROLapp.com"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"www.selfcontrolapp.com"]);
    
    // with https scheme
    cleaned = [SCUtilities cleanBlocklistEntry: @"https://www.selFconTROLapp.com"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"www.selfcontrolapp.com"]);
    
    // with ftp scheme
    cleaned = [SCUtilities cleanBlocklistEntry: @"ftp://www.selFconTROLapp.com"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"www.selfcontrolapp.com"]);
    
    // with port
    cleaned = [SCUtilities cleanBlocklistEntry: @"https://www.selFconTROLapp.com:73"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"www.selfcontrolapp.com:73"]);
    
    // strips username/password
    cleaned = [SCUtilities cleanBlocklistEntry: @"http://charlie:mypass@cnn.com:54"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"cnn.com:54"]);
    
    // strips path etc
    cleaned = [SCUtilities cleanBlocklistEntry: @"http://mysite.com/my/path/is/very/long.php?querystring=ydfjkl&otherquerystring=%40%80%20#cool"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"mysite.com"]);
    
    // CIDR IP ranges
    cleaned = [SCUtilities cleanBlocklistEntry: @"127.0.0.1/20"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"127.0.0.1/20"]);
    
    // can split entries by newlines
    cleaned = [SCUtilities cleanBlocklistEntry: @"http://charlie:mypass@cnn.com:54\nhttps://selfcontrolAPP.com\n192.168.1.1/24\ntest.com\n{}*&\nhttps://reader.google.com/mypath/is/great.php"];
    XCTAssert(cleaned.count == 5);
    XCTAssert([cleaned[0] isEqualToString: @"cnn.com:54"]);
    XCTAssert([cleaned[1] isEqualToString: @"selfcontrolapp.com"]);
    XCTAssert([cleaned[2] isEqualToString: @"192.168.1.1/24"]);
    XCTAssert([cleaned[3] isEqualToString: @"test.com"]);
    XCTAssert([cleaned[4] isEqualToString: @"reader.google.com"]);
}

- (void) testStartingAndRemovingBlocks {
    SCSettings* settings = [SCSettings sharedSettings];

    XCTAssert(![SCUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]);
    XCTAssert(![SCUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);

    // test starting a block
    [SCUtilities startBlockInSettings: settings withBlockDuration: 21600];
    XCTAssert([SCUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);
    NSTimeInterval timeToBlockEnd = [[settings valueForKey: @"BlockEndDate"] timeIntervalSinceNow];
    XCTAssert(round(timeToBlockEnd) == 21600);

    // test removing a block
    [SCUtilities removeBlockFromSettings];
    XCTAssert(![SCUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);
}
- (void) testModernBlockDetection {
    SCSettings* settings = [SCSettings sharedSettings];

    XCTAssert(![SCUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]);
    XCTAssert(![SCUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);

    // test starting a block
    [SCUtilities startBlockInSettings: settings withBlockDuration: 21600];
    XCTAssert(![SCUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]);
    XCTAssert([SCUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);

    // turn the block "on"
    [settings setValue: @YES forKey: @"BlockIsRunning"];
    XCTAssert([SCUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]);
    XCTAssert([SCUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);

    // remove the block
    [SCUtilities removeBlockFromSettings];
    XCTAssert(![SCUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]);
    XCTAssert(![SCUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);
}

- (void) testLegacyBlockDetection {
    // test blockIsRunningInLegacyDictionary
    // the block is "running" even if it's expired, since it hasn't been removed
    XCTAssert([SCUtilities blockIsRunningInLegacyDictionary: activeBlockLegacyDict]);
    XCTAssert([SCUtilities blockIsRunningInLegacyDictionary: expiredBlockLegacyDict]);
    XCTAssert(![SCUtilities blockIsRunningInLegacyDictionary: noBlockLegacyDict]);
    XCTAssert(![SCUtilities blockIsRunningInLegacyDictionary: noBlockLegacyDict2]);
    XCTAssert([SCUtilities blockIsRunningInLegacyDictionary: futureStartDateLegacyDict]);
    XCTAssert([SCUtilities blockIsRunningInLegacyDictionary: negativeBlockDurationLegacyDict]); // negative still might be running?
    XCTAssert([SCUtilities blockIsRunningInLegacyDictionary: veryLongBlockLegacyDict]);
    XCTAssert(![SCUtilities blockIsRunningInLegacyDictionary: emptyLegacyDict]);
    
    // test endDateFromLegacyBlockDictionary
    NSDate* activeBlockEndDate = [SCUtilities endDateFromLegacyBlockDictionary: activeBlockLegacyDict];
    NSDate* expiredBlockEndDate = [SCUtilities endDateFromLegacyBlockDictionary: expiredBlockLegacyDict];
    NSDate* noBlockBlockEndDate = [SCUtilities endDateFromLegacyBlockDictionary: noBlockLegacyDict];
    NSDate* noBlock2BlockEndDate = [SCUtilities endDateFromLegacyBlockDictionary: noBlockLegacyDict2];
    NSDate* futureStartBlockEndDate = [SCUtilities endDateFromLegacyBlockDictionary: futureStartDateLegacyDict];
    NSDate* negativeDurationBlockEndDate = [SCUtilities endDateFromLegacyBlockDictionary: negativeBlockDurationLegacyDict];
    NSDate* veryLongBlockEndDate = [SCUtilities endDateFromLegacyBlockDictionary: veryLongBlockLegacyDict];
    NSDate* emptyBlockEndDate = [SCUtilities endDateFromLegacyBlockDictionary: emptyLegacyDict];

    XCTAssert(round([activeBlockEndDate timeIntervalSinceNow]) == 300); // 5 min from now
    XCTAssert(round([expiredBlockEndDate timeIntervalSinceNow]) == -10); // 10 seconds ago
    XCTAssert([noBlockBlockEndDate isEqualToDate: [NSDate distantPast]]); // no block should be active
    XCTAssert([noBlock2BlockEndDate isEqualToDate: [NSDate distantPast]]); // no block should be active
    XCTAssert([futureStartBlockEndDate isEqualToDate: [NSDate distantPast]]); // no block should be active
    XCTAssert([negativeDurationBlockEndDate isEqualToDate: [NSDate distantPast]]); // no block should be active
    XCTAssert(round([veryLongBlockEndDate timeIntervalSinceNow]) == 25833600); // 299 days from now
    XCTAssert([emptyBlockEndDate isEqualToDate: [NSDate distantPast]]); // block should be expired
}

@end
