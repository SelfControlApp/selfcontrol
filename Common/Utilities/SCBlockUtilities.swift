import Foundation

/// Utility methods for checking block state. Used by all three targets.
enum SCBlockUtilities {

    /// Whether any block is currently running (checks the tamper-resistant settings file).
    static func anyBlockIsRunning() -> Bool {
        let settings = SCSettings.shared
        return settings.value(for: "BlockIsRunning") as? Bool ?? false
    }

    /// Whether the current block has expired.
    static func currentBlockIsExpired() -> Bool {
        guard let endDate = SCSettings.shared.value(for: "BlockEndDate") as? Date else {
            return true
        }
        return endDate.timeIntervalSinceNow <= 0
    }

    /// Whether block enforcement rules exist on the system (pf anchor or hosts entries).
    static func blockRulesFoundOnSystem() -> Bool {
        // Check pf anchor
        let pfAnchorPath = "/etc/pf.anchors/\(StoneConstants.pfAnchorName)"
        if FileManager.default.fileExists(atPath: pfAnchorPath) {
            return true
        }

        // Check hosts file for our sentinel
        if let hostsContent = try? String(contentsOfFile: "/etc/hosts", encoding: .utf8) {
            if hostsContent.contains(StoneConstants.hostsSentinelBegin) {
                return true
            }
        }

        return false
    }

    /// Clear block state from settings (does not remove enforcement rules).
    static func removeBlockFromSettings() {
        let settings = SCSettings.shared
        settings.setValue(false, for: "BlockIsRunning")
        settings.setValue(nil, for: "BlockEndDate")
        settings.setValue(nil, for: "ActiveBlocklist")
        settings.setValue(nil, for: "ActiveBlockAsWhitelist")
        settings.synchronize()
    }
}
