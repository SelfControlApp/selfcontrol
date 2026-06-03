//
//  SafariExtensionHandler.swift
//  SelfControl Rules Extension
//
//  Created by Satendra Singh on 16/11/25.
//

import SafariServices
import os.log

typealias Const = SafariExtensionConstants

class SafariExtensionHandler: SFSafariExtensionHandler {
    private let ping = ServerPing.shared
    private let defaults = UserDefaults(suiteName: Const.appGroup)
    var blockedPatterns: Set<String> = [
        "facebook.com/friends",
        "facebook.com/marketplace",
        "instagram.com/explore",
        "youtube.com/feed/subscriptions"
    ]
    
    override init() {
        super.init()
        os_log(.default, "[SC] 🔍] The extension Initialized")
        pingHostApp()
        ping.start()
    }
    
    deinit {
        let defaults = UserDefaults(suiteName: Const.appGroup)
//        defaults?.set(false, forKey: "ready")
        defaults?.synchronize()
    }
    
    let redirectURL = "https://selfcontrol-blocked.local/blocked"  // 🟢 Your custom page
//    private let appGroup = "group.com.application.SelfControl.corebits"
    private var isEanbled: Bool = false
    
    override func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
//        refreshBlockedURLs()
        blockedPatterns = ping.blockedURL
        let profile: UUID?
        if #available(iOS 17.0, macOS 14.0, *) {
            profile = request?.userInfo?[SFExtensionProfileKey] as? UUID
        } else {
            profile = request?.userInfo?["profile"] as? UUID
        }
        os_log(.default, "[SC] 🔍] The extension received a request for profile: %{public}@", profile?.uuidString ?? "none")
        pingHostApp()
        updateExtensionState()
    }

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        typealias MSG = SafariExtensionConstants.MessagesName
        os_log("[SC] 🔍 The extension received a message: %{public}@", messageName)
        if messageName == MSG.reloadList.rawValue {
//            refreshBlockedURLs()
            blockedPatterns = ping.blockedURL
        }
//        if messageName == "ready" {
//                pingHostApp()
//        }

//        if messageName == "enableService" {
//            self.isEanbled = true
//        }
//        if messageName == "disableService" {
//            self.isEanbled = false
//        }
        
//        guard isEanbled else { return }
        guard messageName == MSG.pageVisit.rawValue,
              let urlString = userInfo?["url"] as? String else { return }

        os_log("[SC] 🔍 Received URL: %{public}@", urlString)

        // Match against blocked URLs
        if ping.blockedURL.contains(where: { urlString.contains($0) }) {
            os_log("[SC] 🚫 Blocking and redirecting: %{public}@", urlString)
            page.dispatchMessageToScript(withName: "REDIRECT_BLOCKED_URL", userInfo: ["redirect": redirectURL])
        } else {
            os_log("[SC] 🔍 Blocked URL: %{public}@", ping.blockedURL)
        }
    }
    
    private func pingHostApp() {
        defaults?.set(true, forKey: Const.UserDefaultsKeys.isExtensionReady)
        defaults?.synchronize()
//        updateExtensionState()
    }
    
    private func updateExtensionState() {
//        defaults?.synchronize()
        isEanbled = defaults?.bool(forKey: Const.UserDefaultsKeys.isExtensionEnabled) ?? false
        os_log(.default, "[SC] 🔍] extension State: %{public}d", isEanbled)
    }
    
    
    
//    private func refreshBlockedURLs() {
//        let res = ContentBlockerExtensionRequestHandler.handleRequestList(groupIdentifier: Const.appGroup)
//        os_log(.default, "[SC] 🔍] List of blocked URLs: %{public}@", res ?? "No data")
//        let domains: [String] = res?.map({ $0.trigger.urlFilter }) ?? []
//        os_log(.default, "[SC] 🔍] List of blocked URLs: %{public}@", domains)
//        blockedPatterns = domains
//    }

    func messagexReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        os_log(.default, "[SC] 🔍] The extension messageReceived: %{public}@", messageName)

//        if messageName == "BLOCK_FRIENDS_PAGE" {
//
//            page.getContainingTab { tab in
//                tab.navigate(to: URL(string: "https://www.facebook.com/")!)
//            }
//        }

//        page.getPropertiesWithCompletionHandler { properties in
//            os_log(.default, "[SC] 🔍] The extension received a message (%@) from a script injected into (%@) with userInfo (%@)", messageName, String(describing: properties?.url), userInfo ?? [:])
//        }
//        page.getPropertiesWithCompletionHandler { properties in
//                  print("[SC] 🔍] ✅ Message Name:", messageName)
//                  print("[SC] 🔍] 🌍 Page URL:", properties?.url?.absoluteString ?? "Unknown")
//                  print("[SC] 🔍] 📦 Data Received:", userInfo ?? [:])
//              }
//              // Example: Send response back to JS
//              page.dispatchMessageToScript(withName: "SWIFT_ACK", userInfo: ["received": true])
        if messageName == "BLOCK_FRIENDS_PAGE" {
            // Redirect the tab away from /friends
            page.getContainingTab { tab in
                // Redirect target — change as needed
                if let url = URL(string: "https://www.facebook.com/") {
                    tab.navigate(to: url)
                }
            }
        }

        page.getPropertiesWithCompletionHandler { properties in
            NSLog("The extension received a message (\(messageName)) from a script injected into (\(String(describing: properties?.url))) with userInfo (\(userInfo ?? [:]))")
            if #available(macOS 10.14, *) {
                os_log(.default, "[SC] 🔍] The extension received a message: %{public}@", properties?.url?.description ?? "-")
            } else {
                // Fallback on earlier versions
            }
            if properties?.url?.description.contains("facebook.com/friends") == true {
                page.getContainingTab(completionHandler: { tab in
                    // Fetch the active page for this tab to access its URL via page properties.
                    tab.navigate(to: URL(string: "https://www.corebitss.com")!)
//                    tab.getActivePage { activePage in
//                        guard let activePage = activePage else {
//                            NSLog("The extension received a message (\(messageName)) but the tab has no active page. userInfo (\(userInfo ?? [:]))")
//                            if #available(macOS 10.14, *) {
//                                os_log(.default, "[SC] 🔍] The extension received a message but the tab has no active page.")
//                            }
//                            return
//                        }
//                        activePage.getPropertiesWithCompletionHandler { tabPageProperties in
//                            let tabURLDesc = tabPageProperties?.url?.description ?? "-"
//                            NSLog("The extension received a message (\(messageName)) from a script injected into (\(tabURLDesc)) with userInfo (\(userInfo ?? [:]))")
//                            if #available(macOS 10.14, *) {
//                                os_log(.default, "[SC] 🔍] The extension received a message: %{public}@", tabURLDesc)
//                            }
//                        }
//                    }
                })
            }
        }
    }

    override func toolbarItemClicked(in window: SFSafariWindow) {
        os_log(.default, "[SC] 🔍] The extension's toolbar item was clicked")
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        os_log(.default, "[SC] 🔍] validateToolbarItem")
        validationHandler(true, "")
//        updateExtensionState()
        pingHostApp()
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
    
    
//    func startHeartbeat() {
//        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
//            self.writeHeartbeat()
//        }
//    }
//
//    func writeHeartbeat() {
//        guard let url = FileManager.default
//            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
//            .appendingPathComponent("heartbeat.json") else { return }
//
//        let data: [String: Any] = [
//            "timestamp": Date().timeIntervalSince1970
//        ]
//
//        try? (data as NSDictionary).write(to: url)
//    }
}
