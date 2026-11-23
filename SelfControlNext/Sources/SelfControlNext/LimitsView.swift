import SwiftUI

struct LimitsView: View {
    @Environment(Store.self) private var store
    @State private var showingPicker = false
    @State private var editing: AppLimit?

    var body: some View {
        Group {
            if store.config.limits.isEmpty {
                ContentUnavailableView {
                    Label("No App Limits", systemImage: "hourglass")
                } description: {
                    Text("Give individual apps a daily time allowance. When you reach it, the app is blocked until tomorrow.")
                } actions: {
                    Button("Add Limit…") { showingPicker = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                Form {
                    if store.isStrict {
                        Section { StrictModeRow() }
                    }
                    Section {
                        ForEach(store.config.limits) { limit in
                            LimitRow(limit: limit) { editing = limit }
                        }
                    } header: {
                        Text("Daily limits")
                    } footer: {
                        Text("Usage counts while an app is in front and you're active. Limits reset at midnight.")
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
            }
        }
        .toolbar {
            ToolbarItem {
                Button { showingPicker = true } label: { Label("Add Limit", systemImage: "plus") }
                    .help("Add an app limit")
            }
        }
        .sheet(isPresented: $showingPicker) {
            AppPickerSheet(title: "Add App Limits", excluded: Set(store.config.limits.map(\.id))) { apps in
                let new = apps.map { AppLimit(app: $0) }
                store.config.limits.append(contentsOf: new)
                if new.count == 1 { editing = new[0] }
            }
        }
        .sheet(item: $editing) { limit in
            LimitEditorSheet(original: limit)
        }
    }
}

private struct LimitRow: View {
    @Environment(Store.self) private var store
    let limit: AppLimit
    let edit: () -> Void

    var body: some View {
        let used = store.usage(for: limit.id)
        let total = limit.limitSeconds(on: Date())
        let cantDisable = !store.strictProblems(replacing: limit, with: { var c = limit; c.enabled = false; return c }()).isEmpty
        let cantDelete = !store.strictProblems(replacing: limit, with: nil).isEmpty
        HStack(spacing: 12) {
            AppIconView(app: limit.app, size: 36)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(limit.app.name).font(.body.weight(.medium))
                    if cantDelete {
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                            .help("Locked by Strict Mode")
                    }
                    Spacer()
                    Text(total.map { "\(formatDuration(used)) of \(formatDuration($0))" } ?? "\(formatDuration(used)) today")
                        .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                }
                if limit.enabled { UsageBar(used: used, limit: total) }
                Text(limit.enabled ? limit.summary : "Paused")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Toggle("Enabled", isOn: Binding(
                get: { limit.enabled },
                set: { newValue in
                    if let i = store.config.limits.firstIndex(where: { $0.id == limit.id }) {
                        store.config.limits[i].enabled = newValue
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(cantDisable && limit.enabled)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: edit)
        .contextMenu {
            Button("Edit…", action: edit)
            Button("Delete", role: .destructive) {
                store.config.limits.removeAll { $0.id == limit.id }
            }
            .disabled(cantDelete)
        }
    }
}

struct LimitEditorSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: AppLimit
    @State private var draft: AppLimit
    @State private var error: String?

    init(original: AppLimit) {
        self.original = original
        _draft = State(initialValue: original)
    }

    var body: some View {
        let locked = !store.strictProblems(replacing: original, with: nil).isEmpty
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                AppIconView(app: draft.app, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.app.name).font(.title2.weight(.semibold))
                    Text("Used \(formatDuration(store.usage(for: draft.id))) today")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)

            Form {
                Section {
                    Toggle("Limit enabled", isOn: $draft.enabled)
                    Picker("Schedule", selection: $draft.customDays) {
                        Text("Every Day").tag(false)
                        Text("Custom Days").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .disabled(!draft.enabled)
                }

                Section("Time allowed") {
                    if draft.customDays {
                        ForEach(Weekdays.ordered, id: \.self) { wd in
                            HStack {
                                Toggle(Weekdays.name(wd), isOn: $draft.perDayEnabled[wd - 1])
                                Spacer()
                                if draft.perDayEnabled[wd - 1] {
                                    DurationPicker(minutes: $draft.perDayMinutes[wd - 1])
                                } else {
                                    Text("No limit").foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        LabeledContent("Each day") {
                            DurationPicker(minutes: $draft.dailyMinutes)
                        }
                    }
                }
                .disabled(!draft.enabled)

                if locked {
                    Section {
                        Label("Strict Mode is on, so this limit can be lowered but not raised or removed.",
                              systemImage: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            if let error {
                Text(error).foregroundStyle(.red).font(.callout).padding(.horizontal, 20)
            }

            HStack {
                Button("Delete Limit", role: .destructive) {
                    store.config.limits.removeAll { $0.id == original.id }
                    dismiss()
                }
                .disabled(locked)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 520, height: draft.customDays ? 640 : 440)
        .animation(.snappy, value: draft.customDays)
    }

    private func save() {
        let problems = store.strictProblems(replacing: original, with: draft)
        if !problems.isEmpty {
            error = "Strict Mode is on, so you can't \(problems.formatted(.list(type: .or)))."
            return
        }
        if let i = store.config.limits.firstIndex(where: { $0.id == original.id }) {
            store.config.limits[i] = draft
        }
        dismiss()
    }
}
