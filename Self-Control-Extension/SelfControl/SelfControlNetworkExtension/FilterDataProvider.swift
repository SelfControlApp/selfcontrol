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
        os_log("[SC] 🔍 NE FilterDataProvider: init")
      super.init()
//        listner.startListening()
    }
    
    // MARK: - Filter Lifecycle
      static let localPort = "8888"
    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        os_log("[SC] 🔍 NE FilterDataProvider: Starting filter", log: OSLog.default, type: .info)
        var blockedHosts = IPCConnection.shared.blockedUrls
//        if blockedHosts.count == 0 {
//            blockedHosts = ["https://www.corebitss.com"]
//        }
        
        os_log("[SC] 🔍 NE Blocked blockedUrls: %{public}@", log: OSLog.default, type: .info, String(describing: blockedHosts))
        
        // Ensure blockedHosts is an array of String
        var filterRules: [NEFilterRule] = blockedHosts.compactMap { address in
            guard let host = address as? String else { return nil }
            // For hostname-based rules, you must use NENetworkRule with nil networks (matches all)
            let networkRule = NENetworkRule(
                remoteNetwork: nil,
                remotePrefix: 0,
                localNetwork: nil,
                localPrefix: 0,
                protocol: .any,
                direction: .outbound
            )
            return NEFilterRule(networkRule: networkRule, action: .filterData)
        }
        
        // Ensure at least one rule exists as required by NEFilterSettings
        if filterRules.count == 0 {
            // Add a default rule (matches all traffic, for example, and allows it)
            let defaultNetworkRule = NENetworkRule(
                remoteNetwork: nil,
                remotePrefix: 0,
                localNetwork: nil,
                localPrefix: 0,
                protocol: .any,
                direction: .any
            )
            let defaultRule = NEFilterRule(networkRule: defaultNetworkRule, action: .filterData)
            filterRules = [defaultRule]
        }
        
        let filterSettings = NEFilterSettings(rules: filterRules, defaultAction: .allow)
        
        apply(filterSettings) { error in
            if let error = error {
                os_log("[SC] 🔍 NE Error applying filter settings: %{public}@", log: OSLog.default, type: .error, error.localizedDescription)
            }
            completionHandler(error)
        }
    }
    
    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
      os_log("[SC] 🔍 NE] FilterDataProvider: Stopping filter with reason %d", log: OSLog.default, type: .info, reason.rawValue)
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
        var result: NEFilterDataVerdict = .allow()
        
        guard IPCConnection.shared.isServiceActive else { //Service is inactive
            return result
        }
        
        guard IPCConnection.shared.blockedUrls.count > 0 else { //No signinficant urls to block
            return result
        }

        if RequestSourceAppValidator.isAllowedHost(flow: flow) {
            return result
        }
        
        guard let socketFlow = flow as? NEFilterSocketFlow else {
            os_log("[SC] 🔍 NE] <handleOutboundData> Not a socket flow. Allowing.", log: OSLog.default, type: .info)
            return result
        }
        if socketFlow.direction !=  .outbound {
            os_log("[SC] 🔍 NE] <handleOutboundData> Not a inbound socket flow. Allowing.", log: OSLog.default, type: .info)
            return result
        }
        
        //          guard let socketFlow = flow as? NEFilterSocketFlow else {
        //              return .allow()
        //          }
        let requestString = String(data: data, encoding: .utf8)
        if let requestString {
            os_log("[SC] 🔍 NE] <handleOutboundData> data HTTP Request: %{public}@", requestString)
        }
        
        // Try HTTP detection
        if let requestString = requestString,
           requestString.hasPrefix("GET ") || requestString.hasPrefix("POST ") {
            
            if let host = extractHost(from: requestString),
               let path = extractPath(from: requestString) {
                let urlString = "http://\(host)\(path)"
                os_log("[SC] 🔍 NE] <handleOutboundData> data HTTP Request: %{public}@", urlString)
            }
            
        } else if let sni = extractSNI(fromTLSData: data) {
            os_log("[SC] 🔍 NE] <handleOutboundData> data TLS SNI Host: %{public}@", sni)
            guard let hostDomain = TLDURLToDomain.getURLDomain(from: sni) else {
                return result
            }
            os_log("[SC] 🔍 NE] <handleOutboundData> data hostDomain: %{public}@", hostDomain)
            
            for url in IPCConnection.shared.blockedUrls {
                if url.contains(hostDomain) {
                    os_log("[SC] 🔍 NE] <handleOutboundData> data  Blocking flow Host match SNI:%{public}@,  host:%{public}@", sni, hostDomain)
                    result = .drop()
                    break
                }
            }
        }
        
        return result
    }

    // Called for each new flow.
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
//        os_log("[SC] 🔍 NE] FilterDataProvider: handleNewFlow invoked", log: OSLog.default, type: .debug)
        guard IPCConnection.shared.isServiceActive else {
            return .allow()
        }
        // Provide peek sizes required by this overload
