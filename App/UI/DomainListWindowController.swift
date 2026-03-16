import Cocoa

final class DomainListWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

    private let defaults = UserDefaults.standard
    private var domainList: [String] = []
    private let tableView = NSTableView()
    private let quickAddField = NSTextField()
    private let removeButton: NSButton

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 320, height: 250)

        removeButton = NSButton(title: "Remove", target: nil, action: nil)

        super.init(window: window)

        removeButton.target = self
        removeButton.action = #selector(removeDomain(_:))

        loadDomainList()
        setupUI()
        updateWindowTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        // Quick-add text field at top
        quickAddField.frame = NSRect(x: 10, y: 366, width: 460, height: 24)
        quickAddField.placeholderString = "Type a domain and press Enter to add"
        quickAddField.autoresizingMask = [.width, .maxYMargin]
        quickAddField.delegate = self
        quickAddField.target = self
        quickAddField.action = #selector(quickAdd(_:))
        contentView.addSubview(quickAddField)

        // Scroll view + table
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 44, width: 480, height: 318))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("domain"))
        column.title = "Domain"
        column.isEditable = true
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 22

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        // Button bar
        let addButton = NSButton(title: "Add", target: self, action: #selector(addDomain(_:)))
        addButton.frame = NSRect(x: 10, y: 10, width: 80, height: 24)
        addButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        contentView.addSubview(addButton)

        removeButton.frame = NSRect(x: 100, y: 10, width: 80, height: 24)
        removeButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        contentView.addSubview(removeButton)
    }

    // MARK: - Data

    private func loadDomainList() {
        domainList = defaults.stringArray(forKey: "Blocklist") ?? []
    }

    private func saveDomainList() {
        defaults.set(domainList, forKey: "Blocklist")
        NotificationCenter.default.post(name: NSNotification.Name("SCConfigurationChangedNotification"), object: self)
    }

    func updateWindowTitle() {
        let isAllowlist = defaults.bool(forKey: "BlockAsWhitelist")
        window?.title = isAllowlist ? "Domain Allowlist" : "Domain Blocklist"
    }

    func refreshDomainList() {
        let reload = {
            self.window?.makeFirstResponder(nil)
            self.loadDomainList()
            self.tableView.reloadData()
        }
        if Thread.isMainThread { reload() } else { DispatchQueue.main.sync { reload() } }
    }

    // MARK: - Window Lifecycle

    override func showWindow(_ sender: Any?) {
        window?.makeKeyAndOrderFront(sender)
        if domainList.isEmpty && !SCBlockUtilities.anyBlockIsRunning() {
            addDomain(self)
        }
        updateWindowTitle()
    }

    func windowWillClose(_ notification: Notification) {
        saveDomainList()
    }

    // MARK: - Actions

    @objc private func addDomain(_ sender: Any) {
        domainList.append("")
        saveDomainList()
        tableView.reloadData()
        let lastRow = domainList.count - 1
        tableView.selectRowIndexes(IndexSet(integer: lastRow), byExtendingSelection: false)
        tableView.editColumn(0, row: lastRow, with: nil, select: true)
    }

    @objc private func removeDomain(_ sender: Any) {
        if SCBlockUtilities.anyBlockIsRunning() { return }
        let selected = tableView.selectedRowIndexes
        guard !selected.isEmpty else { return }
        tableView.abortEditing()
        for index in selected.sorted().reversed() {
            guard index < domainList.count else { continue }
            domainList.remove(at: index)
        }
        saveDomainList()
        tableView.reloadData()
    }

    @objc private func quickAdd(_ sender: NSTextField) {
        let text = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if !domainList.contains(text) {
            domainList.append(text)
            saveDomainList()
            tableView.reloadData()
        }
        sender.stringValue = ""
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        removeButton.isEnabled = !SCBlockUtilities.anyBlockIsRunning()
        return domainList.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0, row < domainList.count else { return nil }
        return domainList[row]
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard row >= 0, row < domainList.count, let newValue = object as? String else { return }
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            domainList.remove(at: row)
        } else {
            domainList[row] = trimmed
        }
        saveDomainList()
        tableView.reloadData()
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        return !SCBlockUtilities.anyBlockIsRunning()
    }
}
