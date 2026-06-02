//
//  ProxyPreferences.swift
//  SelfControl
//
//  Created by Satendra Singh on 12/07/25.
//


import Foundation

struct AppPreferences {
//    static let appGroup = "X6FQ433AWK.com.application.SelfControl.Extension"
    private static let blockedDomainsKey = "BlockedDomains"
    private static let isSafariExtensionKey: String = "isSafariExtensionKey"
    private static let isChromeExtensionKey: String = "isChromeExtensionKey"
    private static let isSafariExtInstallKey: String = "isSafariExtInstallKey"
    private static let isChromeExtInstallKey: String = "isChromeExtInstallKey"
    static let playSoundOnCompletionkey: String = "playSoundOnCompletion"
    private static let showNotificationOnCompletionkey: String = "showNotificationOnCompletion"
    private static let verifyNetworkBeforeBlock: String = "VerifyInternetConnection"
    
    private static let defaults = UserDefaults.standard
    static func getBlockedDomains() -> [String] {
        return defaults.stringArray(forKey: blockedDomainsKey) ?? []
    }
    
    static func setBlockedDomains(_ domains: [String]) {
        defaults.set(domains, forKey: blockedDomainsKey)
    }
    
    static func setSafariExtensionState(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: isSafariExtensionKey)
    }
    
    static func setChromeExtensionState(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: isChromeExtensionKey)
    }
    
    static func safariExtensionState() {
        defaults.value(forKey: isSafariExtensionKey)

    }
    
    static func chromeExtensionState() {
        defaults.value(forKey: isChromeExtensionKey)
    }
    
    static var isSafariExtensionInstalled: Bool {
        return UserDefaults.standard.bool(forKey: isSafariExtInstallKey)
    }

    static func setSafariExtensionInstalled() {
        UserDefaults.standard.set(true, forKey: isSafariExtInstallKey)
    }
    
    static var isChromeExtensionInstalled: Bool {
        return UserDefaults.standard.bool(forKey: isChromeExtInstallKey)
    }
    
    static var playSoundOnCompletion: Bool {
        return UserDefaults.standard.bool(forKey: playSoundOnCompletionkey)
    }
    
    static var showNotificationOnCompletion: Bool {
        return UserDefaults.standard.bool(forKey: showNotificationOnCompletionkey)
    }
    
    static func setChromeExtensionInstalled() {
        UserDefaults.standard.set(true, forKey: isChromeExtInstallKey)
    }
    
    static var showVerifyNetworkAlertBeforeBlock: Bool {
        return UserDefaults.standard.bool(forKey: verifyNetworkBeforeBlock)
    }
    
    static func setShowVerifyNetworkAlertBeforeBlock(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: verifyNetworkBeforeBlock)
    }
    
    static func reset() {
        UserDefaults.standard.removeObject(forKey: isChromeExtInstallKey)
        UserDefaults.standard.removeObject(forKey: isSafariExtInstallKey)
        UserDefaults.standard.removeObject(forKey: isSafariExtensionKey)
        UserDefaults.standard.removeObject(forKey: isChromeExtensionKey)
    }
    
    static var soundNames: [String] {
        ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
    }
}
