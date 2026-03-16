import SwiftUI

struct ScheduleEditorView: View {
    @State private var schedules: [SCSchedule] = []
    @State private var showingAddSheet = false
    @State private var editingSchedule: SCSchedule?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Scheduled Blocks")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            if schedules.isEmpty {
                VStack(spacing: 8) {
                    Text("No schedules yet")
                        .foregroundStyle(.secondary)
                    Text("Add a schedule to automatically block sites at specific times.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(schedules) { schedule in
                        ScheduleRow(schedule: schedule,
                                    onToggle: { toggleSchedule(schedule) },
                                    onEdit: { editingSchedule = schedule })
                    }
                    .onDelete { indices in
                        for index in indices {
                            SCScheduleManager.shared.removeSchedule(schedules[index])
                        }
                        SCScheduleManager.shared.syncAllLaunchdAgents()
                        loadSchedules()
                    }
                }
            }

            HStack {
                Button("Add Schedule") { showingAddSheet = true }
                Spacer()
            }
            .padding()
        }
        .frame(width: 520, height: 400)
        .onAppear { loadSchedules() }
        .sheet(isPresented: $showingAddSheet) {
            ScheduleFormView(schedule: nil) { newSchedule in
                SCScheduleManager.shared.addSchedule(newSchedule)
                SCScheduleManager.shared.syncAllLaunchdAgents()
                loadSchedules()
            }
        }
        .sheet(item: $editingSchedule) { schedule in
            ScheduleFormView(schedule: schedule) { updated in
                SCScheduleManager.shared.updateSchedule(updated)
                SCScheduleManager.shared.syncAllLaunchdAgents()
                loadSchedules()
            }
        }
    }

    private func loadSchedules() {
        schedules = SCScheduleManager.shared.allSchedules()
    }

    private func toggleSchedule(_ schedule: SCSchedule) {
        var updated = schedule
        updated.enabled.toggle()
        SCScheduleManager.shared.updateSchedule(updated)
        SCScheduleManager.shared.syncAllLaunchdAgents()
        loadSchedules()
    }
}

// MARK: - Schedule Row

struct ScheduleRow: View {
    let schedule: SCSchedule
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Toggle("", isOn: .constant(schedule.enabled))
                .toggleStyle(.switch)
                .labelsHidden()
                .onTapGesture { onToggle() }

            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.name.isEmpty ? "Untitled" : schedule.name)
                    .fontWeight(.medium)
                Text("\(daysSummary) at \(String(format: "%02d:%02d", schedule.hour, schedule.minute)) for \(durationText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Edit") { onEdit() }
                .buttonStyle(.borderless)
        }
    }

    private var daysSummary: String {
        if schedule.weekdays.isEmpty { return "Daily" }
        if schedule.weekdays.count == 7 { return "Every day" }
        let abbrevs = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sorted = schedule.weekdays.sorted()
        if sorted == [1, 2, 3, 4, 5] { return "Weekdays" }
        if sorted == [0, 6] { return "Weekends" }
        return sorted.compactMap { $0 < 7 ? abbrevs[$0] : nil }.joined(separator: ", ")
    }

    private var durationText: String {
        let h = schedule.durationMinutes / 60
        let m = schedule.durationMinutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}

// MARK: - Schedule Form

struct ScheduleFormView: View {
    let initialSchedule: SCSchedule?
    let onSave: (SCSchedule) -> Void

    @State private var name = ""
    @State private var selectedDays: Set<Int> = []
    @State private var hour = 9
    @State private var minute = 0
    @State private var durationMinutes = 60
    @State private var blocklistText = ""
    @Environment(\.dismiss) private var dismiss

    init(schedule: SCSchedule?, onSave: @escaping (SCSchedule) -> Void) {
        self.initialSchedule = schedule
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(initialSchedule == nil ? "New Schedule" : "Edit Schedule")
                .font(.headline)

            Form {
                TextField("Name", text: $name)

                // Day selection
                HStack {
                    ForEach(0..<7, id: \.self) { day in
                        let abbrevs = ["S", "M", "T", "W", "T", "F", "S"]
                        Toggle(abbrevs[day], isOn: dayBinding(day))
                            .toggleStyle(.button)
                    }
                }

                // Time
                HStack {
                    Stepper("Hour: \(hour)", value: $hour, in: 0...23)
                    Stepper("Min: \(String(format: "%02d", minute))", value: $minute, in: 0...59, step: 5)
                }

                // Duration
                Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 1...1440, step: 15)

                // Blocklist
                VStack(alignment: .leading) {
                    Text("Domains (one per line):")
                        .font(.caption)
                    TextEditor(text: $blocklistText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 420, height: 440)
        .onAppear { populateFromSchedule() }
    }

    private func dayBinding(_ day: Int) -> Binding<Bool> {
        Binding(
            get: { selectedDays.contains(day) },
            set: { isOn in
                if isOn { selectedDays.insert(day) }
                else { selectedDays.remove(day) }
            }
        )
    }

    private func populateFromSchedule() {
        guard let s = initialSchedule else { return }
        name = s.name
        selectedDays = Set(s.weekdays)
        hour = s.hour
        minute = s.minute
        durationMinutes = s.durationMinutes
        blocklistText = s.blocklist.joined(separator: "\n")
    }

    private func save() {
        let domains = blocklistText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        var schedule = initialSchedule ?? SCSchedule()
        schedule.name = name
        schedule.weekdays = selectedDays.sorted()
        schedule.hour = hour
        schedule.minute = minute
        schedule.durationMinutes = durationMinutes
        schedule.blocklist = domains
        schedule.enabled = true

        onSave(schedule)
        dismiss()
    }
}
