#import <XCTest/XCTest.h>
#import "SCTrustedTime.h"

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

@end
