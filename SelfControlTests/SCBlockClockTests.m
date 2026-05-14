#import <XCTest/XCTest.h>
#import "SCBlockClock.h"
#import "SCSettings.h"

@interface SCBlockClockTests : XCTestCase
@end

@implementation SCBlockClockTests

- (void)setUp {
    [super setUp];
    [SCSettings sharedSettings].readOnly = NO;
    [[SCSettings sharedSettings] setValue: nil forKey: @"BlockTimekeeping"];
}

- (void)testRecordBlockStartPopulatesTimekeepingDict {
    NSDate* before = [NSDate date];
    [SCBlockClock recordBlockStartWithDuration: 600]; // 10 minutes
    NSDate* after = [NSDate date];

    NSDictionary* tk = [[SCSettings sharedSettings] valueForKey: @"BlockTimekeeping"];
    XCTAssertNotNil(tk);

    // Duration + initial elapsed
    XCTAssertEqualWithAccuracy([tk[@"blockDurationSeconds"] doubleValue], 600.0, 0.001);
    XCTAssertEqualWithAccuracy([tk[@"elapsedSecondsAccumulated"] doubleValue], 0.0, 0.001);

    // Wall-clock fields
    NSDate* startWall = tk[@"blockStartWallClock"];
    NSDate* lastWall  = tk[@"lastCheckpointWallClock"];
    XCTAssertNotNil(startWall);
    XCTAssertNotNil(lastWall);
    // Start wall-clock is now (within the time the call took)
    XCTAssertGreaterThanOrEqual([startWall timeIntervalSinceDate: before], -0.001);
    XCTAssertLessThanOrEqual([startWall timeIntervalSinceDate: after], 0.001);
    // Last checkpoint wall-clock equals start wall-clock at t=0
    XCTAssertEqualWithAccuracy([lastWall timeIntervalSinceDate: startWall], 0.0, 0.001);

    // Continuous-time fields
    XCTAssertNotNil(tk[@"blockStartContinuousTime"]);
    XCTAssertNotNil(tk[@"lastCheckpointContinuous"]);
    // Last checkpoint continuous equals start continuous at t=0
    XCTAssertEqualObjects(tk[@"blockStartContinuousTime"], tk[@"lastCheckpointContinuous"]);

    // Boot session ID present
    XCTAssertNotNil(tk[@"bootSessionUUID"]);
    XCTAssertGreaterThan([tk[@"bootSessionUUID"] length], 0);
}

- (void)testRecordBlockStartReplacesPriorDict {
    [SCBlockClock recordBlockStartWithDuration: 60];
    NSDictionary* first = [[[SCSettings sharedSettings] valueForKey: @"BlockTimekeeping"] copy];

    [NSThread sleepForTimeInterval: 0.05];
    [SCBlockClock recordBlockStartWithDuration: 120];
    NSDictionary* second = [[SCSettings sharedSettings] valueForKey: @"BlockTimekeeping"];

    XCTAssertEqualWithAccuracy([second[@"blockDurationSeconds"] doubleValue], 120.0, 0.001);
    // The second record should have a later start wall-clock than the first
    XCTAssertGreaterThan([second[@"blockStartWallClock"] timeIntervalSinceDate: first[@"blockStartWallClock"]], 0.0);
}

- (void)testTickAdvancesElapsedByTrustedDelta {
    [SCBlockClock recordBlockStartWithDuration: 600];
    [NSThread sleepForTimeInterval: 2.0];
    [SCBlockClock tickCheckpoint];

    NSTimeInterval elapsed = [SCBlockClock elapsedSecondsForCurrentBlock];
    XCTAssertGreaterThan(elapsed, 1.5);
    XCTAssertLessThan(elapsed, 3.0);
}

- (void)testElapsedIncludesInFlightSinceLastCheckpoint {
    [SCBlockClock recordBlockStartWithDuration: 600];
    NSTimeInterval immediate = [SCBlockClock elapsedSecondsForCurrentBlock];
    XCTAssertLessThan(immediate, 0.5);
    [NSThread sleepForTimeInterval: 1.0];
    NSTimeInterval later = [SCBlockClock elapsedSecondsForCurrentBlock];
    XCTAssertGreaterThan(later, 0.8);
}

- (void)testBlockDurationHasElapsedFalseInitiallyTrueAfterDuration {
    [SCBlockClock recordBlockStartWithDuration: 1];
    XCTAssertFalse([SCBlockClock blockDurationHasElapsed]);
    [NSThread sleepForTimeInterval: 1.2];
    [SCBlockClock tickCheckpoint];
    XCTAssertTrue([SCBlockClock blockDurationHasElapsed]);
}

- (void)testTickClampsAgainstForwardWallClockJump {
    [SCBlockClock recordBlockStartWithDuration: 600];
    [NSThread sleepForTimeInterval: 0.5];

    // Simulate sudo date +1hour by pushing lastCheckpointWallClock 1 hour into the past.
    // From tickCheckpoint's POV, deltaWall will be ~1 hour but deltaCont will be ~0.5s.
    NSMutableDictionary* tk = [[[SCSettings sharedSettings] valueForKey: @"BlockTimekeeping"] mutableCopy];
    tk[@"lastCheckpointWallClock"] = [NSDate dateWithTimeIntervalSinceNow: -3600.0];
    [[SCSettings sharedSettings] setValue: tk forKey: @"BlockTimekeeping"];

    [SCBlockClock tickCheckpoint];
    NSTimeInterval elapsed = [SCBlockClock elapsedSecondsForCurrentBlock];
    XCTAssertLessThan(elapsed, 5.0); // not 1 hour — clamped to monotonic delta
}

@end
