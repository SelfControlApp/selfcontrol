//
//  AppStateManager.swift
//  SelfControlBGService
//
//  Created by Satendra Singh on 18/05/26.
//

import Foundation
import os.log

actor AppStateManager {
    static let shared = AppStateManager()
    var isBlockingEnabled: Bool = false
    private var safariLastApiUpdateReceivedTime = Date()
    private var isSafariExtensionRunning: Bool = false
    private var isChromeExtensionRunning: Bool = false
    
    func handleApiRequest(path: ServicePath) {
        switch path {
        case .safari:
            receivedSafariApiRequest()
        case .chrome:
            receivedChromeApiRequest()
        }
    }
    
    private func receivedSafariApiRequest() {
        safariLastApiUpdateReceivedTime = Date()
        guard !isChromeExtensionRunning else { return }
        isChromeExtensionRunning = true
        HelperService.send_didEnableWebExtension(WEBExtension.chrome.rawValue, state: true)
    }
    
    private func receivedChromeApiRequest() {
        guard !isChromeExtensionRunning else { return }
        isChromeExtensionRunning = true
        HelperService.send_didEnableWebExtension(WEBExtension.chrome.rawValue, state: true)
    }
    
    func activateContentBlocking() {
        isBlockingEnabled = true
    }
    
    func deactivateContentBlocking() {
        isBlockingEnabled = false
        os_log("[SC] 🔍] BG deactivateContentBlocking: %{public}d",isBlockingEnabled)
    }
    
    func reset() {
        safariLastApiUpdateReceivedTime = Date()
        isSafariExtensionRunning = false
        isChromeExtensionRunning = false
    }
}