//      os_log("[SC] 🔍 NE] FilterDataProvider: handleNewFlow invoked", log: OSLog.default, type: .debug)
        guard IPCConnection.shared.blockedUrls.count > 0 else { //No signinficant urls to block
            return .allow()
        }
          
        if RequestSourceAppValidator.isAllowedHost(flow: flow) {
            return .allow()
        }

        guard let socketFlow = flow as? NEFilterSocketFlow else {
            return .filterDataVerdict(withFilterInbound: false,
                                      peekInboundBytes: 0,
                                      filterOutbound: true,
                                      peekOutboundBytes: Int.max)

//            return .allow()
        }

        // Try to extract SNI hostname (HTTPS)
        guard let hostname = socketFlow.remoteHostname else  {
            return .filterDataVerdict(withFilterInbound: false,
                                      peekInboundBytes: 0,
                                      filterOutbound: true,
                                      peekOutboundBytes: Int.max)
        }

        // Fallback to IP address if SNI is not present
//        let remoteIP = (socketFlow.remoteEndpoint as? NWHostEndpoint)?.hostname ?? hostname

//        let host = hostname.isEmpty ? remoteIP : hostname
        let lower = hostname.lowercased()
        os_log("[SC] 🔍 NE] <handleNewFlow> Host SNI host:%{public}@", lower)
        guard let hostDomain = TLDURLToDomain.getURLDomain(from: lower) else {
            return .filterDataVerdict(withFilterInbound: false,
                                      peekInboundBytes: 0,
                                      filterOutbound: true,
                                      peekOutboundBytes: Int.max)
        }
        os_log("[SC] 🔍 NE] <handleNewFlow> Host SNI domain:%{public}@", hostDomain)
        for url in IPCConnection.shared.blockedUrls {
            if url.contains(hostDomain) {
                os_log("[SC] 🔍 NE] <handleNewFlow> Blocking flow Host:%{public}@", hostDomain)
                return .drop()
            }
        }

        os_log("[SC] 🔍 NE] Not a blocked domain. Allowing.", log: OSLog.default, type: .info)
        return .allow()

      guard let socketFlow = flow as? NEFilterSocketFlow else {
        os_log("[SC] 🔍 NE] Not a socket flow. Allowing.", log: OSLog.default, type: .info)
        return .allow()
      }
        if socketFlow.direction !=  .outbound {
            os_log("[SC] 🔍 NE] Not a inbound socket flow. Allowing.", log: OSLog.default, type: .info)
            return .allow()
        }
        var remoteHost = ""
        if let flowURL = flow.url {
            remoteHost = flowURL.absoluteString
            os_log("[SC] 🔍 NE] flow.url: \(remoteHost)")
        } else {
            if let remoteEndpoint = socketFlow.remoteEndpoint as? NWHostEndpoint {
                remoteHost = remoteEndpoint.hostname
                let port = remoteEndpoint.port
                os_log("[SC] 🔍 NE] NWEndpoint to host: %{public}@, URL: %{public}@, url: %{public}@", log: OSLog.default, type: .debug, remoteHost, port, flow.url?.host() ?? "")
            }
        }

        
        //todo: check host name, work on reverse rule if domain match and if path is nil or blocked, drop connection.
