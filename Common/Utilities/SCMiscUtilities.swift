import Foundation
import CommonCrypto

/// Miscellaneous utility functions used across the app.
enum SCMiscUtilities {

    /// Get the hardware serial number.
    static func serialNumber() -> String? {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard platformExpert != 0 else { return nil }
        defer { IOObjectRelease(platformExpert) }

        guard let serialRef = IORegistryEntryCreateCFProperty(
            platformExpert,
            "IOPlatformSerialNumber" as CFString,
            kCFAllocatorDefault, 0
        ) else { return nil }

        return serialRef.takeUnretainedValue() as? String
    }

    /// SHA1 hash of a string, returned as hex.
    static func sha1Hex(_ input: String) -> String {
        let data = Data(input.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest) }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// The path to the tamper-resistant settings file for this machine.
    static func settingsFilePath() -> String {
        let serial = serialNumber() ?? "unknown"
        let hash = sha1Hex("\(StoneConstants.settingsFilePrefix)\(serial)")
        return "/usr/local/etc/.\(hash).plist"
    }

    /// Clean a blocklist by trimming whitespace, removing empty entries and duplicates.
    static func cleanBlocklist(_ entries: [String]) -> [String] {
        var seen = Set<String>()
        return entries.compactMap { entry in
            let cleaned = entry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !cleaned.isEmpty, !seen.contains(cleaned) else { return nil }
            seen.insert(cleaned)
            return cleaned
        }
    }

    /// Whether the given error represents the user canceling an authorization dialog.
    static func errorIsAuthCanceled(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSOSStatusErrorDomain && nsError.code == errAuthorizationCanceled
    }
}
