import SwiftUI

struct DowntimeView: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                HStack(spacing: 14) {
                    SymbolBadge(symbol: "moon.fill", tint: .indigo, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Downtime").font(.title3.weight(.semibold))
                        Text("Schedule time away from the screen. During Downtime, only apps you choose to allow are available.")
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("Downtime", isOn: $store.config.downtime.enabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.vertical, 4)

                if let active = store.activeDowntime {
                    Label("Downtime is on until \(active.end.formatted(date: .omitted, time: .shortened))",
                          systemImage: "moon.zzz.fill")
                        .foregroundStyle(.indigo)
                }
                StrictModeRow()
            }

            Group {
                Section("Schedule") {
                    Picker("Repeat", selection: $store.config.downtime.mode) {
                        Text("Every Day").tag(DowntimeSchedule.Mode.everyDay)
                        Text("Customize Days").tag(DowntimeSchedule.Mode.custom)
                    }
                    .pickerStyle(.segmented)

                    if store.config.downtime.mode == .everyDay {
                        TimeOfDayPicker(label: "From", time: $store.config.downtime.everyDay.start)
                        TimeOfDayPicker(label: "To", time: $store.config.downtime.everyDay.end)
                    } else {
                        ForEach(Weekdays.ordered, id: \.self) { wd in
                            DayRow(weekday: wd, window: $store.config.downtime.days[wd - 1])
                        }
                    }
                }

                Section {
                    WeekTimeline(schedule: store.config.downtime)
                        .padding(.vertical, 6)
                } header: {
                    Text("This week")
                }

                Section {
                    Toggle(isOn: $store.config.downtime.blockAtDowntime) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Block at Downtime")
                            Text("Block apps as soon as Downtime starts. When off, SelfControl asks whether it's a good time and lets you delay up to 30 minutes at a time.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    AppListEditor(apps: $store.config.downtime.alwaysAllowed, addTitle: "Add Allowed App…")
                } header: {
                    Text("Always allowed")
                } footer: {
                    Text("Finder and SelfControl are always allowed. Every other app is blocked during Downtime.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    HelperRequiredRow(reason: "Blocking websites needs the SelfControl helper, which is installed with your administrator password.")
                    WebsiteListEditor(websites: $store.config.downtime.blockedWebsites)
                        .disabled(!store.helper.isAvailable)
                } header: {
                    Text("Websites blocked during Downtime")
                } footer: {
                    Text("Blocked in every browser and app, the same way SelfControl blocks websites.")
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!store.config.downtime.enabled)
        }
        .formStyle(.grouped)
    }
}

private struct DayRow: View {
    let weekday: Int
    @Binding var window: DayWindow

    var body: some View {
        HStack {
            Toggle(Weekdays.name(weekday), isOn: $window.enabled)
                .frame(width: 140, alignment: .leading)
            Spacer()
            if window.enabled {
                TimeOfDayPicker(label: "From", time: $window.start).labelsHidden().fixedSize()
                Text("to").foregroundStyle(.secondary)
                TimeOfDayPicker(label: "To", time: $window.end).labelsHidden().fixedSize()
            } else {
                Text("No Downtime").foregroundStyle(.secondary)
            }
        }
    }
}

/// Visualises the week's downtime windows on a 24-hour track per day.
struct WeekTimeline: View {
    let schedule: DowntimeSchedule

    private var axisLabels: [String] {
        [0, 6, 12, 18, 24].map { TimeOfDay(hour: $0 % 24, minute: 0).date(on: Date()).formatted(.dateTime.hour()) }
    }

    var body: some View {
        let today = Weekdays.weekday(of: Date())
        VStack(spacing: 7) {
            ForEach(Weekdays.ordered, id: \.self) { wd in
                HStack(spacing: 10) {
                    Text(Weekdays.shortName(wd))
                        .font(.caption.weight(wd == today ? .bold : .regular))
                        .foregroundStyle(wd == today ? .primary : .secondary)
                        .frame(width: 34, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary.opacity(0.7))
                            ForEach(Array(schedule.segments(forWeekday: wd).enumerated()), id: \.offset) { _, seg in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.indigo.gradient)
                                    .frame(width: max(3, geo.size.width * (seg.upperBound - seg.lowerBound)))
                                    .offset(x: geo.size.width * seg.lowerBound)
                            }
                            if wd == today {
                                let now = Date()
                                let mins = Double(Calendar.current.component(.hour, from: now) * 60
                                                  + Calendar.current.component(.minute, from: now))
                                Rectangle().fill(.red).frame(width: 2)
                                    .offset(x: geo.size.width * mins / 1440 - 1)
                            }
                        }
                    }
                    .frame(height: 12)
                }
            }
            HStack(spacing: 10) {
                Spacer().frame(width: 34)
                HStack(spacing: 0) {
                    ForEach(Array(axisLabels.enumerated()), id: \.offset) { index, label in
                        Text(label)
                        if index < axisLabels.count - 1 { Spacer(minLength: 0) }
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}
