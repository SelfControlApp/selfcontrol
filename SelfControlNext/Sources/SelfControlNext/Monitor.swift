import AppKit
import CoreGraphics
import UserNotifications

/// Tracks foreground app usage once a second and enforces focus sessions, downtime and limits.
@MainActor
final class Monitor: NSObject, UNUserNotificationCenterDelegate {
    let store: Store
    private let shield = ShieldController()
    private let delayPrompt = DelayPromptController()
    private var timer: Timer?
    private var lastTick = Date()
    private var lastSave = Date()
    private var lastHeartbeat = Date.distantPast
    private var hadFocus = false
    private var screenLocked = false
    private var asleep = false
    private var displayAsleep = false
    /// domain -> last time we blanked its tab / asked the helper to block it (throttling).
    private var lastSiteAction: [String: Date] = [:]
    private var lastHelperBlockRequest: [String: Date] = [:]
    /// pid -> when we asked it to quit. Gives the app time to show a "Save changes?" sheet.
    private var quitRequests: [pid_t: Date] = [:]

    init(store: Store) {
        self.store = store
    }

    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { if let app { self?.enforce(app) } }
        }
        ws.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { if let app { self?.enforce(app) } }
        }
        ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.asleep = true }
        }
        ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.asleep = false; self?.lastTick = Date() }
        }
        ws.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.displayAsleep = true }
        }
        ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.displayAsleep = false; self?.lastTick = Date() }
        }
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenLocked = true }
        }
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenLocked = false; self?.lastTick = Date() }
        }

        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: Tick

    private func tick() {
        let now = Date()
        // Cap the delta so time asleep or a stalled run loop is never counted.
        let delta = min(max(0, now.timeIntervalSince(lastTick)), 5)
        lastTick = now

        if let focus = store.state.focus, focus.end <= now {
            store.state.focus = nil
            store.saveState()
        }
        let focusActive = store.activeFocus != nil
        if hadFocus && !focusActive {
            notify(id: "focus-done", title: "Focus session complete", body: "Your blocked apps and websites are available again.")
        }
        hadFocus = focusActive

        if now.timeIntervalSince(lastHeartbeat) >= 5 {
            lastHeartbeat = now
            Task { await store.heartbeat() }
        }

        if let front = NSWorkspace.shared.frontmostApplication, let id = front.bundleIdentifier,
           id != Store.ownBundleID, front.activationPolicy == .regular {
            if isUserActive {
                store.addUsage(bundleID: id, name: front.localizedName ?? id, seconds: delta, at: now)
            }
            enforce(front)
            warnAboutLimit(bundleID: id, name: front.localizedName ?? id)
        }
        trackWebsite(front: NSWorkspace.shared.frontmostApplication, delta: delta, now: now)
        warnAboutDowntime(now: now)

        quitRequests = quitRequests.filter { now.timeIntervalSince($0.value) < 30 }
        if now.timeIntervalSince(lastSave) > 30 {
            store.saveState()
            lastSave = now
        }
    }

    // MARK: Websites

    private func trackWebsite(front: NSRunningApplication?, delta: TimeInterval, now: Date) {
        store.browser.update(frontmost: front)
        guard let visit = store.browser.current, front?.bundleIdentifier == visit.browserID else { return }
        // Websites count even without keyboard/mouse input (e.g. watching a video), but not while
        // the screen is locked, asleep, or off.
        let screenOn = !screenLocked && !asleep && !displayAsleep
        let whitelisted = store.effectiveRules.websites.isWhitelisted(host: visit.host)
        if screenOn && !whitelisted {
            store.addWebUsage(domain: visit.domain, seconds: delta, at: now)
            warnAboutSite(visit.domain)
        }
        enforceSite(visit)
    }

    private func enforceSite(_ visit: BrowserTracker.Visit) {
        guard let reason = store.siteBlockReason(for: visit) else { return }
        let target = BlockTarget.website(visit.domain)
        if let kind = reason.overrideKind, store.allowsDelay(reason), !store.isBlockAccepted(kind, visit.domain) {
            delayPrompt.present(target: target, reason: reason, delaysToday: store.delayCount(for: visit.domain)) { [weak self] choice in
                self?.resolveSitePrompt(choice, kind: kind, visit: visit)
            }
            return
        }
        blockSite(visit, reason: reason)
    }

    private func blockSite(_ visit: BrowserTracker.Visit, reason: BlockReason) {
        let now = Date()
        if case .siteLimit = reason, store.helper.status?.websiteBlocks[visit.domain] == nil,
           now.timeIntervalSince(lastHelperBlockRequest[visit.domain] ?? .distantPast) > 10 {
            lastHelperBlockRequest[visit.domain] = now
            let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
            Task { await store.blockWebsite(visit.domain, until: midnight) }
        }
        // Blank the tab right away (the network block alone leaves an already-loaded page on screen).
        if now.timeIntervalSince(lastSiteAction[visit.domain] ?? .distantPast) > 3 {
            lastSiteAction[visit.domain] = now
            store.browser.blankActiveTab(browserID: visit.browserID)
            shield.present(target: .website(visit.domain), reason: reason)
        }
    }

    private func resolveSitePrompt(_ choice: DelayChoice, kind: String, visit: BrowserTracker.Visit) {
        let now = Date()
        switch choice {
        case .delay(let minutes):
            let clamped = min(max(minutes, 1), DelayPromptController.maxDelayMinutes)
            store.setOverride(kind, visit.domain, until: now.addingTimeInterval(TimeInterval(clamped * 60)))
            store.recordDelay(for: visit.domain)
            NSRunningApplication.runningApplications(withBundleIdentifier: visit.browserID).first?.activate()
        case .blockNow:
            let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
            store.acceptBlock(kind, visit.domain, until: midnight)
            lastHelperBlockRequest[visit.domain] = now
            Task { await store.blockWebsite(visit.domain, until: midnight) }
            if let reason = store.siteBlockReason(for: visit) { blockSite(visit, reason: reason) }
        }
    }

    private func warnAboutSite(_ domain: String) {
        guard store.config.settings.warnings, let limit = store.effectiveRules.websites.limitSeconds else { return }
        let remaining = limit - store.webUsage(for: domain)
        if remaining > 0 && remaining <= 300, store.markWarned("web|\(domain)|5") {
            notify(id: "web-\(domain)", title: "5 minutes left on \(domain)",
                   body: "You're close to your \(formatDuration(limit)) daily limit for this site.")
        }
    }

    private var isUserActive: Bool {
        if screenLocked || asleep { return false }
        let threshold = store.config.settings.idleThreshold
        guard threshold > 0, let anyInput = CGEventType(rawValue: ~0) else { return true }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput) < threshold
    }

    // MARK: Enforcement

    private func enforce(_ app: NSRunningApplication) {
        guard app.activationPolicy == .regular, let id = app.bundleIdentifier,
              let reason = store.blockReason(for: id) else { return }
        if quitRequests[app.processIdentifier] != nil { return } // already asked; let it finish (e.g. save dialog)
        let ref = AppRef(bundleID: id, name: app.localizedName ?? id, path: app.bundleURL?.path)

        // Limits and Downtime ask first (unless Strict Mode is on, or the block was already accepted).
        if let kind = reason.overrideKind, store.allowsDelay(reason), !store.isBlockAccepted(kind, id) {
            delayPrompt.present(target: .app(ref), reason: reason, delaysToday: store.delayCount(for: id)) { [weak self] choice in
                self?.resolvePrompt(choice, kind: kind, reason: reason, app: ref)
            }
            return
        }
        block(app, ref: ref, reason: reason)
    }

    private func block(_ app: NSRunningApplication, ref: AppRef, reason: BlockReason) {
        switch store.config.settings.blockAction {
        case .quit:
            quitRequests[app.processIdentifier] = Date()
            if !app.terminate() { app.hide() }
        case .hide:
            app.hide()
        }
        shield.present(target: .app(ref), reason: reason)
    }

    private func resolvePrompt(_ choice: DelayChoice, kind: String, reason: BlockReason, app: AppRef) {
        let now = Date()
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).filter { !$0.isTerminated }
        switch choice {
        case .delay(let minutes):
            let clamped = min(max(minutes, 1), DelayPromptController.maxDelayMinutes)
            store.setOverride(kind, app.bundleID, until: now.addingTimeInterval(TimeInterval(clamped * 60)))
            store.recordDelay(for: app.bundleID)
            running.first?.activate()   // hand focus back; we'll ask again when the delay runs out
        case .blockNow:
            let until: Date
            switch reason {
            case .downtime(let end): until = end
            default: until = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
            }
            store.acceptBlock(kind, app.bundleID, until: until)
            for instance in running { enforce(instance) }
        }
    }

    // MARK: Notifications

    private func warnAboutLimit(bundleID: String, name: String) {
        guard store.config.settings.warnings, let limit = store.limit(for: bundleID),
              let seconds = limit.limitSeconds(on: Date()) else { return }
        let remaining = seconds - store.usage(for: bundleID)
        for minutes in [5, 1] where remaining > 0 && remaining <= TimeInterval(minutes * 60) {
            if store.markWarned("limit|\(bundleID)|\(minutes)") {
                notify(id: "limit-\(bundleID)", title: "\(minutes) minute\(minutes == 1 ? "" : "s") left on \(name)",
                       body: "You're close to your \(formatDuration(seconds)) daily limit.")
            }
        }
    }

    private func warnAboutDowntime(now: Date) {
        guard store.config.settings.warnings, let next = store.effectiveRules.downtime.nextStart(after: now),
              next.timeIntervalSince(now) <= 300 else { return }
        if store.markWarned("downtime|\(Int(next.timeIntervalSince1970))") {
            notify(id: "downtime-soon", title: "Downtime starts in 5 minutes",
                   body: "Only Always Allowed apps will be available starting at \(next.formatted(date: .omitted, time: .shortened)).")
        }
    }

    private func notify(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
