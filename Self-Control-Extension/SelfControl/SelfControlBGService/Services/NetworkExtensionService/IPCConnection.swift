/*
 See the LICENSE.txt file for this sample’s licensing information.
 
 Abstract:
 This file contains the implementation of the app <-> provider IPC connection
 */

import Foundation
import os.log
import Network

/// The IPCConnection class is used by both the app and the system extension to communicate with each other
class IPCConnection: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool = true
    
    override init() {
    }
    
    required init?(coder: NSCoder) {
        return nil
    }

    func encode(with coder: NSCoder) {
        
    }
  // MARK: Properties
  
  var listener: NSXPCListener?
  var currentConnection: NSXPCConnection?
  weak var delegate: ExtensionToApp?
  static let shared = IPCConnection()
    // Published extension state for UI/observers

  // MARK: Methods
  
  /// This method is called by the app to register with the provider running in the system extension.
    func register(completionHandler: @escaping (Bool) -> Void) {
        
//        self.delegate = delegate
//        os_log("[SC] 🔍] register(withExtension")
        BGFileLogger.error("\(#function) ")

        guard currentConnection == nil else {
//            os_log("[SC] 🔍] Already registered with the provider")
            BGFileLogger.error("\(#function) Already registered with the provider")
            completionHandler(true)
            return
        }
        // Fix: Use Task to ensure actor-isolated method is called on its actor
        Task { @MainActor in
            await AppStateManager.shared.reset()
        }

        let newConnection = NSXPCConnection(machServiceName: "X6FQ433AWK.com.application.SelfControl.corebits.network", options: [])
        
        // The exported object is the delegate.
        newConnection.exportedInterface = NSXPCInterface(with: ExtensionToApp.self)
        newConnection.exportedObject = self
        newConnection.invalidationHandler = { [weak self] in
            BGFileLogger.error("\(#function) invalidationHandler")
            self?.currentConnection = nil
        }
        newConnection.interruptionHandler = { [weak self] in
            BGFileLogger.error("\(#function) interruptionHandler")
            self?.currentConnection = nil
        }
        // The remote object is the provider's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: AppToExtensionExtension.self)
        
        currentConnection = newConnection
        newConnection.resume()
        
        guard let providerProxy = newConnection.remoteObjectProxyWithErrorHandler({ registerError in
//            os_log("[SC] 🔍] Failed to register with the provider: %{public}@", registerError.localizedDescription)
            BGFileLogger.error("\(#function) Failed to register with the provider: \(registerError.localizedDescription) ")
            self.currentConnection?.invalidate()
            self.currentConnection = nil
            completionHandler(false)
        }) as? AppToExtensionExtension else {
            BGFileLogger.error("\(#function) Failed to create a remote object proxy ")
//            os_log("[SC] 🔍] Failed to create a remote object proxy for the provider")
            return
        }
        providerProxy.register(completionHandler)
    }
  
  /**
   This method is called by the provider to cause the app (if it is registered) to display a prompt to the user asking
   for a decision about a connection.
   */
  func promptUser(aboutFlow flowInfo: [String: String], responseHandler:@escaping (Bool) -> Void) -> Bool {
    
      guard let connection = currentConnection else {
          BGFileLogger.error("\(#function) Cannot prompt user because the app isn't registered")
//          os_log("[SC] 🔍] Cannot prompt user because the app isn't registered")
          return false
      }
    
    guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
//      os_log("[SC] 🔍] Failed to prompt the user: %{public}@", promptError.localizedDescription)
        BGFileLogger.error("\(#function) Failed to prompt the user: \(promptError.localizedDescription) ")
      self.currentConnection = nil
      responseHandler(true)
    }) as? ExtensionToApp else {
        BGFileLogger.error("\(#function) Failed to create a remote object proxy ")
//        os_log("Failed to create a remote object proxy for the app")
        return false
    }
    
    appProxy.promptUser(aboutFlow: flowInfo, responseHandler: responseHandler)
    
    return true
  }
}

extension IPCConnection: NSXPCListenerDelegate {
  
  // MARK: NSXPCListenerDelegate
  
  func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
    
    // The exported object is this IPCConnection instance.
    newConnection.exportedInterface = NSXPCInterface(with: AppToExtensionExtension.self)
    newConnection.exportedObject = self
    
    // The remote object is the delegate of the app's IPCConnection instance.
    newConnection.remoteObjectInterface = NSXPCInterface(with: ExtensionToApp.self)
    
    newConnection.invalidationHandler = {
      self.currentConnection = nil
    }
    
    newConnection.interruptionHandler = {
      self.currentConnection = nil
    }
    
    currentConnection = newConnection
    newConnection.resume()
    
    return true
  }
    
    func sendMessageToSetBlockingURLs(_ urls: [String]) { //        os_log("[SC] 🔍] Enabling URL blocking")
        BGFileLogger.info("\(#function) Enabling URL blocking")
        guard let providerProxy = currentConnection?.remoteObjectProxyWithErrorHandler({ registerError in
          os_log("[SC] 🔍] Failed to register with the provider: %{public}@", registerError.localizedDescription)
            BGFileLogger.error("\(#function) Failed to register with the provider: \(registerError.localizedDescription)")
        }) as? AppToExtensionExtension else {
//            os_log("[SC] 🔍] Failed to create a remote object proxy for the provider")
            BGFileLogger.error("\(#function) Failed to create a remote object proxy ")
            return
        }
        providerProxy.setBlockedURLs(urls)
    }
    
    func sendMessageToSetActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool) {
//        os_log("[SC] 🔍] sendMessageToSetActiveBrowserExtension:\(extensionTypeRawValue), state:\(state)")
        BGFileLogger.error("\(#function) Failed to create a remote object proxy \(extensionTypeRawValue), state:\(state)")
        guard let providerProxy = currentConnection?.remoteObjectProxyWithErrorHandler({ registerError in
            BGFileLogger.error("\(#function) \(registerError.localizedDescription)")
//          os_log("[SC] 🔍] sendMessageToSetActiveBrowserExtension: %{public}@", registerError.localizedDescription)
        }) as? AppToExtensionExtension else {
            BGFileLogger.error("\(#function) Failed to create a remote object proxy ")
//            os_log("[SC] 🔍] Failed to create a remote object proxy for the provider")
            return
        }
        providerProxy.setActiveBrowserExtension(extensionTypeRawValue, state: state)
    }
    
    func sendMessageToEnableNetworkExtension(_ enable: Bool) -> Bool {
//        os_log("[SC] 🔍] sendMessageToEnableNetworkExtension state %{public}d", enable)
        BGFileLogger.error("\(#function) \(enable)")
        guard let providerProxy = currentConnection?.remoteObjectProxyWithErrorHandler({ registerError in
//          os_log("[SC] 🔍] sendMessageToEnableNetworkExtension: %{public}@", registerError.localizedDescription)
            BGFileLogger.error("\(#function) \(enable)")
        }) as? AppToExtensionExtension else {
            BGFileLogger.error("\(#function) Failed to create a remote object proxy")
//            os_log("[SC] 🔍] Failed to create a remote object proxy for the provider")
            return false
        }
        providerProxy.setEnableService(enable)
        return true
    }
}

extension IPCConnection: ExtensionToApp {
    
    func promptUser(aboutFlow flowInfo: [String: String], responseHandler: @escaping (Bool) -> Void) {
        os_log("[SC] 🔍] promptUser")

    }
    func didSetUrls() {
        os_log("[SC] 🔍] didSetUrls")
    }
}
