//
//  SourceAppAuditTokenBuilder.swift
//  SelfControlExtension
//
//  Created by Satendra Singh on 10/10/25.
//

import NetworkExtension
import Security
import Foundation
import AppKit

struct SourceAppAuditTokenBuilder {

    static func getAppInfo(from flow: NEFilterFlow) -> (bundleID: String?, appName: String?) {
        guard let auditTokenData = flow.sourceAppAuditToken else {
            return (nil, nil)
        }

        // Convert NSData → audit_token_t
        let auditToken = auditTokenData.withUnsafeBytes { ptr -> audit_token_t in
            return ptr.load(as: audit_token_t.self)
        }

        // MARK: 1. Extract PID from audit token
        let pid = audit_token_to_pid(auditToken)

        // MARK: 2. Use SecTask to get bundle identifier
        var bundleID: String? = nil
        if let secTask = SecTaskCreateWithAuditToken(nil, auditToken) {
            // macOS doesn’t define kSecEntitlementApplicationIdentifier constant,
            // so use the raw entitlement string instead:
            let entitlementKey = "application-identifier" as CFString
            bundleID = SecTaskCopyValueForEntitlement(secTask, entitlementKey, nil) as? String
        }

        // MARK: 3. Try to get app name from bundle ID
        var appName: String? = nil
        if let bundleID = bundleID,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            appName = appURL.deletingPathExtension().lastPathComponent
        }

        // MARK: 4. Fallback: get executable name via proc_pidpath()
        if appName == nil {
            var pathBuffer = [CChar](repeating: 0, count: Int(PATH_MAX))
            let result = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            if result > 0 {
                let path = String(cString: pathBuffer)
                appName = URL(fileURLWithPath: path).lastPathComponent
            }
        }

        return (bundleID, appName)
    }

    // Helper: extract PID from audit_token_t
    private static func audit_token_to_pid(_ token: audit_token_t) -> pid_t {
        return pid_t(token.val.0)
    }
}
