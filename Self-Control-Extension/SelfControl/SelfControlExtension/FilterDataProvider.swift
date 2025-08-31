import NetworkExtension
import os.log
import dnssd

/// FilterDataProvider is a NEFilterDataProvider subclass that intercepts flows and applies a test rule.
class FilterDataProvider: NEFilterDataProvider {
    // MARK: - Properties
//    private let listner = PlistListner()
    /// A dictionary for storing flows related to the same process.
    private var relatedFlows: [String: [NEFilterSocketFlow]] = [:]
    
    // MARK: - Initialization
    
    override init() {
        os_log("[SC] 🔍] FilterDataProvider: init")
      super.init()
//        listner.startListening()
    }
    
    // MARK: - Filter Lifecycle
      static let localPort = "8888"

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        os_log("[SC] 🔍] FilterDataProvider: Starting filter", log: OSLog.default, type: .info)
        os_log("[SC] 🔍] captrued Domains: %{public}@", log: OSLog.default, type: .error, ExtensionsPreferencesManager().blockedDomains)
//        os_log("[SC] 🔍] captrued blockedUrls: %{public}@", log: OSLog.default, type: .error, IPCConnection.shared.blockedUrls)

        // Filter incoming TCP connections on port 8888
        let blockedHosts = IPCConnection.shared.blockedUrls

//        let filterRules = blockedHosts.map { address -> NEFilterRule in
//  //          let localNetwork = NWHostEndpoint(hostname: address as! String, port: FilterDataProvider.localPort)
//            let inboundNetworkRule = NENetworkRule(remoteNetwork: address,
//                                                   remotePrefix: 0,
//                                                   localNetwork: nil,
//                                                   localPrefix: 0,
//                                                   protocol: .any,
//                                                   direction: .outbound)
//            return NEFilterRule(networkRule: inboundNetworkRule, action: .filterData)
//        }
        // Filter incoming TCP connections on port 8888
//        let filterRules = ["0.0.0.0", "::"].map { address -> NEFilterRule in
//        let filterRules = ["*"].map { address -> NEFilterRule in
//            let localNetwork = NWHostEndpoint(hostname: address, port: "*")
//            let inboundNetworkRule = NENetworkRule(remoteNetwork: nil,
//                                                   remotePrefix: 0,
//                                                   localNetwork: localNetwork,
//                                                   localPrefix: 0,
//                                                   protocol: .any,
//                                                   direction: .outbound)
//            return NEFilterRule(networkRule: inboundNetworkRule, action: .filterData)
//        }
//
        let filterRules = blockedHosts.map { address -> NEFilterRule in
            let localNetwork = NWHostEndpoint(hostname: address, port: "*")
            let inboundNetworkRule = NENetworkRule(remoteNetwork: nil,
                                                   remotePrefix: 0,
                                                   localNetwork: localNetwork,
                                                   localPrefix: 0,
                                                   protocol: .any,
                                                   direction: .outbound)
            return NEFilterRule(networkRule: inboundNetworkRule, action: .filterData)
        }
        

      // Create a rule matching all outbound traffic.
//      let networkRule = NENetworkRule(remoteNetwork: nil,
//                                      remotePrefix: 0,
//                                      localNetwork: nil,
//                                      localPrefix: 0,
//                                      protocol: .any,
//                                      direction: .outbound)
//      let filterRule = NEFilterRule(networkRule: networkRule, action: .filterData)
//      let filterSettings = NEFilterSettings(rules: [filterRule], defaultAction: .allow)
        let filterSettings = NEFilterSettings(rules: filterRules, defaultAction: .allow)

      apply(filterSettings) { error in
        if let error = error {
          os_log("[SC] 🔍] Error applying filter settings: %@", log: OSLog.default, type: .error, error.localizedDescription)
        }
        completionHandler(error)
      }
    }
    
    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
      os_log("[SC] 🔍] FilterDataProvider: Stopping filter with reason %d", log: OSLog.default, type: .info, reason.rawValue)
      completionHandler()
    }
    
    // MARK: - Flow Handling
    
    // Called for each new flow.
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
      os_log("[SC] 🔍] FilterDataProvider: handleNewFlow invoked", log: OSLog.default, type: .debug)
//        if let appID = flow.sourceAppIdentifier {
//              print("App making the request: \(appID)")
//          }
      guard let socketFlow = flow as? NEFilterSocketFlow else {
        os_log("[SC] 🔍] Not a socket flow. Allowing.", log: OSLog.default, type: .info)
        return .allow()
      }
    
      // Extract remote endpoint (if available).
      guard let remoteEndpoint = socketFlow.remoteEndpoint as? NWHostEndpoint else {
        os_log("[SC] 🔍] No valid remote endpoint. Allowing flow.", log: OSLog.default, type: .error)
        return .allow()
      }
      os_log("[SC] 🔍] Flow from remote endpoint: %{public}@, URL: %{public}@", log: OSLog.default, type: .debug, remoteEndpoint.description, flow.url?.description ?? "nil")
        if let urlString = flow.url?.absoluteString {
            os_log("[SC] 🔍] Checking URL path: %{public}@", urlString)
//            let blockedHosts = ["google.com/mail", "google.com/news", "facebook.com"]
            let blockedHosts = IPCConnection.shared.blockedUrls
            os_log("[SC] 🔍] BlockedList: %{public}@ checking:%{public}@",blockedHosts, urlString)
            for host in blockedHosts {
                if urlString.contains(host) {
                    os_log("[SC] 🔍] Blocking flow to handleNewFlow %{public}@", urlString)
                    return .drop()
//                    return .allow()
                }
            }
        }
  //      if blockedHosts.contains(flow.url?.path() ?? "") {
  //                 os_log("Blocking flow to %@", remoteEndpoint.hostname)
  //                 return .drop()
  //             }
      // Only process outbound traffic.
      if socketFlow.direction != .outbound {
        os_log("[SC] 🔍] Non-outbound traffic. Allowing.", log: OSLog.default, type: .info)
        return .allow()
      }
        
        return .allow()
      
      // Process the flow and decide a verdict.
      let verdict = processEvent(for: socketFlow)
      os_log("[SC] 🔍] Verdict for flow: %{public}@", log: OSLog.default, type: .debug, verdict.debugDescription)
      return verdict
    }
    
//    override func handleInboundDataComplete(for flow: NEFilterFlow) -> NEFilterDataVerdict {
//        if let socketFlow = flow as? NEFilterSocketFlow {
//            if let data = socketFlow.readData {
//                if let requestString = String(data: data, encoding: .utf8) {
//                    if requestString.hasPrefix("GET") || requestString.hasPrefix("POST") {
//                        print("Request: \(requestString)")
//                        // Parse the path here
//                    }
//                }
//            }
//        }
//        return .allow()
//    }
//
//    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
//        return .filterDataVerdict(withFilterInbound: true,
//                                  peekInboundBytes: 1024,
//                                  filterOutbound: true,
//                                  peekOutboundBytes: 1024)
//    }

    
    override func handleInboundData(from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data) -> NEFilterDataVerdict {
        if let requestString = String(data: readBytes, encoding: .utf8) {
            print("Outbound data: \(requestString)")
            os_log("[SC] 🔍] handleInboundData: %{public}@", requestString)

            if requestString.contains("facebook.com/friends") {
                return .drop()
            }
        }
        return .allow()
    }
    
    override func displayMessage(_ message: String, completionHandler: @escaping (Bool) -> Void) {
        return completionHandler(true)
    }
    
    override func handleOutboundData(from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data) -> NEFilterDataVerdict {
        if let urlString = flow.url?.absoluteString {
            os_log("[SC] 🔍] handleOutboundData URL: %{public}@", urlString)
            if urlString.contains("facebook.com/friends") {
                return .drop()
            }
        }

        if let requestString = String(data: readBytes, encoding: .utf8) {
            print("Outbound data: \(requestString)")
            os_log("[SC] 🔍] handleOutboundData: %{public}@", requestString)

            if requestString.contains("facebook.com/friends") {
                return .drop()
            }
        }
        return .allow()
    }
    
//    override func handleOutboundData(from flow: NEFilterFlow,
//                                      readBytesStartOffset offset: Int,
//                                      readBytes: Data,
//                                      completionHandler: @escaping (NEFilterDataVerdict) -> Void) {
//
//        if let requestString = String(data: readBytes, encoding: .utf8) {
//            print("Outbound data: \(requestString)")
//
//            if requestString.contains("facebook.com") {
//                completionHandler(.drop())
//                return
//            }
//        }
//
//        // If undecided, ask for more data
//        completionHandler(.allow())
//    }
    
    /// Processes the flow and returns a verdict.
    /// This is a simplified test rule that blocks flows destined for "example.com".
    private func processEvent(for flow: NEFilterSocketFlow) -> NEFilterNewFlowVerdict {
      guard let endpoint = flow.remoteEndpoint as? NWHostEndpoint else {
        return .allow()
      }
        os_log("[SC] 🔍] processEvent endpoint.hostname: %{public}@ ", endpoint.hostname)
        os_log("[SC] 🔍] processEvent remoteHostname: %{public}@ ", flow.remoteHostname ?? "NOTHING")
        guard let host = flow.remoteHostname?.lowercased().domainString else {
            os_log("[SC] 🔍] processEvent No Host")
            return .allow()
        }
//      os_log("[SC] 🔍] This is localFlowEndpoint: %{public}@ ", flow.localFlowEndpoint?.debugDescription ?? "NOTHING")
        let blockedHosts = IPCConnection.shared.blockedUrls

//      if host == "google.com" || host == "8.8.8.8" {
        if blockedHosts.contains(host) {
        os_log("[SC] 🔍] processEvent: Blocking flow to processEvent %{public}@ ", host)
        return .drop()
//            return .allow()
      }
      // Optionally log other flows for debugging
      os_log("[SC] 🔍] processEvent: Allowing flow to %{public}@", log: OSLog.default, type: .info, host)
      return .allow()
    }

    
    // MARK: - (Optional) Handling Related Flows & Alerts
    
    /// Adds a flow to a list of related flows for a given key.
    private func addRelatedFlow(forKey key: String, flow: NEFilterSocketFlow) {
      os_log("[SC] 🔍] Adding related flow for key: %@", log: OSLog.default, type: .debug, key)
      if relatedFlows[key] == nil {
        relatedFlows[key] = []
      }
      relatedFlows[key]?.append(flow)
    }
    
    /// Processes related flows once a decision is made for a given key.
    private func processRelatedFlows(forKey key: String) {
      guard let flows = relatedFlows[key] else {
        os_log("[SC] 🔍] No related flows for key: %@", log: OSLog.default, type: .debug, key)
        return
      }
      for flow in flows {
        let verdict = processEvent(for: flow)
        resumeFlow(flow, with: verdict)
      }
      relatedFlows[key] = nil
    }
    
    /// A stub method for resuming a flow with a verdict.
    private func resumeFlow(_ flow: NEFilterSocketFlow, with verdict: NEFilterNewFlowVerdict) {
      // In a complete implementation, this would resume the paused flow with the provided verdict.
      os_log("[SC] 🔍] Resuming flow %@ with verdict %@", log: OSLog.default, type: .info, flow.debugDescription, verdict.debugDescription)
    }
    
    /// A stub method to simulate alerting the user.
    /// In a complete implementation, this might trigger an IPC to your app for user intervention.
    private func alertUser(for flow: NEFilterSocketFlow) {
      os_log("[SC] 🔍] Alert: User decision needed for flow %@", log: OSLog.default, type: .info, flow.debugDescription)
    }
  }
//https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions

