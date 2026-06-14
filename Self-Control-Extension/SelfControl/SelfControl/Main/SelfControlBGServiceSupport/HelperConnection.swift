//
//  HelperConnection.swift
//  SelfControl
//
//  Created by Satendra Singh on 08/05/26.
//

// MainApp/HelperConnection.swift
import Cocoa
import ServiceManagement

enum HelperServiceConstants: String {
    case bundleID = "com.application.SelfControl.corebits.bgservice" // HelperApp’s bundle identifier
    case processName = "SelfControlBGService"
    case machServiceName = "com.application.SelfControl.corebits.bgservice.xpc"
}

final class HelperConnection: NSObject, HelperClientProtocol, NSSecureCoding {
    static let shared = HelperConnection()
    static var supportsSecureCoding: Bool = true
    var onExtensionStateChange: ((WEBExtension, Bool) -> Void)?
    var blockedStateHandler: ((Double) -> Void)?
    private var connection: NSXPCConnection?
    private var exportedConnection: NSXPCListenerEndpoint?
    private let checkProcess = CheckProcess(bundleID: HelperServiceConstants.bundleID.rawValue, processName: HelperServiceConstants.processName.rawValue)
    
    private let stateQueue = DispatchQueue(label: "com.application.SelfControl.corebits.bgservice.connection", attributes: .concurrent)
    
    override init() { }
    
    required init?(coder: NSCoder) {
        return nil
    }

    func encode(with coder: NSCoder) {
        
    }
    // MARK: - Public API

    func installLoginItemIfNeeded() async throws {
        if !checkProcess.isRunning() {
            do {
               try LaunchAgentManager.install()
            } catch {
                throw error
            }
        } else {
            print("BG App is already running")
        }
    }

    func uninstallLoginItem() throws {
        let loginItem = SMAppService.loginItem(identifier: HelperServiceConstants.bundleID.rawValue)
        try loginItem.unregister()
    }

    func connect() {
        stateQueue.sync(flags: .barrier) {
            guard self.connection == nil else { return }
            
            let conn = NSXPCConnection(machServiceName: HelperServiceConstants.machServiceName.rawValue, options: [])
            // Remote interface: the helper’s service protocol
            conn.remoteObjectInterface = NSXPCInterface(with: HelperServiceProtocol.self)
            // Exported interface: our client protocol to receive callbacks
            let clientInterface = NSXPCInterface(with: HelperClientProtocol.self)
            conn.exportedInterface = clientInterface
            conn.exportedObject = self
            //            exportedConnection = listener.endpoint
            
            conn.interruptionHandler = { [weak self] in
                print("Conn interruptionHandler")
                // Temporary loss of connection; try to reconnect
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.reconnect()
                }
            }
            
            conn.invalidationHandler = { [weak self] in
                print("Conn invalidationHandler")
                
                // Connection invalidated; tear down and reconnect
                self?.stateQueue.sync(flags: .barrier) {
                    self?.connection = nil
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.connect()
                }
            }
            
            conn.resume()
            self.connection = conn
            // Register for callbacks
            bgProxyServiceConnection()?.registerClient()
        }
    }

    func disconnect() {
        stateQueue.sync(flags: .barrier) {
            self.connection?.invalidate()
            self.connection = nil
        }
    }

    func saveSchedules(schedules: Data, reply: @escaping (Bool) -> Void) {
        stateQueue.async(flags: .barrier) {
            self.bgProxyServiceConnection()?.saveSchedules(schedules: schedules, reply: reply)
        }
    }
    
    func loadSchedules(reply: @escaping (_ schedules: Data) -> Void) {
        //TODO:
    }

    func currentStatus() async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            self.withProxy(error: { cont.resume(throwing: $0) }) { proxy in
                proxy.currentStatus { status in cont.resume(returning: status) }
            }
        }
    }

    // MARK: - HelperClientProtocol (callbacks from helper)

    func didUpdateStatus(_ status: String) {
        print("didUpdateStatus: \(status)")
        // Update UI or post notifications as needed
        NotificationCenter.default.post(name: .helperStatusChanged, object: status)
    }

    func didEmitEvent(_ message: String) {
        print("didEmitEvent: \(message)")
        NotificationCenter.default.post(name: .helperEvent, object: message)
    }
    
    // MARK: - Internal

    private func reconnect() {
        disconnect()
        connect()
    }

    private func withProxy(error: ((Error) -> Void)? = nil, _ body: (HelperServiceProtocol) -> Void) {
        var proxy: AnyObject?
        stateQueue.sync {
            proxy = self.connection?.remoteObjectProxyWithErrorHandler { err in
                error?(err)
            } as AnyObject?
        }
        if let proxy = proxy as? HelperServiceProtocol {
            body(proxy)
        } else {
            error?(NSError(domain: "HelperConnection", code: 1, userInfo: [NSLocalizedDescriptionKey: "No XPC connection"]))
        }
    }
    
    func bgProxyServiceConnection() -> HelperServiceProtocol? {
        var proxy: AnyObject?
        proxy = self.connection?.remoteObjectProxyWithErrorHandler { err in
            print("Conn Error:\(err)")            } as AnyObject?
        return proxy as? HelperServiceProtocol
    }
}

extension Notification.Name {
    static let helperStatusChanged = Notification.Name("HelperStatusChanged")
    static let helperEvent = Notification.Name("HelperEvent")
}
