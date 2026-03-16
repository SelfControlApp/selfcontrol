import Cocoa

/// Central controller that manages block start/stop flow and window lifecycle.
final class AppController: NSObject {
    private(set) var mainWindowController: MainWindowController?
    private(set) var timerWindowController: TimerWindowController?

    private let defaults = UserDefaults.standard
    private let settings = SCSettings.shared
    private let xpc = SCXPCClient()
    private let refreshLock = NSLock()

    private var blockIsOn = false
    var addingBlock = false

    // MARK: - Setup

    func start() {
        defaults.register(defaults: StoneConstants.defaultUserDefaults)

        // Force initial state mismatch so refreshUserInterface applies the correct state
        blockIsOn = !SCBlockUtilities.anyBlockIsRunning()

        observeNotifications()
        refreshUserInterface()
    }

    private func observeNotifications() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleConfigurationChanged),
            name: NSNotification.Name(StoneConstants.configurationChangedNotification),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigurationChanged),
            name: NSNotification.Name(StoneConstants.configurationChangedNotification),
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notification Handling

    @objc private func handleConfigurationChanged() {
        settings.synchronize()

        // Clean empty strings from defaults blocklist
        let raw = defaults.stringArray(forKey: "Blocklist") ?? []
        defaults.set(SCMiscUtilities.cleanBlocklist(raw), forKey: "Blocklist")

        // Notify timer window
        if let twc = timerWindowController {
            DispatchQueue.main.async { twc.configurationChanged() }
        }

        refreshUserInterface()
    }

    // MARK: - UI Refresh

    func refreshUserInterface() {
        if !Thread.isMainThread {
            DispatchQueue.main.sync { self.refreshUserInterface() }
            return
        }

        guard refreshLock.try() else { return }
        defer { refreshLock.unlock() }

        let blockWasOn = blockIsOn
        blockIsOn = SCBlockUtilities.anyBlockIsRunning()

        if blockIsOn {
            if !blockWasOn {
                closeTimerWindow()
                showTimerWindow()
                mainWindowController?.close()
            }
        } else {
            if blockWasOn {
                timerWindowController?.blockEnded()
                closeTimerWindow()
                showMainWindow()
                NSApp.dockTile.badgeLabel = nil
            }

            mainWindowController?.updateControls(addingBlock: addingBlock)
        }
    }

    // MARK: - Window Management

    func showMainWindow() {
        if mainWindowController == nil {
            mainWindowController = MainWindowController(appController: self)
        }
        mainWindowController?.window?.center()
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showTimerWindow() {
        if timerWindowController == nil {
            timerWindowController = TimerWindowController(appController: self)
        }
        timerWindowController?.window?.center()
        timerWindowController?.showWindow(nil)
    }

    private func closeTimerWindow() {
        timerWindowController?.close()
        timerWindowController = nil
    }

    // MARK: - Secondary Windows

    private var domainListWindowController: DomainListWindowController?
    private var scheduleListWindowController: ScheduleListWindowController?
    private var preferencesWindowController: PreferencesWindowController?

    func showDomainList() {
        if domainListWindowController == nil {
            domainListWindowController = DomainListWindowController()
        }
        domainListWindowController?.window?.center()
        domainListWindowController?.showWindow(nil)
    }

    func showSchedules() {
        if scheduleListWindowController == nil {
            scheduleListWindowController = ScheduleListWindowController()
        }
        scheduleListWindowController?.window?.center()
        scheduleListWindowController?.showWindow(nil)
    }

    func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.window?.center()
        preferencesWindowController?.showWindow(nil)
    }

    // MARK: - Start Block

    func startBlock() {
        guard !SCBlockUtilities.anyBlockIsRunning() else {
            showAlert(message: "A block is already running.", info: "Wait for the current block to end before starting a new one.")
            return
        }

        let blocklist = defaults.stringArray(forKey: "Blocklist") ?? []
        let isAllowlist = defaults.bool(forKey: "BlockAsWhitelist")

        if blocklist.isEmpty && !isAllowlist {
            showAlert(message: "Blocklist is empty.", info: "Add at least one entry to your blocklist before starting a block.")
            return
        }

        let duration = defaults.integer(forKey: "BlockDuration")
        if duration <= 0 {
            return
        }

        // Long block warning
        if !showLongBlockWarningIfNeeded(duration: duration) {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            installBlock()
        }
    }

    private func showLongBlockWarningIfNeeded(duration: Int) -> Bool {
        let longThreshold = 2880 // 2 days
        let firstTimeThreshold = 480 // 8 hours
        let isFirstBlock = !defaults.bool(forKey: "FirstBlockStarted")

        let showWarning = duration >= longThreshold || (isFirstBlock && duration >= firstTimeThreshold)
        guard showWarning else { return true }

        if defaults.bool(forKey: "SuppressLongBlockWarning") {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "That's a long block!"
        alert.informativeText = "Remember that once you start the block, you can't turn it off until the timer expires in \(formattedDuration(minutes: duration)). Consider starting a shorter block first."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Start Block Anyway")
        alert.showsSuppressionButton = true

        let response = alert.runModal()
        if alert.suppressionButton?.state == .on {
            defaults.set(true, forKey: "SuppressLongBlockWarning")
        }
        return response != .alertFirstButtonReturn
    }

    // MARK: - Install Block

    private func installBlock() {
        addingBlock = true
        DispatchQueue.main.async { self.refreshUserInterface() }

        xpc.installDaemon { [self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self.showAlert(message: "Failed to install daemon.", info: error.localizedDescription)
                    self.addingBlock = false
                    self.refreshUserInterface()
                }
                return
            }

            let blockDurationSecs = TimeInterval(max(defaults.integer(forKey: "BlockDuration") * 60, 0))
            let endDate = Date(timeIntervalSinceNow: blockDurationSecs)
            let blocklist = defaults.stringArray(forKey: "Blocklist") ?? []
            let isAllowlist = defaults.bool(forKey: "BlockAsWhitelist")

            settings.synchronize()

            let blockSettings: [String: Any] = [
                "ClearCaches": defaults.bool(forKey: "ClearCaches"),
                "AllowLocalNetworks": defaults.bool(forKey: "AllowLocalNetworks"),
                "EvaluateCommonSubdomains": defaults.bool(forKey: "EvaluateCommonSubdomains"),
                "IncludeLinkedDomains": defaults.bool(forKey: "IncludeLinkedDomains"),
                "BlockSoundShouldPlay": defaults.bool(forKey: "BlockSoundShouldPlay"),
                "BlockSound": defaults.integer(forKey: "BlockSound"),
                "EnableErrorReporting": defaults.bool(forKey: "EnableErrorReporting"),
            ]

            xpc.refreshConnectionAndRun { [self] in
                xpc.startBlock(
                    controllingUID: getuid(),
                    blocklist: blocklist,
                    isAllowlist: isAllowlist,
                    endDate: endDate,
                    blockSettings: blockSettings
                ) { error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.showAlert(message: "Failed to start block.", info: error.localizedDescription)
                        }
                    } else {
                        self.defaults.set(true, forKey: "FirstBlockStarted")
                    }

                    self.settings.synchronize()
                    self.addingBlock = false
                    self.refreshUserInterface()
                }
            }
        }
    }

    // MARK: - Modify Running Block

    func addToBlocklist(_ entry: String) {
        guard SCBlockUtilities.anyBlockIsRunning() else { return }

        let cleaned = SCMiscUtilities.cleanBlocklist([entry])
        guard !cleaned.isEmpty else { return }

        var list = defaults.stringArray(forKey: "Blocklist") ?? []
        for item in cleaned where !list.contains(item) {
            list.append(item)
        }
        defaults.set(list, forKey: "Blocklist")
        settings.synchronize()

        xpc.refreshConnectionAndRun { [self] in
            xpc.updateBlocklist(list) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.showAlert(message: "Failed to update blocklist.", info: error.localizedDescription)
                    }
                }
            }
        }
    }

    func extendBlock(minutes: Int) {
        guard SCBlockUtilities.anyBlockIsRunning(), minutes > 0 else { return }

        let maxLength = defaults.integer(forKey: "MaxBlockLength")
        let capped = min(minutes, maxLength)

        guard let oldEnd = settings.value(for: "BlockEndDate") as? Date else { return }
        let newEnd = oldEnd.addingTimeInterval(TimeInterval(capped * 60))

        settings.synchronize()

        xpc.refreshConnectionAndRun { [self] in
            guard !SCBlockUtilities.currentBlockIsExpired(),
                  oldEnd.timeIntervalSinceNow >= 1 else { return }

            xpc.updateBlockEndDate(newEnd) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.showAlert(message: "Failed to extend block.", info: error.localizedDescription)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func showAlert(message: String, info: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func formattedDuration(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 {
            return "\(h)h \(m)m"
        } else if h > 0 {
            return "\(h)h"
        } else {
            return "\(m)m"
        }
    }
}
