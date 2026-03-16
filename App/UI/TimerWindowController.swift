import Cocoa

/// Window shown while a block is running, displaying the countdown timer.
final class TimerWindowController: NSWindowController {
    private weak var appController: AppController?
    private let settings = SCSettings.shared
    private let defaults = UserDefaults.standard

    private var timerLabel: NSTextField!
    private var addToBlockButton: NSButton!
    private var extendButton: NSPopUpButton!
    private var timer: Timer?
    private var blockEndDate: Date?

    // Add-to-block sheet
    private var addSheet: NSWindow?
    private var addTextField: NSTextField?

    init(appController: AppController) {
        self.appController = appController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Stone — Block Active"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
        buildUI()
        loadBlockEndDate()
        startTimer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build UI

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        // Timer label
        timerLabel = NSTextField(labelWithString: "00:00:00")
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 48, weight: .medium)
        timerLabel.alignment = .center
        timerLabel.frame = NSRect(x: 20, y: 100, width: 300, height: 60)
        contentView.addSubview(timerLabel)

        // Add to Block button
        addToBlockButton = NSButton(title: "Add to Block...", target: self, action: #selector(addToBlockClicked(_:)))
        addToBlockButton.bezelStyle = .rounded
        addToBlockButton.frame = NSRect(x: 20, y: 30, width: 140, height: 32)
        contentView.addSubview(addToBlockButton)

        // Extend Time popup
        extendButton = NSPopUpButton(frame: NSRect(x: 180, y: 30, width: 140, height: 32), pullsDown: true)
        extendButton.addItem(withTitle: "Extend Time")
        extendButton.addItems(withTitles: ["+15 minutes", "+30 minutes", "+1 hour"])
        extendButton.target = self
        extendButton.action = #selector(extendTimeSelected(_:))
        contentView.addSubview(extendButton)

        // Disable add-to-block if allowlist mode
        let isAllowlist = settings.value(for: "ActiveBlockAsWhitelist") as? Bool ?? false
        addToBlockButton.isEnabled = !isAllowlist
    }

    // MARK: - Timer

    private func loadBlockEndDate() {
        blockEndDate = settings.value(for: "BlockEndDate") as? Date
    }

    private func startTimer() {
        updateTimerDisplay()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimerDisplay()
        }
    }

    private func updateTimerDisplay() {
        guard let endDate = blockEndDate else {
            timerLabel.stringValue = "Block not active"
            return
        }

        let remaining = Int(endDate.timeIntervalSinceNow)

        if remaining <= 0 {
            timerLabel.stringValue = "Finishing..."
            appController?.refreshUserInterface()
            return
        }

        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        timerLabel.stringValue = String(format: "%02d:%02d:%02d", hours, minutes, seconds)

        // Badge the dock icon
        if defaults.bool(forKey: "BadgeIconEnabled") {
            let badgeMins = seconds > 0 && minutes < 59 ? minutes + 1 : minutes
            NSApp.dockTile.badgeLabel = String(format: "%02d:%02d", hours, badgeMins)
        }
    }

    func blockEnded() {
        timer?.invalidate()
        timer = nil
        timerLabel.stringValue = "Block not active"
        NSApp.dockTile.badgeLabel = nil
    }

    func configurationChanged() {
        loadBlockEndDate()
        updateTimerDisplay()
    }

    // MARK: - Add to Block

    @objc private func addToBlockClicked(_ sender: NSButton) {
        let sheet = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        sheet.title = "Add to Block"

        let cv = sheet.contentView!

        let label = NSTextField(labelWithString: "Enter domain to block:")
        label.frame = NSRect(x: 20, y: 80, width: 260, height: 20)
        cv.addSubview(label)

        let textField = NSTextField(frame: NSRect(x: 20, y: 50, width: 260, height: 24))
        textField.placeholderString = "example.com"
        cv.addSubview(textField)
        addTextField = textField

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelAddSheet(_:)))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.frame = NSRect(x: 100, y: 12, width: 80, height: 32)
        cancelBtn.keyEquivalent = "\u{1b}" // Escape
        cv.addSubview(cancelBtn)

        let addBtn = NSButton(title: "Add", target: self, action: #selector(confirmAddSheet(_:)))
        addBtn.bezelStyle = .rounded
        addBtn.frame = NSRect(x: 190, y: 12, width: 80, height: 32)
        addBtn.keyEquivalent = "\r"
        cv.addSubview(addBtn)

        addSheet = sheet

        window?.beginSheet(sheet, completionHandler: nil)
    }

    @objc private func cancelAddSheet(_ sender: Any) {
        guard let sheet = addSheet else { return }
        window?.endSheet(sheet)
        addSheet = nil
        addTextField = nil
    }

    @objc private func confirmAddSheet(_ sender: Any) {
        guard let sheet = addSheet, let text = addTextField?.stringValue, !text.isEmpty else { return }
        appController?.addToBlocklist(text)
        window?.endSheet(sheet)
        addSheet = nil
        addTextField = nil
    }

    // MARK: - Extend Block

    @objc private func extendTimeSelected(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        let minuteValues = [0, 15, 30, 60] // index 0 is the title
        guard index > 0, index < minuteValues.count else { return }
        appController?.extendBlock(minutes: minuteValues[index])
        // Reset popup to title
        sender.selectItem(at: 0)
    }

    // MARK: - Window Delegate

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

// MARK: - NSWindowDelegate
extension TimerWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Cannot close while block is running
        if SCBlockUtilities.anyBlockIsRunning() {
            return false
        }
        return true
    }
}
