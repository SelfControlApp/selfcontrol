import Foundation

/// Reads and writes .stone blocklist files (binary plist format).
enum SCBlockFileReaderWriter {

    /// Read a blocklist from a .stone file. Returns dict with "Blocklist" and "BlockAsWhitelist" keys.
    static func readBlocklist(from url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) as? [String: Any] else {
            return nil
        }

        guard plist["Blocklist"] != nil else { return nil }
        return plist
    }

    /// Write a blocklist to a .stone file in binary plist format.
    @discardableResult
    static func writeBlocklist(to url: URL, blockInfo: [String: Any]) throws -> Bool {
        let data = try PropertyListSerialization.data(
            fromPropertyList: blockInfo,
            format: .binary,
            options: 0
        )
        try data.write(to: url, options: .atomic)
        return true
    }
}
