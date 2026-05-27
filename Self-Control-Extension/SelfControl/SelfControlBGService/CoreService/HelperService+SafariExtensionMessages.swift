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
            IPCConnection.shared.register(completionHandler: completionHandler)
        }
    }
    
    func setBlockedURLs(_ urls: [String]) {
        queue.async(flags: .barrier) {
            IPCConnection.shared.enableURLBlocking(urls)
            self.blockedUrls = urls
            BlockContentStore.saveBlockedUrls(blockedUrls: urls)
        }
    }
    
    func setActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool) {
        queue.async {
            IPCConnection.shared.setActiveBrowserExtension(extensionTypeRawValue, state: state)
        }
    }
    
    func setEnableService(_ enable: Bool) { //TODO: REmove // Cleanup
//        queue.async { [weak self] in
//            _ = IPCConnection.shared.sendMessageToEnableNetworkExtension(enable)
//            Task {
//                if enable {
//                    await AppStateManager.shared.activateContentBlocking()
//                } else {
//                    await AppStateManager.shared.deactivateContentBlocking()
//                }
//            }
//        }
    }
    
    func sendMessageToSetActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool) {
        queue.async {
            _ = IPCConnection.shared.sendMessageToSetActiveBrowserExtension(extensionTypeRawValue, state: state)
        }
    }
    
    func register(completionHandler: @escaping (Bool) -> Void) { } //TODO Remove
}
