import AppKit
import Observation

/// Reads the active tab's address from the frontmost browser via AppleScript, so website time can
/// be tracked. macOS asks once per browser for permission ("SelfControl wants to control …").
@MainActor @Observable
final class BrowserTracker {
    enum Family { case safari, chromium }

    /// Browsers whose tab URLs can be read. Firefox-based browsers don't support this.
    static let supported: [String: (name: String, family: Family)] = [
        "com.apple.Safari": ("Safari", .safari),
        "com.apple.SafariTechnologyPreview": ("Safari Technology Preview", .safari),
        "com.google.Chrome": ("Google Chrome", .chromium),
        "com.microsoft.edgemac": ("Microsoft Edge", .chromium),
        "com.brave.Browser": ("Brave", .chromium),
        "company.thebrowser.Browser": ("Arc", .chromium),
        "com.vivaldi.Vivaldi": ("Vivaldi", .chromium),
        "com.operasoftware.Opera": ("Opera", .chromium),
        "org.chromium.Chromium": ("Chromium", .chromium),
    ]
    static let unsupported: [String: String] = [
        "org.mozilla.firefox": "Firefox", "app.zen-browser.zen": "Zen", "org.mozilla.firefoxdeveloperedition": "Firefox Developer Edition",
    ]

    struct Visit: Equatable {
        var browserID: String
        var host: String
        /// Registrable domain, e.g. "youtube.com" for "m.youtube.com". Usage is counted per domain.
        var domain: String
    }

    /// The active tab of the frontmost supported browser, if it's an http(s) page.
    private(set) var current: Visit?
    /// Browsers the user hasn't allowed SelfControl to read.
    private(set) var deniedBrowsers: Set<String> = []
    /// Browsers successfully read at least once.
    private(set) var workingBrowsers: Set<String> = []
    private(set) var unsupportedInUse: Set<String> = []

    @ObservationIgnored private var inFlight = false
    @ObservationIgnored private var lastPoll = Date.distantPast

    /// Called every tick with the frontmost app. Polls at most every 2 seconds.
    func update(frontmost app: NSRunningApplication?) {
        guard let id = app?.bundleIdentifier, let browser = Self.supported[id] else {
            if let id = app?.bundleIdentifier, Self.unsupported[id] != nil { unsupportedInUse.insert(id) }
            if current != nil { current = nil }
            return
        }
        if let current, current.browserID != id { self.current = nil }
        guard !inFlight, Date().timeIntervalSince(lastPoll) >= 2 else { return }
        inFlight = true
        lastPoll = Date()

        let tab = browser.family == .safari ? "current tab" : "active tab"
        let script = "tell application id \"\(id)\" to if (count of windows) > 0 then get URL of \(tab) of front window"
        Task {
            let result = await Self.runAppleScript(script)
            inFlight = false
            switch result {
            case .success(let url):
                workingBrowsers.insert(id)
                deniedBrowsers.remove(id)
                if let host = Domains.host(ofURL: url), let domain = Domains.registrableDomain(host) {
                    let visit = Visit(browserID: id, host: host, domain: domain)
                    if current != visit { current = visit }
                } else if current != nil {
                    current = nil
                }
            case .failure(let error):
                if error.isPermissionDenied { deniedBrowsers.insert(id) }
                if current != nil { current = nil }
            }
        }
    }

    /// Points the frontmost browser's active tab at a blank page, so a blocked site stops right away.
    func blankActiveTab(browserID: String) {
        guard let browser = Self.supported[browserID] else { return }
        let tab = browser.family == .safari ? "current tab" : "active tab"
        let script = "tell application id \"\(browserID)\" to if (count of windows) > 0 then set URL of \(tab) of front window to \"about:blank\""
        Task { _ = await Self.runAppleScript(script) }
    }

    /// Opens System Settings at Privacy & Security → Automation.
    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    struct ScriptError: Error {
        var message: String
        /// errAEEventNotPermitted: the user declined (or hasn't granted) Automation access.
        var isPermissionDenied: Bool { message.contains("-1743") }
    }

    /// Runs AppleScript through osascript off the main thread, with a 2-second timeout so a
    /// hung browser can't stall SelfControl.
    nonisolated static func runAppleScript(_ source: String) async -> Result<String, ScriptError> {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            let out = Pipe(), err = Pipe()
            process.standardOutput = out
            process.standardError = err
            do { try process.run() } catch { return .failure(ScriptError(message: error.localizedDescription)) }
            let deadline = Date().addingTimeInterval(2)
            while process.isRunning && Date() < deadline { usleep(20_000) }
            if process.isRunning {
                process.terminate()
                return .failure(ScriptError(message: "timed out"))
            }
            let output = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if process.terminationStatus != 0 {
                let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                return .failure(ScriptError(message: message))
            }
            return .success(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }.value
    }
}
