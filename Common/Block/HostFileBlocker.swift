import Foundation

/// Manages blocking entries in a hosts file using sentinel markers.
final class HostFileBlocker {
    private let filePath: String
    private var newEntries: [String] = []
    private let lock = NSLock()

    init(filePath: String = "/etc/hosts") {
        self.filePath = filePath
    }

    // MARK: - Entry Management

    func addEntry(hostname: String) {
        lock.lock()
        defer { lock.unlock() }
        let clean = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        newEntries.append("0.0.0.0\t\(clean)")
        newEntries.append("::1\t\(clean)")
    }

    func addEntries(_ hostnames: [String]) {
        for h in hostnames { addEntry(hostname: h) }
    }

    // MARK: - File Operations

    func writeNewFileContents() -> Bool {
        guard !newEntries.isEmpty else { return true }

        guard var contents = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            NSLog("HostFileBlocker: Failed to read %@", filePath)
            return false
        }

        // Remove any existing block first
        contents = removeBlockSection(from: contents)

        // Append new block
        var block = "\n\(StoneConstants.hostsSentinelBegin)\n"
        for entry in newEntries {
            block += entry + "\n"
        }
        block += "\(StoneConstants.hostsSentinelEnd)\n"

        contents += block

        do {
            try contents.write(toFile: filePath, atomically: true, encoding: .utf8)
            return true
        } catch {
            NSLog("HostFileBlocker: Failed to write %@: %@", filePath, error.localizedDescription)
            return false
        }
    }

    func clearBlock() -> Bool {
        guard var contents = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return false
        }

        let cleaned = removeBlockSection(from: contents)
        if cleaned == contents { return true } // nothing to remove

        do {
            try cleaned.write(toFile: filePath, atomically: true, encoding: .utf8)
            return true
        } catch {
            NSLog("HostFileBlocker: Failed to clear block in %@: %@", filePath, error.localizedDescription)
            return false
        }
    }

    func isBlockActive() -> Bool {
        guard let contents = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return false
        }
        return contents.contains(StoneConstants.hostsSentinelBegin)
    }

    // MARK: - Append Mode (for adding to a running block)

    func appendEntries(_ hostnames: [String]) -> Bool {
        guard var contents = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return false
        }

        guard let endRange = contents.range(of: StoneConstants.hostsSentinelEnd) else {
            return false
        }

        var newLines = ""
        for h in hostnames {
            let clean = h.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            newLines += "0.0.0.0\t\(clean)\n"
            newLines += "::1\t\(clean)\n"
        }

        contents.insert(contentsOf: newLines, at: endRange.lowerBound)

        do {
            try contents.write(toFile: filePath, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private

    private func removeBlockSection(from contents: String) -> String {
        guard let beginRange = contents.range(of: StoneConstants.hostsSentinelBegin),
              let endRange = contents.range(of: StoneConstants.hostsSentinelEnd) else {
            return contents
        }

        // Include the newline after END marker
        let removeEnd = contents.index(after: endRange.upperBound) < contents.endIndex
            ? contents.index(after: endRange.upperBound)
            : endRange.upperBound

        var result = contents
        result.removeSubrange(beginRange.lowerBound..<removeEnd)
        return result
    }
}
