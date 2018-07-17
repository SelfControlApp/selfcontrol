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

@implementation BlockDateUtilitiesTests

- (NSUserDefaults*)testDefaults {
    return [[NSUserDefaults alloc] initWithSuiteName: @"BlockDateUtilitiesTests"];
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
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    NSUserDefaults* defaults = [self testDefaults];
    
    // Enabled + active old way (started 5 minutes ago, duration 10 min)
    [defaults setValuesForKeysWithDictionary: @{
                                                           @"BlockStartedDate": [NSDate dateWithTimeIntervalSinceNow: -300],
                                                           @"BlockDuration": @10,
                                                           @"BlockEndDate": [NSNull null]
                                                           }];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Enabled + inactive old way (started 10 minutes 5 seconds ago, duration 10 min)
    [defaults setValuesForKeysWithDictionary: @{
                                                @"BlockStartedDate": [NSDate dateWithTimeIntervalSinceNow: -605],
                                                @"BlockDuration": @10,
                                                @"BlockEndDate": [NSNull null]
                                                }];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Disabled old way
    [defaults setValuesForKeysWithDictionary: @{
                                                @"BlockStartedDate": [NSDate distantFuture],
                                                @"BlockDuration": @10,
                                                @"BlockEndDate": [NSNull null]
                                                }];
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Enabled + active new way (started 5 minutes ago, duration 10 min)
    [defaults setValuesForKeysWithDictionary: @{
                                                @"BlockStartedDate": [NSNull null],
                                                @"BlockDuration": @10,
                                                @"BlockEndDate": [NSDate dateWithTimeIntervalSinceNow: 300]
                                                }];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Enabled + inactive new way (started 10 minutes 5 seconds ago, duration 10 min)
    [defaults setValuesForKeysWithDictionary: @{
                                                @"BlockStartedDate": [NSNull null],
                                                @"BlockDuration": @10,
                                                @"BlockEndDate": [NSDate dateWithTimeIntervalSinceNow: -5]
                                                }];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Enabled + active new way, but with old values showing conflicting info
    [defaults setValuesForKeysWithDictionary: @{
                                                @"BlockStartedDate": [NSDate dateWithTimeIntervalSinceNow: -605],
                                                @"BlockDuration": @10,
                                                @"BlockEndDate": [NSDate dateWithTimeIntervalSinceNow: 300]
                                                }];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Disabled new way
    [defaults setValuesForKeysWithDictionary: @{
                                                @"BlockStartedDate": [NSNull null],
                                                @"BlockDuration": @10,
                                                @"BlockEndDate": [NSDate distantPast]
                                                }];
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    
    // Disabled new way, but enabled/active  via the old way
    [defaults setValuesForKeysWithDictionary: @{
                                                @"BlockStartedDate": [NSDate dateWithTimeIntervalSinceNow: -300],
                                                @"BlockDuration": @10,
                                                @"BlockEndDate": [NSDate distantPast]
                                                }];
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert([SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
    

    // Completely clear
    [defaults setValuesForKeysWithDictionary: @{
                                                @"BlockEndDate": [NSNull null],
                                                @"BlockStartedDate": [NSNull null],
                                                @"BlockDuration": [NSNull null]
                                                }];
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsEnabledInDictionary: defaults.dictionaryRepresentation]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDefaults: defaults]);
    XCTAssert(![SCBlockDateUtilities blockIsActiveInDictionary: defaults.dictionaryRepresentation]);
}

@end
