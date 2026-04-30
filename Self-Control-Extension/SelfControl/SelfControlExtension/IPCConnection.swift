/*
 See the LICENSE.txt file for this sample’s licensing information.
 
 Abstract:
 This file contains the implementation of the app <-> provider IPC connection
 */

import Foundation
import os.log
import Network

enum ActiveBrowserExtensios: String {
    case safari
    case chrome
}

/// App --> Provider IPC, to be implememted in Extension
@objc protocol AppToExtensionExtension {
    func register(_ completionHandler: @escaping (Bool) -> Void)
    func setBlockedURLs(_ urls: [String])
    func setBlockedIPAddresses(_ ips: [String])
    // Use Objective-C bridgeable type for XPC surface
    func setActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool)
    func setEnableService(_ enable: Bool)
}

/// Provider --> App IPC to Be implememted in the app
@objc protocol ExtensionToApp {
  func promptUser(aboutFlow flowInfo: [String: String], responseHandler: @escaping (Bool) -> Void)
    func didSetUrls()
}

enum FlowInfoKey: String {
  case localPort
  case remoteAddress
}

/// The IPCConnection class is used by both the app and the system extension to communicate with each other
class IPCConnection: NSObject {
  
  // MARK: Properties
  
  var listener: NSXPCListener?
  var currentConnection: NSXPCConnection?
  weak var delegate: ExtensionToApp?
  static let shared = IPCConnection()
//    var blockedUrls: [String] = ProxyPreferences.getBlockedDomains()
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
  
  func startListener() {
    
    let machServiceName = extensionMachServiceName(from: Bundle.main)
    os_log("[SC] 🔍] Starting XPC listener for mach service %@", machServiceName)
    
    let newListener = NSXPCListener(machServiceName: machServiceName)
    newListener.delegate = self
    newListener.resume()
    listener = newListener
  }
  
  /// This method is called by the app to register with the provider running in the system extension.
  func register(withExtension bundle: Bundle, delegate: ExtensionToApp, completionHandler: @escaping (Bool) -> Void) {
    
    self.delegate = delegate
    
    guard currentConnection == nil else {
      os_log("[SC] 🔍] Already registered with the provider")
      completionHandler(true)
      return
    }
    
    let machServiceName = extensionMachServiceName(from: bundle)
    let newConnection = NSXPCConnection(machServiceName: machServiceName, options: [])
    
    // The exported object is the delegate.
    newConnection.exportedInterface = NSXPCInterface(with: ExtensionToApp.self)
    newConnection.exportedObject = delegate
    
    // The remote object is the provider's IPCConnection instance.
    newConnection.remoteObjectInterface = NSXPCInterface(with: AppToExtensionExtension.self)
    
    currentConnection = newConnection
    newConnection.resume()
    
    guard let providerProxy = newConnection.remoteObjectProxyWithErrorHandler({ registerError in
      os_log("[SC] 🔍] Failed to register with the provider: %@", registerError.localizedDescription)
      self.currentConnection?.invalidate()
      self.currentConnection = nil
      completionHandler(false)
    }) as? AppToExtensionExtension else {
        os_log("Failed to create a remote object proxy for the provider")
        return
    }
    providerProxy.register(completionHandler)
      providerProxy.setBlockedURLs(blockedUrls)
  }
  
