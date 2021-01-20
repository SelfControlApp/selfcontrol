//
//  BlockDateUtilitiesTests.m
//  SelfControlTests
//
//  Created by Charles Stigler on 17/07/2018.
//

#import <XCTest/XCTest.h>
#import "SCUtility.h"
#import "SCSentry.h"
#import "SCErr.h"
#import "SCSettings.h"

@interface SCUtilityTests : XCTestCase

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

@implementation SCUtilityTests

- (NSUserDefaults*)testDefaults {
    return [[NSUserDefaults alloc] initWithSuiteName: @"BlockDateUtilitiesTests"];
}

+ (void)setUp {
    // SCSettings shouldn't be readOnly during our tests
    // so we can test changing values
    [SCSettings sharedSettings].readOnly = NO;
    
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
    XCTAssert([SCMiscUtilities cleanBlocklistEntry: nil].count == 0);
    XCTAssert([SCMiscUtilities cleanBlocklistEntry: @""].count == 0);
    XCTAssert([SCMiscUtilities cleanBlocklistEntry: @"      "].count == 0);
    XCTAssert([SCMiscUtilities cleanBlocklistEntry: @"  \n\n   \n***!@#$%^*()+=<>,/?| "].count == 0);
    XCTAssert([SCMiscUtilities cleanBlocklistEntry: @"://}**"].count == 0);
    
    // can take a plain hostname
    NSArray* cleaned = [SCMiscUtilities cleanBlocklistEntry: @"selfcontrolapp.com"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"selfcontrolapp.com"]);
    
    // and lowercase it
    cleaned = [SCMiscUtilities cleanBlocklistEntry: @"selFconTROLapp.com"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"selfcontrolapp.com"]);
    
    // with subdomains
    cleaned = [SCMiscUtilities cleanBlocklistEntry: @"www.selFconTROLapp.com"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"www.selfcontrolapp.com"]);
    
    // with http scheme
    cleaned = [SCMiscUtilities cleanBlocklistEntry: @"http://www.selFconTROLapp.com"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"www.selfcontrolapp.com"]);
    
    // with https scheme
    cleaned = [SCMiscUtilities cleanBlocklistEntry: @"https://www.selFconTROLapp.com"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"www.selfcontrolapp.com"]);
    
    // with ftp scheme
    cleaned = [SCMiscUtilities cleanBlocklistEntry: @"ftp://www.selFconTROLapp.com"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"www.selfcontrolapp.com"]);
    
    // with port
    cleaned = [SCMiscUtilities cleanBlocklistEntry: @"https://www.selFconTROLapp.com:73"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"www.selfcontrolapp.com:73"]);
    
    // strips username/password
    cleaned = [SCMiscUtilities cleanBlocklistEntry: @"http://charlie:mypass@cnn.com:54"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"cnn.com:54"]);
    
    // strips path etc
    cleaned = [SCMiscUtilities cleanBlocklistEntry: @"http://mysite.com/my/path/is/very/long.php?querystring=ydfjkl&otherquerystring=%40%80%20#cool"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"mysite.com"]);
    
    // CIDR IP ranges
    cleaned = [SCMiscUtilities cleanBlocklistEntry: @"127.0.0.1/20"];
    XCTAssert(cleaned.count == 1 && [[cleaned firstObject] isEqualToString: @"127.0.0.1/20"]);
    
    // can split entries by newlines
    cleaned = [SCMiscUtilities cleanBlocklistEntry: @"http://charlie:mypass@cnn.com:54\nhttps://selfcontrolAPP.com\n192.168.1.1/24\ntest.com\n{}*&\nhttps://reader.google.com/mypath/is/great.php"];
    XCTAssert(cleaned.count == 5);
    XCTAssert([cleaned[0] isEqualToString: @"cnn.com:54"]);
    XCTAssert([cleaned[1] isEqualToString: @"selfcontrolapp.com"]);
    XCTAssert([cleaned[2] isEqualToString: @"192.168.1.1/24"]);
    XCTAssert([cleaned[3] isEqualToString: @"test.com"]);
    XCTAssert([cleaned[4] isEqualToString: @"reader.google.com"]);
}

- (void) testModernBlockDetection {
    SCSettings* settings = [SCSettings sharedSettings];

    XCTAssert(![SCBlockUtilities modernBlockIsRunning]);
    XCTAssert([SCBlockUtilities currentBlockIsExpired]);

    // test a block that should have expired 5 minutes ago
    [settings setValue: @YES forKey: @"BlockIsRunning"];
    [settings setValue: @[ @"facebook.com", @"reddit.com" ] forKey: @"ActiveBlocklist"];
    [settings setValue: @NO forKey: @"ActiveBlockAsWhitelist"];
    [settings setValue: [NSDate dateWithTimeIntervalSinceNow: -300] forKey: @"BlockEndDate"];

    XCTAssert([SCBlockUtilities modernBlockIsRunning]);
    XCTAssert([SCBlockUtilities currentBlockIsExpired]);

    // test block that should still be running
    [settings setValue: [NSDate dateWithTimeIntervalSinceNow: 300] forKey: @"BlockEndDate"];
    XCTAssert([SCBlockUtilities modernBlockIsRunning]);
    XCTAssert(![SCBlockUtilities currentBlockIsExpired]);

    // test removing a block
    [SCBlockUtilities removeBlockFromSettings];
    XCTAssert(![SCBlockUtilities modernBlockIsRunning]);
    XCTAssert([SCBlockUtilities currentBlockIsExpired]);
}

- (void) testLegacyBlockDetection {
    // test blockIsRunningInLegacyDictionary
    // the block is "running" even if it's expired, since it hasn't been removed
    XCTAssert([SCMigrationUtilities blockIsRunningInLegacyDictionary: activeBlockLegacyDict]);
    XCTAssert([SCMigrationUtilities blockIsRunningInLegacyDictionary: expiredBlockLegacyDict]);
    XCTAssert(![SCMigrationUtilities blockIsRunningInLegacyDictionary: noBlockLegacyDict]);
    XCTAssert(![SCMigrationUtilities blockIsRunningInLegacyDictionary: noBlockLegacyDict2]);
    XCTAssert([SCMigrationUtilities blockIsRunningInLegacyDictionary: futureStartDateLegacyDict]);
    XCTAssert([SCMigrationUtilities blockIsRunningInLegacyDictionary: negativeBlockDurationLegacyDict]); // negative still might be running?
    XCTAssert([SCMigrationUtilities blockIsRunningInLegacyDictionary: veryLongBlockLegacyDict]);
    XCTAssert(![SCMigrationUtilities blockIsRunningInLegacyDictionary: emptyLegacyDict]);
}

@end
