# Tamper-Resistant Block Timing — Design

**Date:** 2026-05-14
**Status:** Approved (design phase). Implementation plan not yet written.

## Problem

A SelfControl block today ends when `[NSDate date]` (the macOS system clock) passes `BlockEndDate`. Any user can defeat the block by running `sudo date 0101000026` in Terminal to jump the clock forward. The block ends instantly. The protection is one search away on any AI assistant.

We want to close this hole.

## Threat model

We are defending against a casual user who copy-pastes a bypass from an AI assistant. We are **not** trying to stop a skilled reverse engineer who edits the SelfControl binary, attaches a debugger, or disables the PF firewall directly.

Concretely, we defend against:

- `sudo date` to jump the system clock forward or backward
- Editing the on-disk settings/checkpoint files
- Deleting the on-disk settings/checkpoint files
- Rebooting the Mac mid-block (with or without a clock change)
- Editing `/etc/hosts` to redirect time-server lookups
- Installing a custom root certificate to MITM HTTPS
- Blocking all network traffic

In every case the desired behavior is the same: **the block stays on.** "When in doubt, stay blocked" is the default.

We do **not** defend against:

- Patching the SelfControl binary itself
- Disabling SIP and tampering with the PF kernel module
- Booting from another OS and editing the disk offline
- Physical attacks

## Design overview

Three pieces, layered:

1. A **monotonic counter** (`mach_continuous_time`) so changing the wall clock does not end the block while the Mac is running.
2. A **persisted checkpoint** so the elapsed-time accounting survives reboots and sleep.
3. A **pinned HTTPS time check** at unlock so an attacker who edits the local files still cannot fake the moment the block ends.

The existing `BlockEndDate` is kept as a sanity check. To unlock, *all* three signals must agree.

## Piece 1 — Monotonic counter

### What

`mach_continuous_time()` returns nanoseconds since boot. It is unaffected by `sudo date` and keeps counting during sleep. It resets to 0 on reboot (handled by Piece 2).

### How

At block start, the daemon records:

- `blockStartContinuousTime` — value of `mach_continuous_time()` at block start
- `blockDurationSeconds` — requested duration

On every existing block-state check, compute:

```
continuousElapsed = (mach_continuous_time() - blockStartContinuousTime) / 1e9
```

If `continuousElapsed < blockDurationSeconds`, **block stays on**, even if `BlockEndDate` has passed.

### What this defeats

`sudo date` while the Mac is running. The monotonic counter does not change when the wall clock is changed.

## Piece 2 — Persisted checkpoint

### What

Because the monotonic counter resets on reboot, we periodically write a small note to disk recording how much elapsed time has accumulated. After a reboot the daemon reads the note and picks up where it left off.

### How

