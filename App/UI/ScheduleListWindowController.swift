import Cocoa

final class ScheduleListWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    private let tableView = NSTableView()
    private var schedules: [SCSchedule] = []

    // Edit sheet controls
    private var editSheet: NSWindow?
    private var nameField: NSTextField?
    private var dayCheckboxes: [NSButton] = []
    private var timePicker: NSDatePicker?
    private var durationField: NSTextField?
    private var blocklistField: NSTextField?
    private var editingSchedule: SCSchedule?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Scheduled Blocks"
        window.minSize = NSSize(width: 500, height: 300)

        super.init(window: window)
        setupUI()
        reloadSchedules()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 44, width: 640, height: 356))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 24

        let enabledCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
        enabledCol.title = "On"
        enabledCol.width = 30; enabledCol.minWidth = 30; enabledCol.maxWidth = 30
        tableView.addTableColumn(enabledCol)

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Name"; nameCol.width = 150
        tableView.addTableColumn(nameCol)

        let daysCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("days"))
        daysCol.title = "Days"; daysCol.width = 180
        tableView.addTableColumn(daysCol)

        let timeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeCol.title = "Time"; timeCol.width = 70
        tableView.addTableColumn(timeCol)

        let durationCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
        durationCol.title = "Duration"; durationCol.width = 80
        tableView.addTableColumn(durationCol)

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        let addButton = NSButton(title: "Add", target: self, action: #selector(addSchedule(_:)))
        addButton.frame = NSRect(x: 10, y: 10, width: 80, height: 24)
        addButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        contentView.addSubview(addButton)

        let editButton = NSButton(title: "Edit", target: self, action: #selector(editSchedule(_:)))
        editButton.frame = NSRect(x: 100, y: 10, width: 80, height: 24)
        editButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        contentView.addSubview(editButton)

        let removeButton = NSButton(title: "Remove", target: self, action: #selector(removeSchedule(_:)))
        removeButton.frame = NSRect(x: 190, y: 10, width: 80, height: 24)
        removeButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        contentView.addSubview(removeButton)
    }

    private func reloadSchedules() {
        schedules = SCScheduleManager.shared.allSchedules()
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func addSchedule(_ sender: Any) {
        editingSchedule = nil
        showEditSheet()
    }

    @objc private func editSchedule(_ sender: Any) {
        let row = tableView.selectedRow
        guard row >= 0, row < schedules.count else { return }
        editingSchedule = schedules[row]
        showEditSheet()
    }

    @objc private func removeSchedule(_ sender: Any) {
        let row = tableView.selectedRow
        guard row >= 0, row < schedules.count else { return }
        SCScheduleManager.shared.removeSchedule(schedules[row])
        SCScheduleManager.shared.syncAllLaunchdAgents()
        reloadSchedules()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return schedules.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0, row < schedules.count, let ident = tableColumn?.identifier.rawValue else { return nil }
        let schedule = schedules[row]
        switch ident {
        case "enabled":
            return schedule.enabled
        case "name":
            return schedule.name
        case "days":
            return daysSummary(for: schedule)
        case "time":
            return String(format: "%02d:%02d", schedule.hour, schedule.minute)
        case "duration":
            if schedule.durationMinutes >= 60 {
                let h = schedule.durationMinutes / 60
                let m = schedule.durationMinutes % 60
                return m > 0 ? "\(h)h \(m)m" : "\(h)h"
            }
            return "\(schedule.durationMinutes)m"
        default:
            return nil
        }
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard row >= 0, row < schedules.count,
              tableColumn?.identifier.rawValue == "enabled",
              let value = object as? Bool else { return }
        var schedule = schedules[row]
        schedule.enabled = value
        SCScheduleManager.shared.updateSchedule(schedule)
        SCScheduleManager.shared.syncAllLaunchdAgents()
        reloadSchedules()
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, dataCellFor tableColumn: NSTableColumn?, row: Int) -> NSCell? {
        guard tableColumn?.identifier.rawValue == "enabled" else { return nil }
        let cell = NSButtonCell()
        cell.setButtonType(.switch)
        cell.title = ""
        return cell
    }

    // MARK: - Edit Sheet

    private func showEditSheet() {
        let sheet = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        sheet.title = editingSchedule != nil ? "Edit Schedule" : "New Schedule"
        editSheet = sheet

        guard let content = sheet.contentView else { return }

        var y: CGFloat = 280
        let fieldX: CGFloat = 90
        let labelW: CGFloat = 80

        // Name
        addLabel("Name:", at: NSPoint(x: 10, y: y), in: content, width: labelW)
        let nf = NSTextField(frame: NSRect(x: fieldX, y: y, width: 330, height: 22))
        content.addSubview(nf)
        nameField = nf

        // Days
        y -= 36
        addLabel("Days:", at: NSPoint(x: 10, y: y), in: content, width: labelW)
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var checkboxes: [NSButton] = []
        for i in 0..<7 {
            let cb = NSButton(checkboxWithTitle: dayNames[i], target: nil, action: nil)
            cb.frame = NSRect(x: fieldX + CGFloat(i) * 48, y: y, width: 46, height: 22)
            cb.tag = 100 + i
            content.addSubview(cb)
            checkboxes.append(cb)
        }
        dayCheckboxes = checkboxes

        // Time
        y -= 36
        addLabel("Time:", at: NSPoint(x: 10, y: y), in: content, width: labelW)
        let tp = NSDatePicker(frame: NSRect(x: fieldX, y: y, width: 100, height: 22))
        tp.datePickerStyle = .textFieldAndStepper
        tp.datePickerElements = .hourMinute
        var comps = DateComponents()
        comps.hour = 9; comps.minute = 0; comps.year = 2025; comps.month = 1; comps.day = 1
        tp.dateValue = Calendar.current.date(from: comps) ?? Date()
        content.addSubview(tp)
        timePicker = tp

        // Duration
        y -= 36
        addLabel("Duration:", at: NSPoint(x: 10, y: y), in: content, width: labelW)
        let df = NSTextField(frame: NSRect(x: fieldX, y: y, width: 80, height: 22))
        df.placeholderString = "minutes"
        content.addSubview(df)
        durationField = df
        let minLabel = NSTextField(labelWithString: "minutes")
        minLabel.frame = NSRect(x: fieldX + 86, y: y, width: 60, height: 22)
        content.addSubview(minLabel)

        // Blocklist
        y -= 36
        addLabel("Blocklist:", at: NSPoint(x: 10, y: y), in: content, width: labelW)
        let bf = NSTextField(frame: NSRect(x: fieldX, y: y - 60, width: 330, height: 80))
        bf.placeholderString = "Enter domains, one per line (e.g. facebook.com)"
        content.addSubview(bf)
        blocklistField = bf

        // Buttons
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelEditSheet(_:)))
        cancelBtn.frame = NSRect(x: 260, y: 10, width: 80, height: 30)
        cancelBtn.keyEquivalent = "\u{1b}"
        content.addSubview(cancelBtn)

        let saveBtn = NSButton(title: "Save", target: self, action: #selector(saveEditSheet(_:)))
        saveBtn.frame = NSRect(x: 350, y: 10, width: 80, height: 30)
        saveBtn.keyEquivalent = "\r"
        content.addSubview(saveBtn)

        // Populate if editing
        if let editing = editingSchedule {
            nameField?.stringValue = editing.name
            for day in editing.weekdays where day >= 0 && day < 7 {
                dayCheckboxes[day].state = .on
            }
            var timeComps = DateComponents()
            timeComps.hour = editing.hour; timeComps.minute = editing.minute
            timeComps.year = 2025; timeComps.month = 1; timeComps.day = 1
            if let date = Calendar.current.date(from: timeComps) {
                timePicker?.dateValue = date
            }
            durationField?.integerValue = editing.durationMinutes
            blocklistField?.stringValue = editing.blocklist.joined(separator: "\n")
        } else {
            durationField?.integerValue = 60
        }

        window?.beginSheet(sheet, completionHandler: nil)
    }

    @objc private func cancelEditSheet(_ sender: Any) {
        guard let sheet = editSheet else { return }
        window?.endSheet(sheet)
        editSheet = nil
        editingSchedule = nil
    }

    @objc private func saveEditSheet(_ sender: Any) {
        guard let sheet = editSheet else { return }

        var schedule = editingSchedule ?? SCSchedule()
        schedule.name = nameField?.stringValue ?? ""

        var days: [Int] = []
        for i in 0..<7 {
            if dayCheckboxes[i].state == .on { days.append(i) }
        }
        schedule.weekdays = days

        if let picker = timePicker {
            let cal = Calendar.current
            schedule.hour = cal.component(.hour, from: picker.dateValue)
            schedule.minute = cal.component(.minute, from: picker.dateValue)
        }

        schedule.durationMinutes = max(durationField?.integerValue ?? 1, 1)

        let raw = blocklistField?.stringValue ?? ""
        schedule.blocklist = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if editingSchedule != nil {
            SCScheduleManager.shared.updateSchedule(schedule)
        } else {
            schedule.enabled = true
            SCScheduleManager.shared.addSchedule(schedule)
        }

        SCScheduleManager.shared.syncAllLaunchdAgents()

        window?.endSheet(sheet)
        editSheet = nil
        editingSchedule = nil
        reloadSchedules()
    }

    // MARK: - Helpers

    private func addLabel(_ text: String, at origin: NSPoint, in view: NSView, width: CGFloat) {
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: origin.x, y: origin.y, width: width, height: 22)
        label.alignment = .right
        view.addSubview(label)
    }

    private func daysSummary(for schedule: SCSchedule) -> String {
        if schedule.weekdays.isEmpty { return "Daily" }
        if schedule.weekdays.count == 7 { return "Every day" }

        let weekdaySet = Set(schedule.weekdays)
        if weekdaySet == Set([1, 2, 3, 4, 5]) { return "Weekdays" }
        if weekdaySet == Set([0, 6]) { return "Weekends" }

        let abbrevs = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return schedule.weekdays.sorted().compactMap { idx in
            idx >= 0 && idx < 7 ? abbrevs[idx] : nil
        }.joined(separator: ", ")
    }
}
