//
//  BlockDateUtilitiesTests.m
//  SelfControlTests
//
//  Created by Charles Stigler on 17/07/2018.
//

#import <XCTest/XCTest.h>
#import "SCBlockDateUtilities.h"
#import "SCSettings.h"

@interface BlockDateUtilitiesTests : XCTestCase

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

@implementation BlockDateUtilitiesTests

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


- (void) testStartingAndRemovingBlocks {
    SCSettings* settings = [SCSettings currentUserSettings];

    XCTAssert(![SCBlockDateUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]);
    XCTAssert(![SCBlockDateUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);

    // test starting a block
    [SCBlockDateUtilities startBlockInSettings: settings withBlockDuration: 21600];
    XCTAssert([SCBlockDateUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);
    NSTimeInterval timeToBlockEnd = [[settings valueForKey: @"BlockEndDate"] timeIntervalSinceNow];
    XCTAssert(round(timeToBlockEnd) == 21600);

    // test removing a block
    [SCBlockDateUtilities removeBlockFromSettings: settings];
    XCTAssert(![SCBlockDateUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);
}
- (void) testModernBlockDetection {
    SCSettings* settings = [SCSettings currentUserSettings];

    XCTAssert(![SCBlockDateUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]);
    XCTAssert(![SCBlockDateUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);

    // test starting a block
    [SCBlockDateUtilities startBlockInSettings: settings withBlockDuration: 21600];
    XCTAssert(![SCBlockDateUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]);
    XCTAssert([SCBlockDateUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);

    // turn the block "on"
    [settings setValue: @YES forKey: @"BlockIsRunning"];
    XCTAssert([SCBlockDateUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]);
    XCTAssert([SCBlockDateUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);

    // remove the block
    [SCBlockDateUtilities removeBlockFromSettings: settings];
    XCTAssert(![SCBlockDateUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]);
    XCTAssert(![SCBlockDateUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]);
}

- (void) testLegacyBlockDetection {
    // test blockIsRunningInLegacyDictionary
    // the block is "running" even if it's expired, since it hasn't been removed
    XCTAssert([SCBlockDateUtilities blockIsRunningInLegacyDictionary: activeBlockLegacyDict]);
    XCTAssert([SCBlockDateUtilities blockIsRunningInLegacyDictionary: expiredBlockLegacyDict]);
    XCTAssert(![SCBlockDateUtilities blockIsRunningInLegacyDictionary: noBlockLegacyDict]);
    XCTAssert(![SCBlockDateUtilities blockIsRunningInLegacyDictionary: noBlockLegacyDict2]);
    XCTAssert([SCBlockDateUtilities blockIsRunningInLegacyDictionary: futureStartDateLegacyDict]);
    XCTAssert([SCBlockDateUtilities blockIsRunningInLegacyDictionary: negativeBlockDurationLegacyDict]); // negative still might be running?
    XCTAssert([SCBlockDateUtilities blockIsRunningInLegacyDictionary: veryLongBlockLegacyDict]);
    XCTAssert(![SCBlockDateUtilities blockIsRunningInLegacyDictionary: emptyLegacyDict]);
    
    // test endDateFromLegacyBlockDictionary
    NSDate* activeBlockEndDate = [SCBlockDateUtilities endDateFromLegacyBlockDictionary: activeBlockLegacyDict];
    NSDate* expiredBlockEndDate = [SCBlockDateUtilities endDateFromLegacyBlockDictionary: expiredBlockLegacyDict];
    NSDate* noBlockBlockEndDate = [SCBlockDateUtilities endDateFromLegacyBlockDictionary: noBlockLegacyDict];
    NSDate* noBlock2BlockEndDate = [SCBlockDateUtilities endDateFromLegacyBlockDictionary: noBlockLegacyDict2];
    NSDate* futureStartBlockEndDate = [SCBlockDateUtilities endDateFromLegacyBlockDictionary: futureStartDateLegacyDict];
    NSDate* negativeDurationBlockEndDate = [SCBlockDateUtilities endDateFromLegacyBlockDictionary: negativeBlockDurationLegacyDict];
    NSDate* veryLongBlockEndDate = [SCBlockDateUtilities endDateFromLegacyBlockDictionary: veryLongBlockLegacyDict];
    NSDate* emptyBlockEndDate = [SCBlockDateUtilities endDateFromLegacyBlockDictionary: emptyLegacyDict];

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
