# Tamper-Resistant Block Timing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the `sudo date` bypass (and similar casual tampering) so a block cannot end early.

**Architecture:** Three-layer time gate. (1) `mach_continuous_time()` monotonic counter, (2) a per-30-second on-disk checkpoint that survives reboot, (3) a pinned HTTPS time check (Apple/Google/Cloudflare `Date` header) at unlock. The block can only end when all three agree. UI tells the user when we are waiting on the internet check.

**Tech Stack:** Objective-C / macOS, Foundation `URLSession` for HTTPS, `XCTest`, settings persisted via existing `SCSettings` plist at `/usr/local/etc/`.

**Spec:** `docs/superpowers/specs/2026-05-14-tamper-resistant-timing-design.md`

---

## File Structure

**New files:**
- `Common/Utility/SCBlockClock.h` / `.m` — monotonic counter math + checkpoint persistence + reboot handling. One responsibility: "how much real time has elapsed since block start?"
- `Common/Utility/SCTrustedTime.h` / `.m` — pinned HTTPS time check. One responsibility: "what time does the trusted internet say it is?"
- `Common/Utility/SCPinnedHosts.h` — baked-in `(host, SPKI-SHA256)` tuples.
- `SelfControlTests/SCBlockClockTests.m` — XCTest for the clock.
- `SelfControlTests/SCTrustedTimeTests.m` — XCTest for the pinning + parser.

**Modified files:**
- `Common/SCSettings.m` — register defaults for new `BlockTimekeeping` dictionary key.
- `Common/Utility/SCBlockUtilities.h` / `.m` — replace single-signal `currentBlockIsExpired` with a three-signal `currentBlockIsTrulyExpired` method that consults `SCBlockClock` + `BlockEndDate`. The old method stays for transitional callers; it now returns the *less strict* answer.
- `Daemon/SCDaemonBlockMethods.m` — `startBlock` records `[SCBlockClock recordBlockStart...]`; `checkupBlock` uses the new gate and the trusted-time check.
- `Daemon/SCDaemon.m` / `.h` — add `startCheckpointTimer` / `stopCheckpointTimer` (30 s) and an unlock-attempt backoff state.
- `Daemon/SCDaemonProtocol.h`, `Common/SCXPCClient.h` / `.m` — add `getBlockUnlockGateStateWithReply:` so the app UI can read whether we are waiting on the internet check.
- `TimerWindowController.m` — when the gate state reports `waitingForNetworkVerification == YES`, swap the timer label for the "waiting for internet" copy.

**Why one file per piece:** the clock math and the network check have no overlap. Splitting them means each unit can be unit-tested in isolation, and a future change to (say) the pinning list does not need to touch the clock code.

---

## Conventions

- **Language:** Objective-C, ARC enabled, matching the rest of the codebase.
- **Tests:** `XCTest`, run via `xcodebuild test -workspace SelfControl.xcworkspace -scheme SelfControl -destination 'platform=macOS'` (the existing way). The test target is `SelfControlTests`.
- **Commits:** one per task. Conventional Commits style (`feat:`, `test:`, `refactor:`) matching prior repo history.
- **Adding files to Xcode:** every new source file must be added to the correct target in `SelfControl.xcodeproj`. Each task that creates a new file ends with a manual step: "Add the new file to the SelfControl target *and* the SelfControlTests target (if a test file) via Xcode's File → Add Files…, then commit `project.pbxproj`."

---

## Task 1: SCBlockClock skeleton + record block start

**Files:**
- Create: `Common/Utility/SCBlockClock.h`
- Create: `Common/Utility/SCBlockClock.m`
- Create: `SelfControlTests/SCBlockClockTests.m`

**Goal:** establish the class. `+recordBlockStartWithDuration:` writes a fresh `BlockTimekeeping` dict into `SCSettings` containing the monotonic counter value, wall-clock start, boot UUID, and zero elapsed.

- [ ] **Step 1: Write the failing test**

Create `SelfControlTests/SCBlockClockTests.m`:

```objc
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
    [SCBlockClock recordBlockStartWithDuration: 600]; // 10 minutes

    NSDictionary* tk = [[SCSettings sharedSettings] valueForKey: @"BlockTimekeeping"];
    XCTAssertNotNil(tk);
    XCTAssertEqualWithAccuracy([tk[@"blockDurationSeconds"] doubleValue], 600.0, 0.001);
    XCTAssertNotNil(tk[@"blockStartWallClock"]);
    XCTAssertNotNil(tk[@"blockStartContinuousTime"]);
    XCTAssertNotNil(tk[@"bootSessionUUID"]);
    XCTAssertEqualWithAccuracy([tk[@"elapsedSecondsAccumulated"] doubleValue], 0.0, 0.001);
}

@end
```

- [ ] **Step 2: Run the test, confirm it fails to compile**

Run: `xcodebuild test -workspace SelfControl.xcworkspace -scheme SelfControl -destination 'platform=macOS' -only-testing:SelfControlTests/SCBlockClockTests`

Expected: build error — `SCBlockClock.h` not found.

- [ ] **Step 3: Create the header**

Create `Common/Utility/SCBlockClock.h`:

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Tamper-resistant block-elapsed-time accounting.
/// Combines mach_continuous_time() with a periodic on-disk checkpoint so that
/// changing the system clock with `sudo date` cannot end a block early.
@interface SCBlockClock : NSObject

/// Called once at block start. Writes the BlockTimekeeping dictionary into SCSettings.
+ (void)recordBlockStartWithDuration:(NSTimeInterval)durationSeconds;

/// Called every ~30 s by the daemon. Updates elapsedSecondsAccumulated and the
/// last-checkpoint values, using the smaller of the wall-clock delta and the
/// monotonic delta. A negative wall-clock delta credits zero.
+ (void)tickCheckpoint;

/// Total real seconds elapsed since the block started. Returns 0 if no block.
+ (NSTimeInterval)elapsedSecondsForCurrentBlock;

/// YES iff elapsedSecondsForCurrentBlock >= the recorded duration.
+ (BOOL)blockDurationHasElapsed;

@end

NS_ASSUME_NONNULL_END
```

- [ ] **Step 4: Create the minimal implementation**

Create `Common/Utility/SCBlockClock.m`:

```objc
#import "SCBlockClock.h"
#import "SCSettings.h"
#import <mach/mach_time.h>
#import <sys/sysctl.h>

static NSString* const kTKKey = @"BlockTimekeeping";

@implementation SCBlockClock

+ (NSString*)currentBootSessionUUID {
    struct timeval boottime;
    size_t size = sizeof(boottime);
    if (sysctlbyname("kern.boottime", &boottime, &size, NULL, 0) != 0) {
        return @"unknown";
    }
    return [NSString stringWithFormat: @"%ld.%d", (long)boottime.tv_sec, boottime.tv_usec];
}

+ (uint64_t)continuousNanos {
    return mach_continuous_time();
}

