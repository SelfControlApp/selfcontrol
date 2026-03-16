import Foundation

/// Generates launchd plist dictionaries and manages launchctl operations.
enum LaunchAgentWriter {

    /// Generate a launchd plist for a recurring schedule.
    static func plistForSchedule(_ schedule: SCSchedule,
                                  blocklistPath: String,
                                  cliPath: String) -> [String: Any] {
        let programArguments: [String] = [
            cliPath, "start",
            "--duration", "\(schedule.durationMinutes)",
            "--blocklist", blocklistPath,
        ]

        var calendarIntervals: [[String: Any]] = []
        if schedule.weekdays.isEmpty {
            // Daily — just Hour + Minute
            calendarIntervals.append([
                "Hour": schedule.hour,
                "Minute": schedule.minute,
            ])
        } else {
            for weekday in schedule.weekdays {
                calendarIntervals.append([
                    "Weekday": weekday,
                    "Hour": schedule.hour,
                    "Minute": schedule.minute,
                ])
            }
        }

        return [
            "Label": schedule.launchdLabel,
            "ProgramArguments": programArguments,
            "StartCalendarInterval": calendarIntervals,
            "RunAtLoad": false,
        ]
    }

    /// Load a launchd agent plist.
    static func loadAgent(at path: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["load", "-w", path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            NSLog("LaunchAgentWriter: launchctl load failed for %@ (status %d)", path, task.terminationStatus)
        }
    }

    /// Unload a launchd agent plist.
    static func unloadAgent(at path: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["unload", "-w", path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
    }
}
