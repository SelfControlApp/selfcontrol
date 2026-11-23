import Foundation

/// Blocks websites the same way the original SelfControl does: entries in /etc/hosts plus a pf
/// firewall anchor that blocks the sites' IP addresses (so apps that skip the hosts file are blocked too).
/// Uses its own markers and anchor name so it can't collide with an original SelfControl block.
enum WebsiteBlocker {
    /// Lets tests point every system path at a scratch directory and skip running system tools.
    static let testRoot = ProcessInfo.processInfo.environment["SCN_TEST_ROOT"]
    static var isTesting: Bool { testRoot != nil }
    static func path(_ p: String) -> String { (testRoot ?? "") + p }

    static let beginMarker = "# BEGIN SELFCONTROL NEXT BLOCK"
    static let endMarker = "# END SELFCONTROL NEXT BLOCK"
    static let anchorName = "org.eyebeam.selfcontrolnext"
    static var hostsPath: String { path("/etc/hosts") }
    static var pfConfPath: String { path("/etc/pf.conf") }
    static var anchorPath: String { path("/etc/pf.anchors/\(anchorName)") }
    static var tokenPath: String { path("/Library/Application Support/SelfControlNext/pf-token") }

    // MARK: Apply / remove

    /// The anchor rules we last wrote, to detect tampering. Nil after a restart, which forces a re-apply.
    private static var lastAnchorRules: String?

    /// Blocks `domains`. If `allowlist` is non-nil, also blocks every other address except those
    /// sites (and what they depend on), like the original SelfControl's allowlist mode.
    static func apply(domains: [String], allowlist: [String]? = nil) {
        // Resolve before writing hosts: afterwards the lookups would just return our 0.0.0.0 entries.
        writeHosts(section: nil)
        if !isTesting { flushDNS() }
        let rules: String
        if let allowlist {
            rules = allowlistRules(for: allowedAddresses(allowlist))
        } else {
            // Google sites share servers with the rest of Google: block those via hosts only.
            rules = pfRules(for: resolveAll(domains.filter { !Domains.isGoogle($0) }))
        }
        writeHosts(section: hostsSection(for: domains))
        writeAnchor(rules: rules)
        lastAnchorRules = rules
        addAnchorToPFConf()
        if !isTesting {
            if FileManager.default.fileExists(atPath: tokenPath) {
                shell("/sbin/pfctl", ["-f", "/etc/pf.conf", "-F", "states"])
            } else {
                // -E takes a reference on pf being enabled; we release it with -X in remove().
                let output = shell("/sbin/pfctl", ["-E", "-f", "/etc/pf.conf", "-F", "states"])
                if let tokenLine = output.split(separator: "\n").first(where: { $0.hasPrefix("Token : ") }) {
                    try? String(tokenLine.dropFirst("Token : ".count)).write(toFile: tokenPath, atomically: true, encoding: .utf8)
                }
            }
            flushDNS()
        }
        log("Website block applied: \(domains.count) blocked\(allowlist.map { ", allow-only \($0.count)" } ?? "")")
    }

    /// Addresses to allow for allowed sites, including the domains they depend on.
    static func allowedAddresses(_ allowlist: [String]) -> [String] {
        var domains = Set(allowlist)
        for d in allowlist { domains.formUnion(Domains.relatedDomains[d] ?? []) }
        var addresses = Set(resolveAll(Array(domains)))
        if domains.contains(where: Domains.isGoogle) { addresses.formUnion(Domains.googleRanges) }
        return addresses.sorted()
    }

    static func allowlistRules(for addresses: [String]) -> String {
        var text = "# \(anchorName) allow-only ruleset for SelfControl Next\n"
        text += "block return out proto tcp from any to any\n"
        text += "block return out proto udp from any to any\n"
        // Keep the basics working: DNS, DHCP, NTP, mDNS. (pf uses the last matching rule.)
        for port in [53, 5353] {
            text += "pass out proto tcp from any to any port \(port)\n"
            text += "pass out proto udp from any to any port \(port)\n"
        }
        for port in [67, 68, 123] { text += "pass out proto udp from any to any port \(port)\n" }
        for ip in addresses {
            text += "pass out proto tcp from any to \(ip)\n"
            text += "pass out proto udp from any to \(ip)\n"
        }
        return text
    }

    static func remove() {
        guard isApplied else { return }
        writeHosts(section: nil)
        lastAnchorRules = nil
        try? "".write(toFile: anchorPath, atomically: true, encoding: .utf8)
        if let conf = try? String(contentsOfFile: pfConfPath, encoding: .utf8), conf.contains(anchorName) {
            let kept = conf.components(separatedBy: "\n").filter { !$0.contains(anchorName) }
            let text = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            try? text.write(toFile: pfConfPath, atomically: true, encoding: .utf8)
        }
        if !isTesting {
            if let token = try? String(contentsOfFile: tokenPath, encoding: .utf8), !token.isEmpty {
                _ = shell("/sbin/pfctl", ["-X", token.trimmingCharacters(in: .whitespacesAndNewlines), "-f", "/etc/pf.conf"])
            } else {
                _ = shell("/sbin/pfctl", ["-f", "/etc/pf.conf"])
            }
            try? FileManager.default.removeItem(atPath: tokenPath)
            flushDNS()
        }
        log("Website block removed")
    }

