import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview, limits, websiteLimits, whitelist, downtime, focus, gallery, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .limits: "App Limits"
        case .websiteLimits: "Website Limits"
        case .whitelist: "Website Whitelist"
        case .gallery: "Gallery"
        case .downtime: "Downtime"
        case .focus: "Focus Session"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "chart.bar.xaxis"
        case .limits: "hourglass"
        case .websiteLimits: "globe"
        case .whitelist: "checkmark.shield.fill"
        case .gallery: "square.grid.2x2.fill"
        case .downtime: "moon.fill"
        case .focus: "lock.fill"
        case .settings: "gearshape.fill"
        }
    }

    var tint: Color {
        switch self {
        case .overview: .blue
        case .limits: .orange
        case .websiteLimits: .teal
        case .whitelist: .green
        case .gallery: .purple
        case .downtime: .indigo
        case .focus: .red
        case .settings: .gray
        }
    }
}

struct ContentView: View {
    @Environment(Store.self) private var store
    @State private var selection: SidebarItem? = .overview

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach([SidebarItem.overview]) { row($0) }
                }
                Section("Controls") {
                    ForEach([SidebarItem.limits, .websiteLimits, .whitelist, .downtime, .focus, .gallery]) { row($0) }
                }
                Section {
                    row(.settings)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            .safeAreaInset(edge: .bottom) { StatusFooter().padding(12) }
        } detail: {
            Group {
                switch selection ?? .overview {
                case .overview: OverviewView(select: { selection = $0 })
                case .limits: LimitsView()
                case .websiteLimits: WebsiteLimitsView(select: { selection = $0 })
                case .whitelist: WebsiteWhitelistView()
                case .gallery: GalleryView(select: { selection = $0 })
                case .downtime: DowntimeView()
                case .focus: FocusView(select: { selection = $0 })
                case .settings: SettingsView()
                }
            }
            .navigationTitle((selection ?? .overview).title)
            .overlay(alignment: .top) { NoticeBanner() }
            .animation(.snappy, value: store.notice)
        }
        .onAppear { AppCatalog.shared.loadIfNeeded() }
    }

    private func row(_ item: SidebarItem) -> some View {
        Label {
            Text(item.title)
        } icon: {
            SymbolBadge(symbol: item.symbol, tint: item.tint, size: 22)
        }
        .tag(item)
    }
}

/// Live status shown at the bottom of the sidebar.
private struct StatusFooter: View {
    @Environment(Store.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 6) {
                if let focus = store.activeFocus {
                    StatusPill(symbol: "lock.fill", tint: .red,
                               text: "Focus · \(formatDuration(focus.remaining(), style: .clock)) left")
                }
                if let downtime = store.activeDowntime {
                    StatusPill(symbol: "moon.fill", tint: .indigo,
                               text: "Downtime until \(downtime.end.formatted(date: .omitted, time: .shortened))")
                }
                StatusPill(symbol: "clock", tint: .secondary,
                           text: "\(formatDuration(store.totalUsage())) screen time today")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Shared components

struct SymbolBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).fill(tint.gradient))
    }
}

struct StatusPill: View {
    let symbol: String
    let tint: Color
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .lineLimit(1)
    }
}

/// A rounded card container used on the overview and focus pages.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator.opacity(0.5)))
    }
}

/// Used/limit progress bar that shifts from green to orange to red.
struct UsageBar: View {
    let used: TimeInterval
    let limit: TimeInterval?

    var body: some View {
        let fraction = limit.map { $0 > 0 ? min(1, used / $0) : 1 } ?? 0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(color(fraction).gradient)
                    .frame(width: max(fraction > 0 ? 6 : 0, geo.size.width * fraction))
            }
        }
        .frame(height: 6)
        .animation(.smooth, value: fraction)
    }

    private func color(_ f: Double) -> Color {
        f >= 1 ? .red : f >= 0.8 ? .orange : .green
    }
}

/// Hours + minutes picker.
struct DurationPicker: View {
    @Binding var minutes: Int
    var minimum = 5

    var body: some View {
        HStack(spacing: 6) {
            Picker("Hours", selection: Binding(
                get: { minutes / 60 },
                set: { minutes = clamp($0 * 60 + minutes % 60) }
            )) {
                ForEach(0..<24, id: \.self) { Text("\($0) hr").tag($0) }
            }
            .labelsHidden()
            .frame(width: 80)

            Picker("Minutes", selection: Binding(
                get: { minutes % 60 },
                set: { minutes = clamp((minutes / 60) * 60 + $0) }
            )) {
                ForEach(minuteOptions, id: \.self) { Text("\($0) min").tag($0) }
            }
            .labelsHidden()
            .frame(width: 86)
        }
    }

    private var minuteOptions: [Int] {
        var options = Array(stride(from: 0, to: 60, by: 5))
        if !options.contains(minutes % 60) { options.append(minutes % 60); options.sort() }
        return options
    }

    private func clamp(_ value: Int) -> Int { max(minimum, min(value, 24 * 60 - 1)) }
}

/// Bridges TimeOfDay to an hour/minute DatePicker.
struct TimeOfDayPicker: View {
    let label: String
    @Binding var time: TimeOfDay

    var body: some View {
        DatePicker(label, selection: Binding(
            get: { time.date(on: Date()) },
            set: { time = TimeOfDay(date: $0) }
        ), displayedComponents: .hourAndMinute)
        .datePickerStyle(.field)
    }
}
