import Foundation
import Observation

/// The app's connection to the root helper daemon.
@MainActor @Observable
final class HelperClient {
    enum Health: Equatable {
        case notInstalled, connecting, running, outdated, unreachable
    }

    private(set) var status: HelperStatus?
    private(set) var health: Health = .connecting
    private(set) var isBusy = false

    @ObservationIgnored private var connection: NSXPCConnection?

    var isInstalled: Bool { FileManager.default.fileExists(atPath: Constants.helperPlistPath) }
    var isAvailable: Bool { health == .running || health == .outdated }
    var isStrict: Bool { isAvailable && status?.strict != nil }

    // MARK: Requests

    @discardableResult
    func send(_ request: HelperRequest) async throws -> HelperResponse {
        guard isInstalled else {
            health = .notInstalled
            throw HelperError.message("The SelfControl helper isn't installed.")
        }
        let data = JSON.encode(request)
        do {
            let replyData: Data = try await withCheckedThrowingContinuation { continuation in
                let once = Once(continuation)
                let proxy = connectionForRequests().remoteObjectProxyWithErrorHandler { error in
                    once.resume(throwing: error)
                } as? HelperXPCProtocol
                guard let proxy else { return once.resume(throwing: HelperError.message("Couldn't reach the helper.")) }
                proxy.handle(data) { once.resume(returning: $0) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    once.resume(throwing: HelperError.message("The helper didn't respond."))
                }
            }
            let response = try JSON.decode(HelperResponse.self, replyData)
            status = response.status
            health = response.status.version == Constants.helperVersion ? .running : .outdated
            if let error = response.error { throw HelperError.message(error) }
            return response
        } catch let error as HelperError {
            throw error
        } catch {
            health = .unreachable
            connection?.invalidate()
            connection = nil
            throw HelperError.message("Couldn't reach the helper: \(error.localizedDescription)")
        }
    }

    func refresh() async {
        guard isInstalled else { health = .notInstalled; status = nil; return }
        _ = try? await send(.status)
    }

    private func connectionForRequests() -> NSXPCConnection {
        if let connection { return connection }
        let c = NSXPCConnection(machServiceName: Constants.helperLabel, options: .privileged)
        c.remoteObjectInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        c.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        c.resume()
        connection = c
        return c
    }

    // MARK: Install / uninstall

    /// Copies this binary to /Library/PrivilegedHelperTools and registers it as a LaunchDaemon.
    /// macOS asks for an administrator password.
    func install() async throws {
        guard let executable = Bundle.main.executablePath else { throw HelperError.message("Can't find the app's executable.") }
        let label = Constants.helperLabel
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(label)</string>
            <key>ProgramArguments</key><array><string>\(Constants.helperPath)</string><string>--daemon</string></array>
            <key>MachServices</key><dict><key>\(label)</key><true/></dict>
            <key>RunAtLoad</key><true/>
            <key>KeepAlive</key><true/>
            <key>StandardErrorPath</key><string>/Library/Logs/SelfControlNext-helper.log</string>
        </dict>
        </plist>
        """
        let script = """
        set -e
        /bin/launchctl bootout system/\(label) 2>/dev/null || true
        /bin/mkdir -p /Library/PrivilegedHelperTools
        /bin/cp -f \(shellQuote(executable)) '\(Constants.helperPath)'
        /usr/sbin/chown root:wheel '\(Constants.helperPath)'
        /bin/chmod 755 '\(Constants.helperPath)'
        /usr/bin/codesign --force --sign - --identifier '\(label)' '\(Constants.helperPath)'
        /bin/cat > '\(Constants.helperPlistPath)' <<'PLIST'
        \(plist)
        PLIST
        /usr/sbin/chown root:wheel '\(Constants.helperPlistPath)'
        /bin/chmod 644 '\(Constants.helperPlistPath)'
        for i in 1 2 3 4 5; do /bin/launchctl bootstrap system '\(Constants.helperPlistPath)' && exit 0; sleep 1; done
        exit 1
        """
        try await runAsAdmin(script)
        connection?.invalidate()
        connection = nil
        try await Task.sleep(for: .milliseconds(500))
        await refresh()
    }

    func uninstall() async throws {
        if health == .running || health == .outdated {
            try await send(.prepareUninstall)   // refuses while a session or Strict Mode is active
        }
        let label = Constants.helperLabel
        try await runAsAdmin("""
        /bin/launchctl bootout system/\(label) 2>/dev/null || true
        /bin/rm -f '\(Constants.helperPlistPath)' '\(Constants.helperPath)'
        """)
        connection?.invalidate()
        connection = nil
        status = nil
        health = .notInstalled
    }

    private func runAsAdmin(_ script: String) async throws {
        isBusy = true
        defer { isBusy = false }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let scriptURL = dir.appendingPathComponent("helper.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let appleScript = "do shell script \"/bin/bash \(shellQuote(scriptURL.path))\" with administrator privileges"
            .replacingOccurrences(of: "\\", with: "\\\\")
        let (status, output) = await Task.detached { () -> (Int32, String) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", appleScript]
            let pipe = Pipe()
            p.standardError = pipe
            p.standardOutput = pipe
            do { try p.run() } catch { return (-1, error.localizedDescription) }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        }.value
        if status != 0 {
            if output.contains("-128") { throw HelperError.message("Cancelled.") }
            throw HelperError.message("The installer failed: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum HelperError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let m): m }
    }
}

/// Resumes a continuation at most once (XPC can call both the reply and the error handler).
private final class Once<T>: @unchecked Sendable {
    private var continuation: CheckedContinuation<T, Error>?
    private let lock = NSLock()
    init(_ c: CheckedContinuation<T, Error>) { continuation = c }

    func resume(returning value: T) { take()?.resume(returning: value) }
    func resume(throwing error: Error) { take()?.resume(throwing: error) }

    private func take() -> CheckedContinuation<T, Error>? {
        lock.lock(); defer { lock.unlock() }
        let c = continuation
        continuation = nil
        return c
    }
}
