import Foundation
import Security

/// Manages authorization rights for daemon XPC methods.
enum SCXPCAuthorization {

    // Right names for each daemon method
    private static let rightStartBlock = "com.max4c.stone.startBlock"
    private static let rightUpdateBlocklist = "com.max4c.stone.updateBlocklist"
    private static let rightUpdateEndDate = "com.max4c.stone.updateBlockEndDate"

    /// Set up authorization rights in the policy database.
    static func setupAuthorizationRights(_ authRef: AuthorizationRef) {
        let rights: [(String, String)] = [
            (rightStartBlock, "Start a Stone block"),
            (rightUpdateBlocklist, "Update the active blocklist"),
            (rightUpdateEndDate, "Extend the block duration"),
        ]

        for (right, description) in rights {
            var err = AuthorizationRightGet(right, nil)
            if err == errAuthorizationDenied {
                // Right doesn't exist yet — create it requiring admin auth
                let rightDefinition: [String: Any] = [
                    "class": "user",
                    "comment": description,
                    "group": "admin",
                    "timeout": 300,
                    "shared": true,
                ]
                err = AuthorizationRightSet(authRef, right, rightDefinition as CFDictionary, description as CFString, nil, nil)
                if err != errAuthorizationSuccess {
                    NSLog("SCXPCAuthorization: Failed to set right '%@': %d", right, err)
                }
            }
        }
    }

    /// Validate that the given authorization data grants the right for a command.
    static func checkAuthorization(_ authData: Data, for commandName: String) throws {
        let rightName = self.rightName(for: commandName)

        var authRef: AuthorizationRef?
        let status = authData.withUnsafeBytes { rawPtr -> OSStatus in
            guard let ptr = rawPtr.baseAddress else { return errAuthorizationInvalidRef }
            var extForm = ptr.load(as: AuthorizationExternalForm.self)
            return AuthorizationCreateFromExternalForm(&extForm, &authRef)
        }

        guard status == errAuthorizationSuccess, let auth = authRef else {
            throw SCError.authorizationFailed
        }
        defer { AuthorizationFree(auth, [])  }

        var item = AuthorizationItem(name: rightName, valueLength: 0, value: nil, flags: 0)
        var rights = AuthorizationRights(count: 1, items: &item)
        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights]

        let result = AuthorizationCopyRights(auth, &rights, nil, flags, nil)
        guard result == errAuthorizationSuccess else {
            throw SCError.authorizationFailed
        }
    }

    /// Create authorization data (external form) for sending with XPC calls.
    static func createAuthorizationData() throws -> Data {
        var authRef: AuthorizationRef?
        var status = AuthorizationCreate(nil, nil, [], &authRef)
        guard status == errAuthorizationSuccess, let auth = authRef else {
            throw SCError.authorizationFailed
        }

        // Pre-authorize with admin rights
        let rightName = "com.max4c.stone.startBlock"
        var item = AuthorizationItem(name: rightName, valueLength: 0, value: nil, flags: 0)
        var rights = AuthorizationRights(count: 1, items: &item)
        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]

        status = AuthorizationCopyRights(auth, &rights, nil, flags, nil)
        guard status == errAuthorizationSuccess else {
            throw SCError.authorizationFailed
        }

        var extForm = AuthorizationExternalForm()
        status = AuthorizationMakeExternalForm(auth, &extForm)
        guard status == errAuthorizationSuccess else {
            throw SCError.authorizationFailed
        }

        return Data(bytes: &extForm, count: MemoryLayout<AuthorizationExternalForm>.size)
    }

    private static func rightName(for commandName: String) -> String {
        switch commandName {
        case "startBlock": return rightStartBlock
        case "updateBlocklist": return rightUpdateBlocklist
        case "updateBlockEndDate": return rightUpdateEndDate
        default: return rightStartBlock
        }
    }
}
