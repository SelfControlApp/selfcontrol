import Foundation

// MARK: - Protocol for testability

protocol PFConfigurationStore {
    var pfAnchorPath: String { get }
    var pfConfPath: String { get }
    var pfTokenPath: String { get }
}

struct DefaultPFConfigurationStore: PFConfigurationStore {
    var pfAnchorPath: String { "/etc/pf.anchors/\(StoneConstants.pfAnchorName)" }
    var pfConfPath: String { "/etc/pf.conf" }
    var pfTokenPath: String { "/etc/StonePFToken" }
}

// MARK: - PacketFilter

final class PacketFilter {

    private let isAllowlist: Bool
    private let store: PFConfigurationStore
    private var rules = ""
    private var appendFileHandle: FileHandle?
    private let lock = NSLock()

    private static let pfctlPath = "/sbin/pfctl"

    init(isAllowlist: Bool, store: PFConfigurationStore = DefaultPFConfigurationStore()) {
        self.isAllowlist = isAllowlist
        self.store = store
    }

    // MARK: - Static checks

    static func blockFoundInPF(store: PFConfigurationStore = DefaultPFConfigurationStore()) -> Bool {
        guard let contents = try? String(contentsOfFile: store.pfConfPath, encoding: .utf8) else {
            return false
        }
        return contents.contains("anchor \"\(StoneConstants.pfAnchorName)\"")
    }

    func containsStoneBlock() -> Bool {
        guard let contents = try? String(contentsOfFile: store.pfConfPath, encoding: .utf8) else {
            return false
        }
        return contents.contains(StoneConstants.pfAnchorName)
    }

    // MARK: - Rule generation

    private func ruleStrings(ip: String?, port: Int, maskLen: Int) -> [String] {
        var target = "from any to "
        target += ip ?? "any"
        if maskLen != 0 {
            target += "/\(maskLen)"
        }
        if port != 0 {
            target += " port \(port)"
        }

        if isAllowlist {
            return [
                "pass out proto tcp \(target)\n",
                "pass out proto udp \(target)\n"
            ]
        } else {
            return [
                "block return out proto tcp \(target)\n",
                "block return out proto udp \(target)\n"
            ]
        }
    }

    func addRule(ip: String?, port: Int, maskLen: Int) {
        lock.lock()
        defer { lock.unlock() }

        let strings = ruleStrings(ip: ip, port: port, maskLen: maskLen)
        for rule in strings {
            if let handle = appendFileHandle {
                if let data = rule.data(using: .utf8) {
                    handle.write(data)
                }
            } else {
                rules += rule
            }
        }
    }

    // MARK: - Configuration writing

    private func blockHeader() -> String {
        var header = """
        # Options
        set block-policy drop
        set fingerprints "/etc/pf.os"
        set ruleset-optimization basic
        set skip on lo0

        #
        # \(StoneConstants.pfAnchorName) ruleset for Stone blocks
        #\n
        """

        if isAllowlist {
            header += "block return out proto tcp from any to any\n"
            header += "block return out proto udp from any to any\n\n"
        }

        return header
    }

    private func allowlistFooter() -> String {
        return """
        pass out proto tcp from any to any port 53
        pass out proto udp from any to any port 53
        pass out proto udp from any to any port 123
        pass out proto udp from any to any port 67
        pass out proto tcp from any to any port 67
        pass out proto udp from any to any port 68
        pass out proto tcp from any to any port 68
        pass out proto udp from any to any port 5353
        pass out proto tcp from any to any port 5353\n
        """
    }

    func writeConfiguration() {
        var config = blockHeader()
        config += rules
        if isAllowlist {
            config += allowlistFooter()
        }
        try? config.write(toFile: store.pfAnchorPath, atomically: true, encoding: .utf8)
    }

    // MARK: - Append mode

    func enterAppendMode() {
        if isAllowlist {
            NSLog("WARNING: Can't append rules to allowlist blocks - ignoring")
            return
        }

        appendFileHandle = FileHandle(forWritingAtPath: store.pfAnchorPath)
        guard appendFileHandle != nil else {
            NSLog("ERROR: Failed to get handle for pf.anchors file while attempting to append rules")
            return
        }
        appendFileHandle?.seekToEndOfFile()
    }

    func finishAppending() {
        try? appendFileHandle?.close()
        appendFileHandle = nil
    }

    // MARK: - pf.conf management

    func addStoneConfig() {
        guard var pfConf = try? String(contentsOfFile: store.pfConfPath, encoding: .utf8) else {
            return
        }

        if !pfConf.contains(store.pfAnchorPath) {
            pfConf += "\n"
            pfConf += "anchor \"\(StoneConstants.pfAnchorName)\"\n"
            pfConf += "load anchor \"\(StoneConstants.pfAnchorName)\" from \"\(store.pfAnchorPath)\"\n"
        }

        try? pfConf.write(toFile: store.pfConfPath, atomically: true, encoding: .utf8)
    }

    // MARK: - Start / Stop

    @discardableResult
    func startBlock() -> Int32 {
        addStoneConfig()
        writeConfiguration()

        let args = ["-E", "-f", store.pfConfPath, "-F", "states"]
        let (status, output) = runPfctl(args)

        // Parse and save the token
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("Token : ") {
                let token = String(line.dropFirst("Token : ".count))
                writePFToken(token)
                break
            }
        }

        return status
    }

    @discardableResult
    func refreshPFRules() -> Int32 {
        let args = ["-f", store.pfConfPath, "-F", "states"]
        let (status, _) = runPfctl(args)
        return status
    }

    @discardableResult
    func stopBlock(force: Bool) -> Int32 {
        let token = readPFToken()

        // Clear anchor file
        try? "".write(toFile: store.pfAnchorPath, atomically: true, encoding: .utf8)

        // Remove Stone lines from pf.conf
        if let mainConf = try? String(contentsOfFile: store.pfConfPath, encoding: .utf8) {
            let lines = mainConf.components(separatedBy: "\n")
            var newConf = lines
                .filter { !$0.contains(StoneConstants.pfAnchorName) }
                .joined(separator: "\n")
            newConf = newConf.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            try? newConf.write(toFile: store.pfConfPath, atomically: true, encoding: .utf8)
        }

        let args: [String]
        if let token = token, !token.isEmpty, !force {
            args = ["-X", token, "-f", store.pfConfPath]
        } else {
            args = ["-d", "-f", store.pfConfPath]
        }

        let (status, _) = runPfctl(args)
        return status
    }

    // MARK: - Token persistence

    private func writePFToken(_ token: String) {
        try? token.write(toFile: store.pfTokenPath, atomically: true, encoding: .utf8)
    }

    private func readPFToken() -> String? {
        return try? String(contentsOfFile: store.pfTokenPath, encoding: .utf8)
    }

    // MARK: - Process helper

    private func runPfctl(_ arguments: [String]) -> (Int32, String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: PacketFilter.pfctlPath)
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
        } catch {
            NSLog("ERROR: Failed to launch pfctl: %@", error.localizedDescription)
            return (-1, "")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (task.terminationStatus, output)
    }
}
