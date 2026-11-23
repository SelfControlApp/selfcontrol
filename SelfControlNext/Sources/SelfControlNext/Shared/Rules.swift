import Foundation

// Code shared by the app and the root helper daemon (which is this same binary run with --daemon).

enum Constants {
    static let appBundleID = "org.eyebeam.SelfControlNext"
    static let helperLabel = "org.eyebeam.SelfControlNext.helper"
    static let helperPath = "/Library/PrivilegedHelperTools/org.eyebeam.SelfControlNext.helper"
    static let helperPlistPath = "/Library/LaunchDaemons/org.eyebeam.SelfControlNext.helper.plist"
    /// Bump whenever the helper's behavior or protocol changes so the app offers an update.
    static let helperVersion = 2

    /// Apps that are never blocked, regardless of rules.
    static let essentialBundleIDs: Set<String> = [
        appBundleID, "com.apple.finder", "com.apple.loginwindow", "com.apple.dock", "com.apple.SecurityAgent",
        "com.apple.systemuiserver", "com.apple.controlcenter", "com.apple.Spotlight",
        "com.apple.notificationcenterui", "com.apple.UserNotificationCenter", "com.apple.ScreenSaver.Engine",
    ]
}

private let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

func dayKey(_ date: Date = Date()) -> String { dayFormatter.string(from: date) }

// MARK: - Rules (what Strict Mode locks)

struct Rules: Codable, Equatable {
    var limits: [AppLimit]
    var downtime: DowntimeSchedule
    var websites = WebsiteLimits()

    /// Human-readable descriptions of every way `new` is less strict than `old`. Empty means `new`
    /// is at least as strict, so the change is allowed under Strict Mode.
    static func loosenings(from old: Rules, to new: Rules) -> [String] {
        var problems: [String] = []

        for oldLimit in old.limits where oldLimit.enabled {
            guard let newLimit = new.limits.first(where: { $0.id == oldLimit.id }), newLimit.enabled else {
                problems.append("remove the limit on \(oldLimit.app.name)")
                continue
            }
            for wd in 1...7 {
                guard let before = oldLimit.minutes(forWeekday: wd) else { continue }
                if let after = newLimit.minutes(forWeekday: wd), after <= before { continue }
                problems.append("raise \(oldLimit.app.name)'s limit on \(Weekdays.name(wd))")
                break
            }
        }

        let o = old.downtime, n = new.downtime
        if o.enabled {
            if !n.enabled {
                problems.append("turn off Downtime")
            } else {
                if !n.coverage.isSuperset(of: o.coverage) { problems.append("shorten Downtime") }
                let oldAllowed = Set(o.alwaysAllowed.map(\.bundleID))
                if let added = n.alwaysAllowed.first(where: { !oldAllowed.contains($0.bundleID) }) {
                    problems.append("allow \(added.name) during Downtime")
                }
                if o.blockAtDowntime && !n.blockAtDowntime { problems.append("turn off Block at Downtime") }
                let newSites = Set(n.blockedWebsites)
                if let removed = o.blockedWebsites.first(where: { !newSites.contains($0) }) {
                    problems.append("unblock \(removed) during Downtime")
                }
            }
        }
        let ow = old.websites, nw = new.websites
        if ow.enabled {
            if !nw.enabled {
                problems.append("turn off website limits")
            } else if nw.minutesPerSite > ow.minutesPerSite {
                problems.append("raise the website limit")
            }
            let oldWhitelist = Set(ow.whitelist)
            if let added = nw.whitelist.first(where: { !oldWhitelist.contains($0) }) {
                problems.append("whitelist \(added)")
            }
        }
        return problems
    }
}

extension Rules {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        limits = c.value(.limits, [])
        downtime = c.value(.downtime, DowntimeSchedule())
        websites = c.value(.websites, WebsiteLimits())
    }
}

extension AppLimit {
    /// Minutes allowed on a weekday, or nil if there's no limit that day.
    func minutes(forWeekday weekday: Int) -> Int? {
        guard enabled else { return nil }
        if !customDays { return dailyMinutes }
        return perDayEnabled[weekday - 1] ? perDayMinutes[weekday - 1] : nil
    }
}

extension DowntimeSchedule {
    /// Minutes of the week (0 = Sunday 00:00) covered by Downtime.
    var coverage: IndexSet {
        var set = IndexSet()
        guard enabled else { return set }
        let week = 7 * 1440
        for wd in 1...7 {
            guard let w = window(forWeekday: wd) else { continue }
            let dayStart = (wd - 1) * 1440
            let start = w.start.totalMinutes
            let length = w.end > w.start ? w.end.totalMinutes - start : 1440 - start + w.end.totalMinutes
            for m in 0..<length { set.insert((dayStart + start + m) % week) }
        }
        return set
    }
}

// MARK: - Enforcement decision (used by both the app and the helper)

enum Enforcement {
    /// Why an app should be blocked right now, or nil.
    /// `exemptionsAllowed` is false in Strict Mode, so a focus list can't be used to skip locked limits.
    static func reason(bundleID: String, at now: Date, focus: FocusSession?, rules: Rules?,
                       usage: TimeInterval, exemptionsAllowed: Bool = true,
                       isOverridden: (String) -> Bool = { _ in false }) -> BlockReason? {
        if Constants.essentialBundleIDs.contains(bundleID) { return nil }

        var exempt = false
        if let focus, focus.end > now {
            if focus.apps.contains(where: { $0.bundleID == bundleID }) { return .focus(until: focus.end) }
            if focus.mode == .allowlist && !focus.allowsApp(bundleID) { return .focus(until: focus.end) }
            exempt = exemptionsAllowed && focus.allowsApp(bundleID)
        }
        guard let rules else { return nil }

        if let interval = rules.downtime.activeInterval(at: now),
           !rules.downtime.alwaysAllowed.contains(where: { $0.bundleID == bundleID }),
           !isOverridden("downtime") {
            return .downtime(until: interval.end)
        }

        if !exempt, let limit = rules.limits.first(where: { $0.id == bundleID }), let seconds = limit.limitSeconds(on: now),
           usage >= seconds, !isOverridden("limit") {
            return .limit(used: usage, limit: seconds)
        }
        return nil
    }

    /// Why a website (given as the visited host) should be blocked right now, or nil.
    /// `usage` is today's time on the host's registrable domain.
    static func siteReason(host: String, at now: Date, focus: FocusSession?, rules: Rules?,
                           usage: TimeInterval, exemptionsAllowed: Bool = true,
                           isOverridden: (String) -> Bool = { _ in false }) -> BlockReason? {
        var exempt = false
        if let focus, focus.end > now {
            if focus.blocksSite(host) { return .focus(until: focus.end) }
            if focus.mode == .allowlist && !focus.allowsSite(host) { return .focus(until: focus.end) }
            exempt = exemptionsAllowed && focus.allowsSite(host)
        }
        guard let rules, !exempt, !rules.websites.isWhitelisted(host: host),
              let limit = rules.websites.limitSeconds, usage >= limit, !isOverridden("web") else { return nil }
        return .siteLimit(used: usage, limit: limit)
    }
}

// MARK: - Websites

enum Domains {
    /// Turns user input like "https://www.Facebook.com/feed" into "facebook.com". Returns nil if invalid.
    /// IPv4 addresses and CIDR ranges (e.g. "10.0.0.0/8") are passed through.
    static func normalize(_ input: String) -> String? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let r = s.range(of: "://") { s = String(s[r.upperBound...]) }
        if let slash = s.firstIndex(of: "/"), !isIPRange(s) { s = String(s[..<slash]) }
        if let colon = s.lastIndex(of: ":"), !s.contains("]"), s.filter({ $0 == ":" }).count == 1 {
            s = String(s[..<colon])
        }
        if s.hasPrefix("*.") { s.removeFirst(2) }
        if s.hasPrefix("www.") { s.removeFirst(4) }
        guard !s.isEmpty else { return nil }
        if isIPRange(s) || isIPv4(s) { return s }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-.")
        guard s.unicodeScalars.allSatisfy(allowed.contains), s.contains("."),
              !s.hasPrefix("."), !s.hasSuffix("."), !s.contains("..") else { return nil }
        return s
    }

    static func isIPv4(_ s: String) -> Bool {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { UInt8($0) != nil }
    }

    static func isIPRange(_ s: String) -> Bool {
        let parts = s.split(separator: "/")
        guard parts.count == 2, let bits = Int(parts[1]), (0...32).contains(bits) else { return false }
        return isIPv4(String(parts[0]))
    }

    private static let twoPartSuffixes: Set<String> = [
        "co.uk", "org.uk", "ac.uk", "gov.uk", "com.au", "net.au", "org.au", "edu.au", "co.jp", "co.nz",
        "co.in", "com.br", "com.mx", "co.kr", "com.cn", "com.tw", "com.hk", "com.sg", "co.za", "com.tr",
    ]

    /// "m.youtube.com" -> "youtube.com", "news.bbc.co.uk" -> "bbc.co.uk". Nil for hosts like "localhost".
    static func registrableDomain(_ host: String) -> String? {
        let h = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        if isIPv4(h) { return h }
        let labels = h.split(separator: ".")
        guard labels.count >= 2 else { return nil }
        let lastTwo = labels.suffix(2).joined(separator: ".")
        if twoPartSuffixes.contains(lastTwo) {
            return labels.count >= 3 ? labels.suffix(3).joined(separator: ".") : nil
        }
        return lastTwo
    }

    /// The host of an http(s) URL, or nil for anything else (about:, file:, chrome://, …).
    static func host(ofURL string: String) -> String? {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(), !host.isEmpty else { return nil }
        return host
    }

    /// True if `host` is `entry` or a subdomain of it.
    static func matches(_ host: String, _ entry: String) -> Bool {
        let h = host.lowercased(), e = entry.lowercased()
        return h == e || h.hasSuffix("." + e)
    }

    /// Google-owned sites share front-end servers, so blocking one by IP would break the rest of
    /// Google (Search, Docs, Gmail). Like the original SelfControl, block these via hosts only.
    static func isGoogle(_ domain: String) -> Bool {
        domain.range(of: #"^([a-z0-9-]+\.)*(google|youtube|picasa|sketchup|blogger|blogspot|googlevideo|ytimg|ggpht|gstatic|googleapis)\.([a-z]{1,3})(\.[a-z]{1,3})?$"#,
                     options: .regularExpression) != nil
    }

    /// Other domains a site needs to work, used when only certain sites are allowed.
    static let relatedDomains: [String: [String]] = [
        "youtube.com": ["googlevideo.com", "ytimg.com", "ggpht.com", "youtube-nocookie.com", "gstatic.com", "googleapis.com", "google.com"],
        "google.com": ["gstatic.com", "googleapis.com", "googleusercontent.com"],
        "khanacademy.org": ["kastatic.org", "kasandbox.org", "khanacademy.com"],
        "wikipedia.org": ["wikimedia.org", "wikidata.org"],
        "github.com": ["githubusercontent.com", "githubassets.com", "github.io"],
        "notion.so": ["notion.site", "notion-static.com"],
        "chatgpt.com": ["oaistatic.com", "oaiusercontent.com", "openai.com"],
        "claude.ai": ["anthropic.com"],
    ]

    /// Google's address ranges (from the original SelfControl), allowed in full when a Google site is
    /// allowed, because its video and asset hosts can't be resolved ahead of time.
    static let googleRanges: [String] = [
        "8.8.4.0/24", "8.34.208.0/20", "8.35.192.0/20", "23.251.128.0/19", "34.64.0.0/10", "34.128.0.0/10", "35.184.0.0/13", "35.192.0.0/14", "35.196.0.0/15", "35.198.0.0/16", "35.199.0.0/17", "35.199.128.0/18", "35.200.0.0/13", "35.208.0.0/12", "35.224.0.0/12", "35.240.0.0/13", "64.15.112.0/20", "64.233.160.0/19", "66.102.0.0/20", "66.249.64.0/19", "70.32.128.0/19", "72.14.192.0/18", "74.114.24.0/21", "74.125.0.0/16", "104.154.0.0/16", "104.196.0.0/14", "104.237.160.0/19", "107.167.160.0/19", "107.178.192.0/18", "108.59.80.0/20", "108.170.192.0/18", "108.177.0.0/17", "130.211.0.0/16", "136.112.0.0/12", "142.250.0.0/15", "146.148.0.0/17", "162.216.148.0/22", "162.222.176.0/21", "172.110.32.0/21", "172.217.0.0/16", "172.253.0.0/16", "173.194.0.0/16", "173.255.112.0/20", "192.158.28.0/22", "192.178.0.0/15", "193.186.4.0/24", "199.36.154.0/23", "199.36.156.0/24", "199.192.112.0/22", "199.223.232.0/21", "207.223.160.0/20", "208.65.152.0/22", "208.68.108.0/22", "208.81.188.0/22", "208.117.224.0/19", "209.85.128.0/17", "216.58.192.0/19", "216.73.80.0/20", "216.239.32.0/19", "2001:4860::/32", "2404:6800::/32", "2404:f340::/32", "2600:1900::/28", "2606:73c0::/32", "2607:f8b0::/32", "2620:11a:a000::/40", "2620:120:e000::/40", "2800:3f0::/32", "2a00:1450::/32", "2c0f:fb50::/32"
    ]

    /// Hostnames to put in /etc/hosts for a blocked domain.
    static func hostVariants(_ domain: String) -> [String] {
        if isIPv4(domain) || isIPRange(domain) { return [] }
        return [domain, "www.\(domain)", "m.\(domain)"]
    }
}

// MARK: - App <-> helper protocol

@objc protocol HelperXPCProtocol {
    /// `request` is a JSON-encoded HelperRequest; the reply is a JSON-encoded HelperResponse.
    func handle(_ request: Data, withReply reply: @escaping (Data) -> Void)
}

struct StrictLock: Codable, Equatable {
    var since: Date
    var cooldownHours: Double
    /// Set when the user asks to turn Strict Mode off; it turns off at this time.
    var unlockAt: Date?
}

struct Heartbeat: Codable {
    var agentPath: String
    /// day key -> bundle ID -> seconds of foreground use since the last heartbeat.
    var usageDeltas: [String: [String: Double]]
    /// day key -> domain -> seconds as the active browser tab since the last heartbeat.
    var webUsageDeltas: [String: [String: Double]] = [:]
}

extension Heartbeat {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        agentPath = c.value(.agentPath, "")
        usageDeltas = c.value(.usageDeltas, [:])
        webUsageDeltas = c.value(.webUsageDeltas, [:])
    }
}

enum HelperRequest: Codable {
    case status
    case heartbeat(Heartbeat)
    case setRules(Rules)
    case startFocus(FocusSession)
    /// Block these domains until the given times. Can only add sites or extend times.
    case blockWebsites([String: Date])
    case enableStrict(cooldownHours: Double)
    case requestUnlock
    case cancelUnlock
    case prepareUninstall
}

struct HelperStatus: Codable {
    var version: Int
    var focus: FocusSession?
    var rules: Rules?
    var strict: StrictLock?
    var usageToday: [String: Double]
    var blockedDomains: [String]
    var webUsageToday: [String: Double] = [:]
    var websiteBlocks: [String: Date] = [:]
    /// Non-nil while only certain sites are allowed (an "allow only" focus list).
    var allowlist: [String]?
}

extension HelperStatus {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.value(.version, 0)
        focus = c.value(.focus, nil)
        rules = c.value(.rules, nil)
        strict = c.value(.strict, nil)
        usageToday = c.value(.usageToday, [:])
        blockedDomains = c.value(.blockedDomains, [])
        webUsageToday = c.value(.webUsageToday, [:])
        websiteBlocks = c.value(.websiteBlocks, [:])
        allowlist = c.value(.allowlist, nil)
    }
}

struct HelperResponse: Codable {
    var error: String?
    var status: HelperStatus
}

enum JSON {
    static func encode<T: Encodable>(_ value: T) -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return (try? e.encode(value)) ?? Data()
    }

    static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try d.decode(type, from: data)
    }
}
