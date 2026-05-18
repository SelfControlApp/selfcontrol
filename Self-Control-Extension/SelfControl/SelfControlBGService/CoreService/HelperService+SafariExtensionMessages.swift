//
//  HelperService+AppToExtensionExtension.swift
//  SelfControl
//
//  Created by Satendra Singh on 17/05/26.
//
import OSLog
import Foundation

extension HelperService: AppToExtensionExtension {
    
    func register(_ completionHandler: @escaping (Bool) -> Void) {
        queue.async {
            IPCConnection.shared.register(completionHandler)
        }
    }
    
    func setBlockedURLs(_ urls: [String]) {
        queue.async {
            IPCConnection.shared.enableURLBlocking(urls)
        }
    }
    
    func setActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool) {
        queue.async {
            IPCConnection.shared.setActiveBrowserExtension(extensionTypeRawValue, state: state)
        }
    }
    
    func setEnableService(_ enable: Bool) {
        queue.async {
            _ = IPCConnection.shared.sendMessageToEnableNetworkExtension(enable)
        }
    }
    
    func sendMessageToSetActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool) {
        queue.async {
            _ = IPCConnection.shared.sendMessageToSetActiveBrowserExtension(extensionTypeRawValue, state: state)
        }
    }
    
    func register(completionHandler: @escaping (Bool) -> Void) {
        queue.async {
            IPCConnection.shared.register(completionHandler: completionHandler)
        }
    }
}
