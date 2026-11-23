import SwiftUI

/// The classic SelfControl experience — pick sites and apps and a duration, start, and there's no
/// way to stop early.
struct FocusView: View {
    @Environment(Store.self) private var store
    let select: (SidebarItem) -> Void
    @State private var confirming = false
    @State private var error: String?

    var body: some View {
        if let session = store.activeFocus {
            ActiveFocusView(session: session, enforcedByHelper: store.helper.status?.focus != nil)
        } else {
            setup
        }
    }

    private var minutes: Int { store.config.focusMinutes }
    private var isEmpty: Bool { store.config.focusBlocklist.isEmpty && store.config.focusWebsites.isEmpty }
    private var needsHelper: Bool { !store.config.focusWebsites.isEmpty && !store.helper.isAvailable }

    private var setup: some View {
        @Bindable var store = store
        return Form {
            Section {
                HStack(spacing: 14) {
                    SymbolBadge(symbol: "lock.fill", tint: .red, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Focus Session").font(.title3.weight(.semibold))
                        Text("Block websites and apps for a set amount of time. Once started, a session can't be stopped early, even by quitting, restarting, or deleting SelfControl.")
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
                Button {
                    select(.gallery)
                } label: {
                    Label("Or start one of your Focus Lists from the Gallery", systemImage: "square.grid.2x2")
                }
                .buttonStyle(.link)
            }

            Section("Duration") {
                VStack(spacing: 10) {
                    Text(formatDuration(TimeInterval(minutes * 60)))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.snappy, value: minutes)
                    Slider(value: Binding(
                        get: { Double(store.config.focusMinutes) },
                        set: { store.config.focusMinutes = Int($0) }
                    ), in: 15...(24 * 60), step: 15) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("15m").font(.caption).foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("24h").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        ForEach([25, 60, 120, 240], id: \.self) { m in
                            Button(formatDuration(TimeInterval(m * 60))) { store.config.focusMinutes = m }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }

            Section {
                HelperRequiredRow(reason: "Blocking websites needs the SelfControl helper, which is installed with your administrator password.")
                WebsiteListEditor(websites: $store.config.focusWebsites)
            } header: {
                Text("Websites to block")
            } footer: {
                Text("Blocked in every browser and app until the session ends.").foregroundStyle(.secondary)
            }

            Section {
                AppListEditor(apps: $store.config.focusBlocklist, addTitle: "Add App to Block…")
            } header: {
                Text("Apps to block")
            }

            Section {
                if let error {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
                Button {
                    confirming = true
                } label: {
                    Label("Start Focus Session", systemImage: "lock.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .disabled(isEmpty || needsHelper)
                if !store.helper.isAvailable && !isEmpty {
                    Text("Without the helper, this session only blocks apps while SelfControl is running.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Start a \(formatDuration(TimeInterval(minutes * 60))) focus session?",
                            isPresented: $confirming) {
            Button("Start Session", role: .destructive) {
                Task {
                    do {
                        try await store.startFocus(minutes: minutes)
                        error = nil
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("\(blockedSummary) will be blocked until \(Date().addingTimeInterval(TimeInterval(minutes * 60)).formatted(date: .omitted, time: .shortened)). You won't be able to end the session early.")
        }
    }

    private var blockedSummary: String {
        let items = store.config.focusWebsites + store.config.focusBlocklist.map(\.name)
        if items.count <= 4 { return items.formatted(.list(type: .and)) }
        return "\(items.prefix(3).joined(separator: ", ")) and \(items.count - 3) more"
    }
}

private struct ActiveFocusView: View {
    let session: FocusSession
    let enforcedByHelper: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                VStack(spacing: 28) {
                    ZStack {
                        Circle().stroke(.quaternary, lineWidth: 14)
                        Circle()
                            .trim(from: 0, to: 1 - session.progress(at: context.date))
                            .stroke(Color.red.gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: session.progress(at: context.date))
                        VStack(spacing: 6) {
                            Image(systemName: "lock.fill").font(.title2).foregroundStyle(.red)
                            Text(formatDuration(session.remaining(at: context.date), style: .clock))
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("until \(session.end.formatted(date: .omitted, time: .shortened))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 260, height: 260)

                    if let name = session.listName {
                        VStack(spacing: 4) {
                            Text(name).font(.title3.weight(.semibold))
                            Text(session.mode == .allowlist ? "Only allowed apps and websites work" : "Blocking the list's apps and websites")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }

                    if !session.apps.isEmpty {
                        VStack(spacing: 12) {
                            Text("Blocked apps").font(.headline).foregroundStyle(.secondary)
                            HStack(spacing: 16) {
                                ForEach(session.apps) { app in
                                    VStack(spacing: 4) {
                                        AppIconView(app: app, size: 44).saturation(0.3)
                                        Text(app.name).font(.caption).lineLimit(1).frame(maxWidth: 80)
                                    }
                                }
                            }
                        }
                    }

                    if !session.websites.isEmpty {
                        VStack(spacing: 10) {
                            Text("Blocked websites").font(.headline).foregroundStyle(.secondary)
                            FlowRow(items: session.websites)
                        }
                    }

                    if !session.allowedApps.isEmpty || !session.allowedWebsites.isEmpty {
                        VStack(spacing: 12) {
                            Text(session.mode == .allowlist ? "Allowed (everything else is blocked)" : "Allowed past their limits")
                                .font(.headline).foregroundStyle(.secondary)
                            if !session.allowedApps.isEmpty {
                                HStack(spacing: 16) {
                                    ForEach(session.allowedApps) { app in
                                        VStack(spacing: 4) {
                                            AppIconView(app: app, size: 36)
                                            Text(app.name).font(.caption).lineLimit(1).frame(maxWidth: 80)
                                        }
                                    }
                                }
                            }
                            if !session.allowedWebsites.isEmpty { FlowRow(items: session.allowedWebsites) }
                        }
                    }

                    Label(enforcedByHelper
                          ? "Enforced by the SelfControl helper. This session can't be stopped early."
                          : "This session can't be stopped early.",
                          systemImage: enforcedByHelper ? "lock.shield.fill" : "lock.fill")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            }
        }
    }
}

/// Wrapping row of capsule tags.
private struct FlowRow: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: "globe")
                    .font(.callout)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.quaternary.opacity(0.6), in: Capsule())
            }
        }
        .frame(maxWidth: 600)
    }
}
