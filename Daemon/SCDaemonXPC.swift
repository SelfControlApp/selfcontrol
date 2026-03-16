import Foundation

/// Handles incoming XPC calls. Each connection gets its own instance.
/// Validates authorization, then delegates to SCDaemonBlockMethods.
final class SCDaemonXPC: NSObject, SCDaemonProtocol {

    func startBlock(controllingUID: UInt32,
                    blocklist: [String],
                    isAllowlist: Bool,
                    endDate: Date,
                    blockSettings: [String: Any],
                    authorization: Data,
                    reply: @escaping (Error?) -> Void) {
        // TODO: Validate authorization, delegate to SCDaemonBlockMethods
        NSLog("stonectld: startBlock called with %d entries, endDate=%@", blocklist.count, endDate as NSDate)
        reply(nil)
    }

    func updateBlocklist(_ newBlocklist: [String],
                         authorization: Data,
                         reply: @escaping (Error?) -> Void) {
        // TODO: Validate authorization, delegate to SCDaemonBlockMethods
        reply(nil)
    }

    func updateBlockEndDate(_ newEndDate: Date,
                            authorization: Data,
                            reply: @escaping (Error?) -> Void) {
        // TODO: Validate authorization, delegate to SCDaemonBlockMethods
        reply(nil)
    }

    func getVersion(reply: @escaping (String) -> Void) {
        reply(StoneConstants.versionString)
    }
}
