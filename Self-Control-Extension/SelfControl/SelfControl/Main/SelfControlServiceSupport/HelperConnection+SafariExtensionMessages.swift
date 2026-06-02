//
//  File.swift
//  SelfControl
//
//  Created by Satendra Singh on 17/05/26.
//

extension HelperConnection: AppToExtensionExtension {
    func register(_ completionHandler: @escaping (Bool) -> Void) {
        bgProxyServiceConnection()?.register(completionHandler)
    }
    
    func setBlockedURLs(_ urls: [String]) {
        bgProxyServiceConnection()?.setBlockedURLs(urls)
    }
    
    func setActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool) {
        bgProxyServiceConnection()?.setActiveBrowserExtension(extensionTypeRawValue, state: state)
    }
    
    func sendMessageToSetActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool){
        bgProxyServiceConnection()?.sendMessageToSetActiveBrowserExtension(extensionTypeRawValue, state: state)
    }
    
    func setEnableService(_ enable: Bool) {
        bgProxyServiceConnection()?.setEnableService(enable)
    }
    
    func register(completionHandler: @escaping (Bool) -> Void) {
        bgProxyServiceConnection()?.register(completionHandler)
    }
}
//TODO: create extension on protocol with shared variable to send these message with static

