import Foundation
import Combine
import SafariServices

/// ViewModel to manage blocked paths and write the blockerList.json into the App Group container.
class BlockListViewModel: ObservableObject {
    @Published var blockedPaths: [String] = [
        "facebook.com/friends",
        "youtube.com/shorts/",
        "example.com/private/"
    ]
    private let appGroup = "group.com.application.SelfControl.corebits"
    private let extensionIdentifier = "com.application.SelfControl.corebits.SelfControl-Safari-Extension"

    func addSample() {
        blockedPaths.append("example.com/private/")
    }

    func remove(at index: Int) {
        guard index >= 0 && index < blockedPaths.count else { return }
        blockedPaths.remove(at: index)
    }

    func resetToDefaults() {
        blockedPaths = [
            "facebook.com/friends",
            "youtube.com/shorts/",
            "example.com/private/"
        ]
    }

    func updateBlocker() {
        let urls = ProxyPreferences.getBlockedDomains()
        print("URLS: \(urls)")
        BlockListManager.updateSafariBlockList(blockedPaths: urls, appGroup: appGroup, extensionIdentifier: extensionIdentifier)
    }
}
