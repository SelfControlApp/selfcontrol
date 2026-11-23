import Foundation

// MARK: - Basic value types

struct TimeOfDay: Codable, Hashable, Comparable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        hour = c.hour ?? 0
        minute = c.minute ?? 0
    }

    var totalMinutes: Int { hour * 60 + minute }

    static func < (a: TimeOfDay, b: TimeOfDay) -> Bool { a.totalMinutes < b.totalMinutes }

    func date(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    var formatted: String {
        date(on: Date()).formatted(date: .omitted, time: .shortened)
    }
}

/// Helpers for Calendar weekday numbers (1 = Sunday … 7 = Saturday).
enum Weekdays {
    /// Weekday numbers in the order the user's locale expects (e.g. Mon-first).
    static var ordered: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    static func name(_ weekday: Int) -> String { Calendar.current.weekdaySymbols[weekday - 1] }
    static func shortName(_ weekday: Int) -> String { Calendar.current.shortWeekdaySymbols[weekday - 1] }
    static func weekday(of date: Date) -> Int { Calendar.current.component(.weekday, from: date) }
}

struct AppRef: Codable, Hashable, Identifiable {
    var bundleID: String
    var name: String
    var path: String?

    var id: String { bundleID }
}

// MARK: - App limits

struct AppLimit: Codable, Hashable, Identifiable {
    var app: AppRef
    var enabled = true
    /// Limit used when `customDays` is false.
    var dailyMinutes = 60
    var customDays = false
    /// Indexed by weekday - 1.
    var perDayMinutes: [Int] = Array(repeating: 60, count: 7)
    /// Indexed by weekday - 1. A disabled day has no limit.
    var perDayEnabled: [Bool] = Array(repeating: true, count: 7)

    var id: String { app.bundleID }

    /// Limit in seconds for the given date, or nil if there is no limit that day.
    func limitSeconds(on date: Date) -> TimeInterval? {
        guard enabled else { return nil }
        if !customDays { return TimeInterval(dailyMinutes * 60) }
        let i = Weekdays.weekday(of: date) - 1
        return perDayEnabled[i] ? TimeInterval(perDayMinutes[i] * 60) : nil
    }

    var summary: String {
        if !customDays { return "\(formatDuration(TimeInterval(dailyMinutes * 60))) every day" }
        let active = (0..<7).filter { perDayEnabled[$0] }
        if active.isEmpty { return "No limit on any day" }
        let values = Set(active.map { perDayMinutes[$0] })
        if values.count == 1, let v = values.first {
            return "\(formatDuration(TimeInterval(v * 60))) on \(active.count) day\(active.count == 1 ? "" : "s")"
        }
        return "Custom limits by day"
    }
}

// MARK: - Downtime

struct DayWindow: Codable, Hashable {
    var enabled = true
    var start = TimeOfDay(hour: 22, minute: 0)
    var end = TimeOfDay(hour: 7, minute: 0)
}

struct DowntimeSchedule: Codable, Hashable {
    enum Mode: String, Codable, CaseIterable { case everyDay, custom }

    var enabled = false
    var mode: Mode = .everyDay
    var everyDay = DayWindow()
    /// Indexed by weekday - 1.
    var days: [DayWindow] = Array(repeating: DayWindow(), count: 7)
    /// When true, Downtime blocks apps immediately instead of asking whether to delay.
    var blockAtDowntime = false
    var alwaysAllowed: [AppRef] = [
        AppRef(bundleID: "com.apple.systempreferences", name: "System Settings",
               path: "/System/Applications/System Settings.app"),
    ]
    /// Websites blocked while Downtime is on (requires the helper).
    var blockedWebsites: [String] = []

    func window(forWeekday weekday: Int) -> DayWindow? {
        let w = mode == .everyDay ? everyDay : days[weekday - 1]
        return w.enabled ? w : nil
    }

    /// The downtime interval containing `now`, if any. Windows that cross midnight
    /// belong to the day they start on.
    func activeInterval(at now: Date, calendar: Calendar = .current) -> DateInterval? {
        guard enabled else { return nil }
        let today = calendar.startOfDay(for: now)
        for offset in [-1, 0] {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let interval = interval(startingOn: day, calendar: calendar) else { continue }
            if interval.start <= now && now < interval.end { return interval }
        }
        return nil
    }

    /// The next downtime start strictly after `now`.
    func nextStart(after now: Date, calendar: Calendar = .current) -> Date? {
        guard enabled else { return nil }
        let today = calendar.startOfDay(for: now)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let interval = interval(startingOn: day, calendar: calendar) else { continue }
            if interval.start > now { return interval.start }
        }
        return nil
    }

    private func interval(startingOn day: Date, calendar: Calendar) -> DateInterval? {
        guard let w = window(forWeekday: calendar.component(.weekday, from: day)) else { return nil }
        let start = w.start.date(on: day, calendar: calendar)
        var end = w.end.date(on: day, calendar: calendar)
        if w.end <= w.start { end = calendar.date(byAdding: .day, value: 1, to: end) ?? end }
        return DateInterval(start: start, end: end)
    }

    /// Fractions of the 24h day (0...1) covered by downtime on the given weekday,
    /// including the tail of an overnight window from the previous day.
    func segments(forWeekday weekday: Int) -> [ClosedRange<Double>] {
        guard enabled else { return [] }
        var result: [ClosedRange<Double>] = []
        let previous = weekday == 1 ? 7 : weekday - 1
        if let p = window(forWeekday: previous), p.end <= p.start, p.end.totalMinutes > 0 {
            result.append(0...Double(p.end.totalMinutes) / 1440)
        }
        if let w = window(forWeekday: weekday) {
            let s = Double(w.start.totalMinutes) / 1440
            let e = w.end <= w.start ? 1.0 : Double(w.end.totalMinutes) / 1440
            result.append(s...e)
        }
        return result
    }
}

// MARK: - Website limits

struct WebsiteLimits: Codable, Hashable {
    var enabled = true
    var minutesPerSite = 60
    /// Sites (and their subdomains) that are never limited or counted.
    var whitelist: [String] = []

    func isWhitelisted(host: String) -> Bool {
        whitelist.contains { Domains.matches(host, $0) }
    }

    var limitSeconds: TimeInterval? { enabled ? TimeInterval(minutesPerSite * 60) : nil }
}

// MARK: - Focus lists (the Gallery)

enum FocusMode: String, Codable, CaseIterable, Identifiable {
    /// Block the list's blocked items; allowed items are exempt from limits.
    case exempt
    /// Block everything except the list's allowed items.
    case allowlist

    var id: String { rawValue }
    var title: String {
        switch self {
        case .exempt: "Exempt allowed items from limits"
        case .allowlist: "Block everything except allowed"
        }
    }
    var shortTitle: String {
        switch self {
        case .exempt: "Block list"
        case .allowlist: "Allow only"
        }
    }
}

struct FocusList: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var symbol = "book.fill"
    var color = "blue"
    var mode: FocusMode = .exempt
    var blockedApps: [AppRef] = []
    var blockedWebsites: [String] = []
    var allowedApps: [AppRef] = []
    var allowedWebsites: [String] = []
}

// MARK: - Focus session (the classic SelfControl block, for apps and websites)

struct FocusSession: Codable, Hashable {
    var apps: [AppRef]
    var websites: [String] = []
    var start: Date
    var end: Date
    var listName: String?
    var mode: FocusMode = .exempt
    var allowedApps: [AppRef] = []
    var allowedWebsites: [String] = []

    func allowsApp(_ bundleID: String) -> Bool { allowedApps.contains { $0.bundleID == bundleID } }
    func allowsSite(_ host: String) -> Bool { allowedWebsites.contains { Domains.matches(host, $0) } }
    func blocksSite(_ host: String) -> Bool { websites.contains { Domains.matches(host, $0) } }

    /// Combines another session into this one. The result is never less strict than either:
    /// blocks are combined, allowances shrink, and "allow only" wins over "exempt".
    func merged(with other: FocusSession) -> FocusSession {
        var m = self
        m.end = max(end, other.end)
        m.apps += other.apps.filter { app in !apps.contains { $0.bundleID == app.bundleID } }
        m.websites = Array(Set(websites + other.websites)).sorted()

        let allowedApps: [AppRef], allowedSites: [String]
        switch (mode, other.mode) {
        case (.allowlist, .exempt):
            (allowedApps, allowedSites) = (self.allowedApps, self.allowedWebsites)
        case (.exempt, .allowlist):
            (allowedApps, allowedSites) = (other.allowedApps, other.allowedWebsites)
        default:
            allowedApps = self.allowedApps.filter { a in other.allowedApps.contains { $0.bundleID == a.bundleID } }
            allowedSites = self.allowedWebsites.filter(other.allowedWebsites.contains)
        }
        m.mode = mode == .allowlist || other.mode == .allowlist ? .allowlist : .exempt
        m.allowedApps = allowedApps.filter { a in !m.apps.contains { $0.bundleID == a.bundleID } }
        m.allowedWebsites = allowedSites.filter { !m.websites.contains($0) }
        m.listName = [listName, other.listName].compactMap { $0 }.joined(separator: " + ").nilIfEmpty
        return m
    }

    func remaining(at now: Date = Date()) -> TimeInterval { max(0, end.timeIntervalSince(now)) }
    func progress(at now: Date = Date()) -> Double {
        let total = end.timeIntervalSince(start)
        return total > 0 ? min(1, max(0, now.timeIntervalSince(start) / total)) : 1
    }
}

// MARK: - Settings & persisted documents

enum BlockAction: String, Codable, CaseIterable, Identifiable {
    case quit, hide
    var id: String { rawValue }
    var title: String {
        switch self {
        case .quit: "Quit the app"
        case .hide: "Hide the app"
        }
    }
}

struct AppSettings: Codable, Hashable {
    /// How long turning off Strict Mode takes, chosen when it's turned on.
    var strictCooldownHours: Double = 24
    var blockAction: BlockAction = .quit
    /// Stop counting usage after this many seconds without input. 0 = always count.
    var idleThreshold: TimeInterval = 120
    var warnings = true
    var showMenuBarItem = true
}