    /// True if anything of ours is in /etc/hosts or pf.conf.
    static var isApplied: Bool {
        let hosts = (try? String(contentsOfFile: hostsPath, encoding: .utf8)) ?? ""
        let conf = (try? String(contentsOfFile: pfConfPath, encoding: .utf8)) ?? ""
        return hosts.contains(beginMarker) || conf.contains(anchorName) || FileManager.default.fileExists(atPath: tokenPath)
    }

    /// True if the hosts entries and pf anchor are still in place (nobody edited them out).
    static func isIntact(domains: [String]) -> Bool {
        guard let hosts = try? String(contentsOfFile: hostsPath, encoding: .utf8),
              hosts.contains(hostsSection(for: domains)) else { return false }
        guard let conf = try? String(contentsOfFile: pfConfPath, encoding: .utf8), conf.contains(anchorName),
              let anchor = try? String(contentsOfFile: anchorPath, encoding: .utf8), anchor == lastAnchorRules
        else { return false }
        if isTesting { return true }
        return shell("/sbin/pfctl", ["-s", "info"]).contains("Status: Enabled")
    }

    // MARK: hosts

    static func hostsSection(for domains: [String]) -> String {
        var lines = [beginMarker]
        for host in domains.flatMap(Domains.hostVariants) {
            lines.append("0.0.0.0\t\(host)")
            lines.append("::\t\(host)")
        }
        lines.append(endMarker)
        return lines.joined(separator: "\n")
    }

    /// Replaces (or removes, if nil) our section of /etc/hosts, leaving everything else untouched.
    static func writeHosts(section: String?) {
        let current = (try? String(contentsOfFile: hostsPath, encoding: .utf8)) ?? ""
        var lines: [String] = []
        var inside = false
        for line in current.components(separatedBy: "\n") {
            if line == beginMarker { inside = true; continue }
            if line == endMarker { inside = false; continue }
            if !inside { lines.append(line) }
        }
        var text = lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
        if let section { text += "\n\n" + section }
        text += "\n"
        if text != current {
            do { try text.write(toFile: hostsPath, atomically: true, encoding: .utf8) }
            catch { log("Failed writing hosts: \(error)") }
        }
    }

    // MARK: pf

    static func pfRules(for addresses: [String]) -> String {
        var text = """
        # \(anchorName) ruleset for SelfControl Next blocks
        """
        text += "\n"
        for ip in addresses {
            text += "block return out proto tcp from any to \(ip)\n"
            text += "block return out proto udp from any to \(ip)\n"
        }
        return text
    }

    static func writeAnchor(rules: String) {
        try? FileManager.default.createDirectory(atPath: (anchorPath as NSString).deletingLastPathComponent,
                                                 withIntermediateDirectories: true)
        try? rules.write(toFile: anchorPath, atomically: true, encoding: .utf8)
    }

    static func addAnchorToPFConf() {
        let conf = (try? String(contentsOfFile: pfConfPath, encoding: .utf8)) ?? ""
        guard !conf.contains(anchorName) else { return }
        let text = conf.trimmingCharacters(in: .whitespacesAndNewlines)
            + "\nanchor \"\(anchorName)\"\nload anchor \"\(anchorName)\" from \"/etc/pf.anchors/\(anchorName)\"\n"
        try? text.write(toFile: pfConfPath, atomically: true, encoding: .utf8)
    }

    /// IP addresses (and CIDR ranges) to block for the given entries.
    static func resolveAll(_ domains: [String]) -> [String] {
        var result = Set<String>()
        for entry in domains {
            if Domains.isIPv4(entry) || Domains.isIPRange(entry) { result.insert(entry); continue }
            if isTesting { continue }
            for host in Domains.hostVariants(entry) { result.formUnion(resolve(host)) }
        }
        return result.sorted()
    }

    private static func resolve(_ host: String) -> [String] {
        var hints = addrinfo(ai_flags: 0, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM, ai_protocol: 0,
                             ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &info) == 0, let first = info else { return [] }
        defer { freeaddrinfo(info) }
        var addresses: [String] = []
        for ptr in sequence(first: first, next: { $0.pointee.ai_next }) {
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(ptr.pointee.ai_addr, ptr.pointee.ai_addrlen, &buffer, socklen_t(buffer.count),
                           nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: buffer)
                // Skip loopback/unspecified answers (e.g. from our own hosts entries).
                if !["0.0.0.0", "::", "127.0.0.1", "::1"].contains(ip) { addresses.append(ip) }
            }
        }
        return addresses
    }

    private static func flushDNS() {
        _ = shell("/usr/bin/dscacheutil", ["-flushcache"])
        _ = shell("/usr/bin/killall", ["-HUP", "mDNSResponder"])
    }
}

@discardableResult
func shell(_ executable: String, _ arguments: [String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do { try process.run() } catch { return "" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(data: data, encoding: .utf8) ?? ""
}

func log(_ message: String) {
    NSLog("SelfControlNext: %@", message)
}
