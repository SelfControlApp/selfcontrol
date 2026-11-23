import Charts
import SwiftUI

struct OverviewView: View {
    @Environment(Store.self) private var store
    let select: (SidebarItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                HStack(alignment: .top, spacing: 16) {
                    downtimeCard
                    focusCard
                }
                HStack(alignment: .top, spacing: 16) {
                    mostUsedCard
                    weekCard
                }
                limitsCard
                websitesCard
            }
            .padding(24)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(formatDuration(store.totalUsage()))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text("Screen time today").foregroundStyle(.secondary)
        }
    }

    // MARK: Status cards

    private var downtimeCard: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                SymbolBadge(symbol: "moon.fill", tint: .indigo, size: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Downtime").font(.headline)
                    Text(downtimeStatus).foregroundStyle(.secondary).font(.callout)
                }
                Spacer()
                Button("Edit") { select(.downtime) }.buttonStyle(.link)
            }
        }
    }

    private var downtimeStatus: String {
        let d = store.config.downtime
        if !d.enabled { return "Off" }
        if let active = store.activeDowntime {
            return "On until \(active.end.formatted(date: .omitted, time: .shortened))"
        }
        if let next = d.nextStart(after: Date()) {
            let sameDay = Calendar.current.isDateInToday(next)
            let when = sameDay ? next.formatted(date: .omitted, time: .shortened)
                : next.formatted(.dateTime.weekday(.abbreviated).hour().minute())
            return "Starts \(sameDay ? "at " : "")\(when)"
        }
        return "Scheduled, but no days are enabled"
    }

    private var focusCard: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                SymbolBadge(symbol: "lock.fill", tint: .red, size: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus Session").font(.headline)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        if let f = store.activeFocus {
                            Text("\(formatDuration(f.remaining(), style: .clock)) remaining · \(f.apps.count) apps blocked")
                                .monospacedDigit()
                        } else {
                            Text("Not running")
                        }
                    }
                    .foregroundStyle(.secondary).font(.callout)
                }
                Spacer()
                Button(store.activeFocus == nil ? "Start" : "View") { select(.focus) }.buttonStyle(.link)
            }
        }
    }

    // MARK: Charts

    private var mostUsedCard: some View {
        let top = store.topApps(limit: 6)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Most Used Today").font(.headline)
                if top.isEmpty {
                    Text("No usage recorded yet today.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    ForEach(top, id: \.bundleID) { item in
                        let ref = AppRef(bundleID: item.bundleID, name: item.name)
                        let limit = store.limit(for: item.bundleID)?.limitSeconds(on: Date())
                        HStack(spacing: 10) {
                            AppIconView(app: ref, size: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(item.name).lineLimit(1)
                                    Spacer()
                                    Text(formatDuration(item.seconds)).foregroundStyle(.secondary).monospacedDigit()
                                }
                                .font(.callout)
                                GeometryReader { geo in
                                    let maxSeconds = max(top.first?.seconds ?? 1, 1)
                                    Capsule()
                                        .fill((limit.map { item.seconds >= $0 } == true ? Color.red : .blue).gradient)
                                        .frame(width: max(4, geo.size.width * item.seconds / maxSeconds))
                                }
                                .frame(height: 5)
                            }
                        }
                    }
                }
            }
        }
    }

    private var weekCard: some View {
        let days: [(date: Date, seconds: TimeInterval)] = (0..<7).reversed().compactMap { offset in
            guard let d = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return (d, store.totalUsage(on: d))
        }
        let average = days.map(\.seconds).reduce(0, +) / 7
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Last 7 Days").font(.headline)
                    Spacer()
                    Text("Avg \(formatDuration(average))").font(.callout).foregroundStyle(.secondary)
                }
                Chart {
                    ForEach(days, id: \.date) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("Hours", day.seconds / 3600)
                        )
                        .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Color.blue.gradient : Color.blue.opacity(0.45).gradient)
                        .cornerRadius(4)
                    }
                    if average > 0 {
                        RuleMark(y: .value("Average", average / 3600))
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel { if let h = value.as(Double.self) { Text("\(h, specifier: "%.0f")h") } }
                    }
                }
                .frame(height: 170)
            }
        }
    }

    // MARK: Websites

    private var websitesCard: some View {
        let sites = store.topSites(limit: 5)
        let limit = store.effectiveRules.websites.limitSeconds
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Top Websites Today").font(.headline)
                    Spacer()
                    Button("Manage") { select(.websiteLimits) }.buttonStyle(.link)
                }
                if sites.isEmpty {
                    Text("Time on websites in Safari, Chrome, Edge, Brave, Arc and others shows up here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sites, id: \.domain) { site in
                        let whitelisted = store.effectiveRules.websites.isWhitelisted(host: site.domain)
                        HStack(spacing: 10) {
                            TargetIcon(target: .website(site.domain), size: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(site.domain).lineLimit(1)
                                    Spacer()
                                    Text(limit.map { "\(formatDuration(site.seconds)) / \(formatDuration($0))" } ?? formatDuration(site.seconds))
                                        .foregroundStyle(.secondary).monospacedDigit()
                                }
                                .font(.callout)
                                UsageBar(used: site.seconds, limit: whitelisted ? nil : limit)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Limits

    private var limitsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("App Limits").font(.headline)
                    Spacer()
                    Button("Manage") { select(.limits) }.buttonStyle(.link)
                }
                let limits = store.config.limits.filter(\.enabled)
                if limits.isEmpty {
                    Text("Set daily time limits on individual apps to keep them in check.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 14) {
                        ForEach(limits) { limit in
                            let used = store.usage(for: limit.id)
                            let total = limit.limitSeconds(on: Date())
                            HStack(spacing: 10) {
                                AppIconView(app: limit.app, size: 30)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(limit.app.name).lineLimit(1)
                                        Spacer()
                                        Text(total.map { "\(formatDuration(used)) / \(formatDuration($0))" } ?? "No limit today")
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                    .font(.callout)
                                    UsageBar(used: used, limit: total)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
