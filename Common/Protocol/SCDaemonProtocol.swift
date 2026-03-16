import Foundation

/// XPC protocol for communication between the app/CLI and the privileged daemon.
/// Must be @objc because NSXPCInterface requires it.
@objc protocol SCDaemonProtocol {

    /// Start a new block with the given parameters.
    func startBlock(controllingUID: UInt32,
                    blocklist: [String],
                    isAllowlist: Bool,
                    endDate: Date,
                    blockSettings: [String: Any],
                    authorization: Data,
                    reply: @escaping (Error?) -> Void)

    /// Update the active blocklist (add entries to a running block).
    func updateBlocklist(_ newBlocklist: [String],
                         authorization: Data,
                         reply: @escaping (Error?) -> Void)

    /// Extend the block end date (must be later than current, max +24h).
    func updateBlockEndDate(_ newEndDate: Date,
                            authorization: Data,
                            reply: @escaping (Error?) -> Void)

    /// Get the daemon's version string.
    func getVersion(reply: @escaping (String) -> Void)
}
