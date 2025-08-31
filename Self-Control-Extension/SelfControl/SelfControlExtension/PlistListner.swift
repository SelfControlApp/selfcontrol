//
//  PlistListner.swift
//  SelfControlExtension
//
//  Created by Satendra Singh on 16/08/25.
//

import Foundation
import Network
import os.log

final class PlistListner: NSObject, ObservableObject {
    
    var listener: NWListener? = try! NWListener(using: .tcp, on: 8080)
    var blockeddomainFetcher: (() -> [String])?
    
    func startListening() {
        os_log("[SC] 🔍] NW startListening")
//        let objects: [[String: Any]] = [
//            ["id": 1, "name": "Alice", "status": "running"],
//            ["id": 2, "name": "Bob", "status": "stopped"],
//            ["id": 3, "name": "Charlie", "status": "idle"]
//        ]
        listener = try! NWListener(using: .tcp, on: 8080)
        listener?.newConnectionHandler = { conn in
            let blockedDomainList: [String] = self.blockeddomainFetcher?() ?? []
            let blockedUrls = ["blocked": blockedDomainList]
            let jsonData = try! JSONSerialization.data(withJSONObject: blockedUrls, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8)!

            os_log("[SC] 🔍] NW newConnectionHandler")
            conn.start(queue: DispatchQueue.global(qos: .userInitiated))
//            conn.receiveMessage { data, _, _, _ in
                os_log("[SC] 🔍] NW conn.receiveMessage")
            let response = """
            HTTP/1.1 200 OK\r
            Content-Type: application/json\r
            Access-Control-Allow-Origin: *\r
            \r
            \(jsonString)
            """
            conn.send(content: response.data(using: .utf8), contentContext: .finalMessage , completion: .contentProcessed { error in
                    os_log("[SC] 🔍] NW Sent response:\(error)")
//                    conn.cancel()
                
                })
//            }
            
            conn.stateUpdateHandler = { state in
                if state == .ready {
                    os_log("[SC] 🔍] NW stateUpdateHandler ready")
                }
            }
        }
        listener?.start(queue: DispatchQueue.global(qos: .userInitiated))
//        RunLoop.main.run()
    }
}
