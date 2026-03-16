import Cocoa

/// Main window shown when no block is running. Programmatic Cocoa UI.
final class MainWindowController: NSWindowController {
    private weak var appController: AppController?
    private let defaults = UserDefaults.standard

    private var durationSlider: NSSlider!
    private var durationLabel: NSTextField!
    private var startButton: NSButton!
    private var editBlocklistButton: NSButton!
    private var schedulesButton: NSButton!
    private var modeControl: NSSegmentedControl!
    private var summaryLabel: NSTextField!

    init(appController: AppController) {
        self.appController = appController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Stone"
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildUI()
        updateControls(addingBlock: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build UI

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        let padding: CGFloat = 20
        var y: CGFloat = 280

        // Title
        let titleLabel = makeLabel("Stone", fontSize: 22, bold: true)
        titleLabel.frame = NSRect(x: padding, y: y, width: 380, height: 30)
        contentView.addSubview(titleLabel)
        y -= 50

        // Duration label
        durationLabel = makeLabel("60 minutes", fontSize: 14, bold: false)
        durationLabel.frame = NSRect(x: padding, y: y, width: 380, height: 20)
        contentView.addSubview(durationLabel)
        y -= 30

        // Duration slider
        durationSlider = NSSlider(value: Double(defaults.integer(forKey: "BlockDuration")),
                                  minValue: 1,
                                  maxValue: Double(defaults.integer(forKey: "MaxBlockLength")),
                                  target: self,
                                  action: #selector(sliderChanged(_:)))
        durationSlider.frame = NSRect(x: padding, y: y, width: 380, height: 24)
        contentView.addSubview(durationSlider)
        y -= 40

        // Blocklist/Allowlist toggle
        modeControl = NSSegmentedControl(labels: ["Blocklist", "Allowlist"], trackingMode: .selectOne, target: self, action: #selector(modeChanged(_:)))
        modeControl.frame = NSRect(x: padding, y: y, width: 200, height: 24)
        modeControl.selectedSegment = defaults.bool(forKey: "BlockAsWhitelist") ? 1 : 0
        contentView.addSubview(modeControl)
        y -= 30

        // Summary label
        summaryLabel = makeLabel("", fontSize: 12, bold: false)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.frame = NSRect(x: padding, y: y, width: 380, height: 18)
        contentView.addSubview(summaryLabel)
        y -= 40

        // Start Block button
        startButton = NSButton(title: "Start Block", target: self, action: #selector(startBlockClicked(_:)))
        startButton.bezelStyle = .rounded
        startButton.frame = NSRect(x: padding, y: y, width: 120, height: 32)
        startButton.keyEquivalent = "\r"
        contentView.addSubview(startButton)

        // Edit Blocklist button
        editBlocklistButton = NSButton(title: "Edit Blocklist...", target: self, action: #selector(editBlocklistClicked(_:)))
        editBlocklistButton.bezelStyle = .rounded
        editBlocklistButton.frame = NSRect(x: 160, y: y, width: 130, height: 32)
        contentView.addSubview(editBlocklistButton)

        // Schedules button
        schedulesButton = NSButton(title: "Schedules...", target: self, action: #selector(schedulesClicked(_:)))
        schedulesButton.bezelStyle = .rounded
        schedulesButton.frame = NSRect(x: 305, y: y, width: 100, height: 32)
        contentView.addSubview(schedulesButton)

        updateSliderDisplay()
        updateSummary()
    }

    // MARK: - Actions

    @objc private func sliderChanged(_ sender: NSSlider) {
        defaults.set(sender.integerValue, forKey: "BlockDuration")
        updateSliderDisplay()
    }

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        defaults.set(sender.selectedSegment == 1, forKey: "BlockAsWhitelist")
        updateControls(addingBlock: false)
    }

    @objc private func startBlockClicked(_ sender: NSButton) {
        defaults.set(durationSlider.integerValue, forKey: "BlockDuration")
        appController?.startBlock()
    }

    @objc private func editBlocklistClicked(_ sender: NSButton) {
        appController?.showDomainList()
    }

    @objc private func schedulesClicked(_ sender: NSButton) {
        appController?.showSchedules()
    }

    // MARK: - Update Display

    func updateControls(addingBlock: Bool) {
        let blocklist = defaults.stringArray(forKey: "Blocklist") ?? []
        let isAllowlist = defaults.bool(forKey: "BlockAsWhitelist")
        let duration = defaults.integer(forKey: "BlockDuration")

        let canStart = duration > 0 && (!blocklist.isEmpty || isAllowlist) && !addingBlock

        startButton?.isEnabled = canStart
        durationSlider?.isEnabled = !addingBlock
        editBlocklistButton?.isEnabled = !addingBlock
        startButton?.title = addingBlock ? "Starting Block..." : "Start Block"

        let listType = isAllowlist ? "Allowlist" : "Blocklist"
        editBlocklistButton?.title = "Edit \(listType)..."
        modeControl?.selectedSegment = isAllowlist ? 1 : 0

        updateSliderDisplay()
        updateSummary()
    }

    private func updateSliderDisplay() {
        guard let slider = durationSlider, let label = durationLabel else { return }
        let minutes = slider.integerValue
        if let ac = appController {
            label.stringValue = ac.formattedDuration(minutes: minutes)
        } else {
            let h = minutes / 60
            let m = minutes % 60
            label.stringValue = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        }
    }

    private func updateSummary() {
        let blocklist = defaults.stringArray(forKey: "Blocklist") ?? []
        let isAllowlist = defaults.bool(forKey: "BlockAsWhitelist")
        let type = isAllowlist ? "allowlist" : "blocklist"
        summaryLabel?.stringValue = "\(blocklist.count) entries in \(type)"
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, fontSize: CGFloat, bold: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        return label
    }
}
