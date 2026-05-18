import Foundation
import SafariServices
import os.log

typealias SafariConst = SafariExtensionConstants

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

            let fileURL = containerURL.appendingPathComponent(Constants.SAFARI_BLOCKER_FILE_NAME)
            try data.write(to: fileURL, options: .atomic)

            print("✅ Wrote blockerList.json to: \(fileURL.path)")

//            if SafariExtensionManager.shared.isExtensionReady { //If Safari is ready mark it in the Network extension
            SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: SafariConst.identifier) { state, error in
                    os_log("[SC] 🔍 Safari Extension State Error: %{public}@", error?.localizedDescription ?? "")
                    os_log("[SC] 🔍 Safari Extension State: %{public}d", state?.isEnabled ?? false)
                    print("Safari Extension State Error :\(String(describing: error))")
                    print("Safari Extension State :\(state?.isEnabled ?? false)")
                    Task { @MainActor in
                        if NetworkExtensionState.shared.isEnabled == true {
                            _ = IPCConnectionProxy().sendMessageToSetActiveBrowserExtension(ActiveBrowserExtensios.safari.rawValue, state: state?.isEnabled ?? false)
                            NetworkExtensionState.shared.isSafariExtensionEnabled = state?.isEnabled ?? false
                            NetworkExtensionState.shared.printAll()
                        }
                    }
                }
//            }
        SFSafariApplication.dispatchMessage(
                withName: SafariConst.MessagesName.reloadList.rawValue,
                toExtensionWithIdentifier: SafariConst.identifier,
                userInfo: ["changed": true]) { error in
                    os_log("[SC] 🔍 Safari Message toExtensionWithIdentifier: reloadList: %{public}@", error?.localizedDescription ?? "")
                    print("Safari Message toExtensionWithIdentifier: reloadList:", error)
                    if error == nil {
                        Task { @MainActor in
                            if NetworkExtensionState.shared.isEnabled == true && NetworkExtensionState.shared.isSafariExtensionEnabled == false { //possibly extension is ready now
                                _ = IPCConnectionProxy().sendMessageToSetActiveBrowserExtension(ActiveBrowserExtensios.safari.rawValue, state: true)
                                NetworkExtensionState.shared.isSafariExtensionEnabled = true
                                NetworkExtensionState.shared.printAll()
                            }
                        }
                    }
                }
        } catch {
            print("❌  Safari Error writing blocker file:", error)
        }
    }
    
    static func updateExtensionState() {
        Task { @MainActor in
            if NetworkExtensionState.shared.isEnabled == true {
                IPCConnectionProxy().sendMessageToSetActiveBrowserExtension(ActiveBrowserExtensios.safari.rawValue, state: SafariExtensionManager.shared.isExtensionReady)
            }
        }
    }
    
    static func activateSafariBlocking() {
        updateExtensionState()
        SafariExtensionManager.shared.enableExtension()
        os_log("Safari Message toExtensionWithIdentifier activateSafariBlocking called:")
    }
    
    static func deactivateSafariBlocking() {
        updateExtensionState()
        SafariExtensionManager.shared.disableExtension()
        _ = IPCConnectionProxy().sendMessageToSetActiveBrowserExtension(ActiveBrowserExtensios.safari.rawValue, state: SafariExtensionManager.shared.isExtensionReady)
        os_log("Safari Message toExtensionWithIdentifier deactivateSafariBlocking called:")
    }
}
