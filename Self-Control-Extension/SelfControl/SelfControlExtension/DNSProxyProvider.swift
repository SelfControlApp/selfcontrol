//
//  DNSProxyProvider.swift
//  SelfControl
//
//  Created by Satendra Singh on 02/08/25.
//


import NetworkExtension
import os.log

class DNSProxyProvider: NEDNSProxyProvider {

    // Cache for queried domains (thread-safe)
    var observedDomains = Set<String>()
    let queue = DispatchQueue(label: "dns.sync.queue")

    override func startProxy(options: [String : Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
        NSLog("DNS Proxy started")
        os_log("SC] 🔍 DNS Proxy started")
        completionHandler(nil)
    }

    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        if let tcpFlow = flow as? NEAppProxyTCPFlow {
            os_log("SC] 🔍 DNS Proxy NEAppProxyTCPFlow")
            readFromTCP(flow: tcpFlow)
            return true
        }

        guard let udpFlow = flow as? NEAppProxyUDPFlow else {
            return true
          }
        os_log("SC] 🔍 DNS Proxy NEAppProxyUDPFlow")
          udpFlow.readDatagrams { datagrams, remoteEndpoints, error in
              guard let datagrams = datagrams else { return }

              for data in datagrams {
                  if let message = DNSParser.parseMessage(data) {
                      for question in message.questions {
                          os_log("SC] 🔍 DNS Query for domain: %{public}@", question.name)
                          NSLog("🔍 DNS Query for domain: \(question.name)")
                          // Save domain name, blocklist, etc.
                      }
                  }
              }

              // Respond or forward if you're proxying
//              udpFlow.closeReadWithError(nil)
//              udpFlow.closeWriteWithError(nil)
          }

        return true
    }

    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("DNS Proxy stopped")
        os_log("SC] 🔍 DNS Proxy stopped")
        completionHandler()
    }
    
    func readFromTCP(flow: NEAppProxyTCPFlow) {
        flow.readData { [weak self] data, error in
            guard let data = data, !data.isEmpty else {
                os_log("SC] 🔍 No data or error: : %{public}@", error?.localizedDescription ?? "Empty")
                flow.closeReadWithError(nil)
                flow.closeWriteWithError(nil)
                return
            }

            var offset = 0 58540

            while offset + 2 <= data.count {
                // DNS over TCP starts with 2-byte length prefix
                let length = Int(data.uint16(at: offset))
                offset += 2

                guard offset + length <= data.count else {
                    NSLog("Incomplete DNS message")
                    os_log("SC] 🔍 Incomplete DNS message")
                    break
                }

                let dnsData = data.subdata(in: offset..<(offset + length))
                if let message = DNSParser.parseMessage(dnsData) {
                    for q in message.questions {
                        NSLog("🌐 DNS (TCP) Query: \(q.name)")
                        os_log("SC] 🔍 🌐 (TCP) Query: %{public}@", q.name)
                    }
                }

                offset += length
            }

            // Optionally respond or forward, or keep reading
            flow.closeReadWithError(nil)
            flow.closeWriteWithError(nil)
        }
    }

}

extension Data {
    public func uint16(at offset: Int) -> UInt16 {
        guard offset + 1 < self.count else { return 0 }
        return UInt16(self[offset]) << 8 | UInt16(self[offset + 1])
    }
}
