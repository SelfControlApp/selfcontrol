import SwiftUI

struct ScheduleEditorView: View {
    @State private var schedules: [SCSchedule] = []
    @State private var showingAddSheet = false
    @State private var editingSchedule: SCSchedule?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Schedules")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(schedules.count) active")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            if schedules.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No schedules")
                        .foregroundStyle(.secondary)
                    Text("Automatically block sites on a recurring schedule")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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

            Divider()

            // Footer
            HStack {
                Button(action: { showingAddSheet = true }) {
                    Label("New Schedule", systemImage: "plus")
                        .font(.system(size: 12))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 460, height: 380)
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
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(schedule.enabled ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(schedule.name.isEmpty ? "Untitled" : schedule.name)
                    .font(.system(size: 13, weight: .medium))
                    .opacity(schedule.enabled ? 1 : 0.5)

                HStack(spacing: 6) {
                    Text(daysSummary)
                    Text("·")
                    Text(String(format: "%02d:%02d", schedule.hour, schedule.minute))
                        .font(.system(size: 11, design: .monospaced))
                    Text("·")
                    Text(durationText)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .opacity(schedule.enabled ? 1 : 0.5)
            }

            Spacer()

            Button(action: onToggle) {
                Text(schedule.enabled ? "On" : "Off")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(schedule.enabled ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(schedule.enabled ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
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

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    init(schedule: SCSchedule?, onSave: @escaping (SCSchedule) -> Void) {
        self.initialSchedule = schedule
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(initialSchedule == nil ? "New Schedule" : "Edit Schedule")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 20)
                .padding(.bottom, 16)

            // Form
            VStack(alignment: .leading, spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("NAME")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                                            TextField("Morning focus", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                // Days
                VStack(alignment: .leading, spacing: 6) {
                    Text("DAYS")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                                            HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { day in
                            Button(action: { toggleDay(day) }) {
                                Text(dayLabels[day])
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(width: 32, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedDays.contains(day)
                                                  ? Color.accentColor
                                                  : Color(nsColor: .controlBackgroundColor))
                                    )
                                    .foregroundStyle(selectedDays.contains(day) ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Time + Duration
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TIME")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                                                    HStack(spacing: 2) {
                            Stepper(String(format: "%02d", hour), value: $hour, in: 0...23)
                            Text(":")
                                .foregroundStyle(.tertiary)
                            Stepper(String(format: "%02d", minute), value: $minute, in: 0...59, step: 5)
                        }
                        .font(.system(size: 13, design: .monospaced))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("DURATION")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                                                    Stepper("\(durationMinutes) min", value: $durationMinutes, in: 1...1440, step: 15)
                            .font(.system(size: 13, design: .monospaced))
                    }
                }

                // Domains
                VStack(alignment: .leading, spacing: 4) {
                    Text("DOMAINS")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                                            TextEditor(text: $blocklistText)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 380, height: 440)
        .onAppear { populateFromSchedule() }
    }

    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) { selectedDays.remove(day) }
        else { selectedDays.insert(day) }
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
