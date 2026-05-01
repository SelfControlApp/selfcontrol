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
import Combine
import SafariServices

enum SelfControlViewState: Equatable {
    
    static func == (lhs: SelfControlViewState, rhs: SelfControlViewState) -> Bool {
        switch (lhs, rhs) {
        case (.installNetworkExtension, .installNetworkExtension),
             (.installSafariExtension, .installSafariExtension),
             (.installChromeExtension, .installChromeExtension),
             (.error, .error),
             (.filter, .filter):
            return true
        default:
            return false
        }
    }
    
    
    case installNetworkExtension
    case installSafariExtension
    case installChromeExtension
    case error(Error)
    case filter
}

final class FilterViewModel: NSObject, ObservableObject, OSSystemExtensionRequestDelegate, ExtensionToApp {
    @Published var status: Status = .stopped {
        didSet {
            if self.status == .running {
               updateScheduledEvents()
            }
        }
    }
    @Published var viewState: SelfControlViewState = .installNetworkExtension
    
    @Published var isNetworkExtensionSkipped: Bool = false {
        didSet {
            self.viewState = .filter
        }
    }

    private var isSafariExtensionInstalled: Bool = AppPreferences.isSafariExtensionInstalled
    private var isChromeExtensionInstalled: Bool = AppPreferences.isChromeExtensionInstalled
    var eventRunner: EventSchedulerRunner? = nil
    var eventRunnerHandler: EventSchedulerRunner.EventHandler?
    @State private var domains = AppPreferences.getBlockedDomains()
    private let chromeService = ChromeExtensionRequestListner()
    @State var blockedURLs: [BlockedURL] = []
    var blockerStorage: BlockedURLStore?
    @Published var delay: Double = 5.0
    var blockedIPAddressed: [String] = []
    private var cancellables = Set<AnyCancellable>()
    @Published var isActiveBlocking: Bool = false
    lazy var selfControlDaemon = SSCDaemonHelper()
    
    // Timer to manage delayed actions based on `delay` (in minutes)
    private var blockTimer: Timer?
    var timerFireDate: Date?
    var dockTimer :Timer?
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
//        ProxyPreferences.reset() //TODO: remove
        onInit()
        SafariExtensionManager.shared.onExtensionStateChange = {
            print("SafariExtensionManager.shared.onChange++")
            self.isSafariExtensionInstalled = true
            AppPreferences.setSafariExtensionInstalled()
            Task { @MainActor in
                self.updateSafariExtensionViewStatus()
            }
        }
        self.chromeService.onExtensionStateChange = {
            print("Chrome.shared.onChange++")
            self.isChromeExtensionInstalled = true
            AppPreferences.setChromeExtensionInstalled()
            Task { @MainActor in
                self.updateChromeExtensionViewStatus()
            }
        }
        SafariExtensionManager.shared.resetExtensionState()
        self.extensionIdentifier = extensionBundle.bundleIdentifier
        self.chromeService.blockeddomainFetcher = {
            return AppPreferences.getBlockedDomains()
        }

        self.chromeService.startListening()
        
        // Print status whenever it changes
        $status
            .sink { [weak self] newValue in
                guard let self = self else { return }
                print("[FilterViewModel] status changed to: \(newValue) (\(newValue.text))")
                os_log("[SC] 🔍] status changed to: %{public}@ (%{public}@)", String(describing: newValue), newValue.text)
                // Keep extension state in sync when status changes
                self.refreshExtensionState()
            }
            .store(in: &cancellables)
        Task { @MainActor in
            self.blockerStorage = BlockedURLStore()
        }
        self.eventRunnerHandler = { event in
            
        }
    }
  
  deinit {
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer, name: .NEFilterConfigurationDidChange, object: NEFilterManager.shared())
    }
    blockTimer?.invalidate()
    blockTimer = nil
  }
  
  func onInit() {
    // On initialization load the filter configuration and register for changes.
      Self.loadFilterConfiguration { success in
      guard success else {
        self.status = .stopped
        self.viewState = .installNetworkExtension
        self.refreshExtensionState()
        return
      }
      self.updateStatus()
      self.observer = NotificationCenter.default.addObserver(forName: .NEFilterConfigurationDidChange,
                                                             object: NEFilterManager.shared(),
                                                             queue: .main) { [weak self] _ in
        self?.updateStatus()
        self?.refreshExtensionState()
      }
      // Initial state refresh
      self.refreshExtensionState()
    }
  }
  
  // MARK: - NetworkExtensionStateProviding

    func refreshExtensionState() {
      let isNEEnabled = NEFilterManager.shared().isEnabled
      Task { @MainActor in
          NetworkExtensionState.shared.isEnabled = isNEEnabled
          if isNEEnabled == true { //Reset
              NetworkExtensionState.shared.isSafariExtensionEnabled = false
              NetworkExtensionState.shared.isChromeExtensionEnabled = false
              updateNetworkExtensionViewStatus()
          }
      }       // We’ll query Safari extension state asynchronously for accuracy.
  }
  
    @MainActor func updateNetworkExtensionViewStatus() {
        if NetworkExtensionState.shared.isEnabled == true {
            withAnimation(.easeInOut(duration: 3)) {
                self.viewState = .installChromeExtension
                updateChromeExtensionViewStatus()
            }
        }
    }
    
    @MainActor func updateSafariExtensionViewStatus() {
        if .installNetworkExtension == viewState {
            print(".installNetworkExtension == viewState in updateSafariExtensionViewStatus")
            return
        }
        
        if isSafariExtensionInstalled == true {
                print(" isSafariExtensionInstalled == true true in Safari")
                self.viewState = .filter
        } else {
            withAnimation(.easeInOut(duration: 3)) {
                print("viewState = .installChromeExtension true in Safari")
                self.viewState = .installSafariExtension
            }
        }
    }

    @MainActor func updateChromeExtensionViewStatus() {
        if .installNetworkExtension == viewState {
            print(".installNetworkExtension == viewState in Chrome")
            return
        }

        if isChromeExtensionInstalled == true {
            print("if isChromeExtensionInstalled == true in Chrome")

            updateSafariExtensionViewStatus()
        } else {
            withAnimation(.easeInOut(duration: 3)) {
                print("viewState = .installChromeExtension true in Chrome")
                self.viewState = .installChromeExtension
            }
        }
    }

  // MARK: - UI and Filter Management
  
    func setBlockedUrls(urls: [String]) {
        
        IPCConnection.shared.enableURLBlocking(urls)

        if status == .stopped { //If legacy blocking
            if isActiveBlocking { //if is active blocking
                updateLegacyBlockedList(newBlockedDomains: urls)
            }
        }
        // State might change due to Safari integration
    }

    func setIPAddressesToBlock(addresses: [String]) {
        IPCConnection.shared.enableIPAddressesBlocking(addresses)
    }
        
  func updateStatus() {
    if NEFilterManager.shared().isEnabled {
      registerWithProvider()
    } else {
      status = .stopped
    }
    // Keep extension state refreshed
    refreshExtensionState()
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
  
  static func loadFilterConfiguration(completionHandler: @escaping (Bool) -> Void) {
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
      Self.loadFilterConfiguration { success in
      guard success else {
        self.status = .stopped
        self.refreshExtensionState()
        return
      }
      if filterManager.providerConfiguration == nil {
        let providerConfiguration = NEFilterProviderConfiguration()
        providerConfiguration.filterSockets = true
        providerConfiguration.filterPackets = false
//        providerConfiguration.filterBrowsers = true
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
            self.refreshExtensionState()
            return
          }
          self.registerWithProvider()
        }
      }
    }
  }
    
  func registerWithProvider() {
    // Assuming an IPCConnection singleton similar to the AppKit sample
    IPCConnection.shared.register(withExtension: extensionBundle, delegate: self) { success in
      DispatchQueue.main.async {
        self.status = success ? .running : .stopped
          self.setBlockedUrls(urls: AppPreferences.getBlockedDomains())
          self.refreshExtensionState()
      }
//        setBlockedURLs([])
    }
  }
  
    func activateExtension() {
        // Start by activating the system extension.
        guard let extensionIdentifier = extensionIdentifier else {
            self.status = .stopped
            self.refreshExtensionState()
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
      refreshExtensionState()
      return
    }
      Self.loadFilterConfiguration { success in
      guard success else {
        self.status = .running
        self.refreshExtensionState()
        return
      }
      // Disable the content filter configuration.
      filterManager.isEnabled = false
      filterManager.saveToPreferences { saveError in
        DispatchQueue.main.async {
          if let error = saveError {
            os_log("[SC] 🔍] Failed to disable the filter configuration: %@", error.localizedDescription)
            self.status = .running
            self.refreshExtensionState()
            return
          }
          self.status = .stopped
          self.refreshExtensionState()
        }
      }
    }
  }
  // MARK: - OSSystemExtensionRequestDelegate Methods
  
  func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
    guard result == .completed else {
      os_log("[SC] 🔍] Unexpected result %d for system extension request", result.rawValue)
      status = .stopped
      refreshExtensionState()
      return
    }
    enableFilterConfiguration()
  }
  
  func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
    os_log("[SC] 🔍] System extension request failed: %@", error.localizedDescription)
    status = .stopped
    refreshExtensionState()
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
        // URLs updated; refresh extension state in case Safari side changed.
    }
    
    func activateNetworkBlocking() {
        print("activateNetworkBlocking+++++")
       _ = IPCConnection.shared.sendMessageToEnableNetworkExtension(_enable: true)
        BlockListManager.activateSafariBlocking()
        chromeService.activateSafariBlocking()
        startShowingCountDownInDock()
    }
    
    func deactivateNetworkBlocking() {
         print("deactivateNetworkBlocking+++++")
        _ = IPCConnection.shared.sendMessageToEnableNetworkExtension(_enable: false)
        BlockListManager.deactivateSafariBlocking()
        chromeService.deactivateSafariBlocking()
        if AppPreferences.playSoundOnCompletion {
            NSSound.playDefaultSound()
        }
        if AppPreferences.showNotificationOnCompletion {
            LocalNotificationManager.scheduleNotification()
        }
        stopShowingCountDownInDock()
    }
    
    // MARK: - Timer management
    
    func startTimerWithSelectedDelay() -> Bool {
        cancelTimer()
        let seconds = delay * 60.0
        guard seconds > 30 else {
            os_log("[SC] 🔍] startTimerWithSelectedDelay called with non-positive delay: %f", seconds)
            return false
        }
        timerFireDate = Date().addingTimeInterval(seconds)
        os_log("[SC] 🔍] Scheduling timer to fire in %.0f seconds (%.2f minutes)", seconds, delay)
        blockTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            os_log("[SC] 🔍] Timer fired. Deactivating network blocking.")
            self.deactivateNetworkBlocking()
            self.cancelTimer()
        }
        isActiveBlocking = true
//        RunLoop.main.add(blockTimer!, forMode: .common)
        return true
    }
    
    func extendBlockTimer(by minutes: Int) {
        guard minutes != 0, let timer = blockTimer else { return }
        let delta = TimeInterval(minutes * 60)
        timer.fireDate = timer.fireDate.addingTimeInterval(delta)
        // Optionally also track a blockEndDate if you show a countdown
        timerFireDate = timer.fireDate
        os_log("[SC] 🔍] Timer fire date updated to %{public}@", timerFireDate?.description ?? "Empty time")
    }
    
    func cancelTimer() {
        if let fireDate = timerFireDate {
            os_log("[SC] 🔍] Cancelling timer scheduled for %{public}@", fireDate as NSDate)
        }
        blockTimer?.invalidate()
        blockTimer = nil
        timerFireDate = nil
        self.isActiveBlocking = false
    }
    
    func installLegacyLaunched(futureDuration: Date) {
        selfControlDaemon.install(blockedDomains: AppPreferences.getBlockedDomains(), time: futureDuration)
    }
    
    func updateLegacyBlockedList(newBlockedDomains: [String]) {
        selfControlDaemon.updateBlocklist(newBlockedDomains)
    }
    
    @MainActor func updateBlockList(newBlockedDomains: [BlockedURL], time: Double ) {
        self.delay = time
        if status == .stopped {
            installLegacyLaunched(futureDuration: Date.now.addingTimeInterval(delay*60))
        } else {
            if startTimerWithSelectedDelay() == false {
                return
            }
            saveAndupdateBlockList(newBlockedDomains)
            if startTimerWithSelectedDelay() == false { return }
            activateNetworkBlocking()
        }
    }
    
    @MainActor func saveAndupdateBlockList(_ newBlockedDomains: [BlockedURL]) {
        blockerStorage?.set(blockedURLs)
        let urls = newBlockedDomains.compactMap(\.urls)
        let flattened: [String] = urls.flatMap { $0 }
        AppPreferences.setBlockedDomains(flattened)
        setBlockedUrls(urls: flattened)
    }
    
    func updateScheduledEvents() {
        startEventScheduler()
    }
}
