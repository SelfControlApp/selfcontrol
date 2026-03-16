import Foundation

/// The privileged helper daemon. Listens for XPC connections from the app/CLI,
/// manages block enforcement timers, and validates connecting clients.
final class SCDaemon: NSObject, NSXPCListenerDelegate {
    static let shared = SCDaemon()

    private var listener: NSXPCListener?
    private var checkupTimer: Timer?
    private var inactivityTimer: Timer?
    private var hostsWatcher: SCFileWatcher?

    override init() {
        super.init()
    }

    // MARK: - Lifecycle

    func start() {
        NSLog("stonectld: Starting daemon...")

        // Create XPC listener on our mach service
        listener = NSXPCListener(machServiceName: StoneConstants.machServiceName)
        listener?.delegate = self
        listener?.resume()

        // Start checkup timer (1 second interval)
        checkupTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkupBlock()
        }

        // Watch /etc/hosts for tampering
        hostsWatcher = SCFileWatcher(path: "/etc/hosts") { [weak self] in
            self?.checkBlockIntegrity()
        }
        hostsWatcher?.start()

        // Start inactivity timer
        resetInactivityTimer()

        NSLog("stonectld: Daemon started, listening on %@", StoneConstants.machServiceName)
    }

    // MARK: - NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // TODO: Validate client code signature via audit token
        #if DEBUG
        // In debug builds, accept all connections for easier testing
        #else
        // In release builds, validate the connecting client's code signature
        // let auditToken = SCGetAuditToken(newConnection)
        // TODO: Verify code signature matches com.max4c.stone
        #endif

        let interface = NSXPCInterface(with: SCDaemonProtocol.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = SCDaemonXPC()
        newConnection.resume()

        resetInactivityTimer()
        return true
    }

    // MARK: - Block Checkup

    private func checkupBlock() {
        SCDaemonBlockMethods.shared.checkupBlock()
    }

    private func checkBlockIntegrity() {
        SCDaemonBlockMethods.shared.checkBlockIntegrity()
    }

    // MARK: - Inactivity

    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in
            self?.handleInactivity()
        }
    }

    private func handleInactivity() {
        guard !SCBlockUtilities.anyBlockIsRunning() else {
            resetInactivityTimer()
            return
        }
        NSLog("stonectld: Idle for 2 minutes with no active block. Exiting.")
        exit(EXIT_SUCCESS)
    }
}
