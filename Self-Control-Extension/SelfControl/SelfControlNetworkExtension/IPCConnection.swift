/*
 See the LICENSE.txt file for this sample’s licensing information.
 
 Abstract:
 This file contains the implementation of the app <-> provider IPC connection
 */

import Foundation
import os.log
import Network

/// The IPCConnection class is used by both the app and the system extension to communicate with each other
class IPCConnection: NSObject {
  
  // MARK: Properties
  
  var listener: NSXPCListener?
  var currentConnection: NSXPCConnection?
  weak var delegate: ExtensionToApp?
  static let shared = IPCConnection()
    var blockedUrls: [String] = [String]()
    var blockedList = BlockOrAllowList(items: [])
    var blockedIPAddresses: Set<String> = []
    private(set) var isSafariExtensionEnable: Bool = false
    private(set) var isGoogleChromeEnabled: Bool = false
    // Published extension state for UI/observers
    private(set) var isServiceActive: Bool = false

  // MARK: Methods
  
  /**
   The NetworkExtension framework registers a Mach service with the name in the system extension's NEMachServiceName Info.plist key.
   The Mach service name must be prefixed with one of the app groups in the system extension's com.apple.security.application-groups entitlement.
   Any process in the same app group can use the Mach service to communicate with the system extension.
   */
  private func extensionMachServiceName(from bundle: Bundle) -> String {
    
    guard let networkExtensionKeys = bundle.object(forInfoDictionaryKey: "NetworkExtension") as? [String: Any],
          let machServiceName = networkExtensionKeys["NEMachServiceName"] as? String else {
//      fatalError("Mach service name is missing from the Info.plist")
        os_log("[SC] 🔍] Mach service name is missing from the Info.plist")
        return ""
    }
    
    return machServiceName
  }
  
    //This method is called to start listing for the connections to communicate with app
  func startListener() {
    
    let machServiceName = extensionMachServiceName(from: Bundle.main)
      //X6FQ433AWK.com.application.SelfControl.corebits.network
    os_log("[SC] 🔍] Starting XPC listener for mach service %{public}@", machServiceName)
    
    let newListener = NSXPCListener(machServiceName: machServiceName)
    newListener.delegate = self
    newListener.resume()
    listener = newListener
  }
  
  /// This method is called by the app to register with the provider running in the system extension.
  func register(completionHandler: @escaping (Bool) -> Void) { }

  }

extension IPCConnection: NSXPCListenerDelegate {
  
  // MARK: NSXPCListenerDelegate
  
  func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
      os_log("[SC] 🔍] NE shouldAcceptNewConnection:" )
    // The exported object is this IPCConnection instance.
    newConnection.exportedInterface = NSXPCInterface(with: AppToExtensionExtension.self)
    newConnection.exportedObject = self
    
    // The remote object is the delegate of the app's IPCConnection instance.
    newConnection.remoteObjectInterface = NSXPCInterface(with: ExtensionToApp.self)
    
    newConnection.invalidationHandler = {
        os_log("[SC] 🔍] NE invalidationHandler:" )
      self.currentConnection = nil
    }
    
    newConnection.interruptionHandler = {
        os_log("[SC] 🔍] NE interruptionHandler:" )
      self.currentConnection = nil
    }
    currentConnection?.suspend()
    currentConnection?.invalidate()
    currentConnection = newConnection
    newConnection.resume()
    return true
  }
}


extension IPCConnection: AppToExtensionExtension {
    
    func setEnableService(_ enable: Bool) {
        os_log("[SC] 🔍] NE setEnableService: %{public}d", enable)
        self.isServiceActive = enable
    }
    
    func setBlockedIPAddresses(_ ips: [String]) {
        blockedIPAddresses = Set(ips)
        os_log("[SC] 🔍] NE setBlockedIPAddresses: %{public}@", blockedIPAddresses)
    }
    
    func setBlockedURLs(_ urls: [String]) {
        os_log("[SC] 🔍] NE Extension Received Blocking: %{public}@",urls)
        blockedUrls = urls
//        delegate?.didSetUrls()
        blockedList = BlockOrAllowList(items: blockedUrls)

          guard let connection = currentConnection else {
              os_log("[SC] 🔍] NE Cannot update blocked urls, app isn't registered")
              return
          }
        
        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            os_log("[SC] 🔍] NE Failed to create a remote object proxy for the app: %{public}@", promptError.localizedDescription)
//          self.currentConnection = nil
//          responseHandler(true)
        }) as? ExtensionToApp else {
            os_log("[SC] 🔍] NE  Failed to create a remote object proxy for the app")
            return
        }
        appProxy.didSetUrls()
    }
    
    func setActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool) {
        // Map the raw value to the Swift enum if possible
        os_log("[SC] 🔍] NE Received extension state to %{public}@", extensionTypeRawValue)
        if let mapped = ActiveBrowserExtensios(rawValue: extensionTypeRawValue) {
            switch mapped {
            case .safari:
                self.isSafariExtensionEnable = state
            case .chrome:
                self.isGoogleChromeEnabled = state
            }
            os_log("[SC] 🔍] NE Set browser extension state to %{public}@, state: %{public}d", extensionTypeRawValue, state)
        } else {
            os_log("[SC] 🔍] NE Unknown browser extension type %{public}@", extensionTypeRawValue)
        }
    }
  
  // MARK: ProviderCommunication
  
  func register(_ completionHandler: @escaping (Bool) -> Void) {
    
    os_log("[SC] 🔍] App registered")
    completionHandler(true)
  }
}
