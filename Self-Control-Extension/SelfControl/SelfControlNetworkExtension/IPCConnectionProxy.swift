//
//  IPCConnectionProxy.swift
//  SelfControl
//
//  Created by Satendra Singh on 17/05/26.
//

import Foundation

class IPCConnectionProxy: NSObject, AppToExtensionExtension {
    
    func sendMessageToSetActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool) {
        HelperConnection.shared.sendMessageToSetActiveBrowserExtension(extensionTypeRawValue, state: state)
    }
    
    
    func register(completionHandler: @escaping (Bool) -> Void) {
        HelperConnection.shared.register(completionHandler: completionHandler)
    }
    
    func register(_ completionHandler: @escaping (Bool) -> Void) {
        HelperConnection.shared.register(completionHandler)
    }
    
    func setBlockedURLs(_ urls: [String]) {
        HelperConnection.shared.setBlockedURLs(urls)
    }
    
    func setActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool) {
        HelperConnection.shared.setActiveBrowserExtension(extensionTypeRawValue, state: state)
    }
    
    func setEnableService(_ enable: Bool) {
        HelperConnection.shared.setEnableService(enable)
    }
}
