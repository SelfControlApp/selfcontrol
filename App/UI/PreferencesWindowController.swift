import Cocoa

final class PreferencesWindowController: NSWindowController {

    private let defaults = UserDefaults.standard

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"

        super.init(window: window)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let tabView = NSTabView(frame: contentView.bounds)
        tabView.autoresizingMask = [.width, .height]

        // General tab
        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = "General"
        generalItem.view = makeGeneralTab()
        tabView.addTabViewItem(generalItem)

        // Advanced tab
        let advancedItem = NSTabViewItem(identifier: "advanced")
        advancedItem.label = "Advanced"
        advancedItem.view = makeAdvancedTab()
        tabView.addTabViewItem(advancedItem)

        contentView.addSubview(tabView)
    }

    // MARK: - General Tab

    private func makeGeneralTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 260))
        var y: CGFloat = 220

        // Play sound checkbox
        let soundCheck = NSButton(checkboxWithTitle: "Play sound when block starts", target: self, action: #selector(toggleBlockSound(_:)))
        soundCheck.frame = NSRect(x: 20, y: y, width: 300, height: 22)
        soundCheck.state = defaults.bool(forKey: "BlockSoundShouldPlay") ? .on : .off
        view.addSubview(soundCheck)

        // Sound picker
        y -= 30
        let soundLabel = NSTextField(labelWithString: "Sound:")
        soundLabel.frame = NSRect(x: 40, y: y, width: 50, height: 22)
        view.addSubview(soundLabel)

        let soundPopup = NSPopUpButton(frame: NSRect(x: 94, y: y, width: 180, height: 24), pullsDown: false)
        soundPopup.addItems(withTitles: StoneConstants.blockSoundNames)
        let savedIndex = defaults.integer(forKey: "BlockSound")
        if savedIndex >= 0 && savedIndex < StoneConstants.blockSoundNames.count {
            soundPopup.selectItem(at: savedIndex)
        }
        soundPopup.target = self
        soundPopup.action = #selector(changeBlockSound(_:))
        view.addSubview(soundPopup)

        // Badge icon checkbox
        y -= 36
        let badgeCheck = NSButton(checkboxWithTitle: "Show icon badge when block is running", target: self, action: #selector(toggleBadgeIcon(_:)))
        badgeCheck.frame = NSRect(x: 20, y: y, width: 300, height: 22)
        badgeCheck.state = defaults.bool(forKey: "BadgeIconEnabled") ? .on : .off
        view.addSubview(badgeCheck)

        // Max block length slider
        y -= 40
        let sliderLabel = NSTextField(labelWithString: "Max block length:")
        sliderLabel.frame = NSRect(x: 20, y: y, width: 120, height: 22)
        view.addSubview(sliderLabel)

        let valueLabel = NSTextField(labelWithString: formatMinutes(defaults.integer(forKey: "MaxBlockLength")))
        valueLabel.frame = NSRect(x: 330, y: y, width: 80, height: 22)
        valueLabel.tag = 999
        view.addSubview(valueLabel)

        y -= 24
        let slider = NSSlider(value: Double(defaults.integer(forKey: "MaxBlockLength")),
                              minValue: 1, maxValue: 1440,
                              target: self, action: #selector(changeMaxBlockLength(_:)))
        slider.frame = NSRect(x: 20, y: y, width: 390, height: 22)
        slider.tag = 998
        view.addSubview(slider)

        return view
    }

    // MARK: - Advanced Tab

    private func makeAdvancedTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 260))
        var y: CGFloat = 220

        let items: [(String, String)] = [
            ("Evaluate common subdomains", "EvaluateCommonSubdomains"),
            ("Include linked domains", "IncludeLinkedDomains"),
            ("Clear browser caches on block", "ClearCaches"),
            ("Allow local network connections", "AllowLocalNetworks"),
            ("Enable error reporting", "EnableErrorReporting"),
        ]

        for (title, key) in items {
            let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(toggleAdvancedOption(_:)))
            checkbox.frame = NSRect(x: 20, y: y, width: 360, height: 22)
            checkbox.state = defaults.bool(forKey: key) ? .on : .off
            checkbox.identifier = NSUserInterfaceItemIdentifier(key)
            view.addSubview(checkbox)
            y -= 32
        }

        return view
    }

    // MARK: - Actions

    @objc private func toggleBlockSound(_ sender: NSButton) {
        defaults.set(sender.state == .on, forKey: "BlockSoundShouldPlay")
    }

    @objc private func changeBlockSound(_ sender: NSPopUpButton) {
        defaults.set(sender.indexOfSelectedItem, forKey: "BlockSound")
    }

    @objc private func toggleBadgeIcon(_ sender: NSButton) {
        defaults.set(sender.state == .on, forKey: "BadgeIconEnabled")
    }

    @objc private func changeMaxBlockLength(_ sender: NSSlider) {
        let minutes = sender.integerValue
        defaults.set(minutes, forKey: "MaxBlockLength")
        // Update the value label (sibling with tag 999)
        if let label = sender.superview?.viewWithTag(999) as? NSTextField {
            label.stringValue = formatMinutes(minutes)
        }
    }

    @objc private func toggleAdvancedOption(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue else { return }
        defaults.set(sender.state == .on, forKey: key)
    }

    // MARK: - Helpers

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
}
