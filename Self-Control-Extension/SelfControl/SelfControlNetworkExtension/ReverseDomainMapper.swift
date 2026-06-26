//
//  ReverseDomainMapper.swift
//  SelfControlExtension
//
//  Created by Satendra Singh on 14/10/25.
//

import Foundation

final class ReverseDomainMapper {
    static func reverseDNSUsingGetNameInfo(ipAddress: String) -> String? {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        inet_pton(AF_INET, ipAddress, &addr.sin_addr)

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

        // Precompute length so we don't read from `addr` inside the closure.
        let addrLen = socklen_t(addr.sin_len)

        let result: Int32 = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                getnameinfo(saPtr,
                            addrLen,
                            &hostname, socklen_t(hostname.count),
                            nil, 0,
                            NI_NAMEREQD)
            }
        }

        guard result == 0 else { return nil }
        return String(cString: hostname)
    }
}

enum Regex {
    static let ipAddress = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
    static let hostname = "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$"
}

extension String {
    var isValidIpAddress: Bool {
        return self.matches(pattern: Regex.ipAddress)
    }
    
    var isValidHostname: Bool {
        return self.matches(pattern: Regex.hostname)
    }
    
    private func matches(pattern: String) -> Bool {
        return self.range(of: pattern,
                          options: .regularExpression,
                          range: nil,
                          locale: nil) != nil
    }
}
