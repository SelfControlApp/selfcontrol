//
//  ExtensionsPreferencesManager.swift
//  SelfControl
//
//  Created by Satendra Singh on 12/07/25.
//

import Foundation
import os.log

final class ExtensionsPreferencesManager {
    let appGroup = "X6FQ433AWK.com.application.SelfControl.Extension"
    var blockedDomains: [String] = []
    lazy var defaults = UserDefaults(suiteName: appGroup)
    
    init(blockedDomains: [String]) {
        self.blockedDomains = blockedDomains
    }
    
    init () {
        blockedDomains = defaults?.stringArray(forKey: "BlockedDomains") ?? []
        os_log("SC] 🔍 DNS Blocked Domains Loaded: %{public}@", blockedDomains)
    }
}
