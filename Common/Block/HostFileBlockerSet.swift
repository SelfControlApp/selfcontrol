import Foundation

/// Coordinates multiple HostFileBlocker instances — one for /etc/hosts
/// plus any custom resolver files found in /etc/resolver/.
final class HostFileBlockerSet {
    private var blockers: [HostFileBlocker] = []

    init() {
        // Always include the main hosts file
        blockers.append(HostFileBlocker(filePath: "/etc/hosts"))

        // Check for resolver-based hosts files (uncommon but possible)
        let resolverDir = "/etc/resolver"
        let fm = FileManager.default
        if fm.fileExists(atPath: resolverDir),
           let resolvers = try? fm.contentsOfDirectory(atPath: resolverDir) {
            for resolver in resolvers {
                let path = (resolverDir as NSString).appendingPathComponent(resolver)
                // Only add if it looks like it might contain hosts-style entries
                if let content = try? String(contentsOfFile: path, encoding: .utf8),
                   content.contains("nameserver") {
                    // This is a DNS resolver config, not a hosts file — skip
                    continue
                }
            }
        }
    }

    func addEntry(hostname: String) {
        for blocker in blockers {
            blocker.addEntry(hostname: hostname)
        }
    }

    func addEntries(_ hostnames: [String]) {
        for blocker in blockers {
            blocker.addEntries(hostnames)
        }
    }

    func writeNewFileContents() -> Bool {
        var success = true
        for blocker in blockers {
            if !blocker.writeNewFileContents() { success = false }
        }
        return success
    }

    func clearBlock() -> Bool {
        var success = true
        for blocker in blockers {
            if !blocker.clearBlock() { success = false }
        }
        return success
    }

    func isBlockActive() -> Bool {
        for blocker in blockers {
            if blocker.isBlockActive() { return true }
        }
        return false
    }

    func appendEntries(_ hostnames: [String]) -> Bool {
        var success = true
        for blocker in blockers {
            if !blocker.appendEntries(hostnames) { success = false }
        }
        return success
    }
}
