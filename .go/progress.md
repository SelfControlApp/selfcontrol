# Go Run — 2026-03-16

## Summary
Clean Swift rewrite of SelfControl → Stone. **31 Swift files, ~3,650 lines.** All three targets compile with zero errors and zero warnings.

Branch: `swift-rewrite` (3 commits ahead of master)

## What was built

### Project Infrastructure
- XcodeGen-based project with 3 targets: Stone (app), stonectld (daemon), stone-cli (CLI)
- Deployment target macOS 12.0, Swift 5.9
- Info.plists with SMJobBless/SMAuthorizedClients for privileged helper
- ObjC bridging header for audit token access (1 .m file)

### Common Layer (shared across all targets)
- `SCError` — error enum with localized descriptions
- `StoneConstants` — bundle IDs, sentinel strings, default preferences
- `BlockEntry` — hostname/IP parser with pf rule and hosts line generation
- `SCSchedule` — Codable recurring schedule model
- `SCDaemonProtocol` — @objc XPC protocol
- `SCSettings` — cross-process settings store (root-owned binary plist)
- `SCBlockUtilities` — block state checks
- `SCBlockFileReaderWriter` — .stone blocklist file I/O
- `SCFileWatcher` — FSEvents wrapper
- `SCMiscUtilities` — serial number, SHA1, utilities

### Block Enforcement
- `PacketFilter` — pf rules via pfctl, anchor management, token persistence
- `HostFileBlocker` — /etc/hosts editing with sentinel markers
- `HostFileBlockerSet` — multi-hosts-file coordinator
- `BlockManager` — orchestrates PF + hosts, DNS resolution, subdomain expansion

### XPC Communication
- `SCXPCAuthorization` — AuthorizationServices wrapper
- `SCXPCClient` — SMJobBless + NSXPCConnection lifecycle

### Daemon
- `SCDaemon` — XPC listener, 1s checkup timer, 2min inactivity exit
- `SCDaemonXPC` — protocol implementation with auth validation
- `SCDaemonBlockMethods` — block start/checkup/integrity/update logic
- `SCHelperToolUtilities` — settings ↔ enforcement bridge

### Schedule Manager
- `SCScheduleManager` — Codable CRUD with UserDefaults, launchd sync
- `LaunchAgentWriter` — plist generation, launchctl operations

### CLI
- Full argument parsing: --blocklist, --enddate, --duration, --settings, --uid
- Legacy positional arg fallback, UserDefaults fallback
- XPC-based block start

### App UI (all programmatic, no xibs)
- `AppController` — block start/stop flow, window lifecycle, notification observation
- `MainWindowController` — duration slider, start button, blocklist toggle
- `TimerWindowController` — countdown, add-to-block, extend time, dock badge
- `DomainListWindowController` — editable table, add/remove, quick-add
- `ScheduleListWindowController` — 5-column table, add/edit/remove with sheet
- `PreferencesWindowController` — General + Advanced tabs

## What's NOT done yet
- No app icon / assets
- No localization (English only)
- Code signing not configured (needs your Apple Developer Team ID)
- No Sentry integration
- No "move to Applications" prompt
- No migration from SelfControl settings
- No unit tests
- UI is functional but not polished (no custom styling)

## To test

```bash
cd /Users/maxforsey/Code/selfcontrol
git checkout swift-rewrite
open Stone.xcodeproj
# Set signing team in Xcode, then Build & Run
```
