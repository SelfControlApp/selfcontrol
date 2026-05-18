//
//  HostAppValidator.swift
//  SelfControl
//
//  Created by Satendra Singh on 29/11/25.
//

import NetworkExtension
import OSLog

struct RequestSourceAppValidator {
    
    static func isAllowedHost(flow: NEFilterFlow) -> Bool {
        let process = processFromflow(flow: flow)
//        os_log(" FilterDataProvider: appIdAndName %{public}@, %{public}@", log: OSLog.default, type: .debug, process?.name ?? "", process?.path ?? "")
        os_log(" FilterDataProvider: app %{public}@", log: OSLog.default, type: .debug, process?.description ?? "")
        let isSafariExtensionEnabled = IPCConnection.shared.isSafariExtensionEnable
        let isChromeExtensionEnabled = IPCConnection.shared.isGoogleChromeEnabled

        if let process = process, AllowedProcess.isAllowedProcess(process, isSafariExtensionActive: isSafariExtensionEnabled, isChromeExtensionActive: isChromeExtensionEnabled) {
//            os_log("[SC] 🔍] handleNewFlow: allowing as it is in allowed list.")
            return true
        }
        return false
    }
    
    static func processFromflow(flow: NEFilterFlow) -> Process? {
        guard let auditTokenData = flow.sourceAppAuditToken else {
            return nil
        }
        
        // Convert NSData → audit_token_t
        var auditToken = auditTokenData.withUnsafeBytes { ptr -> audit_token_t in
            return ptr.load(as: audit_token_t.self)
        }
        return Process.init(&auditToken)
    }
}
