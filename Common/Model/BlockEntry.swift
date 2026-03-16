import Foundation

/// Represents a single blocklist entry: a hostname, IP, or IP range with optional port.
struct BlockEntry: Equatable, Hashable {
    let hostname: String
    let port: Int?
    let maskLen: Int?

    /// Parse a blocklist string like "facebook.com", "10.0.0.0/8", or "example.com:443".
    init(string: String) {
        var working = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Strip protocol prefixes
        for prefix in ["http://", "https://", "ftp://"] {
            if working.hasPrefix(prefix) {
                working = String(working.dropFirst(prefix.count))
                break
            }
        }

        // Strip trailing path/query
        if let slashIndex = working.firstIndex(of: "/") {
            working = String(working[working.startIndex..<slashIndex])
        }

        // Extract port (hostname:port)
        var port: Int? = nil
        if let colonIndex = working.lastIndex(of: ":"),
           !working.contains("/"),
           let portNum = Int(working[working.index(after: colonIndex)...]) {
            port = portNum
            working = String(working[working.startIndex..<colonIndex])
        }

        // Extract mask (/24)
        var maskLen: Int? = nil
        if let slashIndex = working.firstIndex(of: "/"),
           let mask = Int(working[working.index(after: slashIndex)...]) {
            maskLen = mask
            working = String(working[working.startIndex..<slashIndex])
        }

        // Strip trailing dot
        if working.hasSuffix(".") {
            working = String(working.dropLast())
        }

        self.hostname = working
        self.port = port
        self.maskLen = maskLen
    }

    /// Whether this entry looks like an IP address (v4 or v6).
    var isIPAddress: Bool {
        return isIPv4 || isIPv6
    }

    var isIPv4: Bool {
        var addr = in_addr()
        return inet_pton(AF_INET, hostname, &addr) == 1
    }

    var isIPv6: Bool {
        var addr = in6_addr()
        return inet_pton(AF_INET6, hostname, &addr) == 1
    }

    /// The pf rule string for this entry (used in packet filter anchor).
    var pfRuleString: String {
        var host = hostname
        if let mask = maskLen {
            host += "/\(mask)"
        }
        if let port = port {
            return "block out proto tcp from any to \(host) port \(port)"
        }
        return "block out proto tcp from any to \(host)"
    }

    /// The /etc/hosts line for this entry (points hostname to 0.0.0.0).
    var hostsLine: String {
        guard !isIPAddress else { return "" }
        return "0.0.0.0\t\(hostname)"
    }
}
