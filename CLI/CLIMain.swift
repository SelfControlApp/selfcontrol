import Foundation

/// Entry point for the stone-cli command-line tool.
@main
struct CLIEntry {
    static func main() {
        let args = CommandLine.arguments

        guard args.count > 1 else {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        // Parse --uid if present
        var controllingUID = getuid()
        if let uidIdx = args.firstIndex(of: "--uid"), uidIdx + 1 < args.count,
           let uid = UInt32(args[uidIdx + 1]) {
            controllingUID = uid_t(uid)
        }

        let command = args.first { !$0.hasPrefix("--") && $0 != args[0] && $0 != String(controllingUID) }
            ?? args[1]

        switch command {
        case "start", "--start", "--install":
            handleStart(args: args, controllingUID: controllingUID)

        case "is-running", "--isrunning", "-r":
            let isRunning = SCBlockUtilities.anyBlockIsRunning()
            print(isRunning ? "YES" : "NO")

        case "print-settings", "--printsettings", "-p":
            let settings = SCSettings.shared.dictionaryRepresentation()
            print(settings)

        case "version", "--version", "-v":
            print(StoneConstants.versionString)

        default:
            printUsage()
        }
    }

    // MARK: - Start Command

    static func handleStart(args: [String], controllingUID: uid_t) {
        if SCBlockUtilities.anyBlockIsRunning() {
            NSLog("ERROR: Block is already running")
            exit(74) // EX_CONFIG
        }

        // Parse --blocklist
        var blocklistPath: String?
        if let idx = args.firstIndex(where: { $0 == "--blocklist" || $0 == "-b" }),
           idx + 1 < args.count {
            blocklistPath = args[idx + 1]
        }

        // Parse --enddate and --duration (mutually exclusive)
        var blockEndDate: Date?
        let endDateStr = argValue(args, for: ["--enddate", "-d"])
        let durationStr = argValue(args, for: ["--duration"])

        if endDateStr != nil && durationStr != nil {
            NSLog("ERROR: --enddate and --duration are mutually exclusive.")
            exit(64) // EX_USAGE
        }

        if let d = durationStr, let minutes = Int(d), minutes > 0 {
            blockEndDate = Date(timeIntervalSinceNow: TimeInterval(minutes * 60))
        } else if let e = endDateStr {
            blockEndDate = ISO8601DateFormatter().date(from: e)
        }

        // Legacy positional fallback: argv[3] = blocklist, argv[4] = enddate
        if (blocklistPath == nil || blockEndDate == nil),
           args.count > 4 {
            blocklistPath = blocklistPath ?? args[3]
            blockEndDate = blockEndDate ?? ISO8601DateFormatter().date(from: args[4])
        }

        var blocklist: [String]
        var blockAsWhitelist = false

        if let path = blocklistPath, let endDate = blockEndDate, endDate.timeIntervalSinceNow >= 1 {
            guard let props = SCBlockFileReaderWriter.readBlocklist(from: URL(fileURLWithPath: path)) else {
                NSLog("ERROR: Block could not be read from file %@", path)
                exit(74)
            }
            blocklist = props["Blocklist"] as? [String] ?? []
            blockAsWhitelist = props["BlockAsWhitelist"] as? Bool ?? false
        } else {
            // Fall back to UserDefaults
            let defaults = UserDefaults.standard
            defaults.register(defaults: StoneConstants.defaultUserDefaults)
            blocklist = defaults.stringArray(forKey: "Blocklist") ?? []
            blockAsWhitelist = defaults.bool(forKey: "BlockAsWhitelist")
            let durationSecs = max(defaults.integer(forKey: "BlockDuration") * 60, 0)
            blockEndDate = Date(timeIntervalSinceNow: TimeInterval(durationSecs))
        }

        guard let endDate = blockEndDate, endDate.timeIntervalSinceNow >= 1 else {
            NSLog("ERROR: Block end date is not in the future")
            exit(74)
        }

        guard !blocklist.isEmpty || blockAsWhitelist else {
            NSLog("ERROR: Blocklist is empty")
            exit(74)
        }

        // Parse --settings (JSON block settings override)
        var blockSettings = defaultBlockSettings()
        if let settingsStr = argValue(args, for: ["--settings", "-s"]),
           let data = settingsStr.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (key, value) in json {
                blockSettings[key] = value
            }
        }

        // Start the block via XPC
        let xpc = SCXPCClient()
        let semaphore = DispatchSemaphore(value: 0)

        xpc.installDaemon { error in
            if let error = error {
                NSLog("ERROR: Failed to install daemon: %@", error.localizedDescription)
                exit(70) // EX_SOFTWARE
            }

            xpc.refreshConnectionAndRun {
                xpc.startBlock(
                    controllingUID: UInt32(controllingUID),
                    blocklist: blocklist,
                    isAllowlist: blockAsWhitelist,
                    endDate: endDate,
                    blockSettings: blockSettings
                ) { error in
                    if let error = error {
                        NSLog("ERROR: Daemon failed to start block: %@", error.localizedDescription)
                        exit(70)
                    }
                    NSLog("INFO: Block successfully added.")
                    semaphore.signal()
                }
            }
        }

        if Thread.isMainThread {
            while semaphore.wait(timeout: .now()) != .success {
                RunLoop.current.run(mode: .default, before: Date())
            }
        } else {
            semaphore.wait()
        }
    }

    // MARK: - Helpers

    static func argValue(_ args: [String], for flags: [String]) -> String? {
        for flag in flags {
            if let idx = args.firstIndex(of: flag), idx + 1 < args.count {
                return args[idx + 1]
            }
        }
        return nil
    }

    static func defaultBlockSettings() -> [String: Any] {
        let defaults = UserDefaults.standard
        defaults.register(defaults: StoneConstants.defaultUserDefaults)
        return [
            "ClearCaches": defaults.bool(forKey: "ClearCaches"),
            "AllowLocalNetworks": defaults.bool(forKey: "AllowLocalNetworks"),
            "EvaluateCommonSubdomains": defaults.bool(forKey: "EvaluateCommonSubdomains"),
            "IncludeLinkedDomains": defaults.bool(forKey: "IncludeLinkedDomains"),
            "BlockSoundShouldPlay": defaults.bool(forKey: "BlockSoundShouldPlay"),
            "BlockSound": defaults.integer(forKey: "BlockSound"),
            "EnableErrorReporting": defaults.bool(forKey: "EnableErrorReporting"),
        ]
    }

    static func printUsage() {
        print("""
        Stone CLI Tool v\(StoneConstants.versionString)
        Usage: stone-cli [--uid <controlling user ID>] <command> [<args>]

        Valid commands:

            start --> starts a Stone block
                --blocklist <path to saved blocklist file>
                --enddate <specified end date for block in ISO8601 format>
                --duration <block duration in minutes (alternative to --enddate)>
                --settings <other block settings in JSON format>

            is-running --> prints YES if a Stone block is currently running, or NO otherwise

            print-settings --> prints the Stone settings being used for the active block

            version --> prints the version of the Stone CLI tool

        Example: stone-cli start --blocklist /path/to/blocklist.stone --duration 60
        """)
    }
}
