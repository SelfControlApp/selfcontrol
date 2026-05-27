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
    
    func send_startNetwrokBlocking(minutes: Int) {
        bgProxyServiceConnection()?.startNetwrokBlocking(minutes: minutes)
    }
    
    func send_stopNetworkBlocking() {
        bgProxyServiceConnection()?.stopNetworkBlocking()
    }
    
    func send_getBlockedStates() {
        bgProxyServiceConnection()?.getBlockedStates { state, endDate in
            if state == true, let endDate = endDate {
                let minutes: Double = Double(endDate.timeIntervalSinceNow / 60)
                self.blockedStateHandler?(minutes)
            }
            print("REceived Blocked State: \(String(describing: state)), End Date: \(String(describing: endDate))")
        }
    }
}
//TODO: create extension on protocol with shared variable to send these message with static

