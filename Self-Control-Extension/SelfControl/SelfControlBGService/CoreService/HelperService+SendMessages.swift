//
//  HelperService+Messages.swift
//  SelfControl
//
//  Created by Satendra Singh on 18/05/26.
//

extension HelperService {
    static var proxyConnectionService: HelperClientProtocol? {
        AppDelegate.shared.service.proxyConnectionService()
    }
    
    static func send_didEnableWebExtension(_ extensionTypeRawValue: String, state: Bool) {
        proxyConnectionService?.didEnableWebExtension(extensionTypeRawValue, state: state)
    }
}
