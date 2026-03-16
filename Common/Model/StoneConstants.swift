import Foundation

/// Central constants for the Stone app, daemon, and CLI.
enum StoneConstants {
    static let versionString = "1.0.0"
    static let bundleIdentifier = "com.max4c.stone"
    static let daemonIdentifier = "com.max4c.stonectld"
    static let cliName = "stone-cli"

    // Mach service name for XPC (must match daemon bundle ID)
    static let machServiceName = "com.max4c.stonectld"

    // Distributed notification names
    static let configurationChangedNotification = "com.max4c.stone.SCSettingsValueChanged"

    // Settings file prefix (hashed with serial number for tamper-resistant path)
    static let settingsFilePrefix = "StoneUserPreferences"

    // Sentinel strings for /etc/hosts and pf rules
    static let hostsSentinelBegin = "# BEGIN STONE BLOCK"
    static let hostsSentinelEnd = "# END STONE BLOCK"
    static let pfAnchorName = "com.max4c.stone"

    // Launchd schedule prefix
    static let scheduleLaunchdPrefix = "com.max4c.stone.schedule"

    // Block sounds
    static let defaultBlockSound = 5
    static let blockSoundNames = [
        "Basso", "Blow", "Bottle", "Frog", "Funk",
        "Glass", "Hero", "Morse", "Ping", "Pop",
        "Purr", "Sosumi", "Submarine", "Tink"
    ]

    /// Default user preferences registered on launch.
    static let defaultUserDefaults: [String: Any] = [
        "BlockDuration": 60,
        "BlockAsWhitelist": false,
        "Blocklist": [] as [String],
        "EvaluateCommonSubdomains": true,
        "IncludeLinkedDomains": true,
        "ClearCaches": true,
        "AllowLocalNetworks": true,
        "BlockSoundShouldPlay": false,
        "BlockSound": defaultBlockSound,
        "MaxBlockLength": 1440,
        "WhitelistHighlightedByDefault": false,
        "BadgeIconEnabled": true,
        "EnableErrorReporting": true,
        "V4MigrationComplete": false,
        "ScheduledBlocks": [] as [[String: Any]],
    ]
}
