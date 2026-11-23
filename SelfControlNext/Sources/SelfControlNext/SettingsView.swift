import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var helperError: String?
    @State private var confirmClear = false
    @State private var confirmStrict = false
    @State private var confirmUnlock = false

    var body: some View {
        @Bindable var store = store
        Form {
            helperSection
            strictSection

            Section {
                Picker("When an app is blocked", selection: $store.config.settings.blockAction) {
                    ForEach(BlockAction.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Enforcement")
            } footer: {
                Text("Quitting asks the app to quit normally, so you'll still be offered to save your work.")
                    .foregroundStyle(.secondary)
            }

            Section("Tracking") {
                Picker("Stop counting after inactivity", selection: $store.config.settings.idleThreshold) {
                    Text("1 minute").tag(TimeInterval(60))
                    Text("2 minutes").tag(TimeInterval(120))
                    Text("5 minutes").tag(TimeInterval(300))
                    Text("10 minutes").tag(TimeInterval(600))
                    Text("Never").tag(TimeInterval(0))
                }
                Toggle("Warn me before limits and Downtime", isOn: $store.config.settings.warnings)
            }

            Section("General") {
                Toggle("Open at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Show in menu bar", isOn: $store.config.settings.showMenuBarItem)
            }

            Section {
                LabeledContent("Today's screen time", value: formatDuration(store.totalUsage()))
                HStack {
                    Button("Reset Today's Usage") { store.resetToday() }
                    Button("Clear All History…", role: .destructive) { confirmClear = true }
                }
                .disabled(store.isStrict)
            } header: {
                Text("Data")
            } footer: {
                if store.helper.isAvailable {
                    Text("App limits use the helper's own record of today's usage, so resetting here doesn't reset them.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .task { await store.helper.refresh() }
        .confirmationDialog("Clear all usage history?", isPresented: $confirmClear) {
            Button("Clear History", role: .destructive) { store.clearHistory() }
        }
    }

    // MARK: Helper

    private var helperSection: some View {
        Section {
            HStack(spacing: 12) {
                SymbolBadge(symbol: "lock.shield.fill", tint: helperTint, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SelfControl Helper").font(.headline)
                    Text(helperStatusText).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if store.helper.isBusy {
                    ProgressView().controlSize(.small)
                } else if store.helper.health != .running {
                    InstallHelperButton(error: $helperError)
                }
            }
            if let helperError {
                Text(helperError).font(.caption).foregroundStyle(.red)
            }
            if let domains = store.helper.status?.blockedDomains, !domains.isEmpty {
                LabeledContent("Blocking now", value: domains.formatted(.list(type: .and)))
            }
            if store.helper.health == .running {
                Button("Uninstall Helper…", role: .destructive) {
                    Task {
                        do { try await store.helper.uninstall(); helperError = nil }
                        catch { helperError = error.localizedDescription }
                    }
                }
                .disabled(store.isStrict || store.activeFocus != nil || store.helper.isBusy)
            }
        } header: {
            Text("Protection")
        } footer: {
            Text("The helper runs in the background with administrator rights. It blocks websites, keeps Focus Sessions and Strict Mode in force if SelfControl is quit or deleted, and stores your locked rules where they can't be edited. Installing it asks for your administrator password.")
                .foregroundStyle(.secondary)
        }
    }

    private var helperTint: Color {
        switch store.helper.health {
        case .running: .green
        case .outdated, .connecting: .orange
        case .notInstalled, .unreachable: .gray
        }
    }

    private var helperStatusText: String {
        switch store.helper.health {
        case .running: "Installed and running"
        case .outdated: "Installed, but an update is available"
        case .connecting: "Checking…"
        case .notInstalled: "Not installed"
        case .unreachable: "Installed, but not responding"
        }
    }

    // MARK: Strict Mode

    private var strictSection: some View {
        @Bindable var store = store
        return Section {
            if !store.helper.isAvailable {
                HelperRequiredRow(reason: "Strict Mode needs the SelfControl helper so your rules can't be edited around.")
            } else if let lock = store.helper.status?.strict {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.fill").font(.title2).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Strict Mode is on").font(.headline)
                        if let unlockAt = lock.unlockAt {
                            TimelineView(.periodic(from: .now, by: 1)) { _ in
                                Text("Turns off \(unlockAt.formatted(.relative(presentation: .named))) (\(unlockAt.formatted(date: .abbreviated, time: .shortened))).")
                            }
                            .font(.callout).foregroundStyle(.secondary)
                        } else {
                            Text("On since \(lock.since.formatted(date: .abbreviated, time: .shortened)). Turning it off takes \(cooldownText(lock.cooldownHours)).")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if lock.unlockAt != nil {
                        Button("Keep Strict Mode On") { Task { await store.cancelUnlock() } }
                    } else {
                        Button("Turn Off…") { confirmUnlock = true }
                    }
                }
                .confirmationDialog("Turn off Strict Mode?", isPresented: $confirmUnlock) {
                    Button("Turn Off in \(cooldownText(lock.cooldownHours))") { Task { await store.requestUnlock() } }
                } message: {
                    Text("Strict Mode stays on for another \(cooldownText(lock.cooldownHours)). You can cancel any time before then.")
                }
            } else {
                Picker("Turning it off takes", selection: $store.config.settings.strictCooldownHours) {
                    ForEach([1.0, 4, 12, 24, 72], id: \.self) { Text(cooldownText($0)).tag($0) }
                }
                Button("Turn On Strict Mode…") { confirmStrict = true }
                    .confirmationDialog("Turn on Strict Mode?", isPresented: $confirmStrict) {
                        Button("Turn On") { Task { await store.enableStrict(hours: store.config.settings.strictCooldownHours) } }
                    } message: {
                        Text("Your current limits and Downtime get locked. You'll only be able to make them stricter, and turning Strict Mode off will take \(cooldownText(store.config.settings.strictCooldownHours)).")
                    }
            }
        } header: {
            Text("Strict Mode")
        } footer: {
            Text("Locks your limits and Downtime so they can only be made stricter, and removes every “Ignore” option. Turning it off only takes effect after a waiting period, so you can't undo it on impulse.")
                .foregroundStyle(.secondary)
        }
    }

    private func cooldownText(_ hours: Double) -> String {
        hours >= 24 && hours.truncatingRemainder(dividingBy: 24) == 0
            ? "\(Int(hours / 24)) day\(hours == 24 ? "" : "s")"
            : "\(Int(hours)) hour\(hours == 1 ? "" : "s")"
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
