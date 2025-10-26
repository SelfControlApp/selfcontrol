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
    
    // MARK: - Flow Handlings
    
    
    func reverseDNSLookup(ip: String) -> String? {
        var hints = addrinfo(ai_flags: AI_NUMERICHOST, ai_family: AF_UNSPEC,
                             ai_socktype: SOCK_STREAM, ai_protocol: IPPROTO_TCP,
                             ai_addrlen: 0, ai_canonname: nil,
                             ai_addr: nil, ai_next: nil)
        var res: UnsafeMutablePointer<addrinfo>?

        if getaddrinfo(ip, nil, &hints, &res) == 0, let addr = res?.pointee.ai_addr {
            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                           &hostBuffer, socklen_t(hostBuffer.count),
                           nil, 0, NI_NAMEREQD) == 0 {
                return String(cString: hostBuffer)
            }
        }
        return nil
    }
    
    func extractHost(from request: String) -> String? {
        for line in request.split(separator: "\r\n") {
            if line.lowercased().hasPrefix("host:") {
                return line.replacingOccurrences(of: "Host:", with: "", options: .caseInsensitive)
                           .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    func extractPath(from request: String) -> String? {
        guard let firstLine = request.split(separator: "\r\n").first else { return nil }
        let comps = firstLine.split(separator: " ")
        return comps.count > 1 ? String(comps[1]) : nil
    }
    
    func extractSNI(fromTLSData data: Data) -> String? {
        // TLS record starts with 0x16 (Handshake), version bytes, then length
        guard data.count > 5, data[0] == 0x16 else { return nil }

        var offset = 5 // Skip record header

        // Verify handshake type = ClientHello (0x01)
        guard data.count > offset, data[offset] == 0x01 else { return nil }
        offset += 4 // Skip type + length (3 bytes)

        // Skip protocol version (2), random (32), session id length + session id
        guard data.count > offset + 34 else { return nil }
        offset += 34
        guard data.count > offset else { return nil }

        // Skip session ID
        if offset < data.count {
            let sessionIDLength = Int(data[offset])
            offset += 1 + sessionIDLength
        }

        // Skip cipher suites
        guard offset + 2 <= data.count else { return nil }
        let cipherSuiteLength = Int(data[offset]) << 8 | Int(data[offset + 1])
        offset += 2 + cipherSuiteLength

        // Skip compression methods
        guard offset < data.count else { return nil }
        let compressionLength = Int(data[offset])
        offset += 1 + compressionLength

        // Skip extensions length
        guard offset + 2 <= data.count else { return nil }
        let extensionsLength = Int(data[offset]) << 8 | Int(data[offset + 1])
        offset += 2
        guard offset + extensionsLength <= data.count else { return nil }

        var extOffset = offset
        while extOffset + 4 <= offset + extensionsLength {
            let extType = Int(data[extOffset]) << 8 | Int(data[extOffset + 1])
            let extLen  = Int(data[extOffset + 2]) << 8 | Int(data[extOffset + 3])
            extOffset += 4

            // Extension type 0 = Server Name
            if extType == 0 {
                // Parse Server Name extension
                var nameOffset = extOffset + 2 // skip list length
                while nameOffset + 3 < extOffset + extLen {
                    let nameType = data[nameOffset]
                    let nameLen = Int(data[nameOffset + 1]) << 8 | Int(data[nameOffset + 2])
                    nameOffset += 3
                    if nameType == 0, nameOffset + nameLen <= data.count {
                        let nameData = data.subdata(in: nameOffset ..< nameOffset + nameLen)
                        return String(data: nameData, encoding: .utf8)
                    }
                    nameOffset += nameLen
                }
            }

            extOffset += extLen
        }

        return nil
    }

    override func handleOutboundData(
          from flow: NEFilterFlow,
          readBytesStartOffset offset: Int,
          readBytes data: Data
      ) -> NEFilterDataVerdict {
          
          
          let process = processFromflow(flow: flow)
  //        os_log(" FilterDataProvider: appIdAndName %{public}@, %{public}@", log: OSLog.default, type: .debug, process?.name ?? "", process?.path ?? "")
          os_log(" FilterDataProvider: app %{public}@", log: OSLog.default, type: .debug, process?.description ?? "")

          if let process = process, AllowedProcess.isAllowedProcess(process) {
              os_log("[SC] 🔍] FilterDataProvider: allowing as it is in allowed list.")
              return .allow()
          }
        guard let socketFlow = flow as? NEFilterSocketFlow else {
          os_log("[SC] 🔍] Not a socket flow. Allowing.", log: OSLog.default, type: .info)
          return .allow()
        }
          if socketFlow.direction !=  .outbound {
              os_log("[SC] 🔍] Not a inbound socket flow. Allowing.", log: OSLog.default, type: .info)
              return .allow()
          }
          
//          guard let socketFlow = flow as? NEFilterSocketFlow else {
//              return .allow()
//          }
        let requestString = String(data: data, encoding: .utf8)
          if let requestString {
              os_log("[SC] 🔍] data HTTP Request: %{public}@", requestString)
          }

          // Try HTTP detection
          if let requestString = requestString,
             requestString.hasPrefix("GET ") || requestString.hasPrefix("POST ") {
              
              if let host = extractHost(from: requestString),
                 let path = extractPath(from: requestString) {
                  let urlString = "http://\(host)\(path)"
                  os_log("[SC] 🔍] data HTTP Request: %{public}@", urlString)
              }

          } else if let sni = extractSNI(fromTLSData: data) {
              os_log("[SC] 🔍] data TLS SNI Host: %{public}@", sni)
              guard let hostDomain = TLDURLToDomain.getURLDomain(from: sni) else {
                  return .allow()
              }
              os_log("[SC] 🔍] data hostDomain: %{public}@", hostDomain)

              for url in IPCConnection.shared.blockedUrls {
                  if url.contains(hostDomain) {
                      os_log("[SC] 🔍] data  Blocking flow Host match SNI:%{public}@,  host:%{public}@", sni, hostDomain)
                      return .drop()
                  }
              }
          }

          return .allow()
      }

    // Called for each new flow.
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        // Provide peek sizes required by this overload
        return .filterDataVerdict(withFilterInbound: false,
                                  peekInboundBytes: 0,
                                  filterOutbound: true,
                                  peekOutboundBytes: Int.max)

      os_log("[SC] 🔍] FilterDataProvider: handleNewFlow invoked", log: OSLog.default, type: .debug)
//        if let appID = flow.sourceAppIdentifier {
//              print("App making the request: \(appID)")
//          }
//        let appIdAndName = SourceAppAuditTokenBuilder.getAppInfo(from: flow)
//        os_log("[SC] 🔍] FilterDataProvider: appIdAndName %@, %@", log: OSLog.default, type: .debug, appIdAndName.appName ?? "", appIdAndName.bundleID ?? "")
        guard IPCConnection.shared.blockedUrls.count > 0 else { //No signinficant urls to block
            return .allow()
        }
        
        let process = processFromflow(flow: flow)
//        os_log(" FilterDataProvider: appIdAndName %{public}@, %{public}@", log: OSLog.default, type: .debug, process?.name ?? "", process?.path ?? "")
        os_log(" FilterDataProvider: app %{public}@", log: OSLog.default, type: .debug, process?.description ?? "")

        if let process = process, AllowedProcess.isAllowedProcess(process) {
            os_log("[SC] 🔍] FilterDataProvider: allowing as it is in allowed list.")
            return .allow()
        }
      guard let socketFlow = flow as? NEFilterSocketFlow else {
        os_log("[SC] 🔍] Not a socket flow. Allowing.", log: OSLog.default, type: .info)
        return .allow()
      }
        if socketFlow.direction !=  .outbound {
            os_log("[SC] 🔍] Not a inbound socket flow. Allowing.", log: OSLog.default, type: .info)
            return .allow()
        }
        var remoteHost = ""
        if let flowURL = flow.url {
            remoteHost = flowURL.absoluteString
            os_log("[SC] 🔍] flow.url: \(remoteHost)")
        } else {
            if let remoteEndpoint = socketFlow.remoteEndpoint as? NWHostEndpoint {
                remoteHost = remoteEndpoint.hostname
                let port = remoteEndpoint.port
                os_log("[SC] 🔍] NWEndpoint to host: %{public}@, URL: %{public}@, url: %{public}@", log: OSLog.default, type: .debug, remoteHost, port, flow.url?.host() ?? "")
            }
        }

        
        //todo: check host name, work on reverse rule if domain match and if path is nil or blocked, drop connection.
//
//        if IPCConnection.shared.blockedList.isMatch(flow as! NEFilterSocketFlow) {
//            os_log("[SC] 🔍] Dropped", log: OSLog.default, type: .info)
//            return .drop()
//        }
//        os_log("[SC] 🔍] Allowed", log: OSLog.default, type: .info)
//
//        return .allow()
    
        os_log("[SC] 🔍] Flow from remote endpoint: %{public}@, URL: %{public}@", log: OSLog.default, type: .debug, socketFlow.remoteEndpoint.debugDescription, flow.url?.description ?? "nil")

      // Extract remote endpoint (if available).
//      guard let remoteEndpoint = socketFlow.remoteEndpoint as? NWHostEndpoint else {
//        os_log("[SC] 🔍] No valid remote endpoint. Allowing flow.", log: OSLog.default, type: .error)
//        return .allow()
//      }

        if remoteHost.isEmpty { //Unable to get host
            return .allow()
        }
        if remoteHost.isValidIpAddress {
            if IPCConnection.shared.blockedIPAddresses.contains(remoteHost) {
                os_log("[SC] 🔍] Blocking flow IP match: %{public}@", remoteHost)
                return .drop()
            }
            if let host = ReverseDomainMapper.reverseDNSUsingGetNameInfo(ipAddress: remoteHost) {
                os_log("[SC] 🔍] Converted IP: %{public}@ to: %{public}@", remoteHost, host)
                remoteHost = host
            } else { //unable to convert, simple ignore
                return .allow()
            }
        } else {
            return .allow()
        }
        guard let hostDomain = TLDURLToDomain.getURLDomain(from: remoteHost) else {
            return .allow()
        }
        for url in IPCConnection.shared.blockedUrls {
            if url.contains(hostDomain) {
                os_log("[SC] 🔍] Blocking flow Host match %{public}@, %{public}@", remoteHost, hostDomain)
                return .drop()
            }
        }
//        if var urlString = flow.url?.absoluteString {
//            os_log("[SC] 🔍] Checking URL path: %{public}@", urlString)
////            let blockedHosts = ["google.com/mail", "google.com/news", "facebook.com"]
//            let blockedHosts = IPCConnection.shared.blockedUrls
//            os_log("[SC] 🔍] BlockedList: %{public}@ checking:%{public}@",blockedHosts, urlString)
//            if urlString.hasPrefix("www.") {
//                let noWWW = String(urlString.dropFirst(4))
//                urlString = noWWW
//            }
//
//            for host in blockedHosts {
//                if urlString.contains(host) {
//                    os_log("[SC] 🔍] Blocking flow to handleNewFlow %{public}@", urlString)
//                    return .drop()
////                    return .allow()
//                }
////                flow.url?.host() == url
//            }
//        }
  //      if blockedHosts.contains(flow.url?.path() ?? "") {
  //                 os_log("Blocking flow to %@", remoteEndpoint.hostname)
  //                 return .drop()
  //             }
      // Only process outbound traffic.
//      if socketFlow.direction != .outbound {
//        os_log("[SC] 🔍] Non-outbound traffic. Allowing.", log: OSLog.default, type: .info)
//        return .allow()
//      }
        
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
    
//    override func handleOutboundData(from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data) -> NEFilterDataVerdict {
//        if let urlString = flow.url?.absoluteString {
//            os_log("[SC] 🔍] handleOutboundData URL: %{public}@", urlString)
//            if urlString.contains("facebook.com/friends") {
//                return .drop()
//            }
//        }
//
//        if let requestString = String(data: readBytes, encoding: .utf8) {
//            print("Outbound data: \(requestString)")
//            os_log("[SC] 🔍] handleOutboundData: %{public}@", requestString)
//
//            if requestString.contains("facebook.com/friends") {
//                return .drop()
//            }
//        }
//        return .allow()
//    }
    
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
    
    func processFromflow(flow: NEFilterFlow) -> Process? {
        guard let auditTokenData = flow.sourceAppAuditToken else {
            return nil
        }
        
        // Convert NSData → audit_token_t
        var auditToken = auditTokenData.withUnsafeBytes { ptr -> audit_token_t in
            return ptr.load(as: audit_token_t.self)
        }
        return Process.init(&auditToken)
    }
  }
//https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions

