//
//  SafariExtensionConstants.swift
//  SelfControl Rules Extension
//
//  Created by Satendra Singh on 09/12/25.
//

import Foundation

struct SafariExtensionConstants {
    static let identifier = "com.application.SelfControl.corebits.SelfControl-Safari-Extension"
    static let appGroup = "group.com.application.SelfControl.corebits"
    static let serviceURL = "http://127.0.0.1:\(servicePort)/safari"
    static let servicePort: UInt16 = 8532

    struct UserDefaultsKeys {
        static let isExtensionEnabled = "enabled"
        static let isExtensionReady = "ready"
    }
    
    enum MessagesName: String {
        case reloadList = "reloadList"
        case pageVisit = "PAGE_VISIT"
        case redirect = "REDIRECT_BLOCKED_URL"
    }
    
    struct SafariBlockerFile {
        static let name: String = "blockerList"
        static let ext: String = "json"
        static var fullName: String { name + "." + ext }
    }
}
