//
//  PlistListner.swift
//  SelfControlExtension
//
//  Created by Satendra Singh on 16/08/25.
//

import Foundation
import Network
import os.log

enum ServicePath: String {
    case chrome = "/chrome"
    case safari = "/safari"
}

final class ChromeExtensionRequestListner: NSObject, ObservableObject {
    private var isChromeStatusSetInExtension: Bool = false
    var listener: NWListener?
    var blockeddomainFetcher: (() -> [String])?
    var isBlockingEnabled: Bool = false
    var onExtensionStateChange: (() -> Void)?

    func startListening() {
        os_log("[SC] 🔍] PlistListner startListening")

        // Safely convert Int port to NWEndpoint.Port
        guard let port = NWEndpoint.Port(rawValue: SafariConst.servicePort) else {
            os_log("[SC] 🔍] Invalid service port: %d", SafariConst.servicePort)
            return
        }
        do {
            listener = try NWListener(using: .tcp, on: port)
        } catch {
            os_log("[SC] 🔍] Failed to create NWListener: %{public}@", error.localizedDescription)
            return
        }
        
        listener?.newConnectionHandler = { conn in
            print("Path: \(conn.endpoint.debugDescription)")
            conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
                if let data = data,
                   let req = String(data: data, encoding: .utf8) {
                    print("Raw Request:", req)
                    if let service = req.httpPathFromConnection() {
                        switch service {
                        case .chrome:
                            print("Chrome request received")
                            os_log("[SC] 🔍] Chrome request received")

                            self.sendChromeBlockedUrls(connection: conn)
                            self.updateChromeStatus()
                        case .safari:
                            // Handle Safari service path if needed
                            conn.cancel()
                            print("Safari request received")
                            os_log("[SC] 🔍] Safari request received")
                            self.updateSafariStatus()
                            break
                        }
                    }
                }
            }

            conn.start(queue: DispatchQueue.global(qos: .userInitiated))

            conn.stateUpdateHandler = { state in
                if state == .ready {
                    os_log("[SC] 🔍] PlistListner stateUpdateHandler ready")
                }
                if state == .cancelled {
                    os_log("[SC] 🔍] PlistListner stateUpdateHandler cancelled")
                }
            }
        }
        
        listener?.start(queue: DispatchQueue.global(qos: .userInitiated))
    }
    
    func activateSafariBlocking() {
        isBlockingEnabled = true
    }
    
    func deactivateSafariBlocking() {
        isBlockingEnabled = false
    }
    
    private func sendChromeBlockedUrls(connection: NWConnection) {
        print("sendChromeBlockedUrls")
        
        var blockedDomainList: [String] = self.blockeddomainFetcher?() ?? []
        if self.isBlockingEnabled == false {
            blockedDomainList = []
        }
        let blockedUrls = ["blocked": blockedDomainList]
        let jsonData = try! JSONSerialization.data(withJSONObject: blockedUrls, options: [])
        let jsonString = String(data: jsonData, encoding: .utf8)!

        os_log("[SC] 🔍] PlistListner newConnectionHandler")
        os_log("[SC] 🔍] PlistListner conn.receiveMessage")
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Access-Control-Allow-Origin: *\r
        \r
        \(jsonString)
        """
        connection.send(content: response.data(using: .utf8), contentContext: .finalMessage , completion: .contentProcessed { error in
            if let error = error {
                os_log("[SC] 🔍] PlistListner Sent response error: %{public}@", "\(error)")
            } else {
                os_log("[SC] 🔍] PlistListner Sent response successfully")
            }
        })
    }
    
    private func updateSafariStatus() {
        SafariExtensionManager.shared.lastUpdateReceivedTime = Date()
    }
    
    private func updateChromeStatus() {
        Task { @MainActor in
            print("newConnectionHandler isEnabled: \(NetworkExtensionState.shared.isEnabled)")
            if NetworkExtensionState.shared.isEnabled == true && NetworkExtensionState.shared.isChromeExtensionEnabled == false {
                NetworkExtensionState.shared.isChromeExtensionEnabled  = IPCConnection.shared.sendMessageToSetActiveBrowserExtension(ActiveBrowserExtensios.chrome.rawValue, state: true)
                NetworkExtensionState.shared.printAll()
            }
            if isChromeStatusSetInExtension == false {
                isChromeStatusSetInExtension = true
                self.onExtensionStateChange?()
            }
        }
    }

}

extension String {
    func httpPathFromConnection() -> ServicePath? {
        if let firstLine = components(separatedBy: "\r\n").first {
            print("Request Line:", firstLine)

            let parts = firstLine.split(separator: " ")
            if parts.count >= 2 {
                let path = parts[1]
                print("HTTP Path:", path)
                return ServicePath(rawValue: String(path))
            }
        }
        return nil
    }
}