+ (void)recordBlockStartWithDuration:(NSTimeInterval)durationSeconds {
    NSDate* now = [NSDate date];
    uint64_t cont = [self continuousNanos];
    NSDictionary* tk = @{
        @"blockStartWallClock":       now,
        @"blockStartContinuousTime":  @(cont),
        @"bootSessionUUID":           [self currentBootSessionUUID],
        @"blockDurationSeconds":      @(durationSeconds),
        @"elapsedSecondsAccumulated": @(0.0),
        @"lastCheckpointWallClock":   now,
        @"lastCheckpointContinuous":  @(cont),
    };
    [[SCSettings sharedSettings] setValue: tk forKey: kTKKey];
}

+ (void)tickCheckpoint { /* implemented in Task 2 */ }
+ (NSTimeInterval)elapsedSecondsForCurrentBlock { return 0.0; /* Task 2 */ }
+ (BOOL)blockDurationHasElapsed { return NO; /* Task 2 */ }

@end
```

- [ ] **Step 5: Add both new files to the Xcode targets**

Open `SelfControl.xcworkspace` in Xcode. File → Add Files…:
- Add `Common/Utility/SCBlockClock.h` and `.m` to the **SelfControl** target *and* the **org.eyebeam.selfcontrold** (daemon) target. (Both targets need the class.)
- Add `SelfControlTests/SCBlockClockTests.m` to the **SelfControlTests** target only.

- [ ] **Step 6: Run the test, confirm it passes**

Run: `xcodebuild test -workspace SelfControl.xcworkspace -scheme SelfControl -destination 'platform=macOS' -only-testing:SelfControlTests/SCBlockClockTests/testRecordBlockStartPopulatesTimekeepingDict`
Expected: 1 test, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add Common/Utility/SCBlockClock.h Common/Utility/SCBlockClock.m SelfControlTests/SCBlockClockTests.m SelfControl.xcodeproj/project.pbxproj
git commit -m "feat: add SCBlockClock with recordBlockStart"
```

---

## Task 2: Same-boot checkpoint accounting

**Files:**
- Modify: `Common/Utility/SCBlockClock.m`
- Modify: `SelfControlTests/SCBlockClockTests.m`

**Goal:** `tickCheckpoint` increments `elapsedSecondsAccumulated` by `min(deltaContinuous, max(0, deltaWall))`. `elapsedSecondsForCurrentBlock` returns the accumulated total plus the in-flight delta since the last checkpoint.

- [ ] **Step 1: Write the failing test**

Append to `SelfControlTests/SCBlockClockTests.m` inside `@implementation`:

```objc
- (void)testTickAdvancesElapsedByTrustedDelta {
    [SCBlockClock recordBlockStartWithDuration: 600];

    // Simulate 2 seconds of real time. The simplest way: sleep.
    [NSThread sleepForTimeInterval: 2.0];
    [SCBlockClock tickCheckpoint];

    NSTimeInterval elapsed = [SCBlockClock elapsedSecondsForCurrentBlock];
    XCTAssertGreaterThan(elapsed, 1.5);
    XCTAssertLessThan(elapsed, 3.0);
}

- (void)testElapsedIncludesInFlightSinceLastCheckpoint {
    [SCBlockClock recordBlockStartWithDuration: 600];
    NSTimeInterval immediate = [SCBlockClock elapsedSecondsForCurrentBlock];
    XCTAssertLessThan(immediate, 0.5); // no checkpoint yet, but barely any time
    [NSThread sleepForTimeInterval: 1.0];
    NSTimeInterval later = [SCBlockClock elapsedSecondsForCurrentBlock];
    XCTAssertGreaterThan(later, 0.8);
}

- (void)testBlockDurationHasElapsedFalseInitiallyTrueAfterDuration {
    [SCBlockClock recordBlockStartWithDuration: 1]; // 1 second
    XCTAssertFalse([SCBlockClock blockDurationHasElapsed]);
    [NSThread sleepForTimeInterval: 1.2];
    [SCBlockClock tickCheckpoint];
    XCTAssertTrue([SCBlockClock blockDurationHasElapsed]);
}
```

- [ ] **Step 2: Run, confirm failures**

Run the three tests. Expected: all fail (`tickCheckpoint` is a no-op, `elapsedSecondsForCurrentBlock` returns 0).

- [ ] **Step 3: Replace the stubs in `SCBlockClock.m`**

```objc
+ (NSDictionary*)readTK {
    return [[SCSettings sharedSettings] valueForKey: kTKKey];
}

+ (void)writeTK:(NSDictionary*)tk {
    [[SCSettings sharedSettings] setValue: tk forKey: kTKKey];
}

+ (NSTimeInterval)inFlightDeltaFromTK:(NSDictionary*)tk {
    NSDate* lastWall = tk[@"lastCheckpointWallClock"];
    uint64_t lastCont = [tk[@"lastCheckpointContinuous"] unsignedLongLongValue];

    NSTimeInterval deltaWall = [[NSDate date] timeIntervalSinceDate: lastWall];
    NSTimeInterval deltaCont = ([self continuousNanos] - lastCont) / 1e9;

    NSTimeInterval trustedDelta = MIN(deltaCont, MAX(0.0, deltaWall));
    if (trustedDelta < 0) trustedDelta = 0;
    return trustedDelta;
}

+ (void)tickCheckpoint {
    NSDictionary* tk = [self readTK];
    if (tk == nil) return;

    // Same-boot guard: if the bootSessionUUID changed, the cross-boot path
    // in Task 3 handles it. For now we assume same boot.
    if (![tk[@"bootSessionUUID"] isEqualToString: [self currentBootSessionUUID]]) {
        // handled in Task 3
        return;
    }

    NSTimeInterval trustedDelta = [self inFlightDeltaFromTK: tk];
    NSTimeInterval newAccum = [tk[@"elapsedSecondsAccumulated"] doubleValue] + trustedDelta;

    NSMutableDictionary* updated = [tk mutableCopy];
    updated[@"elapsedSecondsAccumulated"] = @(newAccum);
    updated[@"lastCheckpointWallClock"]   = [NSDate date];
    updated[@"lastCheckpointContinuous"]  = @([self continuousNanos]);
    [self writeTK: updated];
}

+ (NSTimeInterval)elapsedSecondsForCurrentBlock {
    NSDictionary* tk = [self readTK];
    if (tk == nil) return 0.0;
    if (![tk[@"bootSessionUUID"] isEqualToString: [self currentBootSessionUUID]]) {
        // cross-boot — wait for tickCheckpoint to reconcile (Task 3)
        return [tk[@"elapsedSecondsAccumulated"] doubleValue];
    }
    return [tk[@"elapsedSecondsAccumulated"] doubleValue] + [self inFlightDeltaFromTK: tk];
}

+ (BOOL)blockDurationHasElapsed {
    NSDictionary* tk = [self readTK];
    if (tk == nil) return NO;
    return [self elapsedSecondsForCurrentBlock] >= [tk[@"blockDurationSeconds"] doubleValue];
}
```

- [ ] **Step 4: Run, confirm pass**