  /**
   This method is called by the provider to cause the app (if it is registered) to display a prompt to the user asking
   for a decision about a connection.
   */
  func promptUser(aboutFlow flowInfo: [String: String], responseHandler:@escaping (Bool) -> Void) -> Bool {
    
      guard let connection = currentConnection else {
          os_log("[SC] 🔍] Cannot prompt user because the app isn't registered")
          return false
      }
    
    guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
      os_log("[SC] 🔍] Failed to prompt the user: %{public}@", promptError.localizedDescription)
      self.currentConnection = nil
      responseHandler(true)
    }) as? ExtensionToApp else {
        os_log("Failed to create a remote object proxy for the app")
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
    
    func enableURLBlocking(_ urls: [String]) {
        os_log("[SC] 🔍] Enabling URL blocking")
        guard let providerProxy = currentConnection?.remoteObjectProxyWithErrorHandler({ registerError in
          os_log("[SC] 🔍] Failed to register with the provider: %{public}@", registerError.localizedDescription)
        }) as? AppToExtensionExtension else {
            os_log("[SC] 🔍] Failed to create a remote object proxy for the provider")
            return
        }
        providerProxy.setBlockedURLs(urls)
    }
    
    func enableIPAddressesBlocking(_ urls: [String]) {
        os_log("[SC] 🔍] Enabling URL blocking")
        guard let providerProxy = currentConnection?.remoteObjectProxyWithErrorHandler({ registerError in
          os_log("[SC] 🔍] Failed to register with the provider: %{public}@", registerError.localizedDescription)
        }) as? AppToExtensionExtension else {
            os_log("[SC] 🔍] Failed to create a remote object proxy for the provider")
            return
        }
        providerProxy.setBlockedIPAddresses(urls)
    }
    
    func sendMessageToSetActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool) -> Bool {
        os_log("[SC] 🔍] sendMessageToSetActiveBrowserExtension:\(extensionTypeRawValue), state:\(state)")
        guard let providerProxy = currentConnection?.remoteObjectProxyWithErrorHandler({ registerError in
          os_log("[SC] 🔍] sendMessageToSetActiveBrowserExtension: %{public}@", registerError.localizedDescription)
        }) as? AppToExtensionExtension else {
            os_log("[SC] 🔍] Failed to create a remote object proxy for the provider")
            return false
        }
        providerProxy.setActiveBrowserExtension(extensionTypeRawValue, state: state)
        return true
    }
    
    func sendMessageToEnableNetworkExtension(_enable: Bool) -> Bool {
        os_log("[SC] 🔍] sendMessageToEnableNetworkExtension state:\(_enable)")
        guard let providerProxy = currentConnection?.remoteObjectProxyWithErrorHandler({ registerError in
          os_log("[SC] 🔍] sendMessageToEnableNetworkExtension: %{public}@", registerError.localizedDescription)
        }) as? AppToExtensionExtension else {
            os_log("[SC] 🔍] Failed to create a remote object proxy for the provider")
            return false
        }
        providerProxy.setEnableService(_enable)
        return true
    }
}


extension IPCConnection: AppToExtensionExtension {
    func setEnableService(_ enable: Bool) {
        self.isServiceActive = enable
    }
    
    func setBlockedIPAddresses(_ ips: [String]) {
        blockedIPAddresses = Set(ips)
        os_log("[SC] 🔍] setBlockedIPAddresses: %{public}@", blockedIPAddresses)
    }
    
    func setBlockedURLs(_ urls: [String]) {
        os_log("[SC] 🔍] Extension Received Blocking: %{public}@",urls)
        blockedUrls = urls
//        delegate?.didSetUrls()
        blockedList = BlockOrAllowList(items: blockedUrls)

          guard let connection = currentConnection else {
              print("[SC] 🔍] Cannot update blocked urls, app isn't registered")
              os_log("[SC] 🔍] Cannot update blocked urls, app isn't registered")

              return
          }
        
        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
          os_log("[SC] 🔍] Failed to prompt the user: %{public}@", promptError.localizedDescription)
            os_log("Failed to create a remote object proxy for the app")
//          self.currentConnection = nil
//          responseHandler(true)
        }) as? ExtensionToApp else {
            os_log("[SC] 🔍] Cannot update blocked urls, app isn't registered")
            os_log("Failed to create a remote object proxy for the app")
            return
        }
        appProxy.didSetUrls()
    }
    
    func setActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool) {
        // Map the raw value to the Swift enum if possible
        os_log("[SC] 🔍] Received extension state to %{public}@", extensionTypeRawValue)
        if let mapped = ActiveBrowserExtensios(rawValue: extensionTypeRawValue) {
            switch mapped {
            case .safari:
                self.isSafariExtensionEnable = state
            case .chrome:
                self.isGoogleChromeEnabled = state
            }
            os_log("[SC] 🔍] Set browser extension state to %{public}@", extensionTypeRawValue)
            os_log("[SC] 🔍] Set browser state to %{public}d", state)
        } else {
            os_log("[SC] 🔍] Unknown browser extension type %{public}@", extensionTypeRawValue)
        }
    }
  
  // MARK: ProviderCommunication
  
  func register(_ completionHandler: @escaping (Bool) -> Void) {
    
    os_log("[SC] 🔍] App registered")
    completionHandler(true)
  }
}
