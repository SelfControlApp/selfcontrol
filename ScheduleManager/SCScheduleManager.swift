import Foundation

/// Manages recurring scheduled blocks stored in UserDefaults
/// and synced to launchd user agents.
final class SCScheduleManager {
    static let shared = SCScheduleManager()

    private let defaults = UserDefaults.standard
    private let key = "ScheduledBlocks"

    // MARK: - CRUD

    func allSchedules() -> [SCSchedule] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SCSchedule].self, from: data)) ?? []
    }

    func addSchedule(_ schedule: SCSchedule) {
        var schedules = allSchedules()
        schedules.append(schedule)
        saveSchedules(schedules)
    }

    func removeSchedule(_ schedule: SCSchedule) {
        var schedules = allSchedules()
        schedules.removeAll { $0.id == schedule.id }
        saveSchedules(schedules)
    }

    func updateSchedule(_ schedule: SCSchedule) {
        var schedules = allSchedules()
        if let idx = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[idx] = schedule
        }
        saveSchedules(schedules)
    }

    private func saveSchedules(_ schedules: [SCSchedule]) {
        guard let data = try? JSONEncoder().encode(schedules) else { return }
        defaults.set(data, forKey: key)
    }

    // MARK: - Launchd Sync

    func syncAllLaunchdAgents() {
        let schedules = allSchedules()
        let fm = FileManager.default
        let launchAgentsDir = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents")
        let schedulesDir = self.schedulesDirectory()

        try? fm.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: schedulesDir, withIntermediateDirectories: true)

        // Collect enabled schedule labels
        let enabledLabels = Set(schedules.filter(\.enabled).map(\.launchdLabel))

        // Remove stale plists
        if let existing = try? fm.contentsOfDirectory(atPath: launchAgentsDir) {
            for filename in existing {
                guard filename.hasPrefix(StoneConstants.scheduleLaunchdPrefix),
                      filename.hasSuffix(".plist") else { continue }
                let label = (filename as NSString).deletingPathExtension
                if !enabledLabels.contains(label) {
                    let path = (launchAgentsDir as NSString).appendingPathComponent(filename)
                    LaunchAgentWriter.unloadAgent(at: path)
                    try? fm.removeItem(atPath: path)
                    // Clean up blocklist file
                    let scheduleId = label.replacingOccurrences(of: "\(StoneConstants.scheduleLaunchdPrefix).", with: "")
                    let blocklistPath = (schedulesDir as NSString).appendingPathComponent("\(scheduleId).stone")
                    try? fm.removeItem(atPath: blocklistPath)
                }
            }
        }

        // Write plists for enabled schedules
        for schedule in schedules where schedule.enabled {
            let blocklistPath = (schedulesDir as NSString).appendingPathComponent("\(schedule.id).stone")
            let blocklistURL = URL(fileURLWithPath: blocklistPath)

            do {
                try SCBlockFileReaderWriter.writeBlocklist(
                    to: blocklistURL,
                    blockInfo: [
                        "Blocklist": schedule.blocklist,
                        "BlockAsWhitelist": false,
                    ]
                )
            } catch {
                NSLog("SCScheduleManager: Failed to write blocklist for %@: %@", schedule.id, error.localizedDescription)
                continue
            }

            let cliPath = Bundle.main.path(forAuxiliaryExecutable: "stone-cli")
                ?? "/Applications/Stone.app/Contents/MacOS/stone-cli"

            let plist = LaunchAgentWriter.plistForSchedule(schedule, blocklistPath: blocklistPath, cliPath: cliPath)
            let plistPath = (launchAgentsDir as NSString).appendingPathComponent("\(schedule.launchdLabel).plist")

            // Unload existing before overwriting
            if fm.fileExists(atPath: plistPath) {
                LaunchAgentWriter.unloadAgent(at: plistPath)
            }

            (plist as NSDictionary).write(toFile: plistPath, atomically: true)
            LaunchAgentWriter.loadAgent(at: plistPath)
        }
    }

    private func schedulesDirectory() -> String {
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        return (appSupport as NSString).appendingPathComponent("Stone/Schedules")
    }
}