struct Config: Codable {
    var limits: [AppLimit] = []
    var downtime = DowntimeSchedule()
    var focusBlocklist: [AppRef] = []
    var focusWebsites: [String] = []
    var focusMinutes = 60
    var settings = AppSettings()
    var websites = WebsiteLimits()
    var focusLists: [FocusList] = []
}

struct UsageState: Codable {
    /// "yyyy-MM-dd" -> bundle ID -> seconds of foreground use.
    var days: [String: [String: Double]] = [:]
    /// "yyyy-MM-dd" -> domain -> seconds as the active tab of a frontmost browser.
    var webDays: [String: [String: Double]] = [:]
    var appNames: [String: String] = [:]
    /// "limit|<bundleID>" or "downtime|<bundleID>" -> expiry.
    var overrides: [String: Date] = [:]
    var focus: FocusSession?
    var warned: [String] = []
}

enum BlockReason: Equatable {
    case focus(until: Date)
    case downtime(until: Date)
    case limit(used: TimeInterval, limit: TimeInterval)
    case siteLimit(used: TimeInterval, limit: TimeInterval)

    /// Key prefix for delays and accepted blocks; nil if the block can't be delayed.
    var overrideKind: String? {
        switch self {
        case .focus: nil
        case .downtime: "downtime"
        case .limit: "limit"
        case .siteLimit: "web"
        }
    }
}

/// What a prompt or block screen is about.
enum BlockTarget: Equatable {
    case app(AppRef)
    case website(String)

    var key: String {
        switch self {
        case .app(let a): a.bundleID
        case .website(let d): d
        }
    }
    var name: String {
        switch self {
        case .app(let a): a.name
        case .website(let d): d
        }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Lenient decoding
// Saved files from older versions lack newer fields. Missing (or unreadable) fields fall back to
// their defaults instead of failing the whole file, so upgrades never lose settings or history.

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, _ fallback: @autoclosure () -> T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback()
    }
}

extension Config {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config()
        limits = c.value(.limits, d.limits)
        downtime = c.value(.downtime, d.downtime)
        focusBlocklist = c.value(.focusBlocklist, d.focusBlocklist)
        focusWebsites = c.value(.focusWebsites, d.focusWebsites)
        focusMinutes = c.value(.focusMinutes, d.focusMinutes)
        settings = c.value(.settings, d.settings)
        websites = c.value(.websites, d.websites)
        focusLists = c.value(.focusLists, d.focusLists)
    }
}

extension UsageState {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        days = c.value(.days, [:])
        webDays = c.value(.webDays, [:])
        appNames = c.value(.appNames, [:])
        overrides = c.value(.overrides, [:])
        focus = c.value(.focus, nil)
        warned = c.value(.warned, [])
    }
}

extension FocusSession {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        apps = try c.decode([AppRef].self, forKey: .apps)
        start = try c.decode(Date.self, forKey: .start)
        end = try c.decode(Date.self, forKey: .end)
        websites = c.value(.websites, [])
        listName = c.value(.listName, nil)
        mode = c.value(.mode, .exempt)
        allowedApps = c.value(.allowedApps, [])
        allowedWebsites = c.value(.allowedWebsites, [])
    }
}

extension DowntimeSchedule {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DowntimeSchedule()
        enabled = c.value(.enabled, d.enabled)
        mode = c.value(.mode, d.mode)
        everyDay = c.value(.everyDay, d.everyDay)
        days = c.value(.days, d.days)
        blockAtDowntime = c.value(.blockAtDowntime, d.blockAtDowntime)
        alwaysAllowed = c.value(.alwaysAllowed, d.alwaysAllowed)
        blockedWebsites = c.value(.blockedWebsites, d.blockedWebsites)
    }
}

extension AppSettings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        strictCooldownHours = c.value(.strictCooldownHours, d.strictCooldownHours)
        blockAction = c.value(.blockAction, d.blockAction)
        idleThreshold = c.value(.idleThreshold, d.idleThreshold)
        warnings = c.value(.warnings, d.warnings)
        showMenuBarItem = c.value(.showMenuBarItem, d.showMenuBarItem)
    }
}

extension FocusList {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID())
        name = c.value(.name, "Untitled")
        symbol = c.value(.symbol, "book.fill")
        color = c.value(.color, "blue")
        mode = c.value(.mode, .exempt)
        blockedApps = c.value(.blockedApps, [])
        blockedWebsites = c.value(.blockedWebsites, [])
        allowedApps = c.value(.allowedApps, [])
        allowedWebsites = c.value(.allowedWebsites, [])
    }
}

// MARK: - Formatting

func formatDuration(_ seconds: TimeInterval, style: DurationStyle = .short) -> String {
    let total = Int(seconds.rounded(.down))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    switch style {
    case .short:
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        if m > 0 { return "\(m)m" }
        return seconds > 0 ? "<1m" : "0m"
    case .clock:
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

enum DurationStyle { case short, clock }
