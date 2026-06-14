//
//  SelfControlServiceSupport.swift
//  SelfControl
//
//  Created by Satendra Singh on 03/05/26.
//

import Cocoa

final class SelfControlServiceSupport: NSObject, NSXPCListenerDelegate {
    // Use a reverse-DNS mach service name. This must match your helper’s Info.plist.
    private let listener = NSXPCListener(machServiceName: AppToServiceMessagesConstants.bundleID)
//    private let service = HelperService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        listener.delegate = self
        listener.resume()
        // Agent app has no UI; it just keeps running.
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Configure interfaces for bidirectional communication.
        let exportedInterface = NSXPCInterface(with: AppToServiceMessages.self)
        let clientInterface = NSXPCInterface(with: AppToServiceMessages.self)
//        exportedInterface.setInterface(clientInterface, for: #selector(SelfControlServiceProtocol.registerClient(_:)), argumentIndex: 0, ofReply: false)

        newConnection.exportedInterface = exportedInterface
//        newConnection.exportedObject = service

        newConnection.invalidationHandler = { [weak self] in
            // Optionally clean up client references if you track them per-connection
            _ = self // keep capture
        }
        newConnection.interruptionHandler = { /* handle temporary interruptions */ }

        newConnection.resume()
        return true
    }
}