Run all `SCBlockClockTests`. Expected: 4/4 pass.

- [ ] **Step 5: Commit**

```bash
git add Common/Utility/SCBlockClock.m SelfControlTests/SCBlockClockTests.m
git commit -m "feat(blockclock): same-boot checkpoint accounting"
```

---

## Task 3: Reboot handling

**Files:**
- Modify: `Common/Utility/SCBlockClock.h` / `.m`
- Modify: `SelfControlTests/SCBlockClockTests.m`

**Goal:** Detect a boot-session-UUID change. On the first tick after a reboot, credit `max(0, now - lastCheckpointWallClock)` as elapsed time (treating reboot gap as honest wall-clock time), then reset the boot session.

We cannot literally reboot in a unit test, so we add a *test-only* hook to override the boot UUID.

- [ ] **Step 1: Add a testing hook to the header**

Append to `Common/Utility/SCBlockClock.h` before `@end`:

```objc
#ifdef DEBUG
/// Test-only override. Pass nil to clear.
+ (void)setBootSessionUUIDOverrideForTesting:(nullable NSString*)uuid;
#endif
```

- [ ] **Step 2: Implement the override in `SCBlockClock.m`**

Add at file top (below imports):

```objc
static NSString* sBootUUIDOverride = nil;
```

Modify `currentBootSessionUUID`:

```objc
+ (NSString*)currentBootSessionUUID {
    if (sBootUUIDOverride != nil) return sBootUUIDOverride;
    struct timeval boottime;
    size_t size = sizeof(boottime);
    if (sysctlbyname("kern.boottime", &boottime, &size, NULL, 0) != 0) {
        return @"unknown";
    }
    return [NSString stringWithFormat: @"%ld.%d", (long)boottime.tv_sec, boottime.tv_usec];
}

#ifdef DEBUG
+ (void)setBootSessionUUIDOverrideForTesting:(NSString*)uuid {
    sBootUUIDOverride = [uuid copy];
}
#endif
```

- [ ] **Step 3: Write the failing test**

Append to `SCBlockClockTests.m`:

```objc
- (void)testRebootCreditsWallClockGap {
    [SCBlockClock setBootSessionUUIDOverrideForTesting: @"BOOT_A"];
    [SCBlockClock recordBlockStartWithDuration: 600];
    [NSThread sleepForTimeInterval: 0.5];
    [SCBlockClock tickCheckpoint]; // accumulate ~0.5 s under BOOT_A

    // Simulate reboot: bump boot UUID, force wall clock forward by rewriting
    // lastCheckpointWallClock to 60 s ago.
    [SCBlockClock setBootSessionUUIDOverrideForTesting: @"BOOT_B"];
    NSMutableDictionary* tk = [[[SCSettings sharedSettings] valueForKey: @"BlockTimekeeping"] mutableCopy];
    tk[@"lastCheckpointWallClock"] = [NSDate dateWithTimeIntervalSinceNow: -60.0];
    [[SCSettings sharedSettings] setValue: tk forKey: @"BlockTimekeeping"];

    [SCBlockClock tickCheckpoint]; // should credit ~60 s of reboot gap
    NSTimeInterval elapsed = [SCBlockClock elapsedSecondsForCurrentBlock];
    XCTAssertGreaterThan(elapsed, 55.0);
    XCTAssertLessThan(elapsed, 65.0);
}

- (void)testRebootWithBackwardWallClockCreditsZero {
    [SCBlockClock setBootSessionUUIDOverrideForTesting: @"BOOT_A"];
    [SCBlockClock recordBlockStartWithDuration: 600];
    [NSThread sleepForTimeInterval: 0.5];
    [SCBlockClock tickCheckpoint];

    NSTimeInterval accumBeforeReboot = [SCBlockClock elapsedSecondsForCurrentBlock];

    [SCBlockClock setBootSessionUUIDOverrideForTesting: @"BOOT_B"];
    NSMutableDictionary* tk = [[[SCSettings sharedSettings] valueForKey: @"BlockTimekeeping"] mutableCopy];
    tk[@"lastCheckpointWallClock"] = [NSDate dateWithTimeIntervalSinceNow: +60.0]; // future
    [[SCSettings sharedSettings] setValue: tk forKey: @"BlockTimekeeping"];

    [SCBlockClock tickCheckpoint];
    NSTimeInterval elapsedAfter = [SCBlockClock elapsedSecondsForCurrentBlock];
    XCTAssertEqualWithAccuracy(elapsedAfter, accumBeforeReboot, 1.0); // no extra credit
}

- (void)tearDown {
    [SCBlockClock setBootSessionUUIDOverrideForTesting: nil];
    [super tearDown];
}
```

- [ ] **Step 4: Run, confirm failures**

Both new tests fail because `tickCheckpoint` short-circuits on a UUID mismatch.

- [ ] **Step 5: Update `tickCheckpoint` to handle the cross-boot case**

Replace the "handled in Task 3" comment with:

```objc
if (![tk[@"bootSessionUUID"] isEqualToString: [self currentBootSessionUUID]]) {
    NSTimeInterval gapWall = [[NSDate date] timeIntervalSinceDate: tk[@"lastCheckpointWallClock"]];
    NSTimeInterval credit = MAX(0.0, gapWall);
    NSTimeInterval newAccum = [tk[@"elapsedSecondsAccumulated"] doubleValue] + credit;

    NSMutableDictionary* updated = [tk mutableCopy];
    updated[@"elapsedSecondsAccumulated"] = @(newAccum);
    updated[@"lastCheckpointWallClock"]   = [NSDate date];
    updated[@"lastCheckpointContinuous"]  = @([self continuousNanos]);
    updated[@"bootSessionUUID"]           = [self currentBootSessionUUID];
    [self writeTK: updated];
    return;
}
```

- [ ] **Step 6: Run, confirm pass**

All 6 `SCBlockClockTests` should pass.

- [ ] **Step 7: Commit**

```bash
git add Common/Utility/SCBlockClock.h Common/Utility/SCBlockClock.m SelfControlTests/SCBlockClockTests.m
git commit -m "feat(blockclock): cross-boot reboot accounting"
```

---

## Task 4: Backward-clock detection while running

**Files:**
- Modify: `SelfControlTests/SCBlockClockTests.m`

**Goal:** Verify the `min(deltaContinuous, max(0, deltaWall))` rule actually credits zero when the wall clock moves backward while the daemon is running.

No production code changes — this just locks down behavior already implemented in Task 2.

- [ ] **Step 1: Write the test**

Append:

