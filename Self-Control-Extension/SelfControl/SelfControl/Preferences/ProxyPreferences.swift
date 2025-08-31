//
//  ProxyPreferences.swift
//  SelfControl
//
//  Created by Satendra Singh on 12/07/25.
//


import Foundation

struct ProxyPreferences {
//    static let appGroup = "X6FQ433AWK.com.application.SelfControl.Extension"
    static let blockedDomainsKey = "BlockedDomains"

    static func getBlockedDomains() -> [String] {
        let defaults = UserDefaults.standard
//        let defaults = UserDefaults(suiteName: appGroup)

        return defaults.stringArray(forKey: blockedDomainsKey) ?? []
    }
    
    static func setBlockedDomains(_ domains: [String]) {
//        let defaults = UserDefaults(suiteName: appGroup)
        let defaults = UserDefaults.standard
        defaults.set(domains, forKey: blockedDomainsKey)
    }
}
