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

final class ChromeExtensionRequestListner: NSObject {
    private var isChromeStatusSetInExtension: Bool = false
    var listener: NWListener?
    var blockeddomainFetcher: (() -> [String])?
//    private var isBlockingEnabled: Bool = false
    var onExtensionStateChange: (() -> Void)?
    static let servicePort: UInt16 = 8532
//    private var lastUpdateReceivedTime = Date()
    
    func startListening() {
        os_log("[SC] 🔍] PlistListner startListening")

        // Safely convert Int port to NWEndpoint.Port
        guard let port = NWEndpoint.Port(rawValue: ChromeExtensionRequestListner.servicePort) else {
            os_log("[SC] 🔍] BG Invalid service port: %d", ChromeExtensionRequestListner.servicePort)
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
                        Task {
                            await AppStateManager.shared.handleApiRequest(path: service)
                        }
                        switch service {
                        case .chrome:
//                            os_log("[SC] 🔍] BG Chrome request received")

                            Task {
                                await self.sendChromeBlockedUrls(connection: conn)
                            }
//                            self.updateChromeStatus()
                        case .safari:
                            // Handle Safari service path if needed
                            Task {
                                await self.sendChromeBlockedUrls(connection: conn)
                            }
//                            conn.cancel()
//                            os_log("[SC] 🔍] BG Safari request received")
//                            self.updateSafariStatus()
                            break
                        }
                    }
                }
            }

            conn.start(queue: DispatchQueue.global(qos: .userInitiated))

            conn.stateUpdateHandler = { state in
                if state == .ready {
//                    os_log("[SC] 🔍] PlistListner stateUpdateHandler ready")
                }
                if state == .cancelled {
//                    os_log("[SC] 🔍] PlistListner stateUpdateHandler cancelled")
                }
            }
        }
        
        listener?.start(queue: DispatchQueue.global(qos: .userInitiated))
    }
    
//    func activateSafariBlocking() {
//        isBlockingEnabled = true
//    }
//    
//    func deactivateSafariBlocking() {
//        isBlockingEnabled = false
//    }
    
    private func sendChromeBlockedUrls(connection: NWConnection) async {
        let isBlockEnabled = await AppStateManager.shared.isBlockingEnabled
        print("sendChromeBlockedUrls")
//        os_log("[SC] 🔍] BG sendChromeBlockedUrls %{public}d", isBlockEnabled)
        var blockedDomainList: [String] = self.blockeddomainFetcher?() ?? []
        if isBlockEnabled == false {
            blockedDomainList = []
        }
        let blockedUrls = ["blocked": blockedDomainList]
        let jsonData = try! JSONSerialization.data(withJSONObject: blockedUrls, options: [])
        let jsonString = String(data: jsonData, encoding: .utf8)!

 //       os_log("[SC] 🔍] PlistListner newConnectionHandler")
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Access-Control-Allow-Origin: *\r
        \r
        \(jsonString)
        """
        connection.send(content: response.data(using: .utf8), contentContext: .finalMessage , completion: .contentProcessed { error in
            if let error = error {
//                os_log("[SC] 🔍] PlistListner Sent response error: %{public}@", "\(error)")
            } else {
//                os_log("[SC] 🔍] PlistListner Sent response successfully")
            }
        })
    }
    
//    private func updateSafariStatus() {
//        lastUpdateReceivedTime = Date()
//    }
//    
//    private func updateChromeStatus() {
//        Task {
//            AppStateManager.shared.handleApiRequest(path: "safari-extension-status)")
//            print("newConnectionHandler isEnabled: \(NetworkExtensionState.shared.isEnabled)")
//            if NetworkExtensionState.shared.isEnabled == true && NetworkExtensionState.shared.isChromeExtensionEnabled == false {
////                NetworkExtensionState.shared.isChromeExtensionEnabled  = IPCConnectionProxy().sendMessageToSetActiveBrowserExtension(ActiveBrowserExtensios.chrome.rawValue, state: true)
//                NetworkExtensionState.shared.isChromeExtensionEnabled  = true
//                NetworkExtensionState.shared.printAll()
//            }
//            if isChromeStatusSetInExtension == false {
//                isChromeStatusSetInExtension = true
//                self.onExtensionStateChange?()
//            }
//        }
//    }

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