A new key in `SCSettings`, written to `/usr/local/etc/<settings file>` (root-owned, same protection as today's settings):

```
BlockTimekeeping = {
    blockStartWallClock:        <NSDate>
    blockStartContinuousTime:   <uint64_t>     // mach_continuous_time at start
    bootSessionUUID:            <NSString>     // identifies "this boot"
    elapsedSecondsAccumulated:  <double>       // total across all boots so far
    lastCheckpointWallClock:    <NSDate>       // wall clock at last write
    lastCheckpointContinuous:   <uint64_t>     // monotonic value at last write
}
```

A timer in the daemon updates the checkpoint **every 30 seconds**.

At each checkpoint write:

```
deltaContinuous = mach_continuous_time() - lastCheckpointContinuous
deltaWall       = now() - lastCheckpointWallClock

// Trust the smaller of the two. If they disagree by more than a small
// tolerance, that is a tamper signal (clock changed while running). We
// still credit the smaller of the two, never the larger.
trustedDelta    = min(deltaContinuous_in_seconds, max(0, deltaWall_in_seconds))

elapsedSecondsAccumulated += trustedDelta
```

On daemon startup (e.g., after reboot):

1. Read the persisted `bootSessionUUID`. Compute the current one as the string form of `kern.boottime` (a per-boot timestamp from `sysctl`). If they match, we are still in the same boot session: `blockStartContinuousTime` and `lastCheckpointContinuous` are still valid, so we resume normal checkpoint accounting.
2. If they differ, we rebooted. The monotonic counter has reset, so we cannot use it for the gap. We compute `gapWall = now() - lastCheckpointWallClock`. If `gapWall > 0`, we credit that much elapsed time (treating the reboot gap as honest wall-clock time). If `gapWall <= 0`, we credit zero — clock went backward across the reboot, which is a tamper signal.
3. We then reset `blockStartContinuousTime` and `lastCheckpointContinuous` to the current `mach_continuous_time()`, update `bootSessionUUID` to the current boot timestamp, and resume normal accounting.

To unlock without Piece 3, the daemon requires:

- `elapsedSecondsAccumulated >= blockDurationSeconds`, AND
- `[NSDate date] >= blockEndDate`

### What this defeats

- Reboot mid-block: the note's wall-clock + accumulated total preserves real elapsed time.
- Editing the on-disk note: if `elapsedSecondsAccumulated` is set to a fake huge value, Piece 3 catches it. If the note is deleted, the daemon treats elapsed as zero and stays blocked.
- Tampering while running: `min(deltaContinuous, deltaWall)` makes either direction of wall-clock change a no-op for accumulated time.

### Failure modes

- Missing/corrupt note → assume zero elapsed → block stays on.
- Clock-going-backward signal → can be logged for telemetry but does not shorten the block.

## Piece 3 — Pinned HTTPS time check at unlock

### What

Before the daemon transitions a block from "active" to "ended," it makes one outbound HTTPS request to a pinned set of servers and verifies the real wall-clock time from the response `Date:` header. If verification fails for any reason, the block stays active.

### Servers

A small list baked into the binary, e.g.:

- `https://www.apple.com`
- `https://www.google.com`
- `https://www.cloudflare.com`

We require **at least 2 of 3** to succeed and agree (within ~5 minutes of each other) that the block end time has passed. If fewer than 2 respond with a valid pinned cert, the check fails.

### Pinning

For each server we bake in a SHA-256 fingerprint of the **subject public key** of the leaf or an intermediate CA. (Public-key pinning is more durable than full-cert pinning across renewals.)

Implementation uses `URLSession` with a `URLSessionDelegate` that:

1. Receives `URLAuthenticationChallenge` of type `NSURLAuthenticationMethodServerTrust`.
2. Extracts the server certificate chain from `serverTrust`.
3. For each cert in the chain, computes SHA-256 of the SubjectPublicKeyInfo (SPKI).
4. If any computed hash matches the pinned hash for that host, the challenge passes. Otherwise, the challenge is rejected via `.cancelAuthenticationChallenge`.

Crucially, the delegate does **not** fall back to the system trust evaluation. A user-installed root CA cannot satisfy the pin.

### Request

`HEAD /` to each pinned URL. Parse the `Date:` header (RFC 7231 IMF-fixdate). Discard responses with malformed dates or with TLS warnings.

### Decision

The block is allowed to end iff:

- Piece 1 says continuous elapsed ≥ duration, AND
- Piece 2 says accumulated elapsed ≥ duration, AND
- Piece 3 returns ≥ 2 valid pinned responses whose Date headers all show a time ≥ `BlockEndDate`.

Any one of those failing → stay blocked.

### What this defeats

- Disk tampering of the checkpoint note (`elapsedSecondsAccumulated` forged): Piece 3 still asks the real internet.
- `/etc/hosts` redirecting `www.apple.com` to a local server: pinned key won't match.
- A user-installed root CA enabling MITM: pinned key won't match.
- Network blackholing: no responses → block stays.

## Piece 4 — UI feedback (new in this design pass)

When the daemon would have ended the block based on local signals (Pieces 1 + 2 both green) but Piece 3 fails, the timer window must tell the user **why** the block is not ending.

### What the user sees

A new state in the existing `TimerWindowController` UI, shown when the daemon is waiting on Piece 3:

> **Connect to the internet to finish your block.**
> SelfControl checks the time with a trusted server before ending a block. Once you're online, this will finish automatically.

Visually: small spinner + the message. No "skip" button. No "unlock anyway" override.

### How

A new state field passed from daemon → app over the existing XPC channel:

```
BlockUnlockGate {
    waitingForNetworkVerification: BOOL
    lastNetworkAttemptAt:          NSDate
    lastNetworkErrorReason:        NSString?    // shown in advanced/debug only
}
```

The daemon retries Piece 3 on a backoff (e.g., 10s, 30s, 60s, then every 2 min) while in this state. The timer window observes the XPC state and shows the message whenever `waitingForNetworkVerification == YES`.

### Edge cases

- User puts Mac to sleep in this state: on wake, daemon retries Piece 3 immediately, then continues backoff.
- Block duration was very short (e.g., 1 minute) and internet was offline at the moment of unlock: user may be blocked for an extra few seconds to minutes while the verification succeeds. Acceptable.
- Internet remains down for hours: block stays on. UI keeps showing the message. This is **by design** — the alternative is letting an attacker win by cutting Wi-Fi.

## File-level changes

- `Common/SCSettings.m` + `.h`: add `BlockTimekeeping` dictionary key and accessors.
- `Common/Utility/SCBlockClock.m` + `.h` *(new)*: monotonic-counter math, checkpoint read/write, boot-UUID handling, the "min(deltaWall, deltaContinuous)" rule.
- `Common/Utility/SCTrustedTime.m` + `.h` *(new)*: pinned HTTPS time check; takes a list of (host, SPKI hash) pairs; returns verified time or error.
- `Common/Utility/SCPinnedHosts.h` *(new)*: the baked-in (host, SPKI hash) constants.
- `Daemon/SCDaemonBlockMethods.m`: replace the "is block over?" check with the new three-piece gate.
- `Daemon/SCDaemon.m`: register a 30s checkpoint timer; manage the Piece-3 backoff state machine.
- `Daemon/SCDaemonProtocol.h` and `Common/SCXPCClient.{h,m}`: extend XPC payload with `BlockUnlockGate` fields.
- `TimerWindowController.{h,m}`: render the "waiting on internet" state.
- `SelfControlTests/`: tests for `SCBlockClock` (clock-change scenarios, reboot scenarios) and `SCTrustedTime` (pinning success, pinning failure, MITM rejection, host-down).

## What does NOT change

- The user interface for starting a block.
- The PF firewall mechanism or daemon installation.
- The XPC authorization model.
- Existing settings keys (we add, we don't migrate or remove).
- Block duration limits, blocklist format, or any other product behavior.

## Testing strategy

Unit-testable in `SelfControlTests/`:

- **`SCBlockClock` tests:** simulate clock jumps forward, jumps backward, reboot (reset of monotonic + new boot UUID), and verify `elapsedSecondsAccumulated` only ever grows by the trusted delta.
- **`SCTrustedTime` tests:** spin up a local TLS server with a known cert. Verify: (a) request to a host with matching pinned SPKI succeeds; (b) same host but with a different cert chain is rejected; (c) host whose name resolves to the local server but with mismatched SPKI is rejected.
- **End-to-end manual test plan** (in QA notes, not automated):
  1. Start a 2-minute block. Run `sudo date 010100002030`. Verify block does not end.
  2. Start a block. Reboot. Verify block continues with correct remaining time.
  3. Start a block. Edit `/etc/hosts` to point `www.apple.com` at `127.0.0.1`. Verify block does not end at expiry; UI shows the "connect to internet" message.
  4. Start a block. Disconnect Wi-Fi at expiry. Verify UI shows the message; reconnect; verify block ends within ~30s.

## Open questions

None at design time. The implementation plan (next step) will need to choose:

- Exact SPKI hashes for the pinned hosts and a rotation policy for when those keys change.
- Exact retry/backoff intervals for Piece 3.
- Whether to expose `lastNetworkErrorReason` in a hidden debug panel.

These are tunable, not architectural.

## Out of scope (explicit non-goals)

- A second factor (PIN, password, biometric) at unlock — separate idea.
- Migrating away from the existing `BlockEndDate` field — we keep it for backward compatibility and as a third corroborating signal.
- Cross-device sync of block state — separate idea.
- Stopping the user from uninstalling SelfControl entirely — fundamentally out of scope for a local app.
