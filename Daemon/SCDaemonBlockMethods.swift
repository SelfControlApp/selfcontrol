import Foundation

/// All block-related logic that runs in the daemon process.
/// Access is serialized via a lock to prevent concurrent modifications.
final class SCDaemonBlockMethods {
    static let shared = SCDaemonBlockMethods()

    private let lock = NSLock()
    private var checkupCount: Int = 0

    // MARK: - Start Block

    func startBlock(controllingUID: uid_t,
                    blocklist: [String],
                    isAllowlist: Bool,
                    endDate: Date,
                    blockSettings: [String: Any]) throws {
        guard lock.lock(before: Date(timeIntervalSinceNow: 5)) else {
            NSLog("SCDaemonBlockMethods: Lock timeout on startBlock")
            throw SCError.blockAlreadyRunning
        }
        defer { lock.unlock() }

        guard !SCBlockUtilities.anyBlockIsRunning() else {
            throw SCError.blockAlreadyRunning
        }

        guard !blocklist.isEmpty || isAllowlist else {
            throw SCError.emptyBlocklist
        }

        guard endDate.timeIntervalSinceNow >= 1 else {
            throw SCError.blockEndDateInPast
        }

        let settings = SCSettings.shared

        // Write block parameters to tamper-resistant settings
        settings.setValue(blocklist, for: "ActiveBlocklist")
        settings.setValue(isAllowlist, for: "ActiveBlockAsWhitelist")
        settings.setValue(endDate, for: "BlockEndDate")

        // Write individual block settings
        for (key, value) in blockSettings {
            settings.setValue(value, for: key)
        }

        // Install enforcement rules
        SCHelperToolUtilities.installBlockRulesFromSettings()

        // Mark block as running
        settings.setValue(true, for: "BlockIsRunning")
        settings.synchronize()

        SCHelperToolUtilities.sendConfigurationChangedNotification()

        NSLog("SCDaemonBlockMethods: Block started with %d entries, ends %@",
              blocklist.count, endDate as NSDate)
    }

    // MARK: - Checkup (called every second by the daemon timer)

    func checkupBlock() {
        checkupCount += 1
        let settings = SCSettings.shared

        let blockIsRunning = settings.value(for: "BlockIsRunning") as? Bool ?? false
        let rulesOnSystem = SCBlockUtilities.blockRulesFoundOnSystem()

        if !blockIsRunning && rulesOnSystem {
            // Tamper detected — block was removed from settings but rules remain
            NSLog("SCDaemonBlockMethods: Tamper detected — removing orphaned rules")
            SCHelperToolUtilities.removeBlock()
            return
        }

        if blockIsRunning && SCBlockUtilities.currentBlockIsExpired() {
            // Block has expired — clean up
            NSLog("SCDaemonBlockMethods: Block expired, removing")
            SCHelperToolUtilities.removeBlock()
            return
        }

        // Every 15 seconds, verify block integrity
        if blockIsRunning && checkupCount % 15 == 0 {
            checkBlockIntegrity()
        }
    }

    // MARK: - Update Operations

    func updateBlocklist(_ newBlocklist: [String]) throws {
        guard lock.lock(before: Date(timeIntervalSinceNow: 5)) else { return }
        defer { lock.unlock() }

        guard SCBlockUtilities.anyBlockIsRunning() else {
            throw SCError.blockNotRunning
        }

        let settings = SCSettings.shared
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
        manager.enterAppendMode()
        manager.addEntries(from: newBlocklist)
        manager.finalizeBlock()

        // Update the stored blocklist
        var current = settings.value(for: "ActiveBlocklist") as? [String] ?? []
        current.append(contentsOf: newBlocklist)
        settings.setValue(current, for: "ActiveBlocklist")
        settings.synchronize()

        SCHelperToolUtilities.sendConfigurationChangedNotification()
    }

    func updateBlockEndDate(_ newEndDate: Date) throws {
        guard lock.lock(before: Date(timeIntervalSinceNow: 5)) else { return }
        defer { lock.unlock() }

        guard SCBlockUtilities.anyBlockIsRunning() else {
            throw SCError.blockNotRunning
        }

        let settings = SCSettings.shared
        guard let currentEnd = settings.value(for: "BlockEndDate") as? Date else {
            throw SCError.blockNotRunning
        }

        guard newEndDate > currentEnd else {
            throw SCError.updateEndDateInvalid
        }

        // Max extension: 24 hours beyond current end date
        let maxEnd = currentEnd.addingTimeInterval(24 * 60 * 60)
        guard newEndDate <= maxEnd else {
            throw SCError.updateEndDateTooFar
        }

        settings.setValue(newEndDate, for: "BlockEndDate")
        settings.synchronize()

        SCHelperToolUtilities.sendConfigurationChangedNotification()
    }

    // MARK: - Integrity Check

    func checkBlockIntegrity() {
        guard SCBlockUtilities.anyBlockIsRunning() else { return }

        let pfPresent = PacketFilter.blockFoundInPF()
        let hostsPresent = HostFileBlockerSet().isBlockActive()

        if !pfPresent || !hostsPresent {
            NSLog("SCDaemonBlockMethods: Block integrity failed (pf=%d, hosts=%d), re-applying",
                  pfPresent ? 1 : 0, hostsPresent ? 1 : 0)
            SCHelperToolUtilities.installBlockRulesFromSettings()
        }
    }
}