```objc
- (void)testBackwardWallClockCreditsAtMostMonotonic {
    [SCBlockClock recordBlockStartWithDuration: 600];
    [NSThread sleepForTimeInterval: 0.5];
    [SCBlockClock tickCheckpoint];
    NSTimeInterval before = [SCBlockClock elapsedSecondsForCurrentBlock];

    // Move lastCheckpointWallClock to 1 hour in the future to simulate
    // sudo date -1hour having moved "now" backward relative to it.
    NSMutableDictionary* tk = [[[SCSettings sharedSettings] valueForKey: @"BlockTimekeeping"] mutableCopy];
    tk[@"lastCheckpointWallClock"] = [NSDate dateWithTimeIntervalSinceNow: +3600.0];
    [[SCSettings sharedSettings] setValue: tk forKey: @"BlockTimekeeping"];

    [SCBlockClock tickCheckpoint];
    NSTimeInterval after = [SCBlockClock elapsedSecondsForCurrentBlock];
    // The wall delta is negative; trustedDelta must be 0.
    XCTAssertEqualWithAccuracy(after, before, 1.0);
}
```

- [ ] **Step 2: Run, confirm pass**

This should already pass thanks to Task 2's `MAX(0.0, deltaWall)`.

- [ ] **Step 3: Commit**

```bash
git add SelfControlTests/SCBlockClockTests.m
git commit -m "test(blockclock): lock down backward-wall-clock behavior"
```

---

## Task 5: SCTrustedTime — HTTP Date header parsing

**Files:**
- Create: `Common/Utility/SCTrustedTime.h` / `.m`
- Create: `SelfControlTests/SCTrustedTimeTests.m`

**Goal:** Pure function `+ (NSDate*)parseHTTPDateHeader:(NSString*)header`. No networking yet.

- [ ] **Step 1: Write the failing tests**

`SelfControlTests/SCTrustedTimeTests.m`:

```objc
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
```

- [ ] **Step 2: Run, confirm build failure**

Expected: `SCTrustedTime.h` not found.

- [ ] **Step 3: Create header + impl**

`Common/Utility/SCTrustedTime.h`:

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCTrustedTime : NSObject

/// Parses an HTTP IMF-fixdate (RFC 7231 §7.1.1.1). Returns nil on any error.
+ (nullable NSDate*)parseHTTPDateHeader:(nullable NSString*)header;

@end

NS_ASSUME_NONNULL_END
```

`Common/Utility/SCTrustedTime.m`:

```objc
#import "SCTrustedTime.h"

@implementation SCTrustedTime

+ (NSDateFormatter*)imfFormatter {
    static NSDateFormatter* f = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        f = [[NSDateFormatter alloc] init];
        f.locale = [NSLocale localeWithLocaleIdentifier: @"en_US_POSIX"];
        f.timeZone = [NSTimeZone timeZoneWithAbbreviation: @"GMT"];
        f.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss zzz";
    });
    return f;
}

+ (NSDate*)parseHTTPDateHeader:(NSString*)header {
    if (header.length == 0) return nil;
    return [[self imfFormatter] dateFromString: header];
}

@end
```

- [ ] **Step 4: Add the three new files to the right Xcode targets**

- `SCTrustedTime.h`/`.m` → **SelfControl** target *and* daemon target.
- `SCTrustedTimeTests.m` → **SelfControlTests** only.

- [ ] **Step 5: Run, confirm pass**

Run `-only-testing:SelfControlTests/SCTrustedTimeTests`. Expected: 2/2 pass.

- [ ] **Step 6: Commit**

```bash
git add Common/Utility/SCTrustedTime.h Common/Utility/SCTrustedTime.m SelfControlTests/SCTrustedTimeTests.m SelfControl.xcodeproj/project.pbxproj
git commit -m "feat: SCTrustedTime HTTP Date parser"
```

---

## Task 6: SCPinnedHosts constants

**Files:**
- Create: `Common/Utility/SCPinnedHosts.h`

**Goal:** Provide the baked-in `(host, expected SPKI SHA-256)` tuples used by the pinned URLSession delegate. The hashes are computed once by hand and committed.

- [ ] **Step 1: Compute the SPKI hashes**

For each host, run:

```bash
for host in www.apple.com www.google.com www.cloudflare.com; do
  echo "=== $host ==="
  openssl s_client -connect "$host:443" -servername "$host" </dev/null 2>/dev/null \
    | openssl x509 -pubkey -noout \
    | openssl pkey -pubin -outform der \
    | openssl dgst -sha256 -binary \
    | openssl enc -base64
done
```

Record the three base64 outputs. **Note:** these hashes change when the host rotates its key. The "Open questions" section of the spec acknowledges this; for now we pin the leaf SPKI. A future task can add intermediate-CA pinning for durability.

- [ ] **Step 2: Create the header**

`Common/Utility/SCPinnedHosts.h`:

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// (host, base64 SHA-256 of SubjectPublicKeyInfo of leaf cert).
extern NSArray<NSDictionary<NSString*, NSString*>*>* const SCPinnedHosts;

NS_ASSUME_NONNULL_END
```

