import Foundation

/// Cross-process settings store backed by a root-owned binary plist.
/// The daemon is the primary writer; the app and CLI are read-only clients.
/// Changes propagate via DistributedNotificationCenter.
final class SCSettings {
    static let shared = SCSettings()

    private var settings: [String: Any] = [:]
    private var versionNumber: Int = 0
    private var lastUpdate: Date = .distantPast
    private let filePath: String
    private let isReadOnly: Bool
    private var syncTimer: Timer?
    private let lock = NSLock()

    init() {
        self.filePath = SCMiscUtilities.settingsFilePath()
        self.isReadOnly = geteuid() != 0
        loadFromDisk()
        startObservingNotifications()
        startSyncTimer()
    }

    // MARK: - Public API

    func value(for key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return settings[key]
    }

    func setValue(_ value: Any?, for key: String) {
        guard !isReadOnly else {
            NSLog("SCSettings: Ignoring write to '%@' (read-only mode)", key)
            return
        }
        lock.lock()
        versionNumber += 1
        lastUpdate = Date()
        if let value = value {
            settings[key] = value
        } else {
            settings.removeValue(forKey: key)
        }
        lock.unlock()
    }

    func synchronize() {
        if isReadOnly {
            loadFromDisk()
        } else {
            writeToDisk()
        }
    }

    func dictionaryRepresentation() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        return settings
    }

    // MARK: - Disk I/O

    private func loadFromDisk() {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: filePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data, options: .mutableContainersAndLeaves, format: nil
              ) as? [String: Any] else {
            return
        }

        let diskVersion = plist["SettingsVersionNumber"] as? Int ?? 0
        let diskUpdate = plist["LastSettingsUpdate"] as? Date ?? .distantPast

        // Only apply disk values if they're newer
        if diskVersion > versionNumber || (diskVersion == versionNumber && diskUpdate > lastUpdate) {
            settings = plist
            versionNumber = diskVersion
            lastUpdate = diskUpdate
        }
    }

    private func writeToDisk() {
        lock.lock()
        var toWrite = settings
        toWrite["SettingsVersionNumber"] = versionNumber
        toWrite["LastSettingsUpdate"] = lastUpdate
        lock.unlock()

        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: toWrite, format: .binary, options: 0
            )
            try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)

            // Set file permissions: root-owned, world-readable
            let fm = FileManager.default
            try fm.setAttributes([
                .posixPermissions: 0o755,
                .ownerAccountID: 0
            ], ofItemAtPath: filePath)
        } catch {
            NSLog("SCSettings: Failed to write settings: %@", error.localizedDescription)
        }

        // Notify other processes
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(StoneConstants.configurationChangedNotification),
            object: nil
        )
    }

    // MARK: - Cross-Process Sync

    private func startObservingNotifications() {
        // [Fix #7] Observe on the main run loop so it fires in the daemon too
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: NSNotification.Name(StoneConstants.configurationChangedNotification),
            object: nil
        )
    }

    @objc private func handleRemoteChange(_ notification: Notification) {
        loadFromDisk()
    }

    private func startSyncTimer() {
        // [Fix #7] Schedule on main run loop so it fires in the daemon
        DispatchQueue.main.async { [weak self] in
            self?.syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                self?.synchronize()
            }
        }
    }

    deinit {
        syncTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
