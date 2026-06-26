//
//  SafariExtensionHandler.swift
//  test Safari Ext Extension
//
//  Created by Satendra Singh on 30/10/25.
//

import SafariServices
import os.log

class SafariExtensionHandler: SFSafariExtensionHandler {
    let blockedPatterns: [String] = [
        "facebook.com/friends",
        "facebook.com/marketplace",
        "instagram.com/explore",
        "youtube.com/feed/subscriptions"
    ]

    let redirectURL = "https://selfcontrol-blocked.local/blocked"  // 🟢 Your custom page
    

    override func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        let profile: UUID?
        if #available(iOS 17.0, macOS 14.0, *) {
            profile = request?.userInfo?[SFExtensionProfileKey] as? UUID
        } else {
            profile = request?.userInfo?["profile"] as? UUID
        }

        os_log(.default, "[SC] 🔍] The extension received a request for profile: %{public}@", profile?.uuidString ?? "none")
    }

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        os_log("[SC] 🔍 The extension received a message: %{public}@", messageName)

        guard messageName == "PAGE_VISIT",
              let urlString = userInfo?["url"] as? String else { return }

        os_log("[SC] 🔍 Received URL: %{public}@", urlString)

        // Match against blocked URLs
        if blockedPatterns.contains(where: { urlString.contains($0) }) {
            os_log("[SC] 🚫 Blocking and redirecting: %{public}@", urlString)
            page.dispatchMessageToScript(withName: "REDIRECT_BLOCKED_URL", userInfo: ["redirect": redirectURL])
        }
    }

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
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }

}