Create `Common/Utility/SCPinnedHosts.m` (so the constant has a definition site — header-only `extern` won't link):

```objc
#import "SCPinnedHosts.h"

NSArray<NSDictionary<NSString*, NSString*>*>* const SCPinnedHosts = @[
    @{ @"host": @"www.apple.com",      @"spki": @"<paste base64 hash from Step 1>" },
    @{ @"host": @"www.google.com",     @"spki": @"<paste base64 hash from Step 1>" },
    @{ @"host": @"www.cloudflare.com", @"spki": @"<paste base64 hash from Step 1>" },
];
```

- [ ] **Step 3: Add to Xcode targets**

Both SelfControl and daemon target.

- [ ] **Step 4: Commit**

```bash
git add Common/Utility/SCPinnedHosts.h Common/Utility/SCPinnedHosts.m SelfControl.xcodeproj/project.pbxproj
git commit -m "feat: bake in SPKI pins for trusted time hosts"
```

---

## Task 7: SCTrustedTime — pinned URLSession single-host fetch

**Files:**
- Modify: `Common/Utility/SCTrustedTime.h` / `.m`
- Modify: `SelfControlTests/SCTrustedTimeTests.m`

**Goal:** `+ (void)fetchTimeFromHost:(NSString*)host expectedSPKI:(NSString*)spki completion:(...)` — does a HEAD request, validates the SPKI pin in the URLSession delegate, hands back `(NSDate*, NSError*)`.

The unit test pins against the real Apple cert. This test requires real internet during CI, which is acceptable for a single integration test.

- [ ] **Step 1: Extend the header**

```objc
typedef void (^SCTrustedTimeCompletion)(NSDate* _Nullable verifiedTime, NSError* _Nullable error);

/// Fetches https://<host>/ HEAD and returns the time from the Date: header
/// IFF the server's leaf SubjectPublicKeyInfo SHA-256 (base64) matches expectedSPKI.
+ (void)fetchTimeFromHost:(NSString*)host
             expectedSPKI:(NSString*)spki
                  timeout:(NSTimeInterval)timeoutSeconds
               completion:(SCTrustedTimeCompletion)completion;
```

- [ ] **Step 2: Write the failing test**

```objc
- (void)testFetchFromAppleWithCorrectPinReturnsDate {
    XCTestExpectation* exp = [self expectationWithDescription: @"apple"];
    NSDictionary* apple = SCPinnedHosts[0]; // assumes index 0 is apple
    [SCTrustedTime fetchTimeFromHost: apple[@"host"]
                        expectedSPKI: apple[@"spki"]
                             timeout: 10.0
                          completion:^(NSDate* d, NSError* e) {
        XCTAssertNil(e);
        XCTAssertNotNil(d);
        XCTAssertLessThan(ABS([d timeIntervalSinceNow]), 120.0); // server time within 2 min of ours
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
```

Add to imports: `#import "SCPinnedHosts.h"`.

- [ ] **Step 3: Run, confirm failures**

Both tests fail — method doesn't exist.

- [ ] **Step 4: Implement the pinned fetch**

Add to `SCTrustedTime.m`:

```objc
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>

@interface SCTrustedTimePinningDelegate : NSObject <NSURLSessionDelegate>
@property (copy) NSString* expectedSPKI;
@end

@implementation SCTrustedTimePinningDelegate

- (void)URLSession:(NSURLSession*)session
didReceiveChallenge:(NSURLAuthenticationChallenge*)challenge
 completionHandler:(void(^)(NSURLSessionAuthChallengeDisposition, NSURLCredential* _Nullable))ch
{
    if (![challenge.protectionSpace.authenticationMethod isEqualToString: NSURLAuthenticationMethodServerTrust]) {
        ch(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }
    SecTrustRef trust = challenge.protectionSpace.serverTrust;
    if (trust == NULL) { ch(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil); return; }

    CFIndex count = SecTrustGetCertificateCount(trust);
    BOOL matched = NO;
    for (CFIndex i = 0; i < count && !matched; i++) {
        SecCertificateRef cert = SecTrustGetCertificateAtIndex(trust, i);
        SecKeyRef pubkey = SecCertificateCopyKey(cert);
        if (pubkey == NULL) continue;
        CFErrorRef err = NULL;
        CFDataRef der = SecKeyCopyExternalRepresentation(pubkey, &err);
        CFRelease(pubkey);
        if (der == NULL) continue;
        unsigned char digest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(CFDataGetBytePtr(der), (CC_LONG)CFDataGetLength(der), digest);
        NSData* digestData = [NSData dataWithBytes: digest length: CC_SHA256_DIGEST_LENGTH];
        NSString* b64 = [digestData base64EncodedStringWithOptions: 0];
        CFRelease(der);
        if ([b64 isEqualToString: self.expectedSPKI]) matched = YES;
    }

    if (matched) {
        ch(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust: trust]);
    } else {
        ch(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
    }
}

@end


+ (void)fetchTimeFromHost:(NSString*)host
             expectedSPKI:(NSString*)spki
                  timeout:(NSTimeInterval)timeoutSeconds
               completion:(SCTrustedTimeCompletion)completion
{
    SCTrustedTimePinningDelegate* d = [SCTrustedTimePinningDelegate new];
    d.expectedSPKI = spki;
    NSURLSessionConfiguration* cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = timeoutSeconds;
    NSURLSession* session = [NSURLSession sessionWithConfiguration: cfg delegate: d delegateQueue: nil];

    NSURL* url = [NSURL URLWithString: [NSString stringWithFormat: @"https://%@/", host]];
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL: url];
    req.HTTPMethod = @"HEAD";

    [[session dataTaskWithRequest: req completionHandler:^(NSData* data, NSURLResponse* resp, NSError* error) {
        [session finishTasksAndInvalidate];
        if (error) { completion(nil, error); return; }
        NSHTTPURLResponse* http = (NSHTTPURLResponse*)resp;
        NSString* dateStr = http.allHeaderFields[@"Date"];
        NSDate* parsed = [SCTrustedTime parseHTTPDateHeader: dateStr];
        if (parsed == nil) {
            completion(nil, [NSError errorWithDomain: @"SCTrustedTime" code: 1
                                            userInfo: @{NSLocalizedDescriptionKey: @"No/invalid Date header"}]);
            return;
        }
        completion(parsed, nil);
    }] resume];
}
```

- [ ] **Step 5: Run, confirm pass**

Both tests should pass given internet. (CI without internet → testFetchFromAppleWithCorrectPinReturnsDate will fail; that is expected and the CI config in this repo's `config.yml` already accepts an offline run when needed. If you must run offline, mark it `XCTSkipIf` instead of removing.)

- [ ] **Step 6: Commit**

```bash
git add Common/Utility/SCTrustedTime.h Common/Utility/SCTrustedTime.m SelfControlTests/SCTrustedTimeTests.m
git commit -m "feat(trustedtime): pinned HEAD fetch with SPKI verification"
```

---

## Task 8: SCTrustedTime — multi-host quorum

**Files:**
- Modify: `Common/Utility/SCTrustedTime.h` / `.m`
- Modify: `SelfControlTests/SCTrustedTimeTests.m`

**Goal:** `+ (void)verifyTimeIsAfter:(NSDate*)threshold completion:(...)` — query all pinned hosts in parallel; succeed iff ≥2 hosts return successfully and all returned times are after `threshold` and within 5 minutes of each other.

- [ ] **Step 1: Extend the header**

```objc
typedef void (^SCTrustedTimeQuorumCompletion)(BOOL verified, NSDate* _Nullable medianTime, NSError* _Nullable error);

/// Returns verified=YES iff at least 2 pinned hosts respond, all responses are
/// within 5 minutes of each other, and the median response is >= threshold.
+ (void)verifyTimeIsAfter:(NSDate*)threshold
               completion:(SCTrustedTimeQuorumCompletion)completion;
```

- [ ] **Step 2: Write the failing test**

```objc
- (void)testVerifyAfterPastThresholdSucceeds {
    XCTestExpectation* exp = [self expectationWithDescription: @"quorum"];
    NSDate* past = [NSDate dateWithTimeIntervalSinceNow: -3600];
    [SCTrustedTime verifyTimeIsAfter: past
                          completion:^(BOOL ok, NSDate* med, NSError* err) {
        XCTAssertTrue(ok);
        XCTAssertNotNil(med);
        [exp fulfill];
    }];
    [self waitForExpectations: @[exp] timeout: 20.0];
}

- (void)testVerifyAfterFutureThresholdFails {
    XCTestExpectation* exp = [self expectationWithDescription: @"future"];
    NSDate* future = [NSDate dateWithTimeIntervalSinceNow: 86400 * 365 * 10]; // 10 years
    [SCTrustedTime verifyTimeIsAfter: future
                          completion:^(BOOL ok, NSDate* med, NSError* err) {
        XCTAssertFalse(ok);
        [exp fulfill];
    }];
    [self waitForExpectations: @[exp] timeout: 20.0];
}
```

- [ ] **Step 3: Run, confirm failures**

- [ ] **Step 4: Implement**

In `SCTrustedTime.m`, add:

```objc
+ (void)verifyTimeIsAfter:(NSDate*)threshold completion:(SCTrustedTimeQuorumCompletion)completion {
    NSArray* hosts = SCPinnedHosts;
    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<NSDate*>* results = [NSMutableArray array];
    NSLock* lock = [NSLock new];

    for (NSDictionary* hp in hosts) {
        dispatch_group_enter(group);
        [self fetchTimeFromHost: hp[@"host"]
                   expectedSPKI: hp[@"spki"]
                        timeout: 8.0
                     completion:^(NSDate* d, NSError* e) {
            if (d != nil) {
                [lock lock]; [results addObject: d]; [lock unlock];
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (results.count < 2) {
            completion(NO, nil, [NSError errorWithDomain: @"SCTrustedTime" code: 2
                                                userInfo: @{NSLocalizedDescriptionKey: @"Quorum not reached"}]);
            return;
        }
        NSArray* sorted = [results sortedArrayUsingSelector: @selector(compare:)];
        NSDate* min = sorted.firstObject;
        NSDate* max = sorted.lastObject;
        if ([max timeIntervalSinceDate: min] > 300.0) {
            completion(NO, nil, [NSError errorWithDomain: @"SCTrustedTime" code: 3
                                                userInfo: @{NSLocalizedDescriptionKey: @"Pinned hosts disagree"}]);
            return;
        }
        NSDate* median = sorted[sorted.count / 2];
        BOOL ok = [median compare: threshold] != NSOrderedAscending;
        completion(ok, median, nil);
    });
}
```

- [ ] **Step 5: Run, confirm pass**

- [ ] **Step 6: Commit**

```bash
git add Common/Utility/SCTrustedTime.h Common/Utility/SCTrustedTime.m SelfControlTests/SCTrustedTimeTests.m
git commit -m "feat(trustedtime): multi-host quorum check"
```

---

## Task 9: Wire SCBlockClock into block start

**Files:**
- Modify: `Daemon/SCDaemonBlockMethods.m` (around line 87)

**Goal:** when `startBlock` records `BlockEndDate`, also call `[SCBlockClock recordBlockStartWithDuration:]` so the monotonic counter is anchored.

- [ ] **Step 1: Add the call**

Locate the block in `startBlockWithControllingUID:...` that sets `BlockEndDate`:

```objc
[settings setValue: endDate forKey: @"BlockEndDate"];
```

Add immediately after:

```objc
NSTimeInterval duration = [endDate timeIntervalSinceNow];
if (duration > 0) {
    [SCBlockClock recordBlockStartWithDuration: duration];
}
```

Add `#import "SCBlockClock.h"` at the top.

- [ ] **Step 2: Build the daemon target**

Run: `xcodebuild -workspace SelfControl.xcworkspace -scheme org.eyebeam.selfcontrold build`
Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add Daemon/SCDaemonBlockMethods.m
git commit -m "feat(daemon): record SCBlockClock start when a block begins"
```

---

## Task 10: Replace expiry check with three-signal gate

**Files:**
- Modify: `Common/Utility/SCBlockUtilities.h` / `.m`
- Modify: `SelfControlTests/SCUtilityTests.m`

**Goal:** add `+ (BOOL)currentBlockIsTrulyExpired` which returns YES only when **both** `currentBlockIsExpired` (wall clock) **and** `[SCBlockClock blockDurationHasElapsed]` are YES. Callers in the daemon switch over.

We deliberately keep the old `currentBlockIsExpired` because non-daemon callers (UI hints, migration code) still want the weaker signal.

- [ ] **Step 1: Add to the header**

In `SCBlockUtilities.h`, alongside `currentBlockIsExpired`:

```objc
/// Strict check: both wall-clock and monotonic counter say the block is over.
/// Use this in the daemon before tearing down firewall rules.
+ (BOOL)currentBlockIsTrulyExpired;
```

- [ ] **Step 2: Write the failing test**

In `SCUtilityTests.m` (`testModernBlockDetection` is a good neighbor):

```objc
- (void)testTrulyExpiredRequiresBothSignals {
    SCSettings* s = [SCSettings sharedSettings];
    [s setValue: @YES forKey: @"BlockIsRunning"];
    [s setValue: [NSDate dateWithTimeIntervalSinceNow: -10] forKey: @"BlockEndDate"]; // wall says expired
    [SCBlockClock recordBlockStartWithDuration: 600]; // monotonic says NOT expired

    XCTAssertTrue([SCBlockUtilities currentBlockIsExpired]);
    XCTAssertFalse([SCBlockUtilities currentBlockIsTrulyExpired]); // 👈 the new gate

    // now flip monotonic to also expired
    NSMutableDictionary* tk = [[s valueForKey: @"BlockTimekeeping"] mutableCopy];
    tk[@"elapsedSecondsAccumulated"] = @(99999);
    [s setValue: tk forKey: @"BlockTimekeeping"];
    XCTAssertTrue([SCBlockUtilities currentBlockIsTrulyExpired]);
}
```

Add `#import "SCBlockClock.h"` to the test file.

- [ ] **Step 3: Run, confirm failure**

- [ ] **Step 4: Implement**

In `SCBlockUtilities.m`:

```objc
#import "SCBlockClock.h"

+ (BOOL)currentBlockIsTrulyExpired {
    if (![self currentBlockIsExpired]) return NO;
    return [SCBlockClock blockDurationHasElapsed];
}
```

- [ ] **Step 5: Run, confirm pass**

- [ ] **Step 6: Commit**

```bash
git add Common/Utility/SCBlockUtilities.h Common/Utility/SCBlockUtilities.m SelfControlTests/SCUtilityTests.m
git commit -m "feat: currentBlockIsTrulyExpired requires monotonic agreement"
```

---

## Task 11: Use the strict gate in daemon checkup

**Files:**
- Modify: `Daemon/SCDaemonBlockMethods.m` (around line 313)

**Goal:** the `checkupBlock` branch that removes the firewall rules when the block is "expired" must now use `currentBlockIsTrulyExpired`. Without this, Tasks 1–10 are dead code.

- [ ] **Step 1: Edit `checkupBlock`**

Find:

```objc
} else if ([SCBlockUtilities currentBlockIsExpired]) {
    NSLog(@"INFO: Checkup ran, block expired, removing block.");
    [SCHelperToolUtilities removeBlock];
    ...
}
```

Replace `currentBlockIsExpired` with `currentBlockIsTrulyExpired`.

- [ ] **Step 2: Build the daemon target, confirm clean build**

- [ ] **Step 3: Commit**

```bash
git add Daemon/SCDaemonBlockMethods.m
git commit -m "feat(daemon): require strict (wall + monotonic) gate before unlock"
```

---

## Task 12: Add the 30-second checkpoint timer in the daemon

**Files:**
- Modify: `Daemon/SCDaemon.h` / `.m`

**Goal:** every 30 s while a block is running, call `[SCBlockClock tickCheckpoint]`. The existing daemon already has the timer pattern (`checkupTimer`, `inactivityTimer`); model after it.

- [ ] **Step 1: Add methods to the header**

In `SCDaemon.h`, alongside `startCheckupTimer` etc.:

```objc
- (void)startCheckpointTimer;
- (void)stopCheckpointTimer;
```

- [ ] **Step 2: Add the timer property and methods to `.m`**

```objc
@property (strong, readwrite) NSTimer* checkpointTimer;
```

```objc
- (void)startCheckpointTimer {
    if (self.checkpointTimer != nil) return;
    self.checkpointTimer = [NSTimer scheduledTimerWithTimeInterval: 30.0
                                                            repeats: YES
                                                              block: ^(NSTimer* _Nonnull t) {
        [SCBlockClock tickCheckpoint];
    }];
}

- (void)stopCheckpointTimer {
    if (self.checkpointTimer == nil) return;
    [self.checkpointTimer invalidate];
    self.checkpointTimer = nil;
}
```

In the `dealloc` / shutdown section, add:

```objc
if (self.checkpointTimer) {
    [self.checkpointTimer invalidate];
    self.checkpointTimer = nil;
}
```

Add `#import "SCBlockClock.h"` near the top.

- [ ] **Step 3: Start/stop the timer from `startBlock` and from removal**

In `Daemon/SCDaemonBlockMethods.m`, near the existing `[[SCDaemon sharedDaemon] startCheckupTimer];` call inside `startBlock`, add:

```objc
[[SCDaemon sharedDaemon] startCheckpointTimer];
```

In `SCHelperToolUtilities.m` `removeBlock` (find the existing call that clears block settings) — add `[[SCDaemon sharedDaemon] stopCheckpointTimer];` only if `SCDaemon` is reachable from there; if not, do it where `stopCheckupTimer` is called in `checkupBlock`.

- [ ] **Step 4: Build, confirm clean build**

- [ ] **Step 5: Commit**

```bash
git add Daemon/SCDaemon.h Daemon/SCDaemon.m Daemon/SCDaemonBlockMethods.m Common/Utility/SCHelperToolUtilities.m
git commit -m "feat(daemon): 30s checkpoint timer for SCBlockClock"
```

---

## Task 13: Internet verification gate at unlock time

**Files:**
- Modify: `Daemon/SCDaemonBlockMethods.m`

**Goal:** in the `checkupBlock` "block is truly expired" branch, before calling `removeBlock`, call `[SCTrustedTime verifyTimeIsAfter: blockEndDate completion:^(BOOL ok, ...)]`. Only remove the block when `ok == YES`. If `ok == NO`, set `BlockUnlockGate.waitingForNetworkVerification = YES` in settings and schedule a retry.

- [ ] **Step 1: Define a small helper inside `SCDaemonBlockMethods.m`**

Above `@implementation SCDaemonBlockMethods`:

```objc
static NSTimeInterval const kVerifyBackoffs[] = { 10.0, 30.0, 60.0, 120.0, 120.0 };
static const NSUInteger kVerifyBackoffsCount = sizeof(kVerifyBackoffs) / sizeof(kVerifyBackoffs[0]);
```

- [ ] **Step 2: Refactor the "truly expired" branch in `checkupBlock`**

Replace:

```objc
} else if ([SCBlockUtilities currentBlockIsTrulyExpired]) {
    NSLog(@"INFO: Checkup ran, block expired, removing block.");
    [SCHelperToolUtilities removeBlock];
    [SCHelperToolUtilities sendConfigurationChangedNotification];
    [SCSentry addBreadcrumb: @"Daemon found and cleared expired block" category: @"daemon"];
    [[SCDaemon sharedDaemon] stopCheckupTimer];
}
```

with:

```objc
} else if ([SCBlockUtilities currentBlockIsTrulyExpired]) {
    [SCDaemonBlockMethods attemptVerifiedUnlock];
}
```

Then add the helper method:

```objc
+ (void)attemptVerifiedUnlock {
    SCSettings* settings = [SCSettings sharedSettings];
    NSDate* endDate = [settings valueForKey: @"BlockEndDate"];
    NSUInteger attempt = [[settings valueForKey: @"BlockUnlockAttempt"] unsignedIntegerValue];

    NSMutableDictionary* gate = [[settings valueForKey: @"BlockUnlockGate"] mutableCopy] ?: [NSMutableDictionary dictionary];
    gate[@"waitingForNetworkVerification"] = @YES;
    gate[@"lastNetworkAttemptAt"] = [NSDate date];
    [settings setValue: gate forKey: @"BlockUnlockGate"];
    [SCHelperToolUtilities sendConfigurationChangedNotification];

    [SCTrustedTime verifyTimeIsAfter: endDate completion:^(BOOL ok, NSDate* med, NSError* err) {
        if (ok) {
            NSLog(@"INFO: Verified unlock — removing block.");
            [settings setValue: nil forKey: @"BlockUnlockGate"];
            [settings setValue: @(0) forKey: @"BlockUnlockAttempt"];
            [SCHelperToolUtilities removeBlock];
            [SCHelperToolUtilities sendConfigurationChangedNotification];
            [[SCDaemon sharedDaemon] stopCheckupTimer];
            [[SCDaemon sharedDaemon] stopCheckpointTimer];
            return;
        }

        NSLog(@"WARN: Trusted-time verification failed: %@. Block stays on.", err);
        NSMutableDictionary* g = [[settings valueForKey: @"BlockUnlockGate"] mutableCopy];
        g[@"lastNetworkErrorReason"] = err.localizedDescription ?: @"unknown";
        [settings setValue: g forKey: @"BlockUnlockGate"];
        [settings setValue: @(attempt + 1) forKey: @"BlockUnlockAttempt"];

        NSTimeInterval backoff = kVerifyBackoffs[ MIN(attempt, kVerifyBackoffsCount - 1) ];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(backoff * NSEC_PER_SEC)),
                       dispatch_get_main_queue(),
                       ^{ [SCDaemonBlockMethods attemptVerifiedUnlock]; });
    }];
}
```

Add `#import "SCTrustedTime.h"` and `#import "SCBlockClock.h"`.

- [ ] **Step 3: Build the daemon, confirm clean build**

- [ ] **Step 4: Commit**

```bash
git add Daemon/SCDaemonBlockMethods.m
git commit -m "feat(daemon): require trusted-internet verification before unlock"
```

---

## Task 14: Expose unlock-gate state over XPC

**Files:**
- Modify: `Daemon/SCDaemonProtocol.h`
- Modify: `Daemon/SCDaemonXPC.m`
- Modify: `Common/SCXPCClient.h` / `.m`

**Goal:** the app side can ask the daemon "are we currently waiting on internet verification?" so the timer window can show the message.

- [ ] **Step 1: Add the protocol method**

`SCDaemonProtocol.h`:

```objc
- (void)getBlockUnlockGateStateWithReply:(void(^)(BOOL waitingForNetwork, NSDate* lastAttemptAt, NSString* errorReason))reply;
```

- [ ] **Step 2: Implement in `SCDaemonXPC.m`**

```objc
- (void)getBlockUnlockGateStateWithReply:(void(^)(BOOL, NSDate*, NSString*))reply {
    NSDictionary* gate = [[SCSettings sharedSettings] valueForKey: @"BlockUnlockGate"];
    BOOL waiting = [gate[@"waitingForNetworkVerification"] boolValue];
    NSDate* at = gate[@"lastNetworkAttemptAt"];
    NSString* err = gate[@"lastNetworkErrorReason"];
    reply(waiting, at, err);
}
```

- [ ] **Step 3: Add the convenience method in `SCXPCClient.h` and `.m`**

```objc
- (void)getBlockUnlockGateStateWithReply:(void(^)(BOOL waiting, NSDate* lastAttemptAt, NSString* errorReason))reply;
```

Implementation pattern: copy the structure of any existing one-way getter (e.g., `getVersionWithReply:`).

- [ ] **Step 4: Build both targets**

- [ ] **Step 5: Commit**

```bash
git add Daemon/SCDaemonProtocol.h Daemon/SCDaemonXPC.m Common/SCXPCClient.h Common/SCXPCClient.m
git commit -m "feat(xpc): expose unlock-gate state to the app"
```

---

## Task 15: Show "waiting for internet" in TimerWindowController

**Files:**
- Modify: `TimerWindowController.m`

**Goal:** when the timer's existing periodic update notices the block "should" be over (wall-clock past `BlockEndDate`) but `BlockIsRunning` is still YES, query the unlock gate. If `waitingForNetwork`, replace the time label with the user-facing message.

- [ ] **Step 1: Identify the periodic update entry point**

In `TimerWindowController.m`, find the method that updates the displayed time (search for the timer label outlet, e.g. `timerLabel.stringValue = …`). This is the place that already runs on each second/tick.

- [ ] **Step 2: Add the gate-aware branch**

Inside that method, before any code that sets the time-remaining string, add:

```objc
SCSettings* settings = [SCSettings sharedSettings];
NSDate* endDate = [settings valueForKey: @"BlockEndDate"];
BOOL pastEnd = [[NSDate date] timeIntervalSinceDate: endDate] > 0;
if (pastEnd && [SCBlockUtilities modernBlockIsRunning]) {
    [[SCXPCClient sharedXPC] getBlockUnlockGateStateWithReply:^(BOOL waiting, NSDate* at, NSString* err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (waiting) {
                self.timerLabel.stringValue =
                    NSLocalizedString(@"Connect to the internet to finish your block.",
                                      @"Shown when block end time has passed but trusted-time check has not yet succeeded.");
                self.timerSubLabel.stringValue =
                    NSLocalizedString(@"SelfControl checks the time with a trusted server. Once online, this finishes automatically.",
                                      @"");
            }
        });
    }];
    return;
}
```

(Adapt outlet names — `timerLabel`, `timerSubLabel` — to whatever the controller already uses. If only one label exists, append the sublabel text on a new line.)

- [ ] **Step 3: Add new strings to `Localizable.strings`**

In `en.lproj/Localizable.strings`:

```
"Connect to the internet to finish your block." = "Connect to the internet to finish your block.";
"SelfControl checks the time with a trusted server. Once online, this finishes automatically." = "SelfControl checks the time with a trusted server. Once online, this finishes automatically.";
```

- [ ] **Step 4: Build the SelfControl app target, confirm clean build**

- [ ] **Step 5: Commit**

```bash
git add TimerWindowController.m en.lproj/Localizable.strings
git commit -m "feat(ui): show 'waiting for internet' when unlock gate is open"
```

---

## Task 16: Manual end-to-end QA

**Files:** none — this is a smoke-test checklist.

**Goal:** prove that the four spec scenarios all behave as documented.

Build a Debug variant first: `xcodebuild -workspace SelfControl.xcworkspace -scheme SelfControl -configuration Debug build`. Install/run from `~/Library/Developer/Xcode/DerivedData/...`.

- [ ] **Test 1: `sudo date` attack**
  1. Start a 5-minute block on `example.com`.
  2. Confirm `curl https://example.com` fails.
  3. Run `sudo date 010100002030` (Jan 1 2030).
  4. Wait 10 s. Confirm the block is **still active** (curl still fails) and the timer still counts down toward the real end.
  5. Restore time: `sudo sntp -sS time.apple.com`.

- [ ] **Test 2: Reboot mid-block**
  1. Start a 10-minute block.
  2. Reboot the Mac.
  3. After login, confirm the block is still active and the remaining-time display is close to what it should be.

- [ ] **Test 3: `/etc/hosts` redirect**
  1. Start a 1-minute block.
  2. Edit `/etc/hosts` to add `127.0.0.1 www.apple.com www.google.com www.cloudflare.com`.
  3. Wait past the 1-minute end.
  4. Confirm the timer window shows the "Connect to the internet" message and the block does **not** unlock.
  5. Remove the `/etc/hosts` lines.
  6. Confirm the block unlocks within ~30 s.

- [ ] **Test 4: Wi-Fi off at unlock**
  1. Start a 1-minute block.
  2. Disable Wi-Fi at expiry.
  3. Confirm "Connect to the internet" message appears, block stays on.
  4. Re-enable Wi-Fi.
  5. Confirm block unlocks within ~30 s.

- [ ] **Document any issues** in a follow-up GitHub issue. Do not gate the merge on a perfect manual run — file fixes as separate PRs.

- [ ] **Final commit** (if any docs were tweaked):

```bash
git add docs/superpowers/plans/2026-05-14-tamper-resistant-timing.md
git commit -m "docs: QA results from tamper-resistant timing"
```

---

## Self-Review Notes

**Spec coverage:**
- Piece 1 (monotonic counter) → Tasks 1, 2, 9.
- Piece 2 (persisted checkpoint) → Tasks 2, 3, 4, 12.
- Piece 3 (pinned HTTPS) → Tasks 5, 6, 7, 8, 13.
- Piece 4 (UI) → Tasks 14, 15.
- Threat-model attacks (rows in the spec table) → all covered by the above. Sudo+reboot+clock-change: caught by Piece 3 (Task 13), since the daemon refuses to unlock without quorum agreement that the real time is past `BlockEndDate`.

**Placeholder scan:** the only `<paste …>` placeholders are the SPKI hashes in Task 6, which must be computed at implementation time (the command is provided). These are intentional, not stubs.

**Type consistency:** `SCBlockClock` method names match across Tasks 1, 2, 3, 9, 10, 12. `SCTrustedTime` block typedefs (`SCTrustedTimeCompletion`, `SCTrustedTimeQuorumCompletion`) declared once and used consistently.

**Known small risks for the implementer:**
- `SecCertificateCopyKey` is macOS 10.14+. The repo already requires 10.13 minimum per the existing podfile; if 10.13 support matters, fall back to `SecCertificateCopyPublicKey` (deprecated). Check `Podfile`.
- `[NSTimer scheduledTimerWithTimeInterval: 30 …]` requires a runloop. The daemon does have one (see `SCDaemon.m` existing timers), so this should Just Work.
