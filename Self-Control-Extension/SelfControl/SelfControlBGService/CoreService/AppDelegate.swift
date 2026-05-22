// HelperApp/AppDelegate.swift
import Cocoa
//import Shared
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate, NSXPCListenerDelegate {
    // Use a reverse-DNS mach service name. This must match your helper’s Info.plist.
    private let listener = NSXPCListener(machServiceName: "com.application.SelfControl.corebits.bgservice.xpc")
    let service = HelperService()
    static let shared = AppDelegate()
    override init() {
        print("AppDelegate: init")
        os_log("[SC] 🔍] BG AppDelegate: init")

        super.init()
        listener.delegate = self
        listener.resume()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
//        listener.delegate = self
//        listener.resume()
        // Agent app has no UI; it just keeps running.
    }

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {

        print("shouldAcceptNewConnection")
        os_log("[SC] 🔍] BG shouldAcceptNewConnection")

        let exportedInterface =
            NSXPCInterface(with: HelperServiceProtocol.self)

        newConnection.exportedInterface = exportedInterface
        newConnection.exportedObject = service
        newConnection.remoteObjectInterface = NSXPCInterface(with: HelperClientProtocol.self)
        newConnection.invalidationHandler = {
            os_log("[SC] 🔍] BG newConnection.invalidationHandler")
        }

        newConnection.interruptionHandler = {
            os_log("[SC] 🔍] BG newConnection.interruptionHandler")
        }
        service.clientConnection = newConnection
        newConnection.resume()
        
        return true
    }
}
