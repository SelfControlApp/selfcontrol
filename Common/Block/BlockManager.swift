import Foundation

/// Orchestrates PacketFilter + HostFileBlockerSet to enforce a website block.
/// Handles DNS resolution, common subdomain expansion, and rule generation.
final class BlockManager {
    private let isAllowlist: Bool
    private let allowLocal: Bool
    private let includeCommonSubdomains: Bool
    private let includeLinkedDomains: Bool
    private let packetFilter: PacketFilter
    private let hostsBlocker: HostFileBlockerSet
    private var isAppending = false

    init(isAllowlist: Bool,
         allowLocal: Bool = true,
         includeCommonSubdomains: Bool = true,
         includeLinkedDomains: Bool = true) {
        self.isAllowlist = isAllowlist
        self.allowLocal = allowLocal
        self.includeCommonSubdomains = includeCommonSubdomains
        self.includeLinkedDomains = includeLinkedDomains
        self.packetFilter = PacketFilter(isAllowlist: isAllowlist)
        self.hostsBlocker = HostFileBlockerSet()
    }

    // MARK: - Block Lifecycle

    func prepareToAddBlock() {
        // Nothing to prepare — just reset state
    }

    func addEntries(from strings: [String]) {
        var allEntries: [String] = []

        for string in strings {
            let entry = BlockEntry(string: string)
            allEntries.append(entry.hostname)

            // Add common subdomains if enabled
            if includeCommonSubdomains && !entry.isIPAddress {
                let subdomains = commonSubdomains(for: entry.hostname)
                allEntries.append(contentsOf: subdomains)
            }
        }

        // Resolve DNS and add rules
        for hostname in allEntries {
            let entry = BlockEntry(string: hostname)

            if entry.isIPAddress {
                // IP address — add directly to pf
                packetFilter.addRule(ip: entry.hostname, port: entry.port ?? 0, maskLen: entry.maskLen ?? 0)
            } else {
                // Hostname — add to hosts file and resolve for pf
                if !isAppending {
                    hostsBlocker.addEntry(hostname: entry.hostname)
                }

                // Resolve hostname to IPs for pf rules
                let ips = resolveHostname(entry.hostname)
                for ip in ips {
                    packetFilter.addRule(ip: ip, port: entry.port ?? 0, maskLen: 0)
                }
            }
        }
    }

    func finalizeBlock() {
        if !isAppending {
            packetFilter.writeConfiguration()
            packetFilter.startBlock()
            hostsBlocker.writeNewFileContents()
        } else {
            packetFilter.finishAppending()
            packetFilter.refreshPFRules()
        }
    }

    func clearBlock() -> Bool {
        let pfResult = packetFilter.stopBlock(force: false)
        let hostsResult = hostsBlocker.clearBlock()
        return pfResult == 0 && hostsResult
    }

    // MARK: - Append Mode (add entries to a running block)

    func enterAppendMode() {
        isAppending = true
        packetFilter.enterAppendMode()
    }

    func finishAppending() {
        isAppending = false
        packetFilter.finishAppending()
    }

    // MARK: - DNS Resolution

    private func resolveHostname(_ hostname: String) -> [String] {
        var ips: [String] = []

        let host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
        var resolved: DarwinBoolean = false
        CFHostStartInfoResolution(host, .addresses, nil)
        guard let addresses = CFHostGetAddressing(host, &resolved)?.takeUnretainedValue() as? [Data] else {
            return ips
        }

        for addrData in addresses {
            addrData.withUnsafeBytes { rawPtr in
                let sockaddr = rawPtr.baseAddress!.assumingMemoryBound(to: sockaddr.self)
                var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(sockaddr, socklen_t(addrData.count),
                               &hostBuffer, socklen_t(hostBuffer.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    ips.append(String(cString: hostBuffer))
                }
            }
        }

        return ips
    }

    // MARK: - Common Subdomains

    private func commonSubdomains(for hostname: String) -> [String] {
        let prefixes = ["www.", "m.", "mobile."]
        var result: [String] = []

        for prefix in prefixes {
            let sub = prefix + hostname
            if sub != hostname {
                result.append(sub)
            }
        }

        // Special handling for Google domains
        if isGoogleDomain(hostname) {
            result.append(contentsOf: googleSubdomains(for: hostname))
        }

        return result
    }

    private func isGoogleDomain(_ hostname: String) -> Bool {
        let googlePatterns = ["google.", "youtube.", "gmail.", "googleapis.", "gstatic.", "googlevideo."]
        return googlePatterns.contains { hostname.contains($0) }
    }

    private func googleSubdomains(for hostname: String) -> [String] {
        // Google uses many regional and service subdomains
        let extra = [
            "www.\(hostname)", "apis.\(hostname)", "ssl.\(hostname)",
            "encrypted.\(hostname)", "clients1.\(hostname)"
        ]
        return extra
    }
}