//
//        if IPCConnection.shared.blockedList.isMatch(flow as! NEFilterSocketFlow) {
//            os_log("[SC] 🔍 NE] Dropped", log: OSLog.default, type: .info)
//            return .drop()
//        }
//        os_log("[SC] 🔍 NE] Allowed", log: OSLog.default, type: .info)
//
//        return .allow()
    
        os_log("[SC] 🔍 NE] Flow from remote endpoint: %{public}@, URL: %{public}@", log: OSLog.default, type: .debug, socketFlow.remoteEndpoint.debugDescription, flow.url?.description ?? "nil")

        if remoteHost.isEmpty { //Unable to get host
            return .allow()
        }
        if remoteHost.isValidIpAddress {
            if IPCConnection.shared.blockedIPAddresses.contains(remoteHost) {
                os_log("[SC] 🔍 NE] Blocking flow IP match: %{public}@", remoteHost)
                return .drop()
            }
            if let host = ReverseDomainMapper.reverseDNSUsingGetNameInfo(ipAddress: remoteHost) {
                os_log("[SC] 🔍 NE] Converted IP: %{public}@ to: %{public}@", remoteHost, host)
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
                os_log("[SC] 🔍 NE] Blocking flow Host match %{public}@, %{public}@", remoteHost, hostDomain)
                return .drop()
            }
        }
        
        return .allow()
      
      // Process the flow and decide a verdict.
      let verdict = processEvent(for: socketFlow)
      os_log("[SC] 🔍 NE] Verdict for flow: %{public}@", log: OSLog.default, type: .debug, verdict.debugDescription)
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
            print("Inbound data: \(requestString)")
            os_log("[SC] 🔍 NE] handleInboundData: %{public}@", requestString)

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
//            os_log("[SC] 🔍 NE] handleOutboundData URL: %{public}@", urlString)
//            if urlString.contains("facebook.com/friends") {
//                return .drop()
//            }
//        }
//
//        if let requestString = String(data: readBytes, encoding: .utf8) {
//            print("Outbound data: \(requestString)")
//            os_log("[SC] 🔍 NE] handleOutboundData: %{public}@", requestString)
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
    
    ///ss Processes the flow and returns a verdict.
    /// This is a simplified test rule that blocks flows destined for "example.com".
    private func processEvent(for flow: NEFilterSocketFlow) -> NEFilterNewFlowVerdict {
      guard let endpoint = flow.remoteEndpoint as? NWHostEndpoint else {
        return .allow()
      }
        os_log("[SC] 🔍 NE] processEvent endpoint.hostname: %{public}@ ", endpoint.hostname)
        os_log("[SC] 🔍 NE] processEvent remoteHostname: %{public}@ ", flow.remoteHostname ?? "NOTHING")
        guard let host = flow.remoteHostname?.lowercased().domainString else {
            os_log("[SC] 🔍 NE] processEvent No Host")
            return .allow()
        }
//      os_log("[SC] 🔍 NE] This is localFlowEndpoint: %{public}@ ", flow.localFlowEndpoint?.debugDescription ?? "NOTHING")
        let blockedHosts = IPCConnection.shared.blockedUrls

//      if host == "google.com" || host == "8.8.8.8" {
        if blockedHosts.contains(host) {
        os_log("[SC] 🔍 NE] processEvent: Blocking flow to processEvent %{public}@ ", host)
        return .drop()
//            return .allow()
      }
      // Optionally log other flows for debugging
      os_log("[SC] 🔍 NE] processEvent: Allowing flow to %{public}@", log: OSLog.default, type: .info, host)
      return .allow()
    }

    
    // MARK: - (Optional) Handling Related Flows & Alerts
    
    /// Adds a flow to a list of related flows for a given key.
    private func addRelatedFlow(forKey key: String, flow: NEFilterSocketFlow) {
      os_log("[SC] 🔍 NE] Adding related flow for key: %@", log: OSLog.default, type: .debug, key)
      if relatedFlows[key] == nil {
          
          
        relatedFlows[key] = []
      }
      relatedFlows[key]?.append(flow)
    }
    
    /// Processes related flows once a decision is made for a given key.
    private func processRelatedFlows(forKey key: String) {
      guard let flows = relatedFlows[key] else {
        os_log("[SC] 🔍 NE] No related flows for key: %@", log: OSLog.default, type: .debug, key)
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
      os_log("[SC] 🔍 NE] Resuming flow %@ with verdict %@", log: OSLog.default, type: .info, flow.debugDescription, verdict.debugDescription)
    }
    
    /// A stub method to simulate alerting the user.
    /// In a complete implementation, this might trigger an IPC to your app for user intervention.
    private func alertUser(for flow: NEFilterSocketFlow) {
      os_log("[SC] 🔍 NE] Alert: User decision needed for flow %@", log: OSLog.default, type: .info, flow.debugDescription)
    }
    
//    func processFromflow(flow: NEFilterFlow) -> Process? {
//        guard let auditTokenData = flow.sourceAppAuditToken else {
//            return nil
//        }
//        
//        // Convert NSData → audit_token_t
//        var auditToken = auditTokenData.withUnsafeBytes { ptr -> audit_token_t in
//            return ptr.load(as: audit_token_t.self)
//        }
//        return Process.init(&auditToken)
//    }
  }
//https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions

