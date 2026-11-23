import Foundation
import SystemConfiguration

/// State only the root helper can write. This is the source of truth for anything locked.
struct HelperState: Codable {
    var focus: FocusSession?
    var rules: Rules?
    var strict: StrictLock?
    var usage: [String: [String: Double]] = [:]
    var agentPath: String?
    var appliedDomains: [String] = []
    /// Website-limit blocks the user accepted: domain -> until (end of day).
    var websiteBlocks: [String: Date] = [:]
    /// day -> domain -> seconds, reported by the app.
    var webUsage: [String: [String: Double]] = [:]
    /// Non-nil while an "allow only" list is applied.
    var appliedAllowlist: [String]?
}

extension HelperState {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        focus = c.value(.focus, nil)
        rules = c.value(.rules, nil)
        strict = c.value(.strict, nil)
        usage = c.value(.usage, [:])
        agentPath = c.value(.agentPath, nil)
        appliedDomains = c.value(.appliedDomains, [])
        websiteBlocks = c.value(.websiteBlocks, [:])
        webUsage = c.value(.webUsage, [:])
        appliedAllowlist = c.value(.appliedAllowlist, nil)
    }
}

/// The root LaunchDaemon. Runs as `SelfControlNext --daemon`.
final class HelperDaemon: NSObject, NSXPCListenerDelegate, HelperXPCProtocol, @unchecked Sendable {
    private let queue = DispatchQueue(label: "helper")
    private var state: HelperState
    private let stateURL: URL
    private var listener: NSXPCListener?
    private var timer: DispatchSourceTimer?

    private var lastTick = Date()
    private var lastHeartbeat = Date()   // grace period after the helper starts
    private var lastIntegrityCheck = Date.distantPast
    private var lastAllowlistResolve = Date.distantPast
    private var lastRelaunch = Date.distantPast
    private var terminated: [pid_t: Date] = [:]

    static let heartbeatTimeout: TimeInterval = 12

    override init() {
        let dir = URL(fileURLWithPath: WebsiteBlocker.path("/Library/Application Support/SelfControlNext"))
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o755])
        stateURL = dir.appendingPathComponent("helper-state.json")
        if let data = try? Data(contentsOf: stateURL), let s = try? JSON.decode(HelperState.self, data) {
            state = s
        } else {
            state = HelperState()
        }
        super.init()
    }

    static func run() -> Never {
        let daemon = HelperDaemon()
        daemon.start()
        dispatchMain()
    }

    func start() {
        log("Helper v\(Constants.helperVersion) starting")
        queue.sync {
            // Always re-apply on start: the block must survive restarts and helper crashes.
            if !state.appliedDomains.isEmpty { WebsiteBlocker.apply(domains: state.appliedDomains) }
            tick()
        }
        if !WebsiteBlocker.isTesting {
            let l = NSXPCListener(machServiceName: Constants.helperLabel)
            l.delegate = self
            l.resume()
            listener = l
        }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 2, repeating: 2)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func save() {
        try? JSON.encode(state).write(to: stateURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: stateURL.path)
    }

    // MARK: XPC

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func handle(_ request: Data, withReply reply: @escaping (Data) -> Void) {
        queue.async {
            let error: String?
            do {
                error = self.process(try JSON.decode(HelperRequest.self, request))
            } catch {
                return reply(JSON.encode(HelperResponse(error: "Bad request: \(error)", status: self.status())))
            }
            self.save()
            reply(JSON.encode(HelperResponse(error: error, status: self.status())))
        }
    }

    /// Applies a request. Every request may only make things stricter, except where a Strict Mode
    /// cooldown has run out. Returns an error message if the request was refused.
    func process(_ request: HelperRequest) -> String? {
        let now = Date()
        switch request {
        case .status:
            return nil

        case .heartbeat(let hb):
            lastHeartbeat = now
            state.agentPath = hb.agentPath
            for (day, apps) in hb.usageDeltas {
                for (bundleID, seconds) in apps where seconds > 0 && seconds < 3600 {
                    state.usage[day, default: [:]][bundleID, default: 0] += seconds
                }
            }
            for (day, sites) in hb.webUsageDeltas {
                for (domain, seconds) in sites where seconds > 0 && seconds < 3600 {
                    state.webUsage[day, default: [:]][domain, default: 0] += seconds
                }
            }
            return nil

        case .blockWebsites(let blocks):
            for (domain, until) in blocks where until > now {
                guard let d = Domains.normalize(domain) else { continue }
                state.websiteBlocks[d] = max(state.websiteBlocks[d] ?? .distantPast, until)
            }
            tick()
            return nil

        case .setRules(let rules):
            if state.strict != nil, let current = state.rules {
                let problems = Rules.loosenings(from: current, to: rules)
                if !problems.isEmpty {
                    return "Strict Mode is on, so you can't \(problems.formatted(.list(type: .or)))."
                }
            }
            state.rules = rules
            tick()
            return nil

        case .startFocus(let session):
            guard session.end > now else { return "That session has already ended." }
            if let current = state.focus, current.end > now {
                state.focus = current.merged(with: session)   // can only get stricter
            } else {
                state.focus = session
            }
            tick()
            return nil

        case .enableStrict(let hours):
            guard state.rules != nil else { return "Your rules haven't been sent to the helper yet. Try again." }
            if var lock = state.strict {
                lock.cooldownHours = max(lock.cooldownHours, hours)  // can only get longer
                lock.unlockAt = nil
                state.strict = lock
            } else {
                state.strict = StrictLock(since: now, cooldownHours: max(0, hours), unlockAt: nil)
            }
            return nil

        case .requestUnlock:
            guard var lock = state.strict else { return nil }
            if lock.unlockAt == nil { lock.unlockAt = now.addingTimeInterval(lock.cooldownHours * 3600) }
            state.strict = lock
            tick()
            return nil

        case .cancelUnlock:
            state.strict?.unlockAt = nil
            return nil

        case .prepareUninstall:
            if let focus = state.focus, focus.end > now {
                return "A focus session is running until \(focus.end.formatted(date: .omitted, time: .shortened))."
            }
            if state.strict != nil { return "Turn off Strict Mode first." }
            if let until = state.websiteBlocks.values.filter({ $0 > now }).max() {
                return "Websites over their limit are blocked until \(until.formatted(date: .omitted, time: .shortened))."
            }
            state.rules = nil
            state.focus = nil
            WebsiteBlocker.remove()
            state.appliedDomains = []
            state.appliedAllowlist = nil
            return nil
        }
    }

    func status() -> HelperStatus {
        let now = Date()
        return HelperStatus(version: Constants.helperVersion,
                            focus: state.focus.flatMap { $0.end > now ? $0 : nil },
                            rules: state.rules,
                            strict: state.strict,
                            usageToday: state.usage[dayKey(now)] ?? [:],
                            blockedDomains: state.appliedDomains,
                            webUsageToday: state.webUsage[dayKey(now)] ?? [:],
                            websiteBlocks: state.websiteBlocks.filter { $0.value > now },
                            allowlist: state.appliedAllowlist)
    }

    // MARK: Loop

    func tick() {
        let now = Date()
        let elapsed = min(max(0, now.timeIntervalSince(lastTick)), 5)
        lastTick = now
        var dirty = false

        if let focus = state.focus, focus.end <= now {
            state.focus = nil
            dirty = true
            log("Focus session ended")
        }
        if let unlockAt = state.strict?.unlockAt, unlockAt <= now {
            state.strict = nil
            dirty = true
            log("Strict Mode turned off after cooldown")
        }

        // Websites
        let expiredBlocks = state.websiteBlocks.filter { $0.value <= now }
        if !expiredBlocks.isEmpty {
            state.websiteBlocks = state.websiteBlocks.filter { $0.value > now }
            dirty = true
        }
        let (domains, allowlist) = desiredWebsitePlan(now: now)
        if domains != state.appliedDomains || allowlist != state.appliedAllowlist {
            if domains.isEmpty && allowlist == nil {
                WebsiteBlocker.remove()
            } else {
                WebsiteBlocker.apply(domains: domains, allowlist: allowlist)
                lastAllowlistResolve = now
            }
            state.appliedDomains = domains
            state.appliedAllowlist = allowlist
            dirty = true
            lastIntegrityCheck = now
        } else if allowlist != nil, now.timeIntervalSince(lastAllowlistResolve) >= 300 {
            // Allowed sites' addresses (CDNs) change: look them up again.
            lastAllowlistResolve = now
            lastIntegrityCheck = now
            WebsiteBlocker.apply(domains: domains, allowlist: allowlist)
        } else if !domains.isEmpty || allowlist != nil, now.timeIntervalSince(lastIntegrityCheck) >= 10 {
            lastIntegrityCheck = now
            if !WebsiteBlocker.isIntact(domains: domains) {
                log("Website block was tampered with; re-applying")
                WebsiteBlocker.apply(domains: domains, allowlist: allowlist)
            }
        }

        // Backstop for when the app isn't running (quit, killed, or deleted).
        let enforcing = state.focus != nil || state.strict != nil
        if enforcing, now.timeIntervalSince(lastHeartbeat) > Self.heartbeatTimeout, let user = consoleUser() {
            relaunchAgent(user: user, now: now)
            if enforceProcesses(uid: user.uid, now: now, elapsed: elapsed) { dirty = true }
        }

        pruneUsage(now: now)
        if dirty { save() }
    }

    /// Sites to block and, during an "allow only" session, the sites to allow.
    func desiredWebsitePlan(now: Date) -> (blocked: [String], allowlist: [String]?) {
        var blocked = Set<String>()
        var allowlist: [String]?
        if let focus = state.focus, focus.end > now {
            blocked.formUnion(focus.websites)
            if focus.mode == .allowlist { allowlist = focus.allowedWebsites.sorted() }
        }
        if let rules = state.rules, rules.downtime.activeInterval(at: now) != nil {
            blocked.formUnion(rules.downtime.blockedWebsites)
        }
        blocked.formUnion(state.websiteBlocks.filter { $0.value > now }.keys)
        // In Strict Mode, don't rely on the app: block over-limit sites from our own usage record.
        if state.strict != nil, let rules = state.rules, let limit = rules.websites.limitSeconds {
            for (domain, seconds) in state.webUsage[dayKey(now)] ?? [:]
            where seconds >= limit && !rules.websites.isWhitelisted(host: domain) {
                blocked.insert(domain)
            }
        }
        return (blocked.sorted(), allowlist)
    }

    private func pruneUsage(now: Date) {
        guard state.usage.count > 60, let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: now) else { return }
        let key = dayKey(cutoff)
        state.usage = state.usage.filter { $0.key >= key }
        state.webUsage = state.webUsage.filter { $0.key >= key }
    }

    // MARK: Backstop enforcement

    private func consoleUser() -> (name: String, uid: uid_t)? {
        var uid: uid_t = 0
        guard let name = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) as String?,
              name != "loginwindow", uid >= 500 else { return nil }
        return (name, uid)
    }

    private func relaunchAgent(user: (name: String, uid: uid_t), now: Date) {
        guard !WebsiteBlocker.isTesting, now.timeIntervalSince(lastRelaunch) > 30,
              let path = state.agentPath, FileManager.default.fileExists(atPath: path) else { return }
        lastRelaunch = now
        log("App isn't responding; relaunching \(path)")
        _ = shell("/bin/launchctl", ["asuser", String(user.uid), "/usr/bin/sudo", "-u", user.name,
                                   "/usr/bin/open", "-g", path])
    }

    /// Terminates the user's blocked apps directly. Returns true if usage changed.
    private func enforceProcesses(uid: uid_t, now: Date, elapsed: TimeInterval) -> Bool {
        let rules = state.strict != nil ? state.rules : nil
        let today = dayKey(now)
        var countedApps = Set<String>()
        var usageChanged = false

        for app in RunningApps.list(uid: uid) {
            // Without the app we can't tell which app is in front, so in Strict Mode any time a
            // limited app is open counts toward its limit.
            if let rules, rules.limits.contains(where: { $0.id == app.bundleID && $0.enabled }),
               !countedApps.contains(app.bundleID) {
                countedApps.insert(app.bundleID)
                state.usage[today, default: [:]][app.bundleID, default: 0] += elapsed
                usageChanged = true
            }

            let usage = state.usage[today]?[app.bundleID] ?? 0
            guard Enforcement.reason(bundleID: app.bundleID, at: now, focus: state.focus, rules: rules,
                                     usage: usage, exemptionsAllowed: state.strict == nil) != nil else { continue }

            if let sent = terminated[app.pid], now.timeIntervalSince(sent) > 4 {
                log("Force-killing \(app.bundleID) (\(app.pid))")
                kill(app.pid, SIGKILL)
            } else if terminated[app.pid] == nil {
                log("Terminating blocked app \(app.bundleID) (\(app.pid))")
                terminated[app.pid] = now
                kill(app.pid, SIGTERM)
            }
        }
        terminated = terminated.filter { now.timeIntervalSince($0.value) < 60 }
        return usageChanged
    }
}
