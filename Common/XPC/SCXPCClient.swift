import Foundation
import ServiceManagement

/// App-side XPC client that manages the connection to the privileged daemon.
final class SCXPCClient {
    private var connection: NSXPCConnection?
    private var authData: Data?

    // MARK: - Daemon Installation

    /// Install the privileged helper daemon via SMJobBless.
    func installDaemon(reply: @escaping (Error?) -> Void) {
        var authRef: AuthorizationRef?
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: nil, flags: 0)
        var authRights = AuthorizationRights(count: 1, items: &authItem)
        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]

        let status = AuthorizationCreate(&authRights, nil, flags, &authRef)
        guard status == errAuthorizationSuccess else {
            reply(SCError.authorizationFailed)
            return
        }

        var blessError: Unmanaged<CFError>?
        let success = SMJobBless(kSMDomainSystemLaunchd, StoneConstants.daemonIdentifier as CFString, authRef, &blessError)

        if success {
            NSLog("SCXPCClient: Daemon installed successfully")

            if let auth = authRef {
                SCXPCAuthorization.setupAuthorizationRights(auth)
            }
        } else {
            let error = blessError?.takeRetainedValue()
            NSLog("SCXPCClient: Failed to install daemon: %@", error.map { String(describing: $0) } ?? "unknown")
            reply(SCError.daemonInstallFailed)
            return
        }

        // [Fix #1] Always create fresh auth data with pre-authorized rights,
        // regardless of whether the daemon was just installed or already existed.
        do {
            authData = try SCXPCAuthorization.createAuthorizationData()
        } catch {
            NSLog("SCXPCClient: Failed to create authorization data: %@", error.localizedDescription)
            reply(SCError.authorizationFailed)
            return
        }

        reply(nil)
    }

    // MARK: - Connection Management

    /// [Fix #2] Invalidate existing connection, create a new one, then run block.
    func refreshConnectionAndRun(_ block: @escaping () -> Void) {
        if let oldConnection = connection {
            connection = nil
            oldConnection.invalidationHandler = { [weak self] in
                self?.connectToHelperTool()
                DispatchQueue.main.async { block() }
            }
            oldConnection.invalidate()
        } else {
            connectToHelperTool()
            block()
        }
    }

    private func connectToHelperTool() {
        let conn = NSXPCConnection(machServiceName: StoneConstants.machServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: SCDaemonProtocol.self)

        conn.invalidationHandler = { [weak self] in
            NSLog("SCXPCClient: Connection invalidated")
            self?.connection = nil
        }
        conn.interruptionHandler = {
            NSLog("SCXPCClient: Connection interrupted")
        }

        conn.resume()
        connection = conn
    }

    private func proxy() -> SCDaemonProtocol? {
        if connection == nil { connectToHelperTool() }
        return connection?.remoteObjectProxyWithErrorHandler { error in
            NSLog("SCXPCClient: Remote proxy error: %@", error.localizedDescription)
        } as? SCDaemonProtocol
    }

    // MARK: - Block Operations

    func startBlock(controllingUID: UInt32,
                    blocklist: [String],
                    isAllowlist: Bool,
                    endDate: Date,
                    blockSettings: [String: Any],
                    reply: @escaping (Error?) -> Void) {
        guard let p = proxy(), let auth = authData else {
            reply(SCError.daemonConnectionFailed)
            return
        }
        p.startBlock(controllingUID: controllingUID,
                     blocklist: blocklist,
                     isAllowlist: isAllowlist,
                     endDate: endDate,
                     blockSettings: blockSettings,
                     authorization: auth,
                     reply: reply)
    }

    func updateBlocklist(_ newBlocklist: [String], reply: @escaping (Error?) -> Void) {
        guard let p = proxy(), let auth = authData else {
            reply(SCError.daemonConnectionFailed)
            return
        }
        p.updateBlocklist(newBlocklist, authorization: auth, reply: reply)
    }

    func updateBlockEndDate(_ newEndDate: Date, reply: @escaping (Error?) -> Void) {
        guard let p = proxy(), let auth = authData else {
            reply(SCError.daemonConnectionFailed)
            return
        }
        p.updateBlockEndDate(newEndDate, authorization: auth, reply: reply)
    }

    func getVersion(reply: @escaping (String) -> Void) {
        guard let p = proxy() else {
            reply("unknown")
            return
        }
        p.getVersion(reply: reply)
    }
}
