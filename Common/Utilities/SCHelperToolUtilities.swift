import Foundation

/// Bridge between settings and block enforcement. Used by the daemon.
enum SCHelperToolUtilities {

    /// Read block config from SCSettings and install enforcement rules.
    static func installBlockRulesFromSettings() {
        let settings = SCSettings.shared
        guard let blocklist = settings.value(for: "ActiveBlocklist") as? [String] else {
            NSLog("SCHelperToolUtilities: No active blocklist in settings")
            return
        }

        let isAllowlist = settings.value(for: "ActiveBlockAsWhitelist") as? Bool ?? false
        let evalSubdomains = settings.value(for: "EvaluateCommonSubdomains") as? Bool ?? true
        let linkedDomains = settings.value(for: "IncludeLinkedDomains") as? Bool ?? true
        let allowLocal = settings.value(for: "AllowLocalNetworks") as? Bool ?? true

        let manager = BlockManager(
            isAllowlist: isAllowlist,
            allowLocal: allowLocal,
            includeCommonSubdomains: evalSubdomains,
            includeLinkedDomains: linkedDomains
        )

        manager.prepareToAddBlock()
        manager.addEntries(from: blocklist)
        manager.finalizeBlock()
    }

    /// Remove all block enforcement and clear settings.
    static func removeBlock() {
        let settings = SCSettings.shared
        let isAllowlist = settings.value(for: "ActiveBlockAsWhitelist") as? Bool ?? false

        let manager = BlockManager(isAllowlist: isAllowlist)
        manager.clearBlock()

        if settings.value(for: "ClearCaches") as? Bool ?? true {
            clearBrowserCaches()
            clearOSDNSCache()
        }

        SCBlockUtilities.removeBlockFromSettings()
        sendConfigurationChangedNotification()
    }

    /// Clear browser caches (Safari, Chrome, Firefox).
    static func clearBrowserCaches() {
        let fm = FileManager.default
        let home = NSHomeDirectory()

        let cachePaths = [
            "\(home)/Library/Caches/com.apple.Safari",
            "\(home)/Library/Caches/Google/Chrome",
            "\(home)/Library/Caches/Firefox/Profiles",
        ]

        for path in cachePaths {
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
            }
        }
    }

    /// Flush the OS DNS cache.
    static func clearOSDNSCache() {
        runCommand("/usr/bin/dscacheutil", arguments: ["-flushcache"])
        runCommand("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
    }

    /// Post a configuration changed notification to all processes.
    static func sendConfigurationChangedNotification() {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(StoneConstants.configurationChangedNotification),
            object: nil
        )
    }

    private static func runCommand(_ path: String, arguments: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
    }
}
