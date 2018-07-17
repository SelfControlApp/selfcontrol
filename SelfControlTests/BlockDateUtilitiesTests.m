//
//  BlockDateUtilitiesTests.m
//  SelfControlTests
//
//  Created by Charles Stigler on 17/07/2018.
//

#import <XCTest/XCTest.h>
#import "SCBlockDateUtilities.h"
#import "SCBlockDateUtilities+HelperTools.h"

@interface BlockDateUtilitiesTests : XCTestCase

@end

// Static dictionaries of block values to test against

NSDictionary* enabledActiveOldWayDict; // Enabled + active old way (started 5 minutes ago, duration 10 min)
NSDictionary* enabledInactiveOldWayDict; // Enabled + inactive old way (started 10 minutes 5 seconds ago, duration 10 min)
NSDictionary* disabledOldWayDict; // Disabled old way
NSDictionary* enabledActiveNewWayDict; // Enabled + active new way (started 5 minutes ago, duration 10 min)
NSDictionary* enabledInactiveNewWayDict; // Enabled + inactive new way (started 10 minutes 5 seconds ago, duration 10 min)
NSDictionary* enabledActiveNewWayConflictingInfoDict; // Enabled + active new way, but with old values showing conflicting info
NSDictionary* disabledNewWayDict; // Disabled new way
NSDictionary* enabledOldDisabledNewDict; // Disabled new way, but enabled/active via the old way
NSDictionary* clearDict; // Completely clear defaults (first run)

@implementation BlockDateUtilitiesTests

- (NSUserDefaults*)testDefaults {
    return [[NSUserDefaults alloc] initWithSuiteName: @"BlockDateUtilitiesTests"];
}

