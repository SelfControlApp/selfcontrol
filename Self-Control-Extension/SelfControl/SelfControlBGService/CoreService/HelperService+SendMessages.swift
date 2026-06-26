//
//  HelperService+Messages.swift
//  SelfControl
//
//  Created by Satendra Singh on 18/05/26.
//

import Foundation

extension HelperService {
    static var proxyConnectionService: HelperClientProtocol? {
        AppDelegate.shared.service.proxyConnectionService()
    }
    
    static func send_didEnableWebExtension(_ extensionTypeRawValue: String, state: Bool) {
        proxyConnectionService?.didEnableWebExtension(extensionTypeRawValue, state: state)
        AppDelegate.shared.service.networkExtension.sendMessageToSetActiveBrowserExtension(extensionTypeRawValue, state: state)
    }
    
    static func send_didStartedBlocking(_ state: Bool, _ endDate: Date) {
        proxyConnectionService?.didStartedBlocking(state, endDate)
    }
}
