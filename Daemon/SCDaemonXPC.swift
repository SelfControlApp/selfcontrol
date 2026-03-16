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
        do {
            try SCXPCAuthorization.checkAuthorization(authorization, for: "startBlock")
            try SCDaemonBlockMethods.shared.startBlock(
                controllingUID: uid_t(controllingUID),
                blocklist: blocklist,
                isAllowlist: isAllowlist,
                endDate: endDate,
                blockSettings: blockSettings
            )
            reply(nil)
        } catch {
            NSLog("stonectld: startBlock failed: %@", error.localizedDescription)
            reply(error)
        }
    }

    func updateBlocklist(_ newBlocklist: [String],
                         authorization: Data,
                         reply: @escaping (Error?) -> Void) {
        do {
            try SCXPCAuthorization.checkAuthorization(authorization, for: "updateBlocklist")
            try SCDaemonBlockMethods.shared.updateBlocklist(newBlocklist)
            reply(nil)
        } catch {
            reply(error)
        }
    }

    func updateBlockEndDate(_ newEndDate: Date,
                            authorization: Data,
                            reply: @escaping (Error?) -> Void) {
        do {
            try SCXPCAuthorization.checkAuthorization(authorization, for: "updateBlockEndDate")
            try SCDaemonBlockMethods.shared.updateBlockEndDate(newEndDate)
            reply(nil)
        } catch {
            reply(error)
        }
    }

    func getVersion(reply: @escaping (String) -> Void) {
        reply(StoneConstants.versionString)
    }
}