+ (void)setUp {
    // Initialize the sample data dictionaries
    enabledActiveOldWayDict = @{
                                @"BlockStartedDate": [NSDate dateWithTimeIntervalSinceNow: -300],
                                @"BlockDuration": @10,
                                @"BlockEndDate": [NSNull null]
                                };
    enabledInactiveOldWayDict = @{
                                  @"BlockStartedDate": [NSDate dateWithTimeIntervalSinceNow: -605],
                                  @"BlockDuration": @10,
                                  @"BlockEndDate": [NSNull null]
                                  }; // Enabled + inactive old way (started 10 minutes 5 seconds ago, duration 10 min)
    disabledOldWayDict = @{
                           @"BlockStartedDate": [NSDate distantFuture],
                           @"BlockDuration": @10,
                           @"BlockEndDate": [NSNull null]
                           };
    enabledActiveNewWayDict = @{
                                @"BlockStartedDate": [NSNull null],
                                @"BlockDuration": @10,
                                @"BlockEndDate": [NSDate dateWithTimeIntervalSinceNow: 300]
                                };
    enabledInactiveNewWayDict = @{
                                  @"BlockStartedDate": [NSNull null],
                                  @"BlockDuration": @10,
                                  @"BlockEndDate": [NSDate dateWithTimeIntervalSinceNow: -5]
                                  };
    enabledActiveNewWayConflictingInfoDict = @{
                                               @"BlockStartedDate": [NSDate dateWithTimeIntervalSinceNow: -605],
                                               @"BlockDuration": @10,
                                               @"BlockEndDate": [NSDate dateWithTimeIntervalSinceNow: 300]
                                               };
    disabledNewWayDict = @{
                           @"BlockStartedDate": [NSNull null],
                           @"BlockDuration": @10,
                           @"BlockEndDate": [NSDate distantPast]
                           };
    enabledOldDisabledNewDict = @{
                                  @"BlockStartedDate": [NSDate dateWithTimeIntervalSinceNow: -300],
                                  @"BlockDuration": @10,
                                  @"BlockEndDate": [NSDate distantPast]
                                  };
    clearDict = @{
                  @"BlockEndDate": [NSNull null],
                  @"BlockStartedDate": [NSNull null],
                  @"BlockDuration": [NSNull null]
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

- (void)testBlockEnabledActive {
    NSUserDefaults* defaults = [self testDefaults];
    
    // Enabled + active old way (started 5 minutes ago, duration 10 min)
    [defaults setValuesForKeysWithDictionary: enabledActiveOldWayDict];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Enabled + inactive old way (started 10 minutes 5 seconds ago, duration 10 min)
    [defaults setValuesForKeysWithDictionary: enabledInactiveOldWayDict];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Disabled old way
    [defaults setValuesForKeysWithDictionary: disabledOldWayDict];
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Enabled + active new way (started 5 minutes ago, duration 10 min)
    [defaults setValuesForKeysWithDictionary: enabledActiveNewWayDict];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Enabled + inactive new way (started 10 minutes 5 seconds ago, duration 10 min)
    [defaults setValuesForKeysWithDictionary: enabledInactiveNewWayDict];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Enabled + active new way, but with old values showing conflicting info
    [defaults setValuesForKeysWithDictionary: enabledActiveNewWayConflictingInfoDict];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Disabled new way
    [defaults setValuesForKeysWithDictionary: disabledNewWayDict];
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Disabled new way, but enabled/active via the old way
    [defaults setValuesForKeysWithDictionary: enabledOldDisabledNewDict];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    

    // Completely clear
    [defaults setValuesForKeysWithDictionary: clearDict];
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
}

- (void)testStartBlock {
    NSUserDefaults* defaults = [self testDefaults];
    NSDate* blockEndDate;
    NSDate* expectedEndDate;
    
    // Start from disabled (new way) with 10 min block duraion
    [defaults setValuesForKeysWithDictionary: disabledNewWayDict];
    [SCBlockDateUtilities startBlockInDefaults: defaults];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    // Block end date should now be 10 min from now (with minor margin for timing error)
    blockEndDate = defaults.dictionaryRepresentation[@"BlockEndDate"];
    expectedEndDate = [NSDate dateWithTimeIntervalSinceNow: 600];
    XCTAssert([blockEndDate timeIntervalSinceDate: expectedEndDate] < 2 && [blockEndDate timeIntervalSinceDate: expectedEndDate] > -2);
    
    // Start from disabled (old way) with 10 min block duraion
    [defaults setValuesForKeysWithDictionary: disabledOldWayDict];
    [SCBlockDateUtilities startBlockInDefaults: defaults];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    // Block end date should now be 10 min from now (with minor margin for timing error)
    blockEndDate = defaults.dictionaryRepresentation[@"BlockEndDate"];
    expectedEndDate = [NSDate dateWithTimeIntervalSinceNow: 600];
    XCTAssert([blockEndDate timeIntervalSinceDate: expectedEndDate] < 2 && [blockEndDate timeIntervalSinceDate: expectedEndDate] > -2);
    // Old BlockStartedDate Property should be cleared
    NSDate* blockStartedDate = [defaults objectForKey: @"BlockStartedDate"];
    XCTAssert(blockStartedDate == nil || [blockStartedDate isEqualToDate: [NSDate distantFuture]]);

    // Start from clear (no block duration)
    // Block duration defaults to 15 min, so it should start block with duration 15 minutes
    [defaults setValuesForKeysWithDictionary: clearDict];
    [SCBlockDateUtilities startBlockInDefaults: defaults];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    // Block end date should be now (with minor margin for timing error)
    blockEndDate = defaults.dictionaryRepresentation[@"BlockEndDate"];
    expectedEndDate = [NSDate dateWithTimeIntervalSinceNow: 900];
    XCTAssert([blockEndDate timeIntervalSinceDate: expectedEndDate] < 2 && [blockEndDate timeIntervalSinceDate: expectedEndDate] > -2);
    
    // Start when block is already active - should keep block active, but change the block ending date
    [defaults setValuesForKeysWithDictionary: enabledActiveNewWayDict];
    [defaults setValue: @20 forKey: @"BlockDuration"]; // change duration so we can notice the block ending date changing
    [SCBlockDateUtilities startBlockInDefaults: defaults];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    // Block end date should be 20 min from now (with minor margin for timing error)
    blockEndDate = defaults.dictionaryRepresentation[@"BlockEndDate"];
    expectedEndDate = [NSDate dateWithTimeIntervalSinceNow: 1200];
    XCTAssert([blockEndDate timeIntervalSinceDate: expectedEndDate] < 2 && [blockEndDate timeIntervalSinceDate: expectedEndDate] > -2);
}

- (void)testRemoveBlock {
    NSUserDefaults* defaults = [self testDefaults];
    
    // Remove when block is active/enabled with new properties
    [defaults setValuesForKeysWithDictionary: enabledActiveNewWayDict];
    [SCBlockDateUtilities removeBlockFromDefaults: defaults];
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    
    // Remove when block is active/enabled with old properties
    [defaults setValuesForKeysWithDictionary: enabledActiveOldWayDict];
    [SCBlockDateUtilities removeBlockFromDefaults: defaults];
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    
    // Remove when block is enabled but inactive with new properties
    [defaults setValuesForKeysWithDictionary: enabledInactiveNewWayDict];
    [SCBlockDateUtilities removeBlockFromDefaults: defaults];
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    
    // Remove when block is enabled but inactive with old properties
    [defaults setValuesForKeysWithDictionary: enabledInactiveOldWayDict];
    [SCBlockDateUtilities removeBlockFromDefaults: defaults];
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    
    // Remove when block is already disabled (should stay disabled)
    [defaults setValuesForKeysWithDictionary: disabledNewWayDict];
    [SCBlockDateUtilities removeBlockFromDefaults: defaults];
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
}

- (void)testBlockEndDateRetrieval {
    NSUserDefaults* defaults = [self testDefaults];
    NSDate* foundBlockEndDate;

    // Retrieve when block is active/enabled with new properties
    [defaults setValuesForKeysWithDictionary: enabledActiveNewWayDict];
    foundBlockEndDate = [SCBlockDateUtilities blockEndDateInDefaults: defaults];
    // blockEndDateInDefaults and blockEndDateInDictionary *should* return the same thing
    XCTAssert([foundBlockEndDate isEqualToDate: [SCBlockDateUtilities blockEndDateInDictionary: defaults.dictionaryRepresentation]]);
    // should equal the BlockEndDate in defaults
    XCTAssert([foundBlockEndDate isEqualToDate: [defaults objectForKey: @"BlockEndDate"]]);
    
    // Retrieve when block is active/enabled with old properties
    [defaults setValuesForKeysWithDictionary: enabledActiveOldWayDict];
    foundBlockEndDate = [SCBlockDateUtilities blockEndDateInDefaults: defaults];
    // blockEndDateInDefaults and blockEndDateInDictionary *should* return the same thing
    XCTAssert([foundBlockEndDate isEqualToDate: [SCBlockDateUtilities blockEndDateInDictionary: defaults.dictionaryRepresentation]]);
    // should equal the BlockStartedDate in defaults + 10 minutes
    XCTAssert([foundBlockEndDate timeIntervalSinceDate: [defaults objectForKey: @"BlockStartedDate"]] == 600);
    
    // Retrieve when block is inactive but enabled with new properties
    [defaults setValuesForKeysWithDictionary: enabledInactiveNewWayDict];
    foundBlockEndDate = [SCBlockDateUtilities blockEndDateInDefaults: defaults];
    // blockEndDateInDefaults and blockEndDateInDictionary *should* return the same thing
    XCTAssert([foundBlockEndDate isEqualToDate: [SCBlockDateUtilities blockEndDateInDictionary: defaults.dictionaryRepresentation]]);
    // should equal the BlockEndDate in defaults
    XCTAssert([foundBlockEndDate isEqualToDate: [defaults objectForKey: @"BlockEndDate"]]);
    
    // Retrieve when block is inactive but enabled with old properties
    [defaults setValuesForKeysWithDictionary: enabledInactiveOldWayDict];
    foundBlockEndDate = [SCBlockDateUtilities blockEndDateInDefaults: defaults];
    // blockEndDateInDefaults and blockEndDateInDictionary *should* return the same thing
    XCTAssert([foundBlockEndDate isEqualToDate: [SCBlockDateUtilities blockEndDateInDictionary: defaults.dictionaryRepresentation]]);
    // should equal the BlockStartedDate in defaults + 10 minutes
    XCTAssert([foundBlockEndDate timeIntervalSinceDate: [defaults objectForKey: @"BlockStartedDate"]] == 600);
    
    // Retrieve when block is disabled with new properties
    [defaults setValuesForKeysWithDictionary: disabledNewWayDict];
    foundBlockEndDate = [SCBlockDateUtilities blockEndDateInDefaults: defaults];
    // blockEndDateInDefaults and blockEndDateInDictionary *should* return the same thing
    XCTAssert([foundBlockEndDate isEqualToDate: [SCBlockDateUtilities blockEndDateInDictionary: defaults.dictionaryRepresentation]]);
    // should equal distantPast
    XCTAssert([foundBlockEndDate isEqualToDate: [NSDate distantPast]]);
    
    // Retrieve when block is disabled with old properties
    [defaults setValuesForKeysWithDictionary: disabledOldWayDict];
    foundBlockEndDate = [SCBlockDateUtilities blockEndDateInDefaults: defaults];
    // blockEndDateInDefaults and blockEndDateInDictionary *should* return the same thing
    XCTAssert([foundBlockEndDate isEqualToDate: [SCBlockDateUtilities blockEndDateInDictionary: defaults.dictionaryRepresentation]]);
    // should equal distantPast
    XCTAssert([foundBlockEndDate isEqualToDate: [NSDate distantPast]]);
    
    // Retrieve when defaults is completely clear
    [defaults setValuesForKeysWithDictionary: clearDict];
    foundBlockEndDate = [SCBlockDateUtilities blockEndDateInDefaults: defaults];
    // blockEndDateInDefaults and blockEndDateInDictionary *should* return the same thing
    XCTAssert([foundBlockEndDate isEqualToDate: [SCBlockDateUtilities blockEndDateInDictionary: defaults.dictionaryRepresentation]]);
    // should equal distantPast
    XCTAssert([foundBlockEndDate isEqualToDate: [NSDate distantPast]]);
}

@end
