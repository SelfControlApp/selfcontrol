import SwiftUI

struct MenuBarView: View {
    @Environment(Store.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(formatDuration(store.totalUsage()))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("today").foregroundStyle(.secondary)
                }

                if let focus = store.activeFocus {
                    StatusPill(symbol: "lock.fill", tint: .red,
                               text: "Focus session · \(formatDuration(focus.remaining(), style: .clock)) left")
                }
                if let downtime = store.activeDowntime {
                    StatusPill(symbol: "moon.fill", tint: .indigo,
                               text: "Downtime until \(downtime.end.formatted(date: .omitted, time: .shortened))")
                } else if let next = store.config.downtime.nextStart(after: Date()), Calendar.current.isDateInToday(next) {
                    StatusPill(symbol: "moon", tint: .secondary,
                               text: "Downtime at \(next.formatted(date: .omitted, time: .shortened))")
                }

                let limits = store.config.limits.filter { $0.limitSeconds(on: Date()) != nil }
                if !limits.isEmpty {
                    Divider()
                    ForEach(limits) { limit in
                        let used = store.usage(for: limit.id)
                        let total = limit.limitSeconds(on: Date()) ?? 0
                        HStack(spacing: 8) {
                            AppIconView(app: limit.app, size: 20)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(limit.app.name).lineLimit(1)
                                    Spacer()
                                    Text(used >= total ? "Limit reached" : "\(formatDuration(total - used)) left")
                                        .foregroundStyle(used >= total ? .red : .secondary)
                                        .monospacedDigit()
                                }
                                .font(.caption)
                                UsageBar(used: used, limit: total)
                            }
                        }
                    }
                }

                Divider()
                HStack {
                    Button("Open SelfControl") {
                        openWindow(id: "main")
                        NSApp.activate()
                    }
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                        .disabled(store.activeFocus != nil || store.isStrict)
                        .help(store.activeFocus != nil || store.isStrict ? "SelfControl stays open during a focus session or Strict Mode" : "")
                }
            }
            .padding(14)
            .frame(width: 290)
        }
    }
}
