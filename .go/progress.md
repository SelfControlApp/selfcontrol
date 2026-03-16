# Go Run — 2026-03-15

Started: now
Finished: now
Status: Complete

## Summary
Completed: 2/2 tickets
Blocked: 0
Skipped: 0

## Review Guide

All changes are on a single branch: `worktree-agent-a18ebc64`

### To review:

```bash
cd /Users/maxforsey/Code/selfcontrol/.claude/worktrees/agent-a18ebc64
git diff master...HEAD
```

### What was built:

**1. CLI --duration flag** (`cli-main.m`)
- `selfcontrol-cli start --blocklist <file> --duration 60` starts a 60-minute block
- Mutually exclusive with `--enddate` (errors if both provided)
- Validates duration is a positive integer

**2. SCSchedule model** (`SCSchedule.h/m`)
- Properties: identifier (UUID), name, weekdays (0=Sun-6=Sat), hour, minute, durationMinutes, blocklist, enabled
- Serializes to/from NSDictionary for NSUserDefaults storage

**3. SCScheduleManager** (`SCScheduleManager.h/m`)
- Singleton that reads/writes schedules to NSUserDefaults key `ScheduledBlocks`
- `syncAllLaunchdAgents` writes launchd plists to ~/Library/LaunchAgents/ and blocklist files to ~/Library/Application Support/SelfControl/Schedules/
- Handles load/unload via launchctl, cleans up stale plists on remove/disable

**4. ScheduleListWindowController** (`ScheduleListWindowController.h/m`)
- Programmatic Cocoa UI (no xib) — table with On/Name/Days/Time/Duration columns
- Add/Edit/Remove buttons, edit sheet with day checkboxes + time picker + duration + blocklist
- Toggling the enabled checkbox immediately syncs launchd agents

**5. AppController wiring** (`AppController.h/m`, `SCConstants.h/m`, `project.pbxproj`)
- "Schedules..." menu item added programmatically to the SelfControl menu
- `syncAllLaunchdAgents` called on app launch
- All 6 new files added to Xcode project

### Smoke test:

1. `pod install` then open `SelfControl.xcworkspace` in Xcode
2. Build and run
3. Look for "Schedules..." in the app menu → click it
4. Click Add → fill in name, check some days, set time/duration, enter domains → Save
5. Verify plist exists: `ls ~/Library/LaunchAgents/org.eyebeam.SelfControl.schedule.*.plist`
6. Verify blocklist exists: `ls ~/Library/Application\ Support/SelfControl/Schedules/`
7. Uncheck the "On" checkbox → verify plist is removed
8. Click Remove → verify cleanup

For CLI: `selfcontrol-cli start --blocklist /path/to/file.selfcontrol --duration 60`

### To merge:

```bash
cd /Users/maxforsey/Code/selfcontrol
git merge worktree-agent-a18ebc64
git worktree remove .claude/worktrees/agent-a18ebc64
```

## Build Status
Full xcodebuild fails due to pre-existing infra issues (missing CocoaPods, code signing cert). Unrelated to new code. Individual file syntax checks pass clean.
