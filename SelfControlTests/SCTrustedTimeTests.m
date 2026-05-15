#import <XCTest/XCTest.h>
#import "SCTrustedTime.h"
#import "SCPinnedHosts.h"

@interface SCTrustedTimeTests : XCTestCase
@end

@implementation SCTrustedTimeTests

- (void)testParseValidIMFFixdate {
    NSDate* d = [SCTrustedTime parseHTTPDateHeader: @"Tue, 14 May 2026 12:00:00 GMT"];
    XCTAssertNotNil(d);
    NSDateComponents* c = [[NSCalendar calendarWithIdentifier: NSCalendarIdentifierGregorian]
                            componentsInTimeZone: [NSTimeZone timeZoneWithAbbreviation: @"GMT"]
                            fromDate: d];
    XCTAssertEqual(c.year, 2026);
    XCTAssertEqual(c.month, 5);
    XCTAssertEqual(c.day, 14);
    XCTAssertEqual(c.hour, 12);
}

- (void)testParseGarbageReturnsNil {
    XCTAssertNil([SCTrustedTime parseHTTPDateHeader: @"not a date"]);
    XCTAssertNil([SCTrustedTime parseHTTPDateHeader: @""]);
    XCTAssertNil([SCTrustedTime parseHTTPDateHeader: nil]);
}

- (void)testFetchFromAppleWithCorrectPinReturnsDate {
    XCTestExpectation* exp = [self expectationWithDescription: @"apple"];
    NSDictionary* apple = [SCPinnedHosts hosts][0]; // assumes apple is index 0
    [SCTrustedTime fetchTimeFromHost: apple[@"host"]
                        expectedSPKI: apple[@"spki"]
                             timeout: 10.0
                          completion:^(NSDate* d, NSError* e) {
        XCTAssertNil(e);
        XCTAssertNotNil(d);
        XCTAssertLessThan(ABS([d timeIntervalSinceNow]), 120.0);
        [exp fulfill];
    }];
    [self waitForExpectations: @[exp] timeout: 15.0];
}

- (void)testFetchWithWrongPinFails {
    XCTestExpectation* exp = [self expectationWithDescription: @"badpin"];
    [SCTrustedTime fetchTimeFromHost: @"www.apple.com"
                        expectedSPKI: @"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
                             timeout: 10.0
                          completion:^(NSDate* d, NSError* e) {
        XCTAssertNotNil(e);
        XCTAssertNil(d);
        [exp fulfill];
    }];
    [self waitForExpectations: @[exp] timeout: 15.0];
}

- (void)testVerifyAfterPastThresholdSucceeds {
    XCTestExpectation* exp = [self expectationWithDescription: @"quorum"];
    NSDate* past = [NSDate dateWithTimeIntervalSinceNow: -3600];
    [SCTrustedTime verifyTimeIsAfter: past
                          completion:^(BOOL ok, NSDate* med, NSError* err) {
        XCTAssertTrue(ok);
        XCTAssertNotNil(med);
        [exp fulfill];
    }];
    [self waitForExpectations: @[exp] timeout: 25.0];
}

- (void)testVerifyAfterFutureThresholdFails {
    XCTestExpectation* exp = [self expectationWithDescription: @"future"];
    NSDate* future = [NSDate dateWithTimeIntervalSinceNow: 86400 * 365 * 10];
    [SCTrustedTime verifyTimeIsAfter: future
                          completion:^(BOOL ok, NSDate* med, NSError* err) {
        XCTAssertFalse(ok);
        [exp fulfill];
    }];
    [self waitForExpectations: @[exp] timeout: 25.0];
}

@end
