//
//  FilterViewModel.swift
//  SelfControl
//
//  Created by Egzon Arifi on 02/04/2025.
//

import SwiftUI
import NetworkExtension
import SystemExtensions
import os.log
import Cocoa

final class FilterViewModel: NSObject, ObservableObject, OSSystemExtensionRequestDelegate, AppCommunication {
    @Published var status: Status = .stopped
    @State private var domains = ProxyPreferences.getBlockedDomains()
    private let listner = PlistListner()
    @Published var delay: Double = 0.0
    var blockedIPAddressed: [String] = []
    
  // Date formatter used to log entries
  lazy var dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
  }()
  
  // Observer for filter configuration changes
  var observer: Any?
  var extensionIdentifier: String?
    
  // Load the system extension bundle from the app’s Contents/Library/SystemExtensions folder.
  lazy var extensionBundle: Bundle = {
    let extensionsDirectoryURL = URL(fileURLWithPath: "Contents/Library/SystemExtensions", relativeTo: Bundle.main.bundleURL)
    let extensionURLs: [URL]
    do {
      extensionURLs = try FileManager.default.contentsOfDirectory(at: extensionsDirectoryURL,
                                                                  includingPropertiesForKeys: nil,
                                                                  options: .skipsHiddenFiles)
    } catch let error {
      fatalError("Failed to get the contents of \(extensionsDirectoryURL.absoluteString): \(error.localizedDescription)")
    }
    guard let extensionURL = extensionURLs.first else {
      fatalError("Failed to find any system extensions")
    }
    guard let extensionBundle = Bundle(url: extensionURL) else {
      fatalError("Failed to create a bundle with URL \(extensionURL.absoluteString)")
    }
    return extensionBundle
  }()
  
    override init() {
        super.init()
        onInit()
        self.extensionIdentifier = extensionBundle.bundleIdentifier
        self.listner.blockeddomainFetcher = {
            return ProxyPreferences.getBlockedDomains()
        }
        self.listner.startListening()
    }
  
  deinit {
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer, name: .NEFilterConfigurationDidChange, object: NEFilterManager.shared())
    }
  }
  
  func onInit() {
    // On initialization load the filter configuration and register for changes.
    loadFilterConfiguration { success in
      guard success else {
        self.status = .stopped
        return
      }
      self.updateStatus()
      self.observer = NotificationCenter.default.addObserver(forName: .NEFilterConfigurationDidChange,
                                                             object: NEFilterManager.shared(),
                                                             queue: .main) { [weak self] _ in
        self?.updateStatus()
      }
    }
  }
  
  // MARK: - UI and Filter Management
  
    func setBlockedUrls(urls: [String]) {
        IPCConnection.shared.enableURLBlocking(urls)
        Task {
            let ips: Set<String> = await DNSResolverActor().resolve(hostURL: urls)
            print("Resolved app:\(ips)")
            setIPAddressesToBlock(addresses: Array(ips))
        }
    }

    func setIPAddressesToBlock(addresses: [String]) {
        IPCConnection.shared.enableIPAddressesBlocking(addresses)
    }
    
    private func refreshBlockedIPs() {
        self.listner.blockeddomainFetcher = {
            return ProxyPreferences.getBlockedDomains()
        }
    }
    
  func updateStatus() {
    if NEFilterManager.shared().isEnabled {
      registerWithProvider()
    } else {
      status = .stopped
    }
  }
  
  func logFlow(_ flowInfo: [String: String], at date: Date, userAllowed: Bool) {
    guard let localPort = flowInfo[FlowInfoKey.localPort.rawValue],
          let remoteAddress = flowInfo[FlowInfoKey.remoteAddress.rawValue] else {
      return
    }
    let dateString = dateFormatter.string(from: date)
    let message = "\(dateString) \(userAllowed ? "ALLOW" : "DENY") \(localPort) <-- \(remoteAddress)\n"
    os_log("[SC] 🔍] %@", message)
  }
  
  func loadFilterConfiguration(completionHandler: @escaping (Bool) -> Void) {
    NEFilterManager.shared().loadFromPreferences { loadError in
      DispatchQueue.main.async {
        var success = true
        if let error = loadError {
          os_log("[SC] 🔍] Failed to load the filter configuration: %@", error.localizedDescription)
          success = false
        }
        completionHandler(success)
      }
    }
  }
  
  func enableFilterConfiguration() {
    let filterManager = NEFilterManager.shared()
    guard !filterManager.isEnabled else {
      registerWithProvider()
      return
    }
    loadFilterConfiguration { success in
      guard success else {
        self.status = .stopped
        return
      }
      if filterManager.providerConfiguration == nil {
        let providerConfiguration = NEFilterProviderConfiguration()
        providerConfiguration.filterSockets = true
        providerConfiguration.filterPackets = false
        filterManager.providerConfiguration = providerConfiguration
        if let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String {
          filterManager.localizedDescription = appName
        }
      }
      filterManager.isEnabled = true
      filterManager.saveToPreferences { saveError in
        DispatchQueue.main.async {
          if let error = saveError {
            os_log("[SC] 🔍] Failed to save the filter configuration: %@", error.localizedDescription)
            self.status = .stopped
            return
          } else {
//              self.enableDNSProxy()
          }
          self.registerWithProvider()
        }
      }
    }
  }
    
    func enableDNSProxy() {
        let manager = NEDNSProxyManager.shared()

        manager.loadFromPreferences { error in
            guard error == nil else { return }

            let proto = NEDNSProxyProviderProtocol()
            proto.providerBundleIdentifier = "com.application.SelfControl.corebits.network"
            proto.serverAddress = "127.0.0.1" // placeholder
//            proto.filterSockets = true
            manager.localizedDescription = "DNS Logger"
            manager.providerProtocol = proto
            manager.isEnabled = true

            manager.saveToPreferences { saveError in
                if let saveError = saveError {
                    print("Failed to save: \(saveError)")
                } else {
                    print("DNS proxy saved.")
                }
            }
        }
    }
    
  func registerWithProvider() {
    // Assuming an IPCConnection singleton similar to the AppKit sample
    IPCConnection.shared.register(withExtension: extensionBundle, delegate: self) { success in
      DispatchQueue.main.async {
        self.status = success ? .running : .stopped
          self.setBlockedUrls(urls: ProxyPreferences.getBlockedDomains())
      }
//        setBlockedURLs([])
    }
  }
  
    func activateExtension() {
        // Start by activating the system extension.
        guard let extensionIdentifier = extensionIdentifier else {
            self.status = .stopped
            return
          }
//        let request = OSSystemExtensionRequest.propertiesRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
//        request.delegate = self
//        OSSystemExtensionManager.shared.submitRequest(request)
        let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        activationRequest.delegate = self
        OSSystemExtensionManager.shared.submitRequest(activationRequest)
    }
  // MARK: - UI Event Handlers.
  
  func startFilter() {
    status = .indeterminate
    guard !NEFilterManager.shared().isEnabled else {
      registerWithProvider()
      return
    }
//    guard let extensionIdentifier = extensionBundle.bundleIdentifier else {
//      status = .stopped
//      return
//    }
      activateExtension()
  }
    
    func checkUrlRequest(url: String) {
        URLSession.shared.dataTask(with: URL(string: url)!) { (data, response, error) in
            print("Response: \(String(describing: response))")
            print("Data: \(String(describing: data))")
            print("Error: \(String(describing: error))")
        }.resume()
    }
    
  func stopFilter() {
    let filterManager = NEFilterManager.shared()
    status = .indeterminate
    guard filterManager.isEnabled else {
      status = .stopped
      return
    }
    loadFilterConfiguration { success in
      guard success else {
        self.status = .running
        return
      }
      // Disable the content filter configuration.
      filterManager.isEnabled = false
      filterManager.saveToPreferences { saveError in
        DispatchQueue.main.async {
          if let error = saveError {
            os_log("[SC] 🔍] Failed to disable the filter configuration: %@", error.localizedDescription)
            self.status = .running
            return
          }
          self.status = .stopped
        }
      }
    }
  }
  // MARK: - OSSystemExtensionRequestDelegate Methods
  
  func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
    guard result == .completed else {
      os_log("[SC] 🔍] Unexpected result %d for system extension request", result.rawValue)
      status = .stopped
      return
    }
    enableFilterConfiguration()
  }
  
  func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
    os_log("[SC] 🔍] System extension request failed: %@", error.localizedDescription)
    status = .stopped
  }
  
  func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
    os_log("[SC] 🔍] Extension %@ requires user approval", request.identifier)
  }
  
  func request(_ request: OSSystemExtensionRequest,
               actionForReplacingExtension existing: OSSystemExtensionProperties,
               withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
    os_log("[SC] 🔍] Replacing extension %@ version %@ with version %@", request.identifier, existing.bundleShortVersion, ext.bundleShortVersion)
    return .replace
  }
    
    func request(_ request: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]) {
        os_log("[SC] 🔍] foundProperties extension %@", properties)
    }

  // MARK: - App Communication (Prompting the User)
  
  @objc func promptUser(aboutFlow flowInfo: [String: String], responseHandler: @escaping (Bool) -> Void) {
    guard let localPort = flowInfo[FlowInfoKey.localPort.rawValue],
          let remoteAddress = flowInfo[FlowInfoKey.remoteAddress.rawValue] else {
      os_log("[SC] 🔍] Got a promptUser call without valid flow info: %@", flowInfo)
      responseHandler(true)
      return
    }
    let connectionDate = Date()
    DispatchQueue.main.async {
      // For SwiftUI on macOS, use NSAlert via the shared NSApplication window.
      if let window = NSApplication.shared.windows.first {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "New incoming connection"
        alert.informativeText = "A new connection on port \(localPort) has been received from \(remoteAddress)."
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Deny")
        alert.beginSheetModal(for: window) { response in
          let userAllowed = (response == .alertFirstButtonReturn)
          self.logFlow(flowInfo, at: connectionDate, userAllowed: userAllowed)
          responseHandler(userAllowed)
        }
      } else {
        // Fallback if no window is available.
        self.logFlow(flowInfo, at: connectionDate, userAllowed: true)
        responseHandler(true)
      }
    }
  }
    
    func didSetUrls() {
        print("didSetUrls+++++")
    }
}

