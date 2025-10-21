import Foundation
import SafariServices

struct BlockRule: Codable {
    struct Trigger: Codable {
        let urlFilter: String

        enum CodingKeys: String, CodingKey {
            case urlFilter = "url-filter"
        }
    }

    struct Action: Codable {
        let type: String
    }

    let trigger: Trigger
    let action: Action
}


enum BlockListManager {
    
    static func updateSafariBlockList(blockedPaths: [String], appGroup: String, extensionIdentifier: String) {
        var rules: [BlockRule] = []

        for path in blockedPaths {
//            let components = path.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
//            let domain = String(components[0])
//            let pathPart = components.count == 2 ? String(components[1]) : ""
//
//            let escapedDomain = NSRegularExpression.escapedPattern(for: domain)
//            var pattern = "^https?://(www\\.)?" + escapedDomain
//            if !pathPart.isEmpty {
//                let escapedPath = NSRegularExpression.escapedPattern(for: pathPart)
//                pattern += "/" + escapedPath
//            }
//            pattern += ".*"

//            rules.append(BlockRule(
//                trigger: .init(urlFilter: SimpleRegexConverter.regexFromURL(path) ?? path),
//                action: .init(type: "block")
//            ))
            rules.append(BlockRule(
                trigger: .init(urlFilter: path),
                action: .init(type: "block")
            ))
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(rules)

            let fileManager = FileManager.default
            guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
                print("❌ App group container not found.")
                return
            }

            // Ensure folder exists before writing
            try fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true, attributes: nil)

            let fileURL = containerURL.appendingPathComponent("blockerList.json")
            try data.write(to: fileURL, options: .atomic)

            print("✅ Wrote blockerList.json to: \(fileURL.path)")

            // Query current state for diagnostics; proceed to reload regardless.
            SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: extensionIdentifier) { state, error in
                if let error = error as NSError? {
                    print("⚠️ State check error for \(extensionIdentifier): \(error.domain) code \(error.code) – \(error.localizedDescription)")
                    print("ℹ️ Tips: Ensure the content blocker extension bundle identifier matches exactly, the extension is installed and enabled in Safari, and the app/extension share the same App Group: \(appGroup)")
                } else {
                    print("🔍 Current state of \(extensionIdentifier):", state?.description ?? "Unknown")
                    if state?.isEnabled == false {
                        print("⚠️ Extension not enabled in Safari. Please enable it in Settings → Safari → Extensions.")
                    }
                }

                // Attempt reload regardless; this often yields a clearer error if the identifier is wrong.
                SFContentBlockerManager.reloadContentBlocker(withIdentifier: extensionIdentifier) { error in
                    if let error = error as NSError? {
                        print("❌ Reload error for \(extensionIdentifier): \(error.domain) code \(error.code) – \(error.localizedDescription)")
                        print("ℹ️ If this persists: verify the extension target’s bundle ID, that the extension is enabled, and that it has access to the shared container.")
                    } else {
                        print("✅ Safari Content Blocker reloaded successfully.")
                    }
                }
            }

        } catch {
            print("❌ Error writing blocker file:", error)
        }
    }
}
